import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.core.config import settings
from app.core.security import token_hash
from app.db.session import get_session
from app.models import (
    Booking,
    BookingEvent,
    BookingStatus,
    ParkingSpace,
    RefreshToken,
    User,
    Vehicle,
)
from app.schemas.api import (
    BookingIn,
    CancelIn,
    Login,
    Refresh,
    Register,
    VehicleIn,
    VehicleOut,
)
from app.services.auth import AuthService
from app.services.booking import BookingService

router = APIRouter(prefix="/api")


def public_space(parking_space: ParkingSpace) -> dict[str, Any]:
    return {
        "id": str(parking_space.id),
        "slug": parking_space.slug,
        "title": parking_space.title,
        "district": parking_space.district,
        "landmark": parking_space.landmark,
        "latitude": float(parking_space.latitude),
        "longitude": float(parking_space.longitude),
        "hourly_price_cents": parking_space.hourly_price_cents,
        "currency": parking_space.currency,
        "max_height_m": float(parking_space.max_height_m),
        "max_width_m": float(parking_space.max_width_m),
        "max_length_m": float(parking_space.max_length_m),
        "access_type": parking_space.access_type,
        "is_covered": parking_space.is_covered,
        "has_ev_charging": parking_space.has_ev_charging,
        "is_accessible": parking_space.is_accessible,
        "is_instant_bookable": parking_space.is_instant_bookable,
        "is_verified": parking_space.is_verified,
        "rating": float(parking_space.rating),
        "review_count": parking_space.review_count,
    }


def booking_out(
    booking: Booking,
    parking_space: ParkingSpace | None = None,
    protected: bool = False,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": str(booking.id),
        "public_reference": booking.public_reference,
        "parking_space_id": str(booking.parking_space_id),
        "vehicle_id": str(booking.vehicle_id),
        "start_at": booking.start_at,
        "end_at": booking.end_at,
        "status": booking.status,
        "hourly_price_cents_snapshot": booking.hourly_price_cents_snapshot,
        "total_price_cents": booking.total_price_cents,
        "currency": booking.currency,
        "cancelled_at": booking.cancelled_at,
    }

    if (
        protected
        and booking.status == BookingStatus.confirmed
        and parking_space is not None
    ):
        result.update(
            exact_address=parking_space.exact_address,
            entrance_instructions=parking_space.entrance_instructions,
            access_code=booking.access_code,
            parking_pass_token=booking.parking_pass_token,
        )

    return result


@router.get("/health")
async def health(db: AsyncSession = Depends(get_session)) -> dict[str, str]:
    try:
        await db.execute(text("select 1"))
        database = "connected"
    except Exception:
        database = "unavailable"

    return {
        "status": "ok" if database == "connected" else "degraded",
        "application": "FREIRAUM API",
        "database": database,
        "environment": settings.environment,
        "version": settings.version,
    }


@router.post("/auth/register", status_code=status.HTTP_201_CREATED)
async def register(data: Register, db: AsyncSession = Depends(get_session)) -> dict:
    return await AuthService.register(
        db,
        str(data.email),
        data.password,
        data.display_name,
    )


@router.post("/auth/login")
async def login(data: Login, db: AsyncSession = Depends(get_session)) -> dict:
    return await AuthService.login(db, str(data.email), data.password)


@router.post("/auth/refresh")
async def refresh(data: Refresh, db: AsyncSession = Depends(get_session)) -> dict:
    refresh_record = await db.scalar(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash(data.refresh_token),
            RefreshToken.revoked_at.is_(None),
        )
    )
    if (
        refresh_record is None
        or refresh_record.expires_at < datetime.now(timezone.utc)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "invalid_refresh", "message": "Sitzung abgelaufen."},
        )

    refresh_record.revoked_at = datetime.now(timezone.utc)
    user = await db.get(User, refresh_record.user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return await AuthService._tokens(db, user)


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(data: Refresh, db: AsyncSession = Depends(get_session)) -> None:
    refresh_record = await db.scalar(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash(data.refresh_token)
        )
    )
    if refresh_record is not None:
        refresh_record.revoked_at = datetime.now(timezone.utc)
        await db.commit()


