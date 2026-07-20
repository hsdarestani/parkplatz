from typing import Any

import httpx
from fastapi import APIRouter, HTTPException, Query, status

from app.core.config import settings

router = APIRouter(prefix="/api/routing", tags=["routing"])


@router.get("/walking")
async def walking_route(
    from_lat: float = Query(ge=-90, le=90),
    from_lng: float = Query(ge=-180, le=180),
    to_lat: float = Query(ge=-90, le=90),
    to_lng: float = Query(ge=-180, le=180),
) -> dict[str, Any]:
    """Return a real pedestrian route or fail without inventing an estimate."""
    coordinates = f"{from_lng},{from_lat};{to_lng},{to_lat}"
    url = (
        "https://routing.openstreetmap.de/"
        f"routed-foot/route/v1/driving/{coordinates}"
    )
    headers = {
        "User-Agent": f"FREIRAUM/{settings.version} ({settings.primary_email})",
        "Accept": "application/json",
    }
    params = {
        "overview": "full",
        "geometries": "geojson",
        "steps": "false",
        "alternatives": "false",
    }

    try:
        async with httpx.AsyncClient(timeout=12) as client:
            response = await client.get(url, params=params, headers=headers)
            response.raise_for_status()
            payload = response.json()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "walking_route_unavailable",
                "message": "Die Fußroute ist gerade nicht verfügbar.",
            },
        ) from exc

    routes = payload.get("routes") or []
    if payload.get("code") != "Ok" or not routes:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "walking_route_not_found",
                "message": "Für diese Punkte wurde keine Fußroute gefunden.",
            },
        )

    route = routes[0]
    geometry = route.get("geometry") or {}
    coordinates_out = geometry.get("coordinates") or []
    return {
        "distance_meters": round(float(route.get("distance") or 0)),
        "duration_seconds": round(float(route.get("duration") or 0)),
        "geometry": [
            {"latitude": float(point[1]), "longitude": float(point[0])}
            for point in coordinates_out
            if isinstance(point, list) and len(point) >= 2
        ],
        "source": "OpenStreetMap pedestrian routing",
    }
