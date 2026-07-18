from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.account_routes import router as account_router
from app.api.host_schedule_routes import router as host_schedule_router
from app.api.launch_routes import router as launch_router
from app.api.payment_routes import router as payment_router
from app.api.routes import router
from app.api.trust_routes import router as trust_router
from app.core.config import settings

app = FastAPI(title="FREIRAUM API", version="0.1.0")
app.include_router(router)
app.include_router(host_schedule_router)
app.include_router(payment_router)
app.include_router(launch_router)
app.include_router(trust_router)
app.include_router(account_router)


@app.middleware("http")
async def require_payment_checkout(request: Request, call_next):
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
