from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.routes import router

app = FastAPI(title="FREIRAUM API", version="0.1.0")
app.include_router(router)


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
