import base64
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.api.routes import owned_space
from app.core.config import settings
from app.db.session import get_session
from app.models import Booking, BookingStatus, ParkingSpace, ParkingSpaceImage, Review, User

router = APIRouter(prefix="/api", tags=["marketplace"])

_ALLOWED_IMAGES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


class ReviewIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(min_length=3, max_length=1200)


def _media_root() -> Path:
    root = Path(settings.marketplace_upload_dir)
    root.mkdir(parents=True, exist_ok=True)
    return root


async def _read_image(file: UploadFile) -> tuple[bytes, str]:
    content_type = (file.content_type or "").lower()
    suffix = _ALLOWED_IMAGES.get(content_type)
    if suffix is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "unsupported_image",
                "message": "Bitte lade ein JPG-, PNG- oder WEBP-Bild hoch.",
            },
        )
    payload = await file.read(settings.marketplace_image_max_bytes + 1)
    if not payload or len(payload) > settings.marketplace_image_max_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "image_too_large",
                "message": "Das Bild darf höchstens 8 MB groß sein.",
            },
        )
    return payload, suffix


def _public_media_url(filename: str) -> str:
    return f"/media/{filename}"


def _response_text(payload: dict[str, Any]) -> str:
    values: list[str] = []
    for output in payload.get("output", []):
        for content in output.get("content", []):
            if content.get("type") == "output_text" and content.get("text"):
                values.append(str(content["text"]))
    return "\n".join(values).strip()


async def _review_parking_image(payload: bytes, content_type: str) -> tuple[str, str]:
    if not settings.openai_enabled:
        return "pending", "OpenAI-Prüfung ist noch nicht konfiguriert."

    data_url = f"data:{content_type};base64,{base64.b64encode(payload).decode()}"
    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=45) as client:
            moderation = await client.post(
                "https://api.openai.com/v1/moderations",
                headers=headers,
                json={
                    "model": "omni-moderation-latest",
                    "input": [
                        {
                            "type": "image_url",
                            "image_url": {"url": data_url},
                        }
                    ],
                },
            )
            moderation.raise_for_status()
            if moderation.json().get("results", [{}])[0].get("flagged") is True:
                return "rejected", "Das Bild wurde durch die Inhaltsprüfung abgelehnt."

            response = await client.post(
                "https://api.openai.com/v1/responses",
                headers=headers,
                json={
                    "model": settings.openai_vision_model,
                    "input": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "input_text",
                                    "text": (
                                        "Prüfe dieses Foto für eine Parkplatzplattform. "
                                        "Antworte ausschließlich als JSON mit den Feldern "
                                        "is_parking_space, usable_photo, contains_personal_data "
                                        "(booleans) und reason (kurzer deutscher Text). "
                                        "is_parking_space ist wahr, wenn Garage, Stellplatz, "
                                        "Einfahrt oder Zufahrt klar erkennbar ist. usable_photo "
                                        "ist nur bei ausreichender Helligkeit und Schärfe wahr. "
                                        "contains_personal_data ist wahr bei klar lesbaren "
                                        "Kennzeichen, Dokumenten oder erkennbaren Gesichtern."
                                    ),
                                },
                                {"type": "input_image", "image_url": data_url},
                            ],
                        }
                    ],
                },
            )
            response.raise_for_status()
            result = json.loads(_response_text(response.json()))
            reason = str(result.get("reason") or "Automatische Bildprüfung abgeschlossen.")
            approved = (
                result.get("is_parking_space") is True
                and result.get("usable_photo") is True
                and result.get("contains_personal_data") is not True
            )
            return ("approved", reason) if approved else ("rejected", reason)
    except Exception:
        return "pending", "Automatische Prüfung vorübergehend nicht erreichbar."


@router.get("/locations/suggest")
async def suggest_locations(
    q: str = Query(min_length=3, max_length=160),
) -> list[dict[str, Any]]:
    headers = {
        "User-Agent": f"FREIRAUM/0.9.2 ({settings.nominatim_contact_email})",
        "Accept-Language": "de",
    }
    params = {
        "q": q,
        "format": "jsonv2",
        "addressdetails": "1",
        "countrycodes": "de",
        "limit": "6",
        "email": settings.nominatim_contact_email,
    }
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            response = await client.get(
                f"{settings.nominatim_base_url.rstrip('/')}/search",
                params=params,
                headers=headers,
            )
            response.raise_for_status()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "address_lookup_unavailable",
                "message": "Adressvorschläge sind gerade nicht verfügbar.",
            },
        ) from exc

    results = []
    for item in response.json():
        address = item.get("address") or {}
        results.append(
            {
                "display_name": item.get("display_name"),
                "latitude": float(item["lat"]),
                "longitude": float(item["lon"]),
                "district": (
                    address.get("suburb")
                    or address.get("city_district")
                    or address.get("city")
                    or address.get("town")
                    or "Frankfurt"
                ),
                "road": address.get("road") or address.get("pedestrian"),
                "house_number": address.get("house_number"),
            }
        )
    return results


