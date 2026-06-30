#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="${ROOT_DIR}/.venv/bin/python"
APP_SUPPORT="${HOME}/Library/Application Support/Lira"
MODELS_DIR="${APP_SUPPORT}/models"
MODEL_ID="${LIRA_MODEL_ID:-Qwen/Qwen3.5-4B}"
MODEL_NAME="${LIRA_MODEL_NAME:-Qwen3.5-4B}"
MODEL_PARAMS="${LIRA_MODEL_PARAMS:-4B}"
QUANTIZATION="${LIRA_MODEL_QUANTIZATION:-4-bit}"
MODEL_SLUG="${LIRA_MODEL_SLUG:-qwen3.5}"
MODEL_ROOT="${MODELS_DIR}/${MODEL_SLUG}"
RAW_DIR="${MODEL_ROOT}/hf"
MLX_DIR="${MODEL_ROOT}/mlx"
MANIFEST="${MODEL_ROOT}/manifest.json"
TMP_MANIFEST="${MANIFEST}.tmp"
REVISION="${LIRA_MODEL_REVISION:-main}"
Q_BITS="${LIRA_MODEL_Q_BITS:-4}"
Q_GROUP_SIZE="${LIRA_MODEL_Q_GROUP_SIZE:-64}"

step=""

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  if [[ -n "${step}" ]]; then
    printf 'ERROR: step failed: %s (exit %s)\n' "${step}" "${exit_code}" >&2
  else
    printf 'ERROR: bootstrap failed (exit %s)\n' "${exit_code}" >&2
  fi
  exit "${exit_code}"
}

trap on_error ERR

run() {
  step="$1"
  shift
  printf '\n==> %s\n' "${step}"
  "$@"
}

ensure_tools() {
  [[ -x "${VENV_PYTHON}" ]] || fail "Missing Python venv at ${VENV_PYTHON}. Run scripts/setup_dev.sh first."
  "${VENV_PYTHON}" - <<'PY'
import importlib
missing = []
for package in ("huggingface_hub", "mlx_lm", "mlx"):
    try:
        importlib.import_module(package)
    except Exception as exc:
        missing.append(f"{package}: {exc}")
if missing:
    raise SystemExit("Missing bootstrap dependencies:\n" + "\n".join(missing))
PY
}

manifest_valid() {
  [[ -f "${MANIFEST}" ]] || return 1
  "${VENV_PYTHON}" - "${MANIFEST}" "${MODEL_NAME}" "${MODEL_PARAMS}" "${QUANTIZATION}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected = {
    "name": sys.argv[2],
    "params": sys.argv[3],
    "quantization": sys.argv[4],
}
try:
    data = json.loads(path.read_text())
except Exception:
    raise SystemExit(1)

required = ("name", "params", "quantization", "revision")
if not all(isinstance(data.get(key), str) and data[key] for key in required):
    raise SystemExit(1)
if any(data.get(key) != value for key, value in expected.items()):
    raise SystemExit(1)
if not Path(data.get("mlx_path", "")).is_dir():
    raise SystemExit(1)
PY
}

skip_if_present() {
  if manifest_valid; then
    printf 'Model already exists. Skipping.\n'
    "${VENV_PYTHON}" -m json.tool "${MANIFEST}"
    exit 0
  fi
}

make_dirs() {
  mkdir -p "${RAW_DIR}" "${MLX_DIR}"
}

