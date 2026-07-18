from typing import Literal

from pydantic import BaseModel, Field, model_validator


class DirectPaymentSettingsIn(BaseModel):
    method: Literal["paypal", "revolut", "sepa"]
    payment_url: str | None = Field(default=None, max_length=2048)
    iban: str | None = Field(default=None, max_length=34)
    account_holder: str | None = Field(default=None, max_length=120)
    instructions: str | None = Field(default=None, max_length=1000)
    enabled: bool = True

    @model_validator(mode="after")
    def validate_destination(self) -> "DirectPaymentSettingsIn":
        if self.method in {"paypal", "revolut"}:
            if not self.payment_url or not self.payment_url.startswith("https://"):
                raise ValueError("payment_url must be a secure https URL")
        if self.method == "sepa":
            normalized_iban = (self.iban or "").replace(" ", "").upper()
            if len(normalized_iban) < 15 or not self.account_holder:
                raise ValueError("SEPA requires IBAN and account holder")
        return self


class DirectPaymentReferenceIn(BaseModel):
    reference: str = Field(min_length=3, max_length=255)


class DirectPaymentDecisionIn(BaseModel):
    decision: Literal["confirm", "reject"]
    reason: str | None = Field(default=None, max_length=500)
