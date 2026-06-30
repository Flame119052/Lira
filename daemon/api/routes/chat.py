"""Owns chat and model health HTTP routes."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from daemon.core import config


router = APIRouter()


class ChatStreamRequest(BaseModel):
    prompt: str = Field(min_length=1)
    image: str | None = None
    context: str | None = None
    history: list[dict[str, Any]] | None = None
    tools: list[dict[str, Any]] | None = None
    max_tokens: int = Field(default=config.DEFAULT_MAX_TOKENS, ge=1)


def _status(request: Request) -> str:
    if getattr(request.app.state, "model_loaded", False):
        return "ready"
    if getattr(request.app.state, "model_load_error", None):
        return "error"
    return "loading"


@router.get("/health")
def health(request: Request) -> dict[str, Any]:
    body = {
        "status": _status(request),
        "model_loaded": getattr(request.app.state, "model_loaded", False),
        "model_info": getattr(request.app.state, "model_info", None),
    }
    error = getattr(request.app.state, "model_load_error", None)
    if error:
        body["error"] = error
    return body


@router.get("/model/info")
def model_info(request: Request) -> dict[str, Any]:
    if getattr(request.app.state, "model_loaded", False):
        return getattr(request.app.state, "model_info", None) or {}
    error = getattr(request.app.state, "model_load_error", None)
    if error:
        raise HTTPException(status_code=503, detail=error)
    raise HTTPException(status_code=503, detail="Model is still loading")


@router.post("/chat/stream")
def chat_stream(payload: ChatStreamRequest, request: Request) -> StreamingResponse:
    if not getattr(request.app.state, "model_loaded", False):
        error = getattr(request.app.state, "model_load_error", None)
        detail = error or "Model is still loading"
        raise HTTPException(status_code=503, detail=detail)

    def generate():
        from daemon.core import model

        yield from model.stream_generate(
            payload.prompt,
            image=payload.image,
            context=payload.context,
            history=payload.history,
            tools=payload.tools,
            max_tokens=payload.max_tokens,
        )

    return StreamingResponse(generate(), media_type="text/plain; charset=utf-8")