download_model() {
  HF_HUB_ENABLE_HF_TRANSFER=0 "${VENV_PYTHON}" - "${MODEL_ID}" "${REVISION}" "${RAW_DIR}" <<'PY'
import sys
from pathlib import Path
from huggingface_hub import HfApi, snapshot_download

repo_id, revision, raw_dir = sys.argv[1:4]
api = HfApi()
info = api.model_info(repo_id, revision=revision, files_metadata=True)
resolved = info.sha
files = [s for s in info.siblings if s.rfilename and not s.rfilename.startswith(".")]
bytes_total = sum((getattr(s, "size", None) or 0) for s in files)
print(f"repo={repo_id}")
print(f"requested_revision={revision}")
print(f"resolved_revision={resolved}")
print(f"remote_files={len(files)}")
if bytes_total:
    print(f"remote_bytes={bytes_total}")
print("Hugging Face progress below is byte-backed and resumes from partial cache/local files.")
path = snapshot_download(
    repo_id=repo_id,
    revision=resolved,
    local_dir=raw_dir,
    allow_patterns=[
        "*.json",
        "*.model",
        "*.txt",
        "*.py",
        "*.safetensors",
        "*.tiktoken",
        "tokenizer*",
        "merges.txt",
        "vocab.json",
    ],
    ignore_patterns=["*.bin", "*.h5", "*.ot", "*.msgpack", "*.gguf"],
    max_workers=4,
)
local_bytes = sum(p.stat().st_size for p in Path(path).rglob("*") if p.is_file())
print(f"download_path={path}")
print(f"local_bytes={local_bytes}")
print(f"resolved_revision={resolved}")
PY
}

convert_to_mlx() {
  rm -rf "${MLX_DIR}.tmp"
  "${VENV_PYTHON}" -m mlx_lm convert \
    --hf-path "${RAW_DIR}" \
    --mlx-path "${MLX_DIR}.tmp" \
    --quantize \
    --q-bits "${Q_BITS}" \
    --q-group-size "${Q_GROUP_SIZE}"
  rm -rf "${MLX_DIR}"
  mv "${MLX_DIR}.tmp" "${MLX_DIR}"
}

write_manifest() {
  "${VENV_PYTHON}" - "${MODEL_ID}" "${MODEL_NAME}" "${MODEL_PARAMS}" "${QUANTIZATION}" "${REVISION}" "${RAW_DIR}" "${MLX_DIR}" "${TMP_MANIFEST}" "${MANIFEST}" <<'PY'
import json
import sys
from pathlib import Path
from huggingface_hub import HfApi

model_id, name, params, quantization, revision, raw_dir, mlx_dir, tmp_manifest, manifest = sys.argv[1:10]
resolved = HfApi().model_info(model_id, revision=revision).sha
mlx_path = Path(mlx_dir)
if not mlx_path.is_dir():
    raise SystemExit(f"missing MLX output: {mlx_path}")
if not (mlx_path / "config.json").is_file():
    raise SystemExit(f"missing MLX config.json: {mlx_path / 'config.json'}")
if not any(mlx_path.glob("*.safetensors")):
    raise SystemExit(f"missing MLX safetensors in {mlx_path}")

data = {
    "name": name,
    "params": params,
    "quantization": quantization,
    "revision": resolved,
    "source": model_id,
    "source_path": str(Path(raw_dir)),
    "mlx_path": str(mlx_path),
}
tmp = Path(tmp_manifest)
dst = Path(manifest)
tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
loaded = json.loads(tmp.read_text())
for key in ("name", "params", "quantization", "revision"):
    if not isinstance(loaded.get(key), str) or not loaded[key]:
        raise SystemExit(f"invalid manifest field: {key}")
tmp.replace(dst)
print(f"manifest={dst}")
print(json.dumps(loaded, indent=2, sort_keys=True))
PY
  manifest_valid || fail "Wrote manifest but validation failed."
}

list_models() {
  printf 'default\t%s\t%s\t%s\t%s\n' "${MODEL_ID}" "${MODEL_PARAMS}" "${QUANTIZATION}" "${MODEL_ROOT}"
}

main() {
  case "${1:-}" in
    --list-models)
      list_models
      return
      ;;
    --help|-h)
      printf 'Usage: %s [--list-models]\n' "$0"
      return
      ;;
  esac

  cd "${ROOT_DIR}"
  run "check bootstrap dependencies" ensure_tools
  run "skip if valid manifest is present" skip_if_present
  run "create App Support model directories" make_dirs
  run "download Hugging Face model with resumable byte progress" download_model
  run "convert model to MLX ${QUANTIZATION}" convert_to_mlx
  run "write and verify manifest" write_manifest
  printf '\nSUCCESS: model bootstrap complete.\n'
}

main "$@"
