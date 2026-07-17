from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = (
        "postgresql+psycopg://freiraum:freiraum@localhost:5432/freiraum"
    )
    jwt_secret: str = "development-only-change-me"
    environment: str = "development"
    version: str = "0.1.0"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