@router.get("/auth/me")
async def me(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return {
        "id": str(user.id),
        "email": user.email,
        "display_name": user.display_name,
    }


@router.get("/parking-spaces")
async def spaces(
    covered: bool | None = None,
    ev: bool | None = None,
    accessible: bool | None = None,
    instant: bool | None = None,
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = select(ParkingSpace).where(ParkingSpace.status == "active")
    filters = (
        (covered, ParkingSpace.is_covered),
        (ev, ParkingSpace.has_ev_charging),
        (accessible, ParkingSpace.is_accessible),
        (instant, ParkingSpace.is_instant_bookable),
    )
    for value, column in filters:
        if value is not None:
            query = query.where(column == value)

    parking_spaces = (await db.scalars(query)).all()
    return [public_space(parking_space) for parking_space in parking_spaces]


@router.get("/parking-spaces/{space_id}")
async def space(
    space_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    parking_space = await db.get(ParkingSpace, space_id)
    if parking_space is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return public_space(parking_space)


@router.get("/parking-spaces/{space_id}/availability")
async def availability(
    space_id: uuid.UUID,
    start_at: datetime,
    end_at: datetime,
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    overlap = await db.scalar(
        select(Booking.id).where(
            Booking.parking_space_id == space_id,
            Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
            Booking.start_at < end_at,
            Booking.end_at > start_at,
        )
    )
    return {
        "available": overlap is None,
        "start_at": start_at,
        "end_at": end_at,
    }


@router.get("/vehicles", response_model=list[VehicleOut])
async def vehicles(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[VehicleOut]:
    result = await db.scalars(select(Vehicle).where(Vehicle.user_id == user_id))
    return [VehicleOut.model_validate(vehicle) for vehicle in result.all()]


@router.post(
    "/vehicles",
    status_code=status.HTTP_201_CREATED,
    response_model=VehicleOut,
)
async def add_vehicle(
    data: VehicleIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> VehicleOut:
    vehicle_data = data.model_dump()
    vehicle_data["plate"] = data.plate.upper().strip()
    vehicle = Vehicle(user_id=user_id, **vehicle_data)
    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)
    return VehicleOut.model_validate(vehicle)


@router.patch("/vehicles/{vehicle_id}", response_model=VehicleOut)
async def patch_vehicle(
    vehicle_id: uuid.UUID,
    data: VehicleIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> VehicleOut:
    vehicle = await db.scalar(
        select(Vehicle).where(Vehicle.id == vehicle_id, Vehicle.user_id == user_id)
    )
    if vehicle is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    for key, value in data.model_dump().items():
        setattr(vehicle, key, value)
    vehicle.plate = vehicle.plate.upper().strip()
    await db.commit()
    await db.refresh(vehicle)
    return VehicleOut.model_validate(vehicle)


@router.delete("/vehicles/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_vehicle(
    vehicle_id: uuid.UUID,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> None:
    vehicle = await db.scalar(
        select(Vehicle).where(Vehicle.id == vehicle_id, Vehicle.user_id == user_id)
    )
    if vehicle is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    await db.delete(vehicle)
    await db.commit()


@router.post("/bookings", status_code=status.HTTP_201_CREATED)
async def create_booking(
    data: BookingIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    booking = await BookingService.create(db, user_id, data)
    return booking_out(booking)


@router.get("/bookings")
async def bookings(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    result = await db.scalars(
        select(Booking).where(Booking.user_id == user_id).order_by(Booking.start_at)
    )
    return [booking_out(booking) for booking in result.all()]


@router.get("/bookings/{booking_id}")
async def booking(
    booking_id: uuid.UUID,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    booking_record = await db.scalar(
        select(Booking).where(
            Booking.id == booking_id,
            Booking.user_id == user_id,
        )
    )
    if booking_record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    parking_space = await db.get(ParkingSpace, booking_record.parking_space_id)
    return booking_out(booking_record, parking_space, protected=True)


@router.post("/bookings/{booking_id}/cancel")
async def cancel(
    booking_id: uuid.UUID,
    data: CancelIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    booking_record = await db.scalar(
        select(Booking)
        .where(Booking.id == booking_id, Booking.user_id == user_id)
        .with_for_update()
    )
    if booking_record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    if booking_record.status in {
        BookingStatus.cancelled,
        BookingStatus.completed,
    }:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "not_cancellable",
                "message": "Diese Buchung kann nicht storniert werden.",
            },
        )

    booking_record.status = BookingStatus.cancelled
    booking_record.cancelled_at = datetime.now(timezone.utc)
    booking_record.cancellation_reason = data.reason
    booking_record.access_code = ""
    booking_record.parking_pass_token = ""
    db.add(
        BookingEvent(
            booking_id=booking_record.id,
            event_type="cancelled",
            event_metadata={"reason": data.reason},
        )
    )
    await db.commit()
    return booking_out(booking_record)
