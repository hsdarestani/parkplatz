from typing import Literal

from pydantic import BaseModel, EmailStr, Field, model_validator


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    token: str = Field(min_length=24, max_length=256)
    new_password: str = Field(min_length=8, max_length=128)


class PasswordChangeIn(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def passwords_must_differ(self) -> "PasswordChangeIn":
        if self.current_password == self.new_password:
            raise ValueError("new_password must differ from current_password")
        return self


class NotificationPreferencesIn(BaseModel):
    booking_updates: bool = True
    host_updates: bool = True
    trust_updates: bool = True
    security_updates: bool = True
    marketing: bool = False


class AccountDeletionIn(BaseModel):
    password: str = Field(min_length=1, max_length=128)
    confirmation: Literal["DELETE"]
