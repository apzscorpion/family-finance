import os
from pydantic import field_validator
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Shared Family & Personal Finance Manager"
    ENV: str = "development"
    DEBUG: bool = True
    PORT: int = 8000
    HOST: str = "0.0.0.0"

    SECRET_KEY: str = "dev_secret_key_change_in_production_environment_987654321"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    DATABASE_URL: str = "sqlite:///./family_finance.db"

    MAX_ORGANIZATION_MEMBERS: int = 30
    INVITATION_TOKEN_EXPIRE_HOURS: int = 72

    @field_validator("DEBUG", mode="before")
    def parse_debug(cls, v):
        if isinstance(v, str):
            if v.lower() in ("true", "1", "yes"):
                return True
            if v.lower() in ("false", "0", "no", "release"):
                return False
        return v

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()