@router.post("/auth/me/profile-image")
async def upload_profile_image(
    file: UploadFile = File(...),
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    payload, suffix = await _read_image(file)
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    filename = f"profile-{user_id}-{uuid.uuid4().hex}{suffix}"
    (_media_root() / filename).write_bytes(payload)
    user.profile_image_url = _public_media_url(filename)
    await db.commit()
    return {"profile_image_url": user.profile_image_url}


@router.post("/host/parking-spaces/{space_id}/images", status_code=201)
async def upload_parking_image(
    space_id: uuid.UUID,
    file: UploadFile = File(...),
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    parking_space = await owned_space(db, space_id, user_id)
    payload, suffix = await _read_image(file)
    content_type = file.content_type or "image/jpeg"
    filename = f"parking-{space_id}-{uuid.uuid4().hex}{suffix}"
    (_media_root() / filename).write_bytes(payload)
    approval_status, reason = await _review_parking_image(payload, content_type)
    count = await db.scalar(
        select(func.count(ParkingSpaceImage.id)).where(
            ParkingSpaceImage.parking_space_id == parking_space.id
        )
    )
    image = ParkingSpaceImage(
        parking_space_id=parking_space.id,
        image_url=_public_media_url(filename),
        sort_order=count or 0,
        alt_text=f"Foto von {parking_space.title}",
        approval_status=approval_status,
        ai_reason=reason,
    )
    db.add(image)
    await db.commit()
    await db.refresh(image)
    return {
        "id": image.id,
        "image_url": image.image_url,
        "approval_status": image.approval_status,
        "ai_reason": image.ai_reason,
    }


@router.get("/parking-spaces/{space_id}/images")
async def public_parking_images(
    space_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    images = (
        await db.scalars(
            select(ParkingSpaceImage)
            .where(
                ParkingSpaceImage.parking_space_id == space_id,
                ParkingSpaceImage.approval_status == "approved",
            )
            .order_by(ParkingSpaceImage.sort_order)
        )
    ).all()
    return [
        {
            "id": image.id,
            "image_url": image.image_url,
            "alt_text": image.alt_text,
        }
        for image in images
    ]


@router.get("/host/parking-spaces/{space_id}/images")
async def host_parking_images(
    space_id: uuid.UUID,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    parking_space = await owned_space(db, space_id, user_id)
    images = (
        await db.scalars(
            select(ParkingSpaceImage)
            .where(ParkingSpaceImage.parking_space_id == parking_space.id)
            .order_by(ParkingSpaceImage.sort_order)
        )
    ).all()
    return [
        {
            "id": image.id,
            "image_url": image.image_url,
            "approval_status": image.approval_status,
            "ai_reason": image.ai_reason,
        }
        for image in images
    ]


@router.get("/parking-spaces/{space_id}/reviews")
async def parking_reviews(
    space_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    rows = (
        await db.execute(
            select(Review, User)
            .join(User, User.id == Review.author_id)
            .where(Review.parking_space_id == space_id)
            .order_by(Review.created_at.desc())
        )
    ).all()
    return [
        {
            "id": str(review.id),
            "rating": review.rating,
            "comment": review.comment,
            "created_at": review.created_at,
            "author_name": user.display_name,
            "author_image_url": user.profile_image_url,
        }
        for review, user in rows
    ]


@router.post("/bookings/{booking_id}/review", status_code=201)
async def create_review(
    booking_id: uuid.UUID,
    data: ReviewIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    booking = await db.scalar(
        select(Booking).where(Booking.id == booking_id, Booking.user_id == user_id)
    )
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    if booking.status not in {BookingStatus.confirmed, BookingStatus.completed}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "review_not_available",
                "message": "Nur bestätigte abgeschlossene Aufenthalte können bewertet werden.",
            },
        )
    if booking.end_at > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "review_too_early",
                "message": "Die Bewertung ist nach dem Parkzeitraum verfügbar.",
            },
        )
    existing = await db.scalar(select(Review.id).where(Review.booking_id == booking.id))
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "review_exists",
                "message": "Diese Buchung wurde bereits bewertet.",
            },
        )

    review = Review(
        booking_id=booking.id,
        parking_space_id=booking.parking_space_id,
        author_id=user_id,
        rating=data.rating,
        comment=data.comment.strip(),
    )
    db.add(review)
    await db.flush()
    count = await db.scalar(
        select(func.count(Review.id)).where(
            Review.parking_space_id == booking.parking_space_id
        )
    )
    average = await db.scalar(
        select(func.avg(Review.rating)).where(
            Review.parking_space_id == booking.parking_space_id
        )
    )
    parking_space = await db.get(ParkingSpace, booking.parking_space_id)
    if parking_space is not None:
        parking_space.review_count = int(count or 0)
        parking_space.rating = round(float(average or 0), 1)
    await db.commit()
    await db.refresh(review)
    return {
        "id": str(review.id),
        "rating": review.rating,
        "comment": review.comment,
        "created_at": review.created_at,
    }
