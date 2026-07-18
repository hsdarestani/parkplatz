import uuid
from typing import Literal

from pydantic import BaseModel, Field, model_validator


class VerificationRequestIn(BaseModel):
    parking_space_id: uuid.UUID
    statement: str = Field(min_length=20, max_length=2_000)


class VerificationReviewIn(BaseModel):
    status: Literal["approved", "rejected"]
    note: str = Field(default="", max_length=2_000)


class SafetyReportIn(BaseModel):
    parking_space_id: uuid.UUID | None = None
    booking_id: uuid.UUID | None = None
    category: Literal[
        "incorrect_listing",
        "access_problem",
        "safety_concern",
        "payment_issue",
        "harassment",
        "other",
    ]
    description: str = Field(min_length=20, max_length=4_000)

    @model_validator(mode="after")
    def target_is_required(self) -> "SafetyReportIn":
        if self.parking_space_id is None and self.booking_id is None:
            raise ValueError("parking_space_id or booking_id is required")
        return self


class SafetyReportReviewIn(BaseModel):
    status: Literal["triaged", "resolved", "dismissed"]
    note: str = Field(default="", max_length=2_000)
