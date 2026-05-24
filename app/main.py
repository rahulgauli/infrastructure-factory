from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI

from app.api.routes.infrastructure import router as infrastructure_router
from app.api.routes.providers import router as providers_router
from app.core.config import get_settings

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    Path(settings.generated_dir).mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(
    title=settings.app_name,
    description="Generate enterprise Terraform stacks with automatic cloud security baselines.",
    version=settings.app_version,
    debug=settings.debug,
    lifespan=lifespan,
)
app.include_router(infrastructure_router)
app.include_router(providers_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
