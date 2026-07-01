"""Owns the main daemon process entry point."""

from __future__ import annotations

import argparse
import atexit
import os
import socket
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import uvicorn

from daemon.api.server import app
from daemon.core.config import (
    BIND_HOST,
    DAEMON_PID_FILE,
    DAEMON_PORT_FILE,
    DAEMON_PREFERRED_PORT,
)


def _atomic_write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp_path.write_text(value, encoding="utf-8")
    os.replace(tmp_path, path)


def _remove_runtime_files() -> None:
    for path in (DAEMON_PORT_FILE, DAEMON_PID_FILE):
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def _bind_socket() -> socket.socket:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind((BIND_HOST, DAEMON_PREFERRED_PORT))
    except OSError:
        sock.close()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((BIND_HOST, 0))

    sock.listen(socket.SOMAXCONN)
    sock.set_inheritable(True)
    return sock


def _publish_runtime_files(port: int) -> None:
    _atomic_write(DAEMON_PORT_FILE, f"{port}\n")
    _atomic_write(DAEMON_PID_FILE, f"{os.getpid()}\n")


class _CleanupServer(uvicorn.Server):
    def handle_exit(self, sig: int, frame) -> None:  # type: ignore[no-untyped-def]
        _remove_runtime_files()
        super().handle_exit(sig, frame)


def _run(dev: bool) -> None:
    _remove_runtime_files()
    atexit.register(_remove_runtime_files)
    sock = _bind_socket()
    port = int(sock.getsockname()[1])
    _publish_runtime_files(port)

    try:
        if dev:
            sock.close()
            uvicorn.run(
                "daemon.api.server:app",
                host=BIND_HOST,
                port=port,
                reload=True,
                reload_dirs=[str(REPO_ROOT / "daemon")],
            )
            return

        config = uvicorn.Config(app, host=BIND_HOST, port=port)
        server = _CleanupServer(config)
        server.run(sockets=[sock])
    finally:
        _remove_runtime_files()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the local Lira daemon.")
    parser.add_argument("--dev", action="store_true", help="Enable uvicorn reload.")
    args = parser.parse_args()
    _run(dev=args.dev)


if __name__ == "__main__":
    main()
