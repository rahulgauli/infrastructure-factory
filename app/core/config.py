from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False)

    app_name: str = Field(default="Infrastructure Factory", alias="APP_NAME")
    app_version: str = Field(default="1.0.0", alias="APP_VERSION")
    debug: bool = Field(default=False, alias="DEBUG")
    generated_dir: str = Field(default="generated", alias="GENERATED_DIR")
    terraform_bin: str = Field(default="terraform", alias="TERRAFORM_BIN")
    max_concurrent_executions: int = Field(default=5, alias="MAX_CONCURRENT_EXECUTIONS")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
