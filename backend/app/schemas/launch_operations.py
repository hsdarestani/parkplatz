import uuid
from typing import Literal

from pydantic import BaseModel, Field


class ManualRefundIn(BaseModel):
    reference: str = Field(min_length=3, max_length=255)
    note: str | None = Field(default=None, max_length=500)


class SubscriptionAdminIn(BaseModel):
    plan: Literal["free", "pro"]
    status: Literal["active", "pending", "cancelled"] = "active"


class ReceiptUploadOut(BaseModel):
    booking_id: uuid.UUID
    receipt_url: str
    original_name: str
    mime_type: str
    size_bytes: int
