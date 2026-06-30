"""Owns construction of the local daemon API server."""

from __future__ import annotations

from contextlib import asynccontextmanager
from threading import Thread

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from daemon.api.routes import chat


def _set_initial_model_state(app: FastAPI) -> None:
    app.state.model_loaded = False
    app.state.model_loading = False
    app.state.model_info = None
    app.state.model_load_error = None


def _load_model(app: FastAPI) -> None:
    app.state.model_loading = True
    app.state.model_load_error = None
    try:
        from daemon.core import model

        model.load()
        app.state.model_info = model.info()
        app.state.model_loaded = True
    except Exception as exc:  # pragma: no cover - exercised by live startup.
        app.state.model_load_error = f"{type(exc).__name__}: {exc}"
        app.state.model_loaded = False
    finally:
        app.state.model_loading = False


@asynccontextmanager
async def lifespan(app: FastAPI):
    _set_initial_model_state(app)
    loader = Thread(target=_load_model, args=(app,), name="lira-model-load", daemon=True)
    loader.start()
    yield


def create_app() -> FastAPI:
    """Create the local-only daemon API app."""
    api = FastAPI(title="Lira Daemon", lifespan=lifespan)
    api.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["content-type"],
    )
    api.include_router(chat.router)
    return api


app = create_app()
