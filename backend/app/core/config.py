from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = (
        "postgresql+psycopg://freiraum:freiraum@localhost:5432/freiraum"
    )
    jwt_secret: str = "development-only-change-me"
    environment: str = "development"
    version: str = "0.9.2"

    payment_mode: str = "direct"
    public_app_url: str = "http://localhost:8080"
    platform_fee_basis_points: int = 1500
    payment_hold_minutes: int = 31
    direct_payment_hold_hours: int = 24
    free_host_response_hours: int = 12
    pro_host_response_hours: int = 6
    free_listing_limit: int = 1
    pro_listing_limit: int = 10
    receipt_upload_dir: str = "/var/lib/freiraum/uploads"
    receipt_max_bytes: int = 5_242_880
    marketplace_upload_dir: str = "/var/lib/freiraum/marketplace-media"
    marketplace_image_max_bytes: int = 8_388_608
    password_reset_minutes: int = 30

    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    stripe_country: str = "DE"

    openai_api_key: str = ""
    openai_vision_model: str = "gpt-5-mini"
    nominatim_base_url: str = "https://nominatim.openstreetmap.org"
    nominatim_contact_email: str = "parkplat@aplus-solution.de"

    admin_emails: str = ""
    trust_support_email: str = "parkplat@aplus-solution.de"
    primary_email: str = "parkplat@aplus-solution.de"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def stripe_enabled(self) -> bool:
        return self.payment_mode == "stripe" and bool(self.stripe_secret_key)

    @property
    def openai_enabled(self) -> bool:
        return bool(self.openai_api_key)

    @property
    def admin_email_set(self) -> set[str]:
        return {
            email.strip().lower()
            for email in self.admin_emails.split(",")
            if email.strip()
        }


settings = Settings()
