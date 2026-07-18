from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = (
        "postgresql+psycopg://freiraum:freiraum@localhost:5432/freiraum"
    )
    jwt_secret: str = "development-only-change-me"
    environment: str = "development"
    version: str = "0.1.0"

    payment_mode: str = "beta"
    public_app_url: str = "http://localhost:8080"
    platform_fee_basis_points: int = 1500
    payment_hold_minutes: int = 31
    password_reset_minutes: int = 30

    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    stripe_country: str = "DE"

    admin_emails: str = ""
    trust_support_email: str = "info@aplus-solution.de"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def stripe_enabled(self) -> bool:
        return self.payment_mode == "stripe" and bool(self.stripe_secret_key)

    @property
    def admin_email_set(self) -> set[str]:
        return {
            email.strip().lower()
            for email in self.admin_emails.split(",")
            if email.strip()
        }


settings = Settings()
