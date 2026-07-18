from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.host_schedule_routes import router as host_schedule_router
from app.api.payment_routes import router as payment_router
from app.api.routes import router
from app.core.config import settings

app = FastAPI(title="FREIRAUM API", version="0.1.0")
app.include_router(router)
app.include_router(host_schedule_router)
app.include_router(payment_router)


@app.middleware("http")
async def require_payment_checkout(request: Request, call_next):
    if (
        settings.payment_mode == "stripe"
        and request.method == "POST"
        and request.url.path == "/api/bookings"
    ):
        return JSONResponse(
            status_code=409,
            content={
                "detail": {
                    "code": "payment_required",
                    "message": "Bitte schließe die Buchung über die sichere Zahlung ab.",
                }
            },
        )
    return await call_next(request)


@app.exception_handler(Exception)
async def safe_error(_request: Request, _exception: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={
            "detail": {
                "code": "server_error",
                "message": (
                    "Der Server ist gerade nicht erreichbar. "
                    "Bitte versuche es erneut."
                ),
            }
        },
    )
