from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import func, select

from app.api.account_routes import router as account_router
from app.api.host_schedule_routes import router as host_schedule_router
from app.api.launch_routes import router as launch_router
from app.api.marketplace_routes import router as marketplace_router
from app.api.payment_routes import router as payment_router
from app.api.routes import router
from app.api.trust_routes import router as trust_router
from app.core.config import settings
from app.core.security import decode
from app.db.session import Session
from app.models import ParkingSpace
from app.services.subscriptions import plan_limits, subscription_for

app = FastAPI(title="FREIRAUM API", version=settings.version)
app.include_router(router)
app.include_router(host_schedule_router)
app.include_router(payment_router)
app.include_router(launch_router)
app.include_router(trust_router)
app.include_router(account_router)
app.include_router(marketplace_router)

_media_root = Path(settings.marketplace_upload_dir)
_media_root.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=str(_media_root)), name="marketplace-media")


@app.middleware("http")
async def protect_launch_flows(request: Request, call_next):
    protected_modes = {"stripe", "direct"}
    if (
        settings.payment_mode in protected_modes
        and request.method == "POST"
        and request.url.path == "/api/bookings"
    ):
        return JSONResponse(
            status_code=409,
            content={
                "detail": {
                    "code": "payment_required",
                    "message": "Bitte verwende den vorgesehenen Buchungsablauf.",
                }
            },
        )

    if request.method == "POST" and request.url.path == "/api/host/parking-spaces":
        authorization = request.headers.get("authorization", "")
        if authorization.lower().startswith("bearer "):
            try:
                user_id = decode(authorization.split(" ", 1)[1])
                async with Session() as db:
                    subscription = await subscription_for(db, user_id)
                    assert subscription is not None
                    limit = plan_limits(subscription.plan)["listing_limit"]
                    count = await db.scalar(
                        select(func.count(ParkingSpace.id)).where(
                            ParkingSpace.owner_id == user_id,
                            ParkingSpace.status != "archived",
                        )
                    )
                    await db.commit()
                    if (count or 0) >= limit:
                        return JSONResponse(
                            status_code=409,
                            content={
                                "detail": {
                                    "code": "plan_listing_limit",
                                    "message": (
                                        "Dein aktueller Tarif erlaubt keine weiteren "
                                        "Stellplätze. Wechsle zu FREIRAUM Pro."
                                    ),
                                }
                            },
                        )
            except Exception:
                pass

    return await call_next(request)


@app.exception_handler(Exception)
async def safe_error(_request: Request, _exception: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={
            "detail": {
                "code": "server_error",
                "message": "Der Server ist gerade nicht erreichbar. Bitte versuche es erneut.",
            }
        },
    )
