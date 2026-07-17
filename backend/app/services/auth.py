from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    access_token,
    hash_password,
    refresh_token,
    token_hash,
    verify_password,
)
from app.models import RefreshToken, User


class AuthService:
    @staticmethod
    async def register(
        db: AsyncSession,
        email: str,
        password: str,
        name: str,
    ) -> dict[str, Any]:
        normalized_email = email.strip().lower()
        existing_user = await db.scalar(
            select(User).where(User.email == normalized_email)
        )
        if existing_user is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "email_unavailable",
                    "message": (
                        "Diese E-Mail-Adresse ist bereits registriert. "
                        "Bitte melde dich an."
                    ),
                },
            )

        user = User(
            email=normalized_email,
            password_hash=hash_password(password),
            display_name=name.strip(),
        )
        db.add(user)
        await db.flush()
        return await AuthService._tokens(db, user)

    @staticmethod
    async def login(
        db: AsyncSession,
        email: str,
        password: str,
    ) -> dict[str, Any]:
        user = await db.scalar(
            select(User).where(User.email == email.strip().lower())
        )
        if user is None or not verify_password(password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "code": "invalid_credentials",
                    "message": "E-Mail oder Passwort ist ungültig.",
                },
            )
        return await AuthService._tokens(db, user)

    @staticmethod
    async def _tokens(db: AsyncSession, user: User) -> dict[str, Any]:
        raw_refresh_token = refresh_token()
        db.add(
            RefreshToken(
                user_id=user.id,
                token_hash=token_hash(raw_refresh_token),
                expires_at=datetime.now(timezone.utc) + timedelta(days=30),
            )
        )
        await db.commit()
        return {
            "access_token": access_token(user.id),
            "refresh_token": raw_refresh_token,
            "token_type": "bearer",
            "user": {
                "id": str(user.id),
                "email": user.email,
                "display_name": user.display_name,
            },
        }
