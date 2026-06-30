"""Owns foreground Qwen model loading and generation entry points."""

from __future__ import annotations

import json
from pathlib import Path
from threading import RLock
from typing import Iterator

from daemon.core import config


_MODEL = None
_PROCESSOR = None
_INFERENCE_LOCK = RLock()


def _manifest_path() -> Path:
    manifests = sorted(config.MODELS_DIR.glob("*/manifest.json"))
    if not manifests:
        raise FileNotFoundError(f"No model manifest found under {config.MODELS_DIR}")
    return manifests[0]


def _read_manifest() -> dict:
    path = _manifest_path()
    with path.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    return manifest


def _model_path(manifest: dict) -> str:
    value = manifest.get("mlx_path")
    if not value:
        raise ValueError(f"Model manifest is missing mlx_path: {_manifest_path()}")

    path = Path(value).expanduser()
    if not path.exists():
        raise FileNotFoundError(f"Manifest mlx_path does not exist: {path}")
    return str(path)


def _as_list(value):
    if value is None:
        return None
    if isinstance(value, list):
        return value
    return [value]


def _messages(prompt, context=None, history=None):
    messages = []
    if context:
        messages.append({"role": "system", "content": context})
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": prompt})
    return messages


def load() -> None:
    """Load the foreground model once."""
    global _MODEL, _PROCESSOR

    with _INFERENCE_LOCK:
        if _MODEL is not None and _PROCESSOR is not None:
            return

        import mlx.nn as nn
        from mlx_vlm import load as mlx_vlm_load

        manifest = _read_manifest()
        original_load_weights = nn.Module.load_weights

        def load_weights(module, file_or_weights, strict=False):
            return original_load_weights(module, file_or_weights, strict=strict)

        # This mlx-vlm build ignores its strict=False argument internally.
        nn.Module.load_weights = load_weights
        try:
            _MODEL, _PROCESSOR = mlx_vlm_load(_model_path(manifest), strict=False)
        finally:
            nn.Module.load_weights = original_load_weights


def info() -> dict:
    """Return live model identity from the manifest."""
    manifest = _read_manifest()
    return {
        "name": manifest.get("name"),
        "params": manifest.get("params"),
        "quantization": manifest.get("quantization"),
        "revision": manifest.get("revision"),
    }


def stream_generate(
    prompt,
    image=None,
    context=None,
    history=None,
    tools=None,
    max_tokens=config.DEFAULT_MAX_TOKENS,
) -> Iterator[str]:
    """Stream generated text chunks from the foreground model."""
    load()

    from mlx_vlm import apply_chat_template
    from mlx_vlm import stream_generate as mlx_vlm_stream_generate

    images = _as_list(image)
    template_kwargs = {"enable_thinking": False}
    if tools is not None:
        template_kwargs["tools"] = tools

    with _INFERENCE_LOCK:
        formatted_prompt = apply_chat_template(
            _PROCESSOR,
            _MODEL.config,
            _messages(prompt, context=context, history=history),
            num_images=len(images or []),
            **template_kwargs,
        )

        for chunk in mlx_vlm_stream_generate(
            _MODEL,
            _PROCESSOR,
            formatted_prompt,
            image=images,
            max_tokens=max_tokens,
            enable_thinking=False,
        ):
            text = getattr(chunk, "text", "")
            if text:
                yield text


def generate(
    prompt,
    image=None,
    context=None,
    history=None,
    tools=None,
    max_tokens=config.DEFAULT_MAX_TOKENS,
) -> str:
    """Return the full generated text from the foreground model."""
    return "".join(
        stream_generate(
            prompt,
            image=image,
            context=context,
            history=history,
            tools=tools,
            max_tokens=max_tokens,
        )
    )
