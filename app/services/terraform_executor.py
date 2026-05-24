import asyncio
from pathlib import Path

from app.core.config import get_settings


class TerraformExecutor:
    def __init__(self) -> None:
        self.settings = get_settings()

    async def init(self, work_dir: str) -> tuple[int, str]:
        return await self._run(work_dir, "init", "-input=false")

    async def plan(self, work_dir: str) -> tuple[int, str]:
        return await self._run(work_dir, "plan", "-input=false", "-no-color")

    async def apply(self, work_dir: str) -> tuple[int, str]:
        return await self._run(work_dir, "apply", "-auto-approve", "-input=false", "-no-color")

    async def destroy(self, work_dir: str) -> tuple[int, str]:
        return await self._run(work_dir, "destroy", "-auto-approve", "-input=false", "-no-color")

    async def _run(self, work_dir: str, *args: str) -> tuple[int, str]:
        process = await asyncio.create_subprocess_exec(
            self.settings.terraform_bin,
            *args,
            cwd=str(Path(work_dir)),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await process.communicate()
        output = stdout.decode("utf-8", errors="replace") if stdout else ""
        return process.returncode, output
