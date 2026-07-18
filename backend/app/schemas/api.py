import uuid
from datetime import datetime, time
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator


class Register(BaseModel):
    display_name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class Login(BaseModel):
    email: EmailStr
    password: str


class Refresh(BaseModel):
    refresh_token: str


class ProfileUpdate(BaseModel):
    display_name: str = Field(min_length=2, max_length=100)


class VehicleIn(BaseModel):
    name: str
    plate: str
    height_m: float
    width_m: float
    length_m: float
    is_default: bool = False


class VehicleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    plate: str
    height_m: float
    width_m: float
    length_m: float
    is_default: bool


class HostParkingSpaceIn(BaseModel):
    title: str = Field(min_length=3, max_length=120)
    district: str = Field(min_length=2, max_length=80)
    landmark: str = Field(min_length=2, max_length=120)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    exact_address: str = Field(min_length=5, max_length=240)
    entrance_instructions: str = Field(min_length=5, max_length=1000)
    hourly_price_cents: int = Field(ge=50, le=100_000)
    currency: str = Field(default="EUR", min_length=3, max_length=3)
    max_height_m: float = Field(gt=0, le=10)
    max_width_m: float = Field(gt=0, le=10)
    max_length_m: float = Field(gt=0, le=30)
    access_type: Literal[
        "open",
        "barrier",
        "gate",
        "underground",
        "reception",
    ] = "open"
    is_covered: bool = False
    has_ev_charging: bool = False
    is_accessible: bool = False
    is_instant_bookable: bool = True


class HostParkingStatusIn(BaseModel):
    status: Literal["active", "paused"]


class HostAvailabilityRuleIn(BaseModel):
    weekday: int = Field(ge=0, le=6)
    active: bool = True
    start_time: time = time(0, 0)
    end_time: time = time(23, 59)
    price_override_cents: int | None = Field(default=None, ge=50, le=100_000)

    @model_validator(mode="after")
    def validate_time_range(self) -> "HostAvailabilityRuleIn":
        if self.active and self.end_time <= self.start_time:
            raise ValueError("end_time must be after start_time")
        return self


class HostAvailabilityScheduleIn(BaseModel):
    rules: list[HostAvailabilityRuleIn] = Field(min_length=7, max_length=7)

    @model_validator(mode="after")
    def validate_unique_weekdays(self) -> "HostAvailabilityScheduleIn":
        weekdays = [rule.weekday for rule in self.rules]
        if sorted(weekdays) != list(range(7)):
            raise ValueError("rules must contain every weekday exactly once")
        return self


class HostAvailabilityBlockIn(BaseModel):
    start_at: datetime
    end_at: datetime
    reason: str | None = Field(default=None, max_length=240)

    @model_validator(mode="after")
    def validate_range(self) -> "HostAvailabilityBlockIn":
        if self.end_at <= self.start_at:
            raise ValueError("end_at must be after start_at")
        return self


class BookingIn(BaseModel):
    parking_space_id: uuid.UUID
    vehicle_id: uuid.UUID
    start_at: datetime
    end_at: datetime
    idempotency_key: str = Field(min_length=8, max_length=100)


class CancelIn(BaseModel):
    reason: str = "Vom Nutzer storniert"
