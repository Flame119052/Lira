"""Owns daemon configuration paths, ports, and constants."""

from __future__ import annotations

import os
import sys
from functools import lru_cache
from pathlib import Path


APP_NAME = "Lira"
DATA_ROOT_ENV = "LIRA_DATA_ROOT"
DEFAULT_DATA_ROOT = Path.home() / "Library" / "Application Support" / APP_NAME
PERSISTED_DATA_ROOT_SETTING = DEFAULT_DATA_ROOT / "data_root.txt"

BIND_HOST = "127.0.0.1"

DAEMON_PREFERRED_PORT = 8765
BONSAI_SIDECAR_PREFERRED_PORT = 8766

BACKGROUND_SAFETY_MARGIN_BYTES = 3 * 1024**3
BACKGROUND_MAX_INSTANCES = 2
QWEN_4B_FOOTPRINT_BYTES = 3 * 1024**3
QWEN_9B_FOOTPRINT_BYTES = 7 * 1024**3
BONSAI_FOOTPRINT_BYTES = 2 * 1024**3

DEFAULT_MAX_TOKENS = 1024
CONTEXT_TOKEN_BUDGET = 4096
MEMORY_CONTEXT_TOKEN_BUDGET = 200
WORKER_OUTPUT_TOKEN_BUDGET = 6000

SERVER_STARTUP_TIMEOUT_SECONDS = 60
MODEL_LOAD_TIMEOUT_SECONDS = 600
SIDECAR_HEALTH_TIMEOUT_SECONDS = 30
REQUEST_TIMEOUT_SECONDS = 120
STREAM_IDLE_TIMEOUT_SECONDS = 30
BACKGROUND_IDLE_TIMEOUT_SECONDS = 300


def _warn(message: str) -> None:
    print(f"Lira config: {message}", file=sys.stderr)


def _persisted_data_root_override() -> Path | None:
    if not PERSISTED_DATA_ROOT_SETTING.is_file():
        return None

    value = PERSISTED_DATA_ROOT_SETTING.read_text(encoding="utf-8").strip()
    if not value:
        return None
    return Path(value).expanduser()


def _candidate_data_root() -> tuple[Path, str, bool]:
    env_value = os.environ.get(DATA_ROOT_ENV, "").strip()
    if env_value:
        return Path(env_value).expanduser(), DATA_ROOT_ENV, True

    persisted = _persisted_data_root_override()
    if persisted is not None:
        return persisted, str(PERSISTED_DATA_ROOT_SETTING), True

    return DEFAULT_DATA_ROOT, "default", False


def _resolve_root(path: Path, source: str, is_override: bool) -> Path:
    resolved = path

    if resolved.exists() and not resolved.is_dir():
        if is_override:
            _warn(
                f"configured data root from {source} is not a directory: "
                f"{resolved}; falling back to {DEFAULT_DATA_ROOT}"
            )
        return DEFAULT_DATA_ROOT

    if not resolved.exists():
        parent = resolved.parent
        if not parent.exists():
            if is_override:
                _warn(
                    f"configured data root from {source} is unavailable: "
                    f"{resolved}; falling back to {DEFAULT_DATA_ROOT}"
                )
            return DEFAULT_DATA_ROOT
        resolved.mkdir(parents=False, exist_ok=True)

    return resolved


@lru_cache(maxsize=1)
def data_root() -> Path:
    """Return the single root for user data, model weights, and runtime files."""
    candidate, source, is_override = _candidate_data_root()
    return _resolve_root(candidate, source, is_override)


MODELS_DIR = data_root() / "models"
DB_PATH = data_root() / "lira.sqlite3"
MEMPALACE_DIR = data_root() / "mempalace"
ANNOTATION_SCREENSHOTS_DIR = data_root() / "annotation_screenshots"

DAEMON_PORT_FILE = data_root() / "daemon.port"
DAEMON_PID_FILE = data_root() / "daemon.pid"
BONSAI_SIDECAR_PORT_FILE = data_root() / "bonsai_sidecar.port"
BONSAI_SIDECAR_PID_FILE = data_root() / "bonsai_sidecar.pid"
BACKGROUND_INSTANCES_DIR = data_root() / "background_instances"


def background_instance_port_file(instance_id: str | int) -> Path:
    return BACKGROUND_INSTANCES_DIR / f"{instance_id}.port"


def background_instance_pid_file(instance_id: str | int) -> Path:
    return BACKGROUND_INSTANCES_DIR / f"{instance_id}.pid"
