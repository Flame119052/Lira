# Lira — Slice Map

**Version:** 3.0
**Status:** Active build guide
**Companion:** `PRD.md` — the full product spec (architecture, schemas, contracts). Read it first. `DECISIONS.md` — the rationale/working-agreement.

> This is a clean, from-scratch build guide. It assumes an empty repository and walks the entire product, top to bottom, in small slices. There is no "already built" — every slice is to be built and proven.

---

## A. How to Use This Document

The product is **13 milestones** (the user-visible "usable product" checkpoints), each decomposed into **small slices**. Build strictly top to bottom using the [Build Order Index](#c-build-order-index). Never start a slice until the one above it has passed **both** its Acceptance test **and** its Must-still-pass regression gate, with evidence pasted.

### What a slice is
The **smallest change that produces one observably-testable behavior** — usually 1–3 tightly-coupled files. A thin vertical cut through the stack that produces something real and testable.

### Why slices are small — the regression gate
Small slices make a **regression gate** cheap enough to run every time. Every slice carries a **"Must-still-pass"** field: the specific earlier behaviors it is forbidden to break, each re-run with pasted output. A slice is complete only when:
1. its **Acceptance test** passes live (output pasted), **and**
2. every **Must-still-pass** check still passes (output pasted), **and**
3. tests are written and green, the build succeeds, and there are zero orphaned processes.

### The Evidence rule (in every Agent prompt's Definition of done)
> **Evidence rule — paste the actual command/test output for every checklist item and every claim of done; an item counts as done only when its proof is in your report, and a bare "verified" with no pasted output is rejected.**

---

## B. Global Conventions

- **One model touches Qwen:** `daemon/core/model.py`. **One file knows the sidecar:** `daemon/bonsai/client.py`. **One place for paths/ports:** `daemon/core/config.py`. **One Swift file makes URL calls:** `app/Lira/Services/APIClient.swift`. **One place defines endpoints:** `daemon/api/routes/`.
- **Two processes, two venvs, never a shared interpreter.** Main daemon (`.venv`, stock MLX) and Bonsai sidecar (`.venv-bonsai`, forked/GGUF MLX) communicate only over `127.0.0.1` HTTP.
- **Files stay under 500 lines.** Split by responsibility if needed.
- **Ports are discovered, never hardcoded** beyond a preferred default (daemon 8765, sidecar 8766) — bind a free port if taken and publish it to a `.port` file.
- **The model signature is frozen from Slice 1.4:** `model.generate(prompt, image, context, history, tools, max_tokens=...)` and `model.stream_generate(...)`. Never change it; only fill arguments.
- **One configurable data root.** All model weights + user data live under a single root resolved in `config.py`, in this order: env `LIRA_DATA_ROOT` → a persisted user setting → default `~/Library/Application Support/Lira/`. **Public-release builds default to this App Support path on the main/boot SSD — never an external drive.** Dev may override (e.g. `LIRA_DATA_ROOT=/Volumes/<drive>/Lira-data`) to keep weights off the boot disk. Wherever a later slice says "App Support," it means this data root. If a configured root is unavailable (drive unmounted), fail with a clear message and fall back to the default.

---

## C. Build Order Index

Strict sequence. `Step` = build position. `ID` = stable slice identifier. Tick the box only when the slice's Acceptance test **and** Must-still-pass gate are both green with evidence.

| Step | ID   | Slice                                                                   | Milestone             | ✓ |
|------|------|-------------------------------------------------------------------------|-----------------------|---|
| 1    | F1   | Repo scaffold                                                           | Foundations           | ☐ |
| 2    | F2   | Dependency stack (two venvs, pinned, Bonsai load proven)                | Foundations           | ☐ |
| 3    | 1.1  | Dev environment script (`setup_dev.sh`)                                 | M1 Brain              | ☐ |
| 4    | 1.2  | Model bootstrap (`bootstrap_model.sh`)                                  | M1 Brain              | ☐ |
| 5    | 1.3  | Config — paths, ports, constants                                        | M1 Brain              | ☐ |
| 6    | 1.4  | Model loader + **frozen signature** + streaming + `info()`              | M1 Brain              | ☐ |
| 7    | 1.5  | API server + `/health` + `/model/info`                                  | M1 Brain              | ☐ |
| 8    | 1.6  | Daemon entry + port discovery                                           | M1 Brain              | ☐ |
| 9    | 1.7  | Throwaway dev UI (curl/CLI smoke)                                       | M1 Brain              | ☐ |
| 10   | 2.1  | Xcode project + MenuBarExtra                                            | M2 Face               | ☐ |
| 11   | 2.2  | DaemonService — launch/monitor both processes + restart recovery        | M2 Face               | ☐ |
| 12   | 2.3  | APIClient (only URL-bearing Swift file)                                 | M2 Face               | ☐ |
| 13   | 2.4  | Orb view (six states)                                                   | M2 Face               | ☐ |
| 14   | 2.5  | Chat view (streaming) + single-flight guard                             | M2 Face               | ☐ |
| 15   | 2.6  | Menu bar (six states)                                                   | M2 Face               | ☐ |
| 16   | 2.7  | Settings view (live model info, never hardcoded)                        | M2 Face               | ☐ |
| 17   | 2.8  | App lifecycle (auto start/stop, clean teardown)                         | M2 Face               | ☐ |
| 18   | 3.1  | Bonsai sidecar process (server + model load + port discovery)           | M3 Sidecar/Jobs       | ☐ |
| 19   | 3.2  | Bonsai client (daemon side)                                             | M3 Sidecar/Jobs       | ☐ |
| 20   | 3.3  | Notification queue                                                      | M3 Sidecar/Jobs       | ☐ |
| 21   | 3.4  | Tool registry + JSON schemas                                            | M3 Sidecar/Jobs       | ☐ |
| 22   | 3.5  | Dispatcher (parse function calls → route)                               | M3 Sidecar/Jobs       | ☐ |
| 23   | 3.6  | Orchestrator (delegation; foreground off-limits)                        | M3 Sidecar/Jobs       | ☐ |
| 24   | 3.7  | Job queue (SQLite state table)                                          | M3 Sidecar/Jobs       | ☐ |
| 25   | 3.8  | Worker wrappers (base / claude_code / codex)                            | M3 Sidecar/Jobs       | ☐ |
| 26   | 3.9  | Job runner (concurrent, bounded)                                        | M3 Sidecar/Jobs       | ☐ |
| 27   | 3.10 | Job monitor (reads state, no inference)                                 | M3 Sidecar/Jobs       | ☐ |
| 28   | 3.11 | RAM detection (macOS reclaimable / pressure-aware)                      | M3 Sidecar/Jobs       | ☐ |
| 29   | 3.12 | Background instance process (separate model, idle teardown)             | M3 Sidecar/Jobs       | ☐ |
| 30   | 3.13 | Dynamic multi-instance pool (RAM-gated) + `qwen_instance` worker        | M3 Sidecar/Jobs       | ☐ |
| 31   | 3.14 | Chat route dispatch loop + backend single-flight guard                  | M3 Sidecar/Jobs       | ☐ |
| 32   | 3.15 | Jobs API routes                                                         | M3 Sidecar/Jobs       | ☐ |
| 33   | 3.16 | App job surface — panel + banners + full-output detail view             | M3 Sidecar/Jobs       | ☐ |
| 34   | 4.1  | Memory: storage schema (`db.py`, FTS, sqlite-vec)                       | M4 Memory             | ☐ |
| 35   | 4.2  | Memory: verbatim store (`mempalace.py`)                                 | M4 Memory             | ☐ |
| 36   | 4.3  | Memory: session lifecycle + incognito (recall across restart)           | M4 Memory             | ☐ |
| 37   | 4.4  | Memory: fact/decision extraction (Bonsai → typed records)               | M4 Memory             | ☐ |
| 38   | 4.5  | Memory: retrieval (keyword-expand + FTS + semantic, <200 tok)           | M4 Memory             | ☐ |
| 39   | 4.6  | Memory: projects & threads (2-level nesting)                            | M4 Memory             | ☐ |
| 40   | 4.7  | Memory: re-entry greeting                                               | M4 Memory             | ☐ |
| 41   | 4.8  | Memory: compaction (80% threshold via Bonsai)                           | M4 Memory             | ☐ |
| 42   | 4.9  | Memory: context assembly — KV tiers (`context.py`) ⟵ keystone           | M4 Memory             | ☐ |
| 43   | 4.10 | Memory: chat wiring (real context, no M3 regression) ⟵ keystone         | M4 Memory             | ☐ |
| 44   | 4.11 | Memory: API routes (`routes/memory.py`)                                 | M4 Memory             | ☐ |
| 45   | 4.12 | Memory: MemoryView UI (inspect + delete + clear-all)                    | M4 Memory             | ☐ |
| 46   | 5.1  | Instructions: storage (YAML + structured settings)                      | M5 Instructions/Tasks | ☐ |
| 47   | 5.2  | Instructions: into Tier-2 + cache invalidation + mid-convo edit         | M5 Instructions/Tasks | ☐ |
| 48   | 5.3  | Task list: backend (hot/cold, `tasklist.py`)                            | M5 Instructions/Tasks | ☐ |
| 49   | 5.4  | Task list: into dynamic context + Bonsai updates on job state           | M5 Instructions/Tasks | ☐ |
| 50   | 5.5  | Instructions + task-list settings UI                                    | M5 Instructions/Tasks | ☐ |
| 51   | 6.1  | Voice: wake word ("Lira", openWakeWord)                                 | M6 Voice              | ☐ |
| 52   | 6.2  | Voice: VAD (Silero)                                                     | M6 Voice              | ☐ |
| 53   | 6.3  | Voice: transcription (mlx-whisper)                                      | M6 Voice              | ☐ |
| 54   | 6.4  | Voice: TTS speaker (Kokoro, sentence-boundary start)                    | M6 Voice              | ☐ |
| 55   | 6.5  | Voice: state machine (wake→listen→transcribe→respond→speak, interrupt)  | M6 Voice              | ☐ |
| 56   | 6.6  | Voice: auto-mute (calls / DND / quiet hours / manual)                   | M6 Voice              | ☐ |
| 57   | 6.7  | Voice: API routes + app wiring + menu-bar states                        | M6 Voice              | ☐ |
| 58   | 7.1  | Screen: capture (ScreenCaptureKit)                                      | M7 Screen             | ☐ |
| 59   | 7.2  | Screen: analyzer (Qwen vision + coords as %)                            | M7 Screen             | ☐ |
| 60   | 7.3  | Screen: overlay window (transparent, click-through, all spaces)         | M7 Screen             | ☐ |
| 61   | 7.4  | Screen: annotation drawing (% → pixel)                                  | M7 Screen             | ☐ |
| 62   | 7.5  | Screen: annotation lifecycle (persist until clear; overlap ask)         | M7 Screen             | ☐ |
| 63   | 7.6  | Screen: screenshot archival (24h → Bonsai summary)                      | M7 Screen             | ☐ |
| 64   | 7.7  | Screen: diagram view (Mermaid in WKWebView, draggable)                  | M7 Screen             | ☐ |
| 65   | 7.8  | Screen: perception API routes + app wiring                              | M7 Screen             | ☐ |
| 66   | 8.1  | Control: safety preflight (`safety.py`)                                 | M8 Control            | ☐ |
| 67   | 8.2  | Control: audit logger (write before confirm)                            | M8 Control            | ☐ |
| 68   | 8.3  | Control: native executor (files / apps / calendar, silent)              | M8 Control            | ☐ |
| 69   | 8.4  | Control: undo system                                                    | M8 Control            | ☐ |
| 70   | 8.5  | Control: trust system (per-capability, promotion, hard-rule exclusions) | M8 Control            | ☐ |
| 71   | 8.6  | Control: live cursor (CGEvent + overlay cursor)                         | M8 Control            | ☐ |
| 72   | 8.7  | Control: Lira's Space (dedicated macOS Space)                           | M8 Control            | ☐ |
| 73   | 8.8  | Control: API routes + confirmation UI + trust panel                     | M8 Control            | ☐ |
| 74   | 9.1  | Browser: control via browser-use (local Qwen backend, DOM mode)         | M9 Browser            | ☐ |
| 75   | 9.2  | Browser: Chrome extension (manifest, content, background)               | M9 Browser            | ☐ |
| 76   | 9.3  | Browser: daemon↔extension WebSocket                                     | M9 Browser            | ☐ |
| 77   | 9.4  | Browser: API routes + cursor mode + app wiring                          | M9 Browser            | ☐ |
| 78   | 10.1 | Proactive: trigger engine (families)                                    | M10 Proactive         | ☐ |
| 79   | 10.2 | Proactive: calendar integration (EventKit read-only, meeting brief)     | M10 Proactive         | ☐ |
| 80   | 10.3 | Proactive: settings (per-trigger on/off, thresholds, quiet hours)       | M10 Proactive         | ☐ |
| 81   | 11.1 | Local agent: OpenAI-compatible instance serving (reuse 3.12/3.13 pool)  | M11 Local Agents      | ☐ |
| 82   | 11.2 | Local agent: OpenCode worker (`local_agent`)                            | M11 Local Agents      | ☐ |
| 83   | 11.3 | Local agent: restrictive permission gate (ask-for-everything)           | M11 Local Agents      | ☐ |
| 84   | 11.4 | Local agent: routing + cloud advocacy + local/cloud labeling            | M11 Local Agents      | ☐ |
| 85   | 12.1 | Onboarding: flow shell (9 steps, progress, back)                        | M12 Onboarding/Dist   | ☐ |
| 86   | 12.2 | Onboarding: permissions step (mic / screen / accessibility)             | M12 Onboarding/Dist   | ☐ |
| 87   | 12.3 | Onboarding: model choice + download + bootstrap API                     | M12 Onboarding/Dist   | ☐ |
| 88   | 12.4 | Onboarding: CLI / routing / autonomy / personality / voice steps        | M12 Onboarding/Dist   | ☐ |
| 89   | 12.5 | Distribution: DMG build (`build_dmg.sh`, both venvs bundled)            | M12 Onboarding/Dist   | ☐ |
| 90   | 13.1 | Polish: Sparkle updates                                                 | M13 Polish            | ☐ |
| 91   | 13.2 | Polish: error handling + recovery (global)                              | M13 Polish            | ☐ |
| 92   | 13.3 | Polish: performance targets (cold start <45s, first token <1s)          | M13 Polish            | ☐ |
| 93   | 13.4 | Polish: final regression sweep over the whole product                   | M13 Polish            | ☐ |

**Build-order principle:** build *all features* (M1–M11) before packaging/onboarding (M12) and the final polish pass (M13). M11 (capable local agents) is the last feature and has a hard dependency on M8 (control/safety); it must be in the product before it is packaged, onboarded, and polished.

---

## D. Repository Structure

Set up once in F1, never reorganized.

```
lira/
├── daemon/                          ← MAIN backend (stock MLX, venv: .venv)
│   ├── core/                        ← config, model, context, tools, dispatcher, orchestrator, notifications
│   ├── api/                         ← server.py + routes/ (chat, voice, memory, perception, control, jobs, bootstrap, browser)
│   ├── workers/                     ← base, qwen_instance, claude_code, codex
│   ├── jobs/                        ← queue (SQLite), runner (concurrent), monitor (no inference)
│   ├── memory/                      ← db, mempalace, session, retriever, projects, instructions, tasklist, compaction, lifecycle
│   ├── voice/                       ← wakeword, vad, listener, transcriber, speaker
│   ├── perception/                  ← screen, analyzer, archival
│   ├── control/                     ← safety, executor, trust, logger, undo, browser
│   ├── proactive/                   ← triggers, calendar
│   ├── bonsai/                      ← client.py (ONLY file aware of the sidecar), scheduler.py
│   └── main.py                      ← main daemon entry point
├── background_instance/             ← on-demand separate Qwen instance(s); server.py + main.py (idle teardown)
├── bonsai_sidecar/                  ← SEPARATE process (forked/GGUF MLX, venv: .venv-bonsai); server.py, bonsai.py, main.py, requirements.txt
├── app/Lira/                        ← Xcode SwiftUI project (App/, Views/, Models/, Services/)
│   └── Services/                    ← DaemonService.swift, APIClient.swift (ONLY URL-bearing Swift file)
├── extension/                       ← Chrome extension (manifest.json, background.js, content.js)
├── tests/{daemon,bonsai_sidecar}/
├── scripts/                         ← setup_dev.sh, bootstrap_model.sh, build_dmg.sh
├── models/                          ← dev-only gitignored symlink to App Support models
├── requirements.txt · bonsai_sidecar/requirements.txt · .gitignore · .env.example
```

All user data + weights live in `~/Library/Application Support/Lira/`. Never commit weights.

---

## E. Dependency Stack

Two separate virtual environments because Bonsai's MLX build conflicts with Qwen's stock MLX. Pin every version. The pins below are a known-good starting lock — re-resolve and re-verify on the target machine.

**Main daemon — `.venv` (`requirements.txt`):** `mlx`, `mlx-lm`, `mlx-vlm`, `mlx-whisper`, `kokoro`, `fastapi`, `uvicorn`, `websockets`, `httpx`, `sqlmodel`, `sqlite-vec`, `mempalace`, `huggingface_hub`, `openWakeWord`, `silero-vad`, `sounddevice`, `Pillow`, `pyyaml`, `psutil`, `browser-use`, `playwright`, and the pyobjc frameworks (Quartz, ApplicationServices, ScreenCaptureKit, EventKit, Contacts). *Note:* `pyobjc-framework-AppKit` is not a PyPI distribution — use `pyobjc-framework-Cocoa`. Run `playwright install chromium` in `.venv`.
*Known-good pins:* `mlx==0.31.2`, `mlx-lm==0.31.3`, `mlx-vlm==0.6.0`, `mlx-whisper==0.4.3`, `kokoro==0.9.4`, `fastapi==0.136.3`, `uvicorn==0.48.0`, `sqlite-vec==0.1.9`, `mempalace==3.3.5`, `playwright==1.60.0`, `pyobjc-framework-Cocoa==12.2`.

**Bonsai sidecar — `.venv-bonsai`:** Primary: forked MLX (`mlx @ git+https://github.com/PrismML-Eng/mlx.git@prism`) + minimal FastAPI deps. **Documented fallback:** if the fork won't build/loads-hang, load the **GGUF Q1_0_g128** build (`prism-ml/Bonsai-8B-gguf`) via `llama-cpp-python` (Metal), same HTTP interface. *Fallback pins:* `llama-cpp-python==0.3.25`, `diskcache==5.6.3`, `huggingface_hub==1.17.0`, `fastapi==0.136.3`, `uvicorn==0.48.0`. **Decide during F2 based on what actually loads; record which.** The two `mlx` packages must never coexist in one interpreter.

**Swift:** SwiftUI + Combine (native), Sparkle (SPM). **Extension:** plain JS, no deps.

---

## F. Non-negotiables — Apply to Every Slice

1. **API server binds to 127.0.0.1 only.** 2. **API keys in macOS Keychain only.** 3. **Every action logged immediately** (`audit_log` before success is confirmed). 4. **Memory fully deletable.** 5. **Destructive actions always confirm** (delete/send/irreversible). 6. **Both processes clean up on exit** — zero orphans, verified after every run. 7. **No telemetry.** 8. **No secrets in git** (incl. weights). 9. **Both inter-process endpoints local-only.** 10. **Each slice ships with tests.** 11. **The signature contract is fixed** — `model.generate/stream_generate(prompt, image, context, history, tools, max_tokens=...)` from Slice 1.4. 12. **The foreground model is never blocked by background work.**

**The regression gate (v3 practice):** every slice declares and re-runs its **Must-still-pass** behaviors with pasted evidence before it is called done.

---

## G. Detailed Slices

### G.0 — Operating Contract for Every Agent Prompt (read once)

Every "Agent prompt" below is written for an agentic coding tool — **Claude Code or Codex** — that can read/write files **and run commands on this Mac**. These standing orders apply to all of them; each prompt says "Operate under §G.0" instead of repeating them:

1. **Plan before code.** Read the cited PRD sections and the named files first; restate the goal + a short step plan before editing anything.
2. **Stay in scope.** Create/edit only the files under "you own"; never touch "off-limits" files. If the work needs a change outside scope, or the spec is ambiguous or contradicts the code, **STOP and report — never guess or silently reconcile.**
3. **Verify on the real machine — never from reading code.** Use your shell/computer tools to actually run what you built: start the daemon (`python daemon/main.py --dev`), `curl` the endpoints, run `pytest`, build the app (`xcodebuild`), kill/restart processes, time responses, and check `pgrep -fl` for orphans. Run → read the real output → fix → re-run until green. Both Claude Code and Codex can execute commands and drive the UI — use that; do not simulate or assume.
4. **Evidence rule.** Paste the actual command/test output for every Definition-of-done item. An item is done only when its real output is in your report; a bare "verified" with no output is rejected.
5. **Don't regress.** Re-run every **Must-still-pass** check and paste its output before declaring done.
6. **Respect §F non-negotiables and §B conventions** at all times. Keep files < 500 lines; keep changes surgical.
7. **Report** which files you changed (must match "you own"), which Must-still-pass checks you re-ran, and any scope conflict you hit.

---

### Foundations — Repo + Environments

*One-time setup before M1. Done when: both venvs build clean and the Bonsai model answers one inference.*

---

#### Slice F1 — Repo scaffold

- **Goal.** An empty-but-correct repository skeleton exactly matching [§D](#d-repository-structure), committed once.
- **Depends on.** Nothing (first slice).
- **Files — Owns:** the entire tree as stubs; `.gitignore`; `.env.example`; empty requirements files. **Off-limits:** any feature logic.
- **Build.** git init → create every dir/file in §D as a stub (Python files get a one-line docstring) → `__init__.py` in every package → `.gitignore` (`.venv`, `.venv-bonsai`, `.env`, `models/`, weights, `__pycache__/`, `*.pid`, `*.port`, `.DS_Store`, Xcode output) → `.env.example` → initial commit.
- **Acceptance test.** `tree -a` reproduces §D; `git status` clean after commit; `git check-ignore .venv .env models/` confirms exclusion.
- **Must-still-pass.** N/A (first slice).
- **Guardrails.** Match the tree exactly. Never commit weights/`.env`/secrets. `daemon/` and `bonsai_sidecar/` import across the boundary only via HTTP.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Senior engineer scaffolding a brand-new repository: exact structure, zero feature logic.
> **Objective.** Create the Lira skeleton exactly as in §D and make the initial commit.
> **Read first.** §D (full tree); §F Non-negotiables. Restate your plan in 2–3 lines before editing.
> **You own.** The whole tree + stubs in §D; `.gitignore`; `.env.example`; empty `requirements.txt` and `bonsai_sidecar/requirements.txt`. **Off-limits.** Any feature logic in any file.
> **Build, in order.** 1) `git init`. 2) Create every dir/file in §D as a stub (each Python file gets a one-line responsibility docstring). 3) `__init__.py` in every package under `daemon/`, `background_instance/`, `bonsai_sidecar/`. 4) `.gitignore`: `.venv`, `.venv-bonsai`, `.env`, `models/`, weights, `__pycache__/`, `*.pid`, `*.port`, `.DS_Store`, Xcode output. 5) `.env.example` (no real values). 6) Initial commit.
> **Hard rules.** Match the tree exactly (names + nesting). Never commit weights/`.env`/secrets — verify `.gitignore` first. Keep `daemon/` and `bonsai_sidecar/` separate (HTTP-only boundary).
> **Verify on the real machine.** Actually run `tree -a` (or `find .`), `git status`, and `git check-ignore .venv .env models/`; read the real output.
> **Definition of done — paste real output for each.** 1) `tree -a` reproduces §D exactly. 2) `git status` clean after the commit. 3) `git check-ignore` proves venvs/`.env`/weights excluded. 4) List any file you were unsure where to place. **Must-still-pass:** N/A — first slice.
> **If the tree and any slice's files disagree, STOP and flag it — do not silently reconcile.**

---

#### Slice F2 — Dependency stack (two isolated venvs)

- **Goal.** `.venv` (main, stock MLX) and `.venv-bonsai` (sidecar, forked/GGUF MLX) build from scratch, all imports smoke-test, and the Bonsai model answers one inference.
- **Depends on.** F1.
- **Files — Owns:** `requirements.txt`, `bonsai_sidecar/requirements.txt`. **Off-limits:** feature code.
- **Build.** Verify macOS ≥14.0 + arm64 → pin every package → create `.venv` + main stack + `playwright install chromium` → create `.venv-bonsai` separately with forked MLX → **load `prism-ml/Bonsai-8B-mlx-1bit` and run one inference; on failure fall back to GGUF via `llama-cpp-python`, pin it, record the decision** → smoke-test main imports + `sqlite_vec.load()`.
- **Acceptance test.** Both venvs build on a clean Mac; every import passes; the Bonsai model loads and answers one inference (report which backend + why).
- **Must-still-pass.** N/A.
- **Guardrails.** The two `mlx` packages never share an interpreter. Every version pinned. Nothing global. A failed install stops the run.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Senior environment/build engineer on Apple Silicon; you prove environments work before declaring them ready.
> **Objective.** Install the full stack into two isolated venvs (`.venv` main / `.venv-bonsai` sidecar) and prove the Bonsai model loads.
> **Read first.** §E Dependency Stack (both lists + fork/GGUF notes + reference pins); Slice 1.1. Restate your plan first.
> **You own.** `requirements.txt`, `bonsai_sidecar/requirements.txt`. **Off-limits.** Feature code.
> **Build, in order.** 1) Verify macOS ≥14.0 and `arm64`; else stop. 2) Pin every package to a resolved version. 3) Create `.venv`, install the main stack, `playwright install chromium`. 4) Create `.venv-bonsai` separately, install the sidecar stack with forked MLX. 5) **Load `prism-ml/Bonsai-8B-mlx-1bit` and run one inference; if the fork won't load, fall back to GGUF via `llama-cpp-python`, pin it, and record the decision.** 6) Smoke-test main imports + `sqlite_vec.load()`.
> **Hard rules.** The two `mlx` packages never share an interpreter. Every version pinned. Nothing global. No secrets committed. A failed install stops the run.
> **Verify on the real machine.** Actually build both venvs from scratch, run the import smoke tests in each, and run one real Bonsai inference — paste the outputs.
> **Definition of done — paste real output for each.** 1) Both venvs build clean. 2) `import mlx, mlx_vlm, fastapi, sqlite_vec, mempalace` + `sqlite_vec.load()` pass in `.venv`. 3) The Bonsai model answers one inference — state the backend (forked MLX / GGUF) and why. 4) Report the exact resolved pins. **Must-still-pass:** N/A — first env slice.
> **Prove the forked-MLX/Bonsai load before anything depends on it — test by importing and running, not by a successful `pip install` alone.**

---

### M1 — The Brain Wakes Up

*Qwen3.5 loads and streams a response over HTTP. Done when: you send a message to the daemon and watch a streamed reply, and `/model/info` reports the live model identity.*
*PRD: §5.1, §5.2, §5.4, §5.7.*

---

#### Slice 1.1 — Dev environment script

- **Goal.** `scripts/setup_dev.sh` builds the entire dev environment on a clean Mac in one run.
- **Depends on.** F2.  **Files — Owns:** `scripts/setup_dev.sh`. **Off-limits:** daemon code.
- **Build.** Stop on any failure: check macOS ≥14.0 → `arm64` → Homebrew if missing → `python@3.11` → `.venv` + main deps → `.venv-bonsai` + sidecar deps (GGUF fallback) → `playwright install chromium` → success print.
- **Acceptance test.** From deleted venvs, the script completes and both import cleanly; an injected failure exits non-zero with a clear message.
- **Must-still-pass.** F2 imports still pass.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Build engineer writing a one-shot, fail-loud setup script.
> **Objective.** `scripts/setup_dev.sh` builds both venvs reproducibly on a clean Mac.
> **Read first.** §E; F2's recorded backend decision. Restate your plan first.
> **You own.** `scripts/setup_dev.sh`. **Off-limits.** Daemon code.
> **Build, in order.** macOS/arm64 checks → Homebrew if missing → `python@3.11` → `.venv` + main deps → `.venv-bonsai` + sidecar deps (GGUF fallback) → `playwright install chromium` → success print. Stop with a clear message + non-zero exit on any failure.
> **Hard rules.** Never silently continue past a failure. Never skip the Bonsai venv.
> **Verify on the real machine.** Actually delete `.venv` and `.venv-bonsai`, run `./scripts/setup_dev.sh`, then import-smoke both venvs; inject a failure and confirm it aborts loudly.
> **Definition of done — paste real output for each.** 1) Clean run from deleted venvs completes. 2) Imports pass in both venvs. 3) An injected failure exits non-zero with a clear message. **Must-still-pass:** F2 imports still pass.

---

#### Slice 1.2 — Model bootstrap

- **Goal.** `scripts/bootstrap_model.sh` downloads Qwen3.5, converts to MLX, stores it under App Support with a resumable, real-progress download.
- **Depends on.** 1.1.  **Files — Owns:** `scripts/bootstrap_model.sh`. **Off-limits:** daemon code.
- **Build.** Skip-if-present (valid `manifest.json`) → mkdir → resumable HF download with real byte progress → MLX 4-bit convert → write + verify `manifest.json` (name/params/quant/revision).
- **Acceptance test.** First run downloads + writes a valid manifest; interrupt + re-run resumes; a second run prints "Skipping."
- **Must-still-pass.** 1.1 still completes clean.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Engineer building a resumable model-bootstrap script.
> **Objective.** Download + convert Qwen3.5 to MLX under App Support with truthful progress and a manifest.
> **Read first.** PRD §5.2 (live identity from manifest), §15.3. Restate your plan first.
> **You own.** `scripts/bootstrap_model.sh`. **Off-limits.** Daemon code.
> **Build, in order.** Skip-if-present (valid `manifest.json`) → mkdir → resumable HuggingFace download with real byte progress → MLX 4-bit convert → write + verify `manifest.json` (name/params/quant/revision).
> **Hard rules.** Weights only under App Support, never the repo. The manifest is the single source of model identity (consumed by 1.4 `info()`).
> **Verify on the real machine.** Actually run it: kill it mid-download and re-run to prove resume; run it again to prove it skips; print the manifest.
> **Definition of done — paste real output for each.** 1) Fresh run writes a valid `manifest.json`. 2) Interrupt + re-run resumes (no full re-download). 3) A second run prints "Skipping." **Must-still-pass:** 1.1 still completes clean.

---

#### Slice 1.3 — Config

- **Goal.** `daemon/core/config.py` is the single home for all paths, ports, and constants.
- **Depends on.** F1.  **Files — Owns:** `daemon/core/config.py`. **Off-limits:** everything else.
- **Build.** A `data_root()` resolver (env `LIRA_DATA_ROOT` → persisted user setting → default `~/Library/Application Support/Lira/`); then models dir, DB path, MemPalace path, annotation-screenshots dir, `.port`/`.pid` paths (daemon + sidecar + background instances) — **all derived from `data_root()`**. Preferred ports (8765/8766), RAM constants (`BACKGROUND_SAFETY_MARGIN_BYTES`, `BACKGROUND_MAX_INSTANCES`, model-footprint estimate), token budgets, timeouts, `127.0.0.1` bind address. If an overridden `data_root()` is unavailable (e.g. external drive unmounted), raise a clear error and fall back to the App Support default. Pure constants + tiny helpers.
- **Acceptance test.** Default import → everything resolves under `~/Library/Application Support/Lira/` (main SSD). With `LIRA_DATA_ROOT=/tmp/lira-test`, everything resolves there. With `LIRA_DATA_ROOT` pointed at a non-existent/unmounted path → clear error + fall back to default. `grep` shows no hardcoded data path or port elsewhere.
- **Must-still-pass.** N/A.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Engineer centralizing configuration.
> **Objective.** `daemon/core/config.py` as the only source of paths, ports, and constants, with a single **configurable data root** that defaults to the main SSD for release.
> **Read first.** PRD §5.1 (port discovery), §17; §B "One configurable data root". Restate your plan first.
> **You own.** `daemon/core/config.py`. **Off-limits.** Everything else.
> **Build.** A `data_root()` resolver in order: env `LIRA_DATA_ROOT` → persisted user setting → default `~/Library/Application Support/Lira/` (the **public-release default — main/boot SSD, never an external drive**). Derive **every** data path (models dir, DB, MemPalace, annotation screenshots, `.port`/`.pid` files) from `data_root()`. Then ports/pid/port-file paths, preferred ports, RAM/token/timeout constants, the `127.0.0.1` bind address. If an overridden root is unavailable (drive unmounted), raise a clear error and fall back to the App Support default. Pure constants + tiny path helpers.
> **Hard rules.** Nothing else in the codebase defines a path or port. Release builds ship no override → always the App Support default on the main SSD. An external drive is a dev-only override, never the shipped default.
> **Verify on the real machine.** Actually run (1) default: `python -c "import daemon.core.config as c; print(c.data_root(), c.DB_PATH)"` → confirm under App Support; (2) `LIRA_DATA_ROOT=/tmp/lira-test python -c "import daemon.core.config as c; print(c.DB_PATH)"` → confirm under `/tmp/lira-test`; (3) point `LIRA_DATA_ROOT` at a missing path → confirm a clear error + fallback. Then `grep -rn` for hardcoded data paths/ports elsewhere.
> **Definition of done — paste real output for each.** 1) Default resolves under App Support (main SSD). 2) `LIRA_DATA_ROOT` override relocates every data path. 3) Unmounted/missing override → clear error + fallback to default. 4) `grep` shows no hardcoded data path/port anywhere else. **Must-still-pass:** N/A.

---

#### Slice 1.4 — Model loader + frozen signature + `info()`

- **Goal.** `daemon/core/model.py` loads Qwen once and exposes the **frozen** generate/stream signature plus live `info()` from the manifest.
- **Depends on.** 1.2, 1.3.  **Files — Owns:** `daemon/core/model.py`. **May read:** `config.py`, the manifest. **Off-limits:** API/routes/all else.
- **Interfaces (FROZEN — #11).** `generate(prompt, image=None, context=None, history=None, tools=None, max_tokens=...)`, `stream_generate(...)` same params, `info() -> {name,params,quantization,revision}` from the manifest, `load()`. Re-entrant inference lock.
- **Acceptance test.** `load()` then `stream_generate("hello")` yields tokens; `info()` returns the manifest's real values; changing the manifest changes `info()`.
- **Must-still-pass.** 1.3 import still clean.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** ML systems engineer owning the only file that touches Qwen.
> **Objective.** Load Qwen once; expose the frozen generate/stream signature + manifest-driven `info()`; stream tokens.
> **Read first.** PRD §5.2, §5.4, §5.7 (frozen signature); non-negotiable #11. Restate your plan first.
> **You own.** `daemon/core/model.py`. **May read.** `config.py`, the manifest. **Off-limits.** API/routes/all else.
> **Honor (FROZEN, #11).** `generate(prompt, image=None, context=None, history=None, tools=None, max_tokens=…)`, `stream_generate(…)` same params, `info() -> {name,params,quantization,revision}` from the manifest, `load()`. Do not change the signature.
> **Build.** mlx-vlm load → apply chat template → token streaming → `info()` from the manifest → a re-entrant inference lock.
> **Hard rules.** Signature frozen forever. No hardcoded model name. Only this file imports Qwen.
> **Verify on the real machine.** Actually call `load()` then `stream_generate("hello")` and watch tokens arrive one-by-one; print `info()`; edit the manifest and confirm `info()` changes.
> **Definition of done — paste real output for each.** 1) `stream_generate` yields tokens incrementally (not one blob). 2) `info()` returns the manifest's real values and changes when the manifest changes. **Must-still-pass:** 1.3 import still clean.

---

#### Slice 1.5 — API server + `/health` + `/model/info`

- **Goal.** A FastAPI app that loads the model on startup and serves `/health`, `/model/info`, and a streaming chat endpoint.
- **Depends on.** 1.4.  **Files — Owns:** `daemon/api/server.py`, `daemon/api/routes/chat.py` (minimal). **May read:** `model.py`, `config.py`. **Off-limits:** memory/jobs/etc.
- **Build.** FastAPI app; startup loads the model in a background thread (server answers during load with a "loading" health state); `GET /health` → `{status, model_loaded, model_info}`; `GET /model/info`; streaming `POST /chat/stream`; localhost-only CORS.
- **Acceptance test.** `curl /health` shows loading→ready; `/model/info` returns the manifest identity; `curl -N /chat/stream` streams a reply.
- **Must-still-pass.** 1.4 streaming through the model layer.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Backend engineer building the daemon's HTTP surface.
> **Objective.** A FastAPI app that loads the model on startup and serves `/health`, `/model/info`, and streaming `/chat/stream`.
> **Read first.** PRD §5.1, §5.4; non-negotiables #1, #9. Restate your plan first.
> **You own.** `daemon/api/server.py`, `daemon/api/routes/chat.py` (minimal streaming endpoint). **May read.** `model.py`, `config.py`. **Off-limits.** memory/jobs/control.
> **Build.** App + startup model-load thread (server answers during load with a "loading" health state) → `GET /health` `{status, model_loaded, model_info}` → `GET /model/info` → streaming `POST /chat/stream` → localhost-only CORS.
> **Hard rules.** Bind 127.0.0.1 only. Endpoints live only under `api/routes/`. No hardcoded model name in responses.
> **Verify on the real machine.** Actually start the server and run `curl /health` (during *and* after load), `curl /model/info`, and `curl -N /chat/stream`; read the output.
> **Definition of done — paste real curl output for each.** 1) `/health` transitions loading→ready and answers *during* load. 2) `/model/info` returns the live identity. 3) `/chat/stream` streams a reply. **Must-still-pass:** 1.4 streaming still works through the model layer.

---

#### Slice 1.6 — Daemon entry + port discovery

- **Goal.** `daemon/main.py` starts the server, discovering a free port and publishing it to a `.port` file.
- **Depends on.** 1.5.  **Files — Owns:** `daemon/main.py`. **May read:** `config.py`, `server.py`. **Off-limits:** all else.
- **Build.** Try preferred 8765; if taken, bind an OS-assigned free port; atomically write the actual port to the daemon `.port` file + a `.pid` file; clean both on graceful exit; `--dev` reload.
- **Acceptance test.** 8765 free → binds 8765, writes `.port`. 8765 occupied → binds a different free port, publishes it. Graceful stop removes `.port`/`.pid`.
- **Must-still-pass.** 1.5 endpoints reachable on the discovered port.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Systems engineer making the daemon robust to port conflicts.
> **Objective.** `daemon/main.py` with preferred-port→free-port discovery and a published `.port` file.
> **Read first.** PRD §5.1 (port discovery); non-negotiables #1, #6. Restate your plan first.
> **You own.** `daemon/main.py`. **May read.** `config.py`, `server.py`. **Off-limits.** All else.
> **Build.** Try preferred 8765 → if taken, bind an OS-assigned free port → atomically write the actual port to the daemon `.port` file + a `.pid` file → clean both on graceful exit → `--dev` enables reload.
> **Hard rules.** Bind 127.0.0.1 only. Clean PID/port files on exit (#6).
> **Verify on the real machine.** Actually start it with 8765 free (confirm it binds 8765 and writes `.port`); then occupy 8765 and start again (confirm a different free port is bound and published); then stop and confirm `.port`/`.pid` are gone.
> **Definition of done — paste real output for each.** 1) Binds 8765 + writes `.port` when free. 2) Binds + publishes a different free port when 8765 is taken. 3) Graceful stop removes `.port`/`.pid`. **Must-still-pass:** 1.5 endpoints reachable on the discovered port (`curl` it).

---

#### Slice 1.7 — Throwaway dev UI (smoke)

- **Goal.** A minimal CLI/curl smoke path to chat with the daemon end-to-end before the app exists.
- **Depends on.** 1.6.  **Files — Owns:** one throwaway script under `scripts/`. **Off-limits:** daemon code.
- **Build.** Read the discovered port from the `.port` file → POST a message to `/chat/stream` → print streamed tokens. Clearly throwaway.
- **Acceptance test.** Running it streams a Qwen reply in the terminal using the discovered port.
- **Must-still-pass.** 1.6 port discovery + 1.5 streaming.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
>
> **Role.** Engineer writing a throwaway smoke client.
> **Objective.** Stream a chat reply from the terminal via the discovered port, end-to-end, before the app exists.
> **Read first.** Slices 1.5–1.6. Restate your plan first.
> **You own.** One throwaway script under `scripts/` (e.g. `dev_chat.sh`). **Off-limits.** Daemon code.
> **Build.** Read the discovered port from the daemon `.port` file → POST a message to `/chat/stream` → print streamed tokens. Mark it clearly throwaway; no product logic may depend on it.
> **Verify on the real machine.** Actually start the daemon and run the script; watch the tokens stream in the terminal.
> **Definition of done — paste the streamed output.** 1) Running it streams a Qwen reply using the port read from `.port` (never hardcoded). **Must-still-pass:** 1.6 port discovery + 1.5 streaming still work.

### M2 — It Gets a Face

*A SwiftUI app with the orb, chat, menu bar, and daemon auto-start. Done when: you launch the app, it starts the daemon itself, you chat with a streaming reply, and killing the daemon then pressing Restart brings it back.*
*PRD: §4.3–4.4, §5.1, §8.5.*
> **App invariants:** `APIClient.swift` is the **only** Swift file with a URL/URLSession. All daemon URLs come from the discovered `.port` file. Never hardcode a port or model name.

---

#### Slice 2.1 — Xcode project + MenuBarExtra
- **Goal.** A buildable SwiftUI macOS-14 app with a `MenuBarExtra` + main-window shell, sandbox off. **Depends on.** M1. **Owns:** `App/LiraApp.swift`, `AppDelegate.swift`, `Views/ContentView.swift`. **Off-limits:** daemon, other views.
- **Acceptance.** `xcodebuild` → `** BUILD SUCCEEDED **`; menu-bar item + empty window appear. **Must-still-pass:** N/A.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS SwiftUI engineer scaffolding the app. **Objective.** A buildable macOS-14 app with `MenuBarExtra` + a main-window shell, sandbox off. **Read first.** PRD §4.4, §15.1 (no App Store → full system access). **You own.** `LiraApp.swift`, `AppDelegate.swift`, `Views/ContentView.swift`. **Off-limits.** Daemon code, other views. **Build.** App entry + `MenuBarExtra` + `WindowGroup` shell; disable the app sandbox; deployment target 14.0, Apple-Silicon only. No URL/URLSession here. **Verify on the real machine.** Actually run `xcodebuild` and read the result; launch the app and confirm the menu-bar item + empty window appear. **Definition of done — paste real output.** 1) `xcodebuild` prints `** BUILD SUCCEEDED **`. 2) Launch shows a menu-bar item + a main window. **Must-still-pass:** N/A — first app slice.

---

#### Slice 2.2 — DaemonService (launch/monitor both + restart recovery)
- **Goal.** The app starts, monitors, and reliably restarts **both** the daemon and the Bonsai sidecar as **independent** processes. **Depends on.** 2.1, 1.6. **Owns:** `Services/DaemonService.swift`. **Off-limits:** views.
- **Acceptance.** Both start healthy; kill daemon only → Restart relaunches just the daemon; kill sidecar only → Restart relaunches just the sidecar; quit → zero orphans (`pgrep`). **Must-still-pass:** 1.6 port discovery; app build.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS engineer owning process lifecycle. **Objective.** Launch/monitor/restart both the daemon and the Bonsai sidecar as **independent** processes, with reliable crash recovery. **Read first.** PRD §5.1; non-negotiable #6; Slice 1.6. **You own.** `DaemonService.swift`. **May read.** `APIClient.swift`, the `.port` files. **Off-limits.** Views, daemon code. **Build.** Spawn daemon + sidecar independently → wait for each `.port` + healthy → expose `daemonState` (starting/ready/stopped/error) → restart relaunches **only the dead** process (never bail because the other is alive), deleting stale `.pid`/`.port` first and resetting handles → quit terminates both. **Hard rules.** Treat the two processes independently. Clean stale files before relaunch (#6). 127.0.0.1 only. **Verify on the real machine.** Actually launch the app; `kill -9` the daemon **only** mid-run and press Restart (sidecar must stay up); then `kill -9` the sidecar only and Restart; then quit and run `pgrep -fl python`. **Definition of done — paste real output for each.** 1) Both start healthy. 2) Kill-daemon-only → Restart relaunches just the daemon → `ready`. 3) Kill-sidecar-only → Restart relaunches just the sidecar. 4) Quit → `pgrep` shows **zero** orphans. **Must-still-pass:** 1.6 port discovery still drives the URLs; the app still builds.

---

#### Slice 2.3 — APIClient (only URL-bearing Swift file)
- **Goal.** A single Swift networking layer reading the discovered port. **Depends on.** 2.2. **Owns:** `Services/APIClient.swift`, `Models/{Message,Session,Job}.swift`. **Off-limits:** views.
- **Acceptance.** `health()`/`modelInfo()` decode against a live daemon; `streamChat` yields tokens; `grep` shows no other URLSession user. **Must-still-pass:** 2.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Swift networking engineer. **Objective.** The single API client (the only URL-bearing Swift file), reading the discovered port. **Read first.** PRD §5.1; non-negotiable #1. **You own.** `Services/APIClient.swift`, `Models/{Message,Session,Job}.swift`. **Off-limits.** Views, other services. **Build.** Read the daemon `.port`; typed async `health()`, `modelInfo()`, `streamChat()` (token stream) + decodable models + job/memory stubs for later slices. **Hard rules.** This is the **only** Swift file with a URL/URLSession; all URLs derive from `.port`, never hardcoded. **Verify on the real machine.** Actually start the daemon, run a small test calling `health()`/`modelInfo()`/`streamChat()`, and run `grep -rn URLSession app/` to confirm no other file uses it. **Definition of done — paste real output.** 1) `health()`/`modelInfo()` decode against a live daemon. 2) `streamChat` yields tokens. 3) `grep` shows `APIClient.swift` is the only URLSession user. **Must-still-pass:** 2.2 still launches the daemon this calls.

---

#### Slice 2.4 — Orb view (six states)
- **Goal.** The particle orb renders six states (idle/listening/thinking/responding/error/muted). **Depends on.** 2.1. **Owns:** `Views/OrbView.swift`. **Off-limits:** services.
- **Acceptance.** Each state renders its distinct animation; idle CPU stays low. **Must-still-pass:** 2.1 build.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI/Core Animation engineer. **Objective.** The six-state particle orb. **Read first.** PRD §4.3. **You own.** `Views/OrbView.swift`. **Off-limits.** Services, other views. **Build.** A teal/cyan particle sphere on a dark background; per-state animation driven by an `OrbState` enum. Visual only, no network. **Verify on the real machine.** Actually build (`xcodebuild`) and run the app/preview; toggle through all six states and watch each distinct animation; read idle CPU in Activity Monitor. **Definition of done — paste output/screenshots.** 1) Each of the six states renders its distinct animation. 2) Idle CPU stays low. **Must-still-pass:** 2.1 build still succeeds.

---

#### Slice 2.5 — Chat view (streaming) + single-flight guard
- **Goal.** Stream Qwen's reply token-by-token; **cannot** send a new message while one is in flight. **Depends on.** 2.3, 2.4. **Owns:** `Views/ChatView.swift`, `App/AppState.swift`. **Off-limits:** services, daemon.
- **Acceptance.** A reply streams; mid-stream Send + Enter are disabled; spamming Enter sends nothing extra and never corrupts the transcript. **Must-still-pass:** 2.3 streamChat; app builds.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI engineer building the chat surface with a hard single-flight guard. **Objective.** Stream replies token-by-token; make a second concurrent send impossible from the UI. **Read first.** PRD §5.4; non-negotiable #12. **You own.** `Views/ChatView.swift`, `App/AppState.swift`. **May read.** `APIClient`, `OrbView`. **Off-limits.** Services, daemon. **Build.** Message list + input; `streamChat` appends tokens to the last assistant bubble; orb responding→idle. An `isResponding` flag disables **both** the send button **and** the return-key path during a stream, re-enabled only on completion/error. **Hard rules.** No URL calls here (use `APIClient`). The guard must cover the keyboard path, not just the button. **Verify on the real machine.** Actually run the app with the daemon up; send a message, and while it streams, **hammer Enter and click Send repeatedly**; confirm no extra requests fire and the transcript isn't corrupted. **Definition of done — paste/describe real results.** 1) A reply streams into the bubble. 2) Mid-stream, Send + Enter are disabled. 3) Spamming Enter sends nothing extra and never corrupts the transcript. **Must-still-pass:** 2.3 `streamChat` still yields tokens; the app still builds.

---

#### Slice 2.6 — Menu bar (six states)
- **Goal.** Six-state menu-bar icon + basic controls (open / mute / restart / quit). **Depends on.** 2.1, 2.2. **Owns:** menu-bar view. **Off-limits:** service internals.
- **Acceptance.** Icon tracks state; all menu actions work. **Must-still-pass:** 2.2 restart; 2.5 chat.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS menu-bar engineer. **Objective.** A six-state menu-bar icon + basic controls. **Read first.** PRD §4.4, §8.5. **You own.** Menu-bar content in `LiraApp.swift` / a small `Views/MenuBarView.swift`. **May read.** `AppState`, `DaemonService`. **Off-limits.** Service internals. **Build.** Six icon states (idle grey / listening teal pulse / activated white pulse / thinking amber spin / speaking teal wave / muted red); menu items: open window, mute toggle, restart (via `DaemonService`), quit. **Verify on the real machine.** Actually run the app; drive state changes and watch the icon follow; click each menu action. **Definition of done — paste/describe.** 1) The icon reflects each state change. 2) Open/mute/restart/quit all work. **Must-still-pass:** 2.2 restart still works (now also from the menu); 2.5 chat unaffected.

---

#### Slice 2.7 — Settings view (live model info)
- **Goal.** Show the **live** loaded model identity (never hardcoded). **Depends on.** 2.3. **Owns:** `Views/SettingsView.swift`. **Off-limits:** service internals.
- **Acceptance.** Settings shows the manifest's real identity; editing the manifest changes it. **Must-still-pass:** 2.3 modelInfo.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI settings engineer. **Objective.** Show the live loaded model identity in Settings (never a hardcoded name). **Read first.** PRD §5.2. **You own.** `Views/SettingsView.swift`. **May read.** `APIClient`, `AppState`. **Off-limits.** Service internals. **Build.** Read `modelInfo()` and display name/params/quantization/revision live; placeholders for later sections (voice, trust, memory). **Hard rules.** No hardcoded model name anywhere in the app. **Verify on the real machine.** Actually run the app, read the displayed identity, then edit the manifest, reload, and confirm the displayed value changes. **Definition of done — paste the value before/after.** 1) Settings shows the manifest's real identity. 2) Editing the manifest changes it — nothing hardcoded. **Must-still-pass:** 2.3 `modelInfo()` still decodes.

---

#### Slice 2.8 — App lifecycle (auto start/stop, clean teardown)
- **Goal.** Launch auto-starts the daemon; quit stops both cleanly. **Depends on.** 2.2, 2.5. **Owns:** lifecycle wiring in `AppDelegate.swift`/`LiraApp.swift`. **Off-limits:** service internals.
- **Acceptance.** Cold launch reaches a working chat with no terminal; quit → zero orphans. **Must-still-pass:** 2.2 restart, 2.5 single-flight, 2.6 menu states.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS lifecycle engineer. **Objective.** Launching the app auto-starts the daemon; quitting stops both processes cleanly. **Read first.** PRD §5.1; non-negotiable #6. **You own.** Lifecycle wiring in `AppDelegate.swift`/`LiraApp.swift`. **May read.** `DaemonService`. **Off-limits.** Service internals. **Build.** On launch, `DaemonService.start()`; show daemon state (starting/ready/error with a Restart affordance); on quit, stop both processes + clean PID/port files. **Hard rules.** Zero orphans on quit (#6). **Verify on the real machine.** Actually do a cold launch (no terminal) and reach a working chat; then quit and run `pgrep -fl python`. **Definition of done — paste real output.** 1) Cold launch auto-starts the daemon and chat works with no terminal step. 2) Quit → `pgrep` shows zero orphans. **Must-still-pass:** 2.2 restart, 2.5 single-flight, 2.6 menu states all still work.

### M3 — Sidecar, Tool Dispatch, and the Job System

*Bonsai online; Qwen can call tools; background jobs run in separate RAM-gated instances and surface results — without ever blocking the front chat. Done when: Qwen emits a function call that runs, a background job completes and shows its full output, two background jobs run concurrently while the foreground stays responsive, and rapid-sending can't crash the daemon.*
*PRD: §5.5–5.6, §6, §12.*
> **Invariants:** the foreground Qwen (`model.py`) is **never** used for background work (#12). All background generation runs in `background_instance/` processes, RAM-gated. `bonsai/client.py` is the only daemon file that knows the sidecar exists.

---

#### Slice 3.1 — Bonsai sidecar process
- **Goal.** A separate process loading Bonsai and serving extract/classify/expand/compact/score over `127.0.0.1`. **Owns:** `bonsai_sidecar/{server.py,bonsai.py,main.py}`. **Off-limits:** all `daemon/` code.
- **Acceptance.** `/health` ready fast; `/extract` returns real JSON; quit removes its files. **Must-still-pass:** 1.6 daemon port stays independent.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** ML engineer owning the isolated Bonsai sidecar. **Objective.** A separate process serving Bonsai's five functions over localhost. **Read first.** PRD §5.1, §12; §E (forked-MLX vs GGUF). **You own.** `bonsai_sidecar/{server.py,bonsai.py,main.py}`. **May read.** `config.py`. **Off-limits.** All `daemon/` code (process boundary). **Build.** Load the model (forked MLX primary, GGUF fallback) **applying the chat template** → FastAPI on a discovered port (pref 8766) published to the sidecar `.port` → `POST /extract|/classify|/expand|/compact|/score` returning clean JSON → `GET /health` with `model_loaded` → clean PID/port on exit. **Hard rules.** Never imports `daemon/`. Bind 127.0.0.1 only. Chat template applied (or output is garbage). **Verify on the real machine.** Actually start the sidecar, `curl /health` and a real `POST /extract`, then quit and confirm `.port`/`.pid` are gone. **Definition of done — paste real output.** 1) `/health` shows `model_loaded: true` within seconds. 2) `/extract` returns structured JSON (real content). 3) Quit removes its files. **Must-still-pass:** 1.6 daemon port discovery stays independent.

---

#### Slice 3.2 — Bonsai client (daemon side)
- **Goal.** The single daemon-side HTTP client to the sidecar; degrades gracefully if it's down. **Owns:** `daemon/bonsai/client.py`. **Off-limits:** all other daemon code.
- **Acceptance.** Each method round-trips live; sidecar-down returns safe defaults, no exception. **Must-still-pass:** 3.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the sole daemon-side bridge to the sidecar. **Objective.** An async, fault-tolerant Bonsai client. **Read first.** PRD §12.4; non-negotiable #9. **You own.** `daemon/bonsai/client.py`. **May read.** `config.py`, sidecar `.port`. **Off-limits.** All other daemon code. **Build.** Async `extract`, `classify`, `expand_keywords`, `compact`, `score_urgency` over the discovered sidecar port; **degrade gracefully** (safe defaults, never raise) if the sidecar is down. **Hard rules.** This is the **only** daemon file aware the sidecar exists. Never crash on sidecar failure. **Verify on the real machine.** Actually run each method against a live sidecar; then **stop the sidecar** and confirm calls return safe defaults without raising. **Definition of done — paste both behaviors.** 1) Each method round-trips live. 2) Sidecar-down returns safe defaults, no exception. **Must-still-pass:** 3.1 sidecar endpoints still serve.

---

#### Slice 3.3 — Notification queue
- **Goal.** Thread-safe in-memory queue for background→Qwen handoffs. **Owns:** `daemon/core/notifications.py`. **Off-limits:** chat route (wired in 3.14).
- **Acceptance.** Ordered single-delivery drain; concurrent-push safe. **Must-still-pass:** N/A.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the notification handoff queue. **Objective.** A thread-safe push/drain queue. **Read first.** PRD §6.2, §12.3. **You own.** `daemon/core/notifications.py`. **Off-limits.** Chat-route internals. **Build.** `push(notification)`, `drain() -> list` (FIFO, clears), thread-safe; shape `{type, ref_id, title, summary, urgency}`. In-memory only. **Verify on the real machine.** Actually run `pytest tests/daemon/` covering ordered single-delivery and a concurrent-push test. **Definition of done — paste pytest output.** 1) Pushes drain in order and only once. 2) Concurrent pushes don't corrupt the queue. **Must-still-pass:** N/A.

---

#### Slice 3.4 — Tool registry + JSON schemas
- **Goal.** The catalog of tools Qwen can call, as JSON schemas. **Owns:** `daemon/core/tools.py`. **Off-limits:** dispatcher/subsystems.
- **Acceptance.** Valid schemas; Qwen emits a well-formed `delegate_background_task` call when injected. **Must-still-pass:** 1.4 generation with `tools=`.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer defining Qwen's tool surface. **Objective.** The JSON-schema tool registry injected into Qwen's context. **Read first.** PRD §5.6. **You own.** `daemon/core/tools.py`. **May read.** `config.py`. **Off-limits.** Dispatcher/subsystems. **Build.** `schemas() -> list` grouped by domain (control/screen/memory/delegation); register at least `delegate_background_task` + memory `save`/`query` stubs now; typed params. Schemas only — no execution. **Verify on the real machine.** Actually inject the schemas into a real Qwen generation and confirm it emits a well-formed `delegate_background_task` call. **Definition of done — paste a schema + the emitted call.** 1) `schemas()` returns valid JSON schemas. 2) Qwen emits a well-formed call when injected. **Must-still-pass:** 1.4 generation still works with `tools=` populated.

---

#### Slice 3.5 — Dispatcher
- **Goal.** Parse Qwen's function calls and route deterministically. **Owns:** `daemon/core/dispatcher.py`. **Off-limits:** subsystem internals.
- **Acceptance.** A delegation call routes to the orchestrator and returns a job id; a malformed call degrades cleanly. **Must-still-pass:** 3.4.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building deterministic function-call routing. **Objective.** Parse Qwen's function calls from the stream and route them to subsystems. **Read first.** PRD §5.5–5.6. **You own.** `daemon/core/dispatcher.py`. **May read.** `tools.py`, `orchestrator.py`, `notifications.py`. **Off-limits.** Subsystem internals. **Build.** `is_function_call(buffer)`, `extract_function_call(buffer)`, `handle(call, session_id) -> result`; route delegation→orchestrator (control/screen/memory stubbed). Unknown/malformed → clean error, never crash. User never sees raw calls. **Verify on the real machine.** Actually run a `delegate_background_task` call through `handle` (expect a job id) and a malformed call (expect a clean error). **Definition of done — paste both paths.** 1) Delegation routes and returns a job id. 2) A malformed call returns a clean error without crashing. **Must-still-pass:** 3.4 schemas still parse.

---

#### Slice 3.6 — Orchestrator (delegation; foreground off-limits)
- **Goal.** Choose cloud / local / queue for a delegation — never the foreground model. **Owns:** `daemon/core/orchestrator.py` (routing half; RAM-snapshot half in 3.11). **Off-limits:** `model.py`.
- **Acceptance.** Ample-RAM → local plan; forced-low-RAM → queue/cloud with a clear message; foreground never referenced. **Must-still-pass:** 3.5.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer implementing delegation execution. **Objective.** Choose cloud / local / queue for a delegated task — **never the foreground model**. **Read first.** PRD §5.6, §6.4; non-negotiable #12. **You own.** `daemon/core/orchestrator.py` (routing half). **May read.** `config.py`, `jobs/queue.py`. **Off-limits.** The foreground `model.py`. **Build.** `route(task) -> plan`: (1) foreground off-limits; (2) prefer an available cloud worker; (3) for local, request a pooled background instance gated by RAM (3.11/3.13); (4) on insufficient RAM/unavailable → queue or advocate cloud. Create the job + hand to the runner. Decide *how*, not *whether*. **Hard rules.** Foreground is never a target (#12). **Verify on the real machine.** Actually run a delegation with ample RAM (expect a local plan) and one with RAM forced low (expect queue/cloud with a clear message); grep to prove `model.py` foreground is never referenced. **Definition of done — paste both outcomes.** 1) Ample-RAM → local instance plan. 2) Forced-low-RAM → queue/cloud-fallback with a clear message. 3) Foreground never referenced. **Must-still-pass:** 3.5 routing reaches here.

---

#### Slice 3.7 — Job queue (SQLite state table)
- **Goal.** The durable job state table = the cross-process IPC layer. **Owns:** `daemon/jobs/queue.py`. **Off-limits:** runner/monitor.
- **Acceptance.** enqueue/update/list/get work and survive a daemon restart. **Must-still-pass:** 1.3 config paths.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the job state store. **Objective.** The SQLite `jobs` table + CRUD that is the cross-process IPC layer. **Read first.** PRD §6.1–6.2. **You own.** `daemon/jobs/queue.py`. **May read.** `config.py`. **Off-limits.** Runner/monitor logic. **Build.** The `jobs` table (exact §6.1 schema) + `enqueue/dequeue/update/get/list/unsurfaced_terminal_jobs/mark_surfaced`; init on daemon start. State-only, no inference. **Hard rules.** This table is the only cross-process job channel; durable across restart. **Verify on the real machine.** Actually enqueue a job, update its status, `list`/`get` it, then restart the daemon and confirm the row survives. **Definition of done — paste a row before/after restart.** 1) `enqueue/update/list/get` work. 2) The row survives a restart. **Must-still-pass:** 1.3 config paths.

---

#### Slice 3.8 — Worker wrappers (base / claude_code / codex)
- **Goal.** The worker interface + the two cloud CLI workers (interactive, fresh per task). **Owns:** `daemon/workers/{base,claude_code,codex}.py`. **Off-limits:** `model.py`, `qwen_instance.py` (3.13).
- **Acceptance.** An installed CLI runs a job to completion; an absent one reports `available()=false`. **Must-still-pass:** 3.7.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer wrapping the cloud CLI workers. **Objective.** `BaseWorker` + interactive `claude_code`/`codex` wrappers, fresh session per task. **Read first.** PRD §5.3; non-negotiable #2. **You own.** `daemon/workers/{base.py,claude_code.py,codex.py}`. **May read.** `config.py`, `jobs/queue.py`. **Off-limits.** `model.py`; `qwen_instance.py`. **Build.** `BaseWorker` (`available()`, `run(job, on_progress) -> str`); `claude_code`/`codex` as **interactive** `subprocess.Popen` sessions (not `-p`), fresh per task, killed on completion, progress to the job record. Keys from Keychain only. **Hard rules.** Fresh session per task; no key in files; raw output not user-facing. **Verify on the real machine.** With a CLI installed, actually run a job end-to-end; then point at an absent binary and confirm `available()` is false and routing falls back. **Definition of done — paste both.** 1) An installed CLI runs a job to completion. 2) An absent CLI reports `available()=false`. **Must-still-pass:** 3.7 job records update from worker progress.

---

#### Slice 3.9 — Job runner (concurrent, bounded)
- **Goal.** Run multiple jobs concurrently, bounded by real capacity. **Owns:** `daemon/jobs/runner.py`. **Off-limits:** `model.py`.
- **Acceptance.** Two jobs run with overlapping timestamps at capacity ≥2; serialize at capacity 1. **Must-still-pass:** 3.7, 3.8.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building a concurrent, bounded job runner. **Objective.** Run multiple background jobs at once, bounded by real worker/instance capacity. **Read first.** PRD §6.2; non-negotiable #12. **You own.** `daemon/jobs/runner.py`. **May read.** `queue.py`, `workers/*`, `orchestrator.py`. **Off-limits.** `model.py`. **Build.** A bounded concurrent loop: dequeue ready jobs, run up to N at once (N from worker/instance availability), write back `needs_input|complete|failed`. Sequential-safe at one worker. **Hard rules.** Never runs work on the foreground model (#12). Concurrency bounded by real capacity. **Verify on the real machine.** Actually enqueue two ready jobs and confirm overlapping timestamps when capacity allows; then set capacity 1 and confirm they serialize. **Definition of done — paste the timestamps.** 1) Two jobs run concurrently (overlapping) at capacity ≥2. 2) Serialize cleanly at capacity 1. **Must-still-pass:** 3.7 state transitions; 3.8 workers.

---

#### Slice 3.10 — Job monitor (no inference)
- **Goal.** Pure state-reader that turns terminal/needs-input states into notifications. **Owns:** `daemon/jobs/monitor.py`. **Off-limits:** `model.py`.
- **Acceptance.** Each terminal state yields exactly one notification; sidecar-down still works. **Must-still-pass:** 3.3, 3.7.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the inference-free job monitor. **Objective.** Turn terminal/needs-input job states into notifications. **Read first.** PRD §6.2, §12.2. **You own.** `daemon/jobs/monitor.py`. **May read.** `queue.py`, `notifications.py`, `bonsai/client.py`. **Off-limits.** `model.py`. **Build.** Poll `unsurfaced_terminal_jobs()` → notification per job → `bonsai_client.score_urgency` (degrade to 0) → push → `mark_surfaced`. **Never calls the foreground model.** **Hard rules.** No inference beyond Bonsai urgency. One notification per state change. **Verify on the real machine.** Actually drive a job to complete/needs_input/failed and confirm exactly one notification each; stop the sidecar and confirm urgency degrades to 0 without error. **Definition of done — paste the notification + degraded path.** 1) Each terminal state → exactly one notification. 2) Sidecar-down still works. **Must-still-pass:** 3.3 drain; 3.7 surfaced flags.

---

#### Slice 3.11 — RAM detection (macOS reclaimable / pressure-aware)
- **Goal.** Accurate free-memory detection counting reclaimable/purgeable/cached memory + a model-aware footprint. **Owns:** the RAM-snapshot functions in `daemon/core/orchestrator.py`. **Off-limits:** routing (3.6), the pool (3.13).
- **Acceptance.** With genuine free RAM a single ~2.5 GB instance is allowed (compare your figure to `vm_stat`/Activity Monitor); under pressure it's refused. **Must-still-pass:** 3.6.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS systems engineer who understands unified memory, purgeable/cached pages, and memory pressure. **Objective.** Accurate free-memory detection counting macOS reclaimable memory + a model-derived footprint, so the gate never falsely refuses. **Read first.** PRD §6.4; non-negotiable #12. **You own.** The RAM-snapshot functions in `daemon/core/orchestrator.py`. **May read.** `config.py`, the manifest. **Off-limits.** Routing (3.6), the pool (3.13). **Build.** `resources_snapshot() -> {available_bytes, pressure}` computing **reclaimable** available from `vm_stat`/`host_statistics64` (free + inactive + speculative + **purgeable** + file-backed × page size) and/or the macOS memory-pressure level (`sysctl kern.memorystatus_vm_pressure_level`) — **not** raw `psutil.virtual_memory().available`. `resources_available(footprint)` → reclaimable ≥ footprint + `SAFETY_MARGIN`; `footprint` from the manifest/measured RSS. Log your figure vs `psutil.available` vs pressure. **Hard rules.** The metric must reflect what macOS will actually reclaim; footprint is model-derived. **Verify on the real machine.** Actually read live memory: print your reclaimable figure, `psutil.available`, and `vm_stat`/Activity Monitor side by side; with genuine free RAM confirm a single ~2.5 GB (4B) instance is allowed; force pressure and confirm it's refused. **Definition of done — paste your figure vs `psutil.available` vs `vm_stat`.** 1) With genuine free RAM, `resources_available(footprint_4B)` is true (false-refusal gone). 2) Under real pressure it's false. **Must-still-pass:** 3.6 routing consumes this gate.

---

#### Slice 3.12 — Background instance process (separate model, idle teardown)
- **Goal.** An on-demand separate process loading its own Qwen on an OpenAI-compatible endpoint, idle self-teardown. **Owns:** `background_instance/{server.py,main.py}`. **Off-limits:** the foreground `model.py` instance.
- **Acceptance.** Spawn→serve→idle-exit with no orphan; foreground first token ~2s while it runs. **Must-still-pass:** 3.11 gate; #12.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the on-demand background model instance. **Objective.** A separate-process Qwen on an OpenAI-compatible endpoint with idle self-teardown. **Read first.** PRD §6.4; non-negotiables #6, #12. **You own.** `background_instance/{server.py,main.py}`. **May read.** `config.py`. **Off-limits.** The foreground `model.py` instance (this loads its own copy). **Build.** Own-process `model.load()` → `POST /v1/chat/completions` + `GET /health` on `127.0.0.1` + a discovered per-instance `.port` → busy flag → an **idle watchdog** that SIGTERMs itself after the idle timeout → SIGTERM handler for clean exit. **Hard rules.** Separate process + separate model copy — never the foreground instance (#12). 127.0.0.1 only. Idle teardown. Zero orphans. **Verify on the real machine.** Actually spawn it, `curl /health` then `/v1/chat/completions`, run a long completion **while** hitting the foreground `/chat/stream` (time its first token), wait out the idle timeout, and `pgrep` for orphans. **Definition of done — paste the lifecycle + concurrent foreground time.** 1) Spawn→serve→idle-exit with no orphan. 2) Foreground first token ~2s while the instance runs. **Must-still-pass:** 3.11 gate authorizes the spawn; #12 holds.

---

#### Slice 3.13 — Dynamic multi-instance pool (RAM-gated) + `qwen_instance` worker
- **Goal.** A pool that spawns multiple instances as RAM allows + a `qwen_instance` worker running jobs concurrently against them. **Owns:** `daemon/workers/qwen_instance.py` + a pool module. **Off-limits:** `model.py`.
- **Acceptance.** Two local jobs → two concurrent instances while the foreground answers ~2s; out-of-RAM parks/queues (no OOM) and resumes; idle teardown; zero orphans. **Must-still-pass:** 3.9, 3.11, 3.12, #12.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the RAM-gated background instance pool. **Objective.** Spawn multiple background instances as reclaimable RAM allows, reuse idle ones, and a `qwen_instance` worker that runs jobs concurrently against them. **Read first.** PRD §6.4; non-negotiables #6, #12; Slices 3.11–3.12. **You own.** `daemon/workers/qwen_instance.py` + a pool module (`daemon/jobs/background_pool.py` or `daemon/workers/pool.py`). **May read.** `orchestrator.py` (RAM gate), `config.py`. **Off-limits.** `model.py`. **Build.** Pool tracks each instance (process, port, busy/idle, last_used). `acquire()`: return an idle healthy instance; else if `resources_available(footprint)` and count < `BACKGROUND_MAX_INSTANCES`, spawn one; else `None`. `release()`, idle pruning. `qwen_instance` worker `acquire→run via /v1/chat/completions→release`; on `None`, park/queue (orchestrator cloud-fallback). **Hard rules.** `while reclaimable − SAFETY_MARGIN ≥ footprint and count < MAX: may spawn`. Foreground never used (#12). Zero orphans. **Verify on the real machine.** Actually start **two** local jobs with ample RAM → confirm **two** instances run concurrently while the foreground `/chat/stream` answers ~2s; force RAM low → confirm it parks/queues (no OOM) and resumes when memory frees; wait out idle teardown; `pgrep` after quit. **Definition of done — paste each.** 1) Two concurrent instances + foreground first-token time. 2) Out-of-RAM parks/queues without OOM and resumes. 3) Idle teardown; zero orphans. **Must-still-pass:** 3.9 concurrency; 3.11 gate; 3.12 instance lifecycle; #12.

---

#### Slice 3.14 — Chat route dispatch loop + backend single-flight guard
- **Goal.** Chat route runs the function-call dispatch loop, drains notifications, streams Qwen, and **cannot be crashed by concurrent sends**. **Owns:** `daemon/api/routes/chat.py`. **Off-limits:** memory subsystems (M4).
- **Acceptance.** Tool calls work mid-stream; two concurrent requests → second 409, no crash; end-to-end spam-Enter can't crash the daemon. **Must-still-pass:** 1.5, 2.5, 3.5.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer wiring the chat dispatch loop with a crash-proof backend guard. **Objective.** Stream + tool-dispatch + notification-drain, with at most one foreground generation at a time. **Read first.** PRD §5.5–5.6, §6.2; non-negotiable #12. **You own.** `daemon/api/routes/chat.py`. **May read.** `model.py`, `dispatcher.py`, `notifications.py`, `context.py` (interim). **Off-limits.** Memory subsystems (M4). **Build.** Per message: drain notifications → build interim context → stream from `model.stream_generate` buffering to detect a function call → on a call, `dispatcher.handle` + feed the result back, continue → else finish. A **backend single-flight** `threading.Lock`: a concurrent request gets `409 "busy"`. **Hard rules.** One foreground generation at a time. User never sees raw tool calls. Streaming preserved token-by-token. **Verify on the real machine.** Actually run a normal chat with a tool call; fire **two** `/chat/stream` requests at once (curl `&`) and confirm the second returns 409 and the daemon does not crash; then drive the 2.5 UI spam-Enter end-to-end and confirm no crash. **Definition of done — paste each.** 1) Tool calls work mid-stream; notifications drain before the reply. 2) Concurrent requests → second 409, daemon alive. 3) End-to-end spam-Enter can't crash the daemon. **Must-still-pass:** 1.5 streaming; 2.5 UI single-flight; 3.5 dispatch.

---

#### Slice 3.15 — Jobs API routes
- **Goal.** create / list / get(full) / answer / cancel job endpoints. **Owns:** `daemon/api/routes/jobs.py`. **Off-limits:** runner internals.
- **Acceptance.** Create→list→get(full)→answer/cancel all work; `get` returns the complete output. **Must-still-pass:** 3.7, 3.14.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer exposing the job API. **Objective.** create/list/get/answer/cancel job endpoints. **Read first.** PRD §6.1–6.3; non-negotiable #1. **You own.** `daemon/api/routes/jobs.py`. **May read.** `queue.py`, `orchestrator.py`. **Off-limits.** Runner internals. **Build.** `POST /jobs` (create with `worker_hint`), `GET /jobs`, `GET /jobs/{id}` (full record incl. `raw_output`), `POST /jobs/{id}/answer`, `POST /jobs/{id}/cancel`; register the router in `server.py`. **Hard rules.** 127.0.0.1 only. Full `raw_output` returned. **Verify on the real machine.** Actually `curl` create → list → get (confirm full output) → answer/cancel. **Definition of done — paste each response.** 1) Create→list→get(full)→answer/cancel all work. 2) `get` returns the complete output, not a preview. **Must-still-pass:** 3.7 state; 3.14 chat unaffected.

---

#### Slice 3.16 — App job surface (panel + banners + full-output detail view)
- **Goal.** The app shows jobs, banners on state changes, and the **complete** output of a finished job. **Owns:** `Views/{JobsPanelView,JobDetailView}.swift` + `AppState` job wiring + `APIClient` job methods. **Off-limits:** daemon code.
- **Acceptance.** Jobs appear; banners fire; a completed job's entire output is viewable + copyable. **Must-still-pass:** 2.5, 3.13, 3.15.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI engineer surfacing jobs. **Objective.** A jobs panel + state-change banners + a full-output detail view. **Read first.** PRD §6.2–6.3. **You own.** `Views/{JobsPanelView,JobDetailView}.swift`, job wiring in `AppState.swift`, job methods in `APIClient.swift`. **May read.** `Models/Job.swift`. **Off-limits.** Daemon code. **Build.** Poll `/jobs` → a panel listing jobs with status → banners on transitions (needs_input/complete/failed) → a tap-to-open detail view showing the **full** `raw_output` (scroll/select/copy), no truncation as the only view → answer/cancel actions. **Hard rules.** `APIClient` remains the only URL-bearing Swift file. Full output viewable. **Verify on the real machine.** Actually run the app + daemon; start a background job, watch it appear and the banners fire, and tap a completed job to confirm its **entire** output is selectable/copyable. **Definition of done — paste/describe each.** 1) Jobs appear; banners fire. 2) A completed job's full output is viewable + copyable. **Must-still-pass:** 2.5 chat single-flight; 3.13 concurrency (foreground responsive while jobs run); 3.15 endpoints.

### M4 — Memory: It Remembers You

*Lira remembers you across sessions — facts, decisions, projects, threads — all inspectable and deletable. Done when: you tell Lira your name, quit, reopen, and it knows; relevant context surfaces; the re-entry greeting names your active project; you can see and delete every record.*
*PRD: §7 (full memory system; canonical SQLite schema in §7.5).*
> **Invariants:** Bonsai (via `bonsai/client.py`) does **all** model-based memory ops; Qwen never writes its own memory. `core/context.py` is the single home for KV-tier assembly. 127.0.0.1 only; files < 500 lines.

---

#### Slice 4.1 — Storage schema
- **Goal.** All SQLite tables + FTS indexes + sqlite-vec created on daemon start. **Owns:** `daemon/memory/db.py`. **Off-limits:** retrieval/session/context.
- **Acceptance.** Every table + FTS index exists; `vec_version()` returns; survives restart; `jobs` table untouched. **Must-still-pass:** 3.7 jobs table.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Local-data engineer (SQLite / FTS5 / sqlite-vec). **Objective.** Create all tables + FTS indexes + the sqlite-vec extension on daemon start. **Read first.** PRD §7.4–7.5 (the full schema in §7.5 is the contract). **You own.** `daemon/memory/db.py`. **May read.** `config.py`. **Off-limits.** retrieval/session/context. **Build.** Every table + FTS5 index from PRD §7.5 + sqlite-vec load on the same connection; init on daemon start; idempotent (`IF NOT EXISTS`). One DB file under App Support. **Verify on the real machine.** Actually start the daemon, open the live DB, run `.schema`, call `vec_version()`, and restart to confirm persistence — read the real DB, not the source. **Definition of done — paste `.schema` + `vec_version()`.** 1) Every table + FTS index exists. 2) `vec_version()` returns. 3) Schema survives restart. **Must-still-pass:** 3.7 `jobs` table still present and working (shared DB file).

---

#### Slice 4.2 — Verbatim store (MemPalace)
- **Goal.** Verbatim conversation storage + semantic retrieval on the sqlite-vec backend. **Owns:** `daemon/memory/mempalace.py`. **Off-limits:** session/retriever.
- **Acceptance.** Relevant turns retrieved above 0.65; noise excluded. **Must-still-pass:** 4.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Retrieval engineer. **Objective.** MemPalace verbatim store on the sqlite-vec backend. **Read first.** PRD §7.4. **You own.** `daemon/memory/mempalace.py`. **May read.** `db.py`, `config.py`. **Off-limits.** session/retriever. **Build.** MemPalace with `storage_backend="sqlite-vec"`, `db_path=config.DB_PATH`; `store(content, metadata)` (session_id/thread_id/timestamp/role); `retrieve(query, n=3)` returning only results with similarity > 0.65. Same DB file; no separate service. **Verify on the real machine.** Actually store several turns and run `retrieve` queries; confirm relevant turns come back above 0.65 and noise is excluded — print the scores. **Definition of done — paste a store+retrieve run with scores.** 1) Relevant turns retrieved above threshold. 2) Noise excluded. **Must-still-pass:** 4.1 schema/extension still load.

---

#### Slice 4.3 — Session lifecycle + incognito
- **Goal.** Sessions survive restart, resume within a window, and can run fully in-RAM (incognito). **Owns:** `daemon/memory/session.py`. **Off-limits:** retriever/projects/context.
- **Acceptance.** Fact + session survive quit+relaunch; incognito writes zero rows and discards on toggle-off. **Must-still-pass:** 4.1, 4.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building session lifecycle + incognito. **Objective.** Durable sessions, a resume window, and RAM-only incognito. **Read first.** PRD §7.10 (session close), §7.2 (re-entry), §17 (incognito). **You own.** `daemon/memory/session.py`. **May read.** `mempalace.py`, `db.py`. **Off-limits.** retriever/projects/context. **Build.** `new_session`; `add_message` (MemPalace write + thread `last_active` + 15-min inactivity timer); `end_session` (deterministic **no-model** summary from existing records); `resume_or_new` (resume if last ended < 4h ago); `get_re_entry_context`. **Incognito:** RAM-only (no writes, extraction skipped); toggle-off discards the in-RAM session entirely. **Hard rules.** Summaries use pure assembly, never a model call. Incognito persists nothing. **Verify on the real machine.** Actually tell Lira a fact (row written), quit + relaunch (row + session survive), turn incognito on (zero rows), toggle off (in-RAM session gone) — check the live DB. **Definition of done — paste the row pre/post restart + the incognito zero-write proof.** 1) Fact + session survive quit+relaunch. 2) Incognito writes zero rows and discards on toggle-off. **Must-still-pass:** 4.2 store/retrieve; 4.1 schema.

---

#### Slice 4.4 — Fact/decision extraction (Bonsai → typed records)
- **Goal.** Bonsai extracts typed records from conversation, silently, never blocking chat. **Owns:** the extraction helper in `memory/`. **Off-limits:** chat route (4.10), `model.py`.
- **Acceptance.** A stated fact/decision appears as a row; chatter writes nothing; the reply is never blocked. **Must-still-pass:** 4.3, 3.2 degrade.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer wiring Bonsai extraction into storage. **Objective.** Turn conversation into typed records, silently, never blocking chat. **Read first.** PRD §7.5–7.6. **You own.** The extraction helper in `memory/` that calls `bonsai_client.extract` and writes rows. **May read.** `db.py`, `session.py`, `bonsai/client.py`. **Off-limits.** The chat route (4.10), `model.py`. **Build.** After an assistant turn, async-call `bonsai_client.extract` → schema-matched JSON → write to the right tables; handle contradictions (confidence), superseded decisions, resolved threads; fire only on recordable content; skip in incognito. **Hard rules.** Qwen never writes memory — only Bonsai does, via the client. Async, never blocks streaming. Incognito-safe. **Verify on the real machine.** Actually say "my name is X" (expect a `facts` row), state a decision (expect a `decisions` row), make casual chatter (expect no rows), confirm the reply isn't blocked — read the live DB. **Definition of done — paste the conversation + resulting rows.** 1) A stated fact/decision appears as a row. 2) Chatter writes nothing. 3) The reply is never blocked. **Must-still-pass:** 4.3 session writes; 3.2 client degrades if sidecar down.

---

#### Slice 4.5 — Retrieval
- **Goal.** A relevant-records block per message — keyword-expand + FTS + semantic, deduped, < 200 tokens. **Owns:** `daemon/memory/retriever.py`. **Off-limits:** context assembly (4.9).
- **Acceptance.** A related message surfaces relevant records; block < 200 tokens. **Must-still-pass:** 4.4, 3.2 degrade.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Retrieval/context engineer. **Objective.** A relevant-records block per message, cheap and under budget. **Read first.** PRD §7.7. **You own.** `daemon/memory/retriever.py`. **May read.** `db.py`, `mempalace.py`, `bonsai/client.py`. **Off-limits.** Context assembly (4.9). **Build.** `get_context_for_message(message, session_id)`: `bonsai_client.expand_keywords` → 3 parallel FTS queries (decisions, current-project facts/decisions, open threads) + `mempalace.retrieve(n=3)` → dedupe, cap 15 → a clean block under 200 tokens. **Hard rules.** Bonsai client is the only model-based path; degrade gracefully if the sidecar is down. Output < 200 tokens. **Verify on the real machine.** Actually store 5 conversations on different topics, then send a related message and confirm the relevant records surface; print the block + its token count. **Definition of done — paste the block + token count.** 1) A related message surfaces the relevant records. 2) The block stays under 200 tokens. **Must-still-pass:** 4.4 records exist; 3.2 degrade path.

---

#### Slice 4.6 — Projects & threads (2-level nesting)
- **Goal.** Threads classify into projects (or standalone), nesting capped at two levels in code. **Owns:** `daemon/memory/projects.py`. **Off-limits:** context/retriever.
- **Acceptance.** Classification works; a third-level attempt collapses to two. **Must-still-pass:** 4.3.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building project/thread classification. **Objective.** Classify threads into projects (or standalone), with nesting capped at two levels. **Read first.** PRD §7.3. **You own.** `daemon/memory/projects.py`. **May read.** `db.py`, `bonsai/client.py`. **Off-limits.** context/retriever. **Build.** `classify_and_assign(thread_id, messages)` via `bonsai_client.classify` → assign / create-new (surface a suggestion) / standalone; **enforce two-level nesting** (a child's `parent_thread_id` may point only to a top-level thread; nest-under-a-child attaches to that child's parent instead). `get_active_project`, `get_latest_thread`. **Hard rules.** Never a third nesting level (PRD invariant). Bonsai-only classification. **Verify on the real machine.** Actually classify a thread, then **deliberately try to create a third nesting level** and confirm it collapses to two; confirm `get_active_project` returns the most recent. **Definition of done — paste a classification + the nesting-cap test.** 1) Classification works. 2) A third-level attempt collapses to two. **Must-still-pass:** 4.3 thread `last_active` updates.

---

#### Slice 4.7 — Re-entry greeting
- **Goal.** A one-line resume suggestion from active project + latest thread + time of day. **Owns:** `get_re_entry_suggestion()`. **Off-limits:** chat route.
- **Acceptance.** Names the right project + thread; time-appropriate. **Must-still-pass:** 4.6, 4.3.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the re-entry suggestion. **Objective.** A one-line, accurate resume-greeting source. **Read first.** PRD §7.2–7.3. **You own.** `get_re_entry_suggestion()` (in `projects.py` or `session.py`). **May read.** `projects.py`, `session.py`. **Off-limits.** Chat route. **Build.** Combine active project + latest open thread + time context → a single ranked line, no summary dump. **Verify on the real machine.** Actually store some work, simulate a return, and confirm the suggestion names the correct active project + latest thread and adapts to time of day. **Definition of done — paste the suggestion after a real return.** 1) Names the right project + thread. 2) Time-appropriate, one line. **Must-still-pass:** 4.6 active project; 4.3 re-entry context.

---

#### Slice 4.8 — Compaction
- **Goal.** Silently compress the oldest prose at 80% of the window, never touching records. **Owns:** `daemon/memory/compaction.py`. **Off-limits:** context internals.
- **Acceptance.** Short passes unchanged; long triggers compaction (logged). **Must-still-pass:** 4.3, 3.2 degrade.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building context compaction. **Objective.** Compress old prose at 80% of the window without touching records. **Read first.** PRD §7.11. **You own.** `daemon/memory/compaction.py`. **May read.** `bonsai/client.py`. **Off-limits.** Context-assembly internals. **Build.** `check_and_compact(messages)`: estimate tokens (~4 chars/token); < 80% of 262,144 → unchanged; else compact the oldest 30% via `bonsai_client.compact` into one system summary message; log that it fired. Never compact decisions/facts/tasks — only prose. **Hard rules.** Only prose compacted. Bonsai-only. Silent. **Verify on the real machine.** Actually run a short conversation (unchanged) and a genuinely long one (triggers compaction — confirm in logs + before/after lengths). **Definition of done — paste the trigger log + before/after lengths.** 1) Short passes unchanged. 2) Long triggers compaction. **Must-still-pass:** 4.3 history integrity; 3.2 degrade path.

---

#### Slice 4.9 — Context assembly: KV tiers ⟵ keystone
- **Goal.** The single home for everything Qwen reads — Tier 1 / Tier 2 / dynamic, via KV-cache prefixing. **Owns:** `daemon/core/context.py`. **Off-limits:** chat route (4.10), `model.py`.
- **Acceptance.** Four pieces returned; Tier 1 never rebuilds, Tier 2 only on the flag; dynamic < 500 tokens. **Must-still-pass:** 4.5, 4.8.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Context-engineering specialist. **Objective.** The KV-tier context assembler — the single home for everything Qwen reads. **Read first.** PRD §7.7–7.9. **You own.** `daemon/core/context.py`. **May read.** `retriever.py`, `session.py`, `projects.py`, `compaction.py`, `notifications.py`, `tasklist.py` (stub until M5). **Off-limits.** The chat route (4.10), `model.py`. **Build.** `build_cached_prefix` — Tier 1 (system prompt + safety, computed once, never invalidated) + Tier 2 (profile, instructions [stub until M5], active-project snapshot, capability block, rebuilt **only** on an `invalidate_cache()` flag). `build_dynamic_context` — hot task list (stub) + `retriever.get_context_for_message` + drained notifications, **< 500 tokens**. `build_context(...) -> {prefix, dynamic, history, tools}`, `history` = last 4 through `compaction.check_and_compact`. **Hard rules.** Only file building prompts. Tier 1 never rebuilds; Tier 2 only on the flag. Dynamic < 500 tokens. **Verify on the real machine.** Actually call `build_context` across several messages; print the four pieces + token counts; trigger an `invalidate_cache()` and confirm only Tier 2 rebuilds while Tier 1 stays cached. **Definition of done — paste the pieces + token counts + a Tier-2 invalidation test.** 1) Four pieces returned. 2) Tier rebuild rules hold. 3) Dynamic < 500 tokens. **Must-still-pass:** 4.5 retrieval; 4.8 compaction.

---

#### Slice 4.10 — Chat wiring (real context, no M3 regression) ⟵ keystone
- **Goal.** Wire the real context assembler into the chat loop; accurate re-entry greeting; **no M3 regression**. **Owns:** `daemon/api/routes/chat.py` (rewire). **Off-limits:** memory internals, the model signature.
- **Acceptance.** After restart "what's my name" recalls; context appears; greeting names project/thread. **Must-still-pass (re-run, paste):** spam-Enter no-crash, background doesn't block foreground, kill+Restart recovers.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Integration specialist; you respect the frozen signature and do not break M3. **Objective.** Wire the real context assembler into the chat loop so Qwen reads memory every turn and gives an accurate re-entry greeting — without regressing M3. **Read first.** PRD §7.7, §7.2; non-negotiables #11, #12; the **current** `daemon/api/routes/chat.py` (M3 loop + the 409 single-flight guard) and `daemon/core/context.py` (4.9). **You own.** `daemon/api/routes/chat.py` (rewire only). **May read.** `context.py`, `session.py`, `bonsai/client.py`. **Off-limits.** Memory internals; the `model.py` signature. **Honor (FROZEN, #11).** `model.stream_generate(prompt, image, context, history, tools, max_tokens=…)` — do not change it. **Build.** Swap interim context for `context.build_context` → feed the frozen `stream_generate` → preserve streaming, the function-call dispatch loop, the 409 guard, foreground isolation → async `bonsai_client.extract` → incognito-safe → re-entry greeting at session start. **Hard rules.** Signature unchanged. Tier 1 never rebuilds; Tier 2 only on the flag. Dynamic < 500 tokens. Foreground never blocked (#12). Incognito persists nothing. **Verify on the real machine — this is the riskiest slice for M3.** Actually restart and ask "what's my name" (expect recall); confirm context appears + the greeting names project/thread; then **re-run the M3 set**: spam Enter mid-response (no corruption/crash), run a background job during chat (foreground unblocked), `kill` the daemon then Restart (recovers). **Definition of done — paste every check incl. the M3 re-runs.** 1) Cross-session recall + accurate greeting. 2) Spam-Enter no-crash. 3) Background doesn't block foreground. 4) Kill+Restart recovers. 5) `tests/daemon/test_context.py` green. **Must-still-pass:** the entire M3 regression set above.

---

#### Slice 4.11 — Memory API routes
- **Goal.** HTTP access to inspect and delete every piece of memory. **Owns:** `daemon/api/routes/memory.py`. **Off-limits:** memory internals.
- **Acceptance.** Every endpoint works; `/memory/clear` refuses without `{confirm:true}`. **Must-still-pass:** 4.4, 4.10.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** API engineer. **Objective.** HTTP endpoints to inspect and delete every piece of memory. **Read first.** PRD §7, §18; non-negotiables #1, #4. **You own.** `daemon/api/routes/memory.py`. **May read.** memory modules' public functions. **Off-limits.** Memory internals. **Build.** sessions (list/messages/delete), projects+threads, facts (list/delete), decisions (list/delete), `POST /memory/clear` requiring `{confirm: true}`; register the router. **Hard rules.** 127.0.0.1 only. Everything deletable (#4). Confirm-gated clear. **Verify on the real machine.** Actually `curl` each endpoint; delete a fact and confirm the row **and its embedding** are gone; call `/memory/clear` without the flag (refusal) and with it (wipe). **Definition of done — paste each endpoint response.** 1) Every endpoint returns/deletes correctly. 2) `/memory/clear` refuses without the flag. **Must-still-pass:** 4.4 records exist; 4.10 chat unaffected.

---

#### Slice 4.12 — MemoryView UI (inspect + delete + clear-all)
- **Goal.** A three-tab MemoryView where the user sees and deletes every record, end-to-end. **Owns:** `Views/MemoryView.swift` + `APIClient` memory methods. **Off-limits:** daemon code.
- **Acceptance.** Records shown; deleting a fact makes Lira forget it on the next question; Clear-All wipes; build succeeds. **Must-still-pass:** 2.7, 4.10.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI + API engineer; the user can see and delete *every* record. **Objective.** A three-tab MemoryView + clear-all, with deletion verified end-to-end. **Read first.** PRD §7, §18; non-negotiable #4. **You own.** `Views/MemoryView.swift` + memory methods in `APIClient.swift`. **May read.** `Models/*`. **Off-limits.** Daemon code. **Build.** Tabs — Sessions (list→summary→messages, swipe-delete), Projects & Threads (tree + standalone), Facts (category headers, swipe-delete); a "Clear All Memory" footer requiring the user to type "delete", previewing what's removed first. **Hard rules.** `APIClient` remains the only URL-bearing Swift file. Verify deletion end-to-end. **Verify on the real machine.** Actually build + run; confirm sessions/facts/decisions show; **delete a fact, then ask Lira and confirm it no longer knows it**; run Clear-All; `xcodebuild`. **Definition of done — paste the delete-then-ask proof + the build line.** 1) Records shown. 2) Deleting a fact makes Lira forget it on the next question. 3) Clear-All wipes everything. 4) `** BUILD SUCCEEDED **`. **Must-still-pass:** 2.7 settings live info; 4.10 chat recall (then deletion removes it).

### M5 — Personal Instructions and Task List

*Lira knows how you like to work and stays oriented across long sessions. Done when: a free-form instruction changes behavior immediately and persists, and a live task list rides at the top of context.*
*PRD: §4.5, §7.8, §7.9.*

---

#### Slice 5.1 — Instructions storage
- **Goal.** YAML structured + free-form (300-token cap) instructions with conditional blocks. **Owns:** `daemon/memory/instructions.py`. **Off-limits:** context assembly.
- **Acceptance.** Set persists; over-cap rejected; context-kind filtering works. **Must-still-pass:** 4.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the instructions store. **Objective.** YAML structured + free-form (300-token cap) instructions with conditional blocks. **Read first.** PRD §4.5, §7.8. **You own.** `daemon/memory/instructions.py`. **May read.** `config.py`. **Off-limits.** Context assembly. **Build.** YAML at App Support; structured settings (style/pushback/tone/empathy/proactivity); free-form with a hard 300-token cap; conditional blocks (coding-only, voice-only); `get/set/get_for_context/invalidate_cache`. **Hard rules.** Enforce the 300-token cap. **Verify on the real machine.** Actually `set` instructions (confirm the YAML), submit > 300 tokens (confirm rejection), call `get_for_context("coding")` (confirm only coding blocks). **Definition of done — paste the YAML + a cap-rejection.** 1) Set persists. 2) Over-cap rejected. 3) Context-kind filtering works. **Must-still-pass:** 4.1 schema (preferences may mirror structured settings).

---

#### Slice 5.2 — Instructions into Tier-2 + cache invalidation + mid-convo edit
- **Goal.** Instructions load into Tier 2; a mid-conversation change takes effect immediately and persists. **Owns:** the Tier-2 instructions wiring + update path in `context.py`. **Off-limits:** model signature, streaming.
- **Acceptance.** A spoken/typed instruction changes the next reply and survives restart. **Must-still-pass:** 4.9 tier rules; 4.10.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Context engineer. **Objective.** Instructions in the Tier-2 prefix + immediate, persistent mid-conversation edits. **Read first.** PRD §7.7–7.8. **You own.** The Tier-2 instructions wiring + update path in `daemon/core/context.py`. **May read.** `instructions.py`. **Off-limits.** The model signature, streaming behavior. **Build.** Tier 2 pulls `instructions.get_for_context`; a mid-conversation change calls `instructions.set` + `invalidate_cache` so the next prefix rebuild reflects it; Tier 1 never rebuilds. **Hard rules.** Only Tier 2 rebuilds on the flag; persists across restart. **Verify on the real machine.** Actually say "stop explaining your reasoning", confirm the **next** reply complies, check the YAML persisted, then restart and confirm it still complies. **Definition of done — paste before/after replies + post-restart proof.** 1) The instruction changes the next reply. 2) It survives restart. **Must-still-pass:** 4.9 tier rules (Tier 1 cached, Tier 2 on flag); 4.10 chat unaffected.

---

#### Slice 5.3 — Task list backend
- **Goal.** A hot/cold task list with caps + heartbeat timestamps. **Owns:** `daemon/memory/tasklist.py`. **Off-limits:** context assembly.
- **Acceptance.** Overflow spills to cold; hot stays within caps/budget. **Must-still-pass:** 4.1 tasks table.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the task list. **Objective.** A hot/cold task list with caps + heartbeat timestamps. **Read first.** PRD §7.9. **You own.** `daemon/memory/tasklist.py`. **May read.** `db.py`, `jobs/queue.py`. **Off-limits.** Context assembly. **Build.** Hot list (active ≤5, pending checks ≤3, ~100 tokens) + cold list (SQLite); `get_hot/add/update/complete`; pending-check timestamps as the heartbeat schedule. **Hard rules.** Hot list ~100 tokens; caps enforced. **Verify on the real machine.** Actually add tasks beyond the hot caps (confirm spill to cold) and measure `get_hot()` token count. **Definition of done — paste the caps test + a `get_hot` token count.** 1) Overflow spills to cold. 2) Hot stays within caps/budget. **Must-still-pass:** 4.1 schema (`tasks`).

---

#### Slice 5.4 — Task list into dynamic context + Bonsai updates on job state
- **Goal.** The hot task list rides in dynamic context, updated when jobs change state. **Owns:** the task-list hook in `core/context.py` + monitor→tasklist update path. **Off-limits:** `model.py`.
- **Acceptance.** A job appears/updates in the hot list; total dynamic context < 500 tokens. **Must-still-pass:** 4.9 budget; 3.10 monitor.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Integration engineer. **Objective.** The hot task list rides in dynamic context, updated when jobs change state. **Read first.** PRD §7.9, §6.2. **You own.** The task-list hook in `core/context.py` (replace the M4 stub) + the monitor→tasklist update path. **May read.** `tasklist.py`, `jobs/monitor.py`. **Off-limits.** `model.py`. **Build.** `build_dynamic_context` includes `tasklist.get_hot()`; the job monitor updates the task list on state changes (no inference). **Hard rules.** Dynamic context stays < 500 tokens with the task list included. **Verify on the real machine.** Actually run a background job and confirm it appears in the hot list, completing it updates the list; measure total dynamic-context tokens. **Definition of done — paste the list across a job state change + total dynamic token count.** 1) A job appears/updates in the hot list. 2) Total dynamic context < 500 tokens. **Must-still-pass:** 4.9 dynamic budget; 3.10 monitor single-delivery.

---

#### Slice 5.5 — Instructions + task-list settings UI
- **Goal.** Settings to edit instructions and view the task list. **Owns:** Settings sections + `APIClient` methods. **Off-limits:** daemon internals.
- **Acceptance.** A UI setting change alters the next reply; task view reflects live state. **Must-still-pass:** 2.7, 5.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI settings engineer. **Objective.** Edit instructions + view the task list in Settings. **Read first.** PRD §4.5, §7.8–7.9. **You own.** Instructions/task sections in `SettingsView.swift` + methods in `APIClient.swift`. **May read.** `AppState`. **Off-limits.** Daemon internals. **Build.** Structured-setting controls (segmented pickers) + a free-form text box (cap shown) + a read-only task-list view; changes call the daemon and apply immediately. **Hard rules.** `APIClient` remains the only URL-bearing Swift file. **Verify on the real machine.** Actually run the app; change a setting and confirm the next reply changes; confirm the task view reflects live state. **Definition of done — paste/describe the change taking effect.** 1) A UI setting change alters the next reply. 2) The task view reflects live state. **Must-still-pass:** 2.7 live model info; 5.2 immediacy/persistence.

---

### M6 — Voice

*Wake word → STT → Qwen → TTS, hands-free. Done when: you say "Lira", speak, and hear a spoken reply you can interrupt mid-sentence, with auto-mute respecting calls and quiet hours.*
*PRD: §8.*
> **Invariant:** all voice is local — no API calls. Wake-word detection runs on its own thread even during TTS (for interruption).

---

#### Slice 6.1 — Wake word
- **Goal.** Always-on "Lira" detection (CPU, low false-trigger). **Owns:** `daemon/voice/wakeword.py`. **Off-limits:** listener/transcriber.
- **Acceptance.** "Lira" fires; low false-trigger at default. **Must-still-pass:** M1 unaffected.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Audio engineer. **Objective.** Always-on "Lira" wake-word detection. **Read first.** PRD §8.1–8.2, §8.6. **You own.** `daemon/voice/wakeword.py`. **May read.** `config.py`. **Off-limits.** listener/transcriber. **Build.** openWakeWord with a custom "Lira" model on a background thread; wake event; sensitivity configurable (0.1–0.9). CPU-only, always-on, no audio leaves the device. **Verify on the real machine.** Actually run it: say "Lira" (confirm a wake event) and play ambient speech (confirm rare false-triggers at default). **Definition of done — paste detection logs for hit + ambient.** 1) "Lira" fires. 2) Low false-trigger at default. **Must-still-pass:** M1 daemon unaffected (voice is additive).

---

#### Slice 6.2 — VAD
- **Goal.** End-of-speech detection via Silero VAD. **Owns:** `daemon/voice/vad.py`. **Off-limits:** transcriber.
- **Acceptance.** End-of-speech fires past threshold, not on short pauses. **Must-still-pass:** 6.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Audio engineer. **Objective.** End-of-speech detection via Silero VAD. **Read first.** PRD §8.1, §8.7. **You own.** `daemon/voice/vad.py`. **Off-limits.** transcriber. **Build.** Silero VAD; configurable silence threshold (0.5–2.0s); emits a "speech ended" signal. Local. **Verify on the real machine.** Actually speak then pause just under and just over the threshold; confirm end-of-speech fires only past the threshold. **Definition of done — paste threshold-boundary tests.** 1) Fires past threshold. 2) Short pauses don't trigger. **Must-still-pass:** 6.1 wake event still fires.

---

#### Slice 6.3 — Transcription
- **Goal.** Local transcription via mlx-whisper (ANE). **Owns:** `daemon/voice/transcriber.py`. **Off-limits:** listener.
- **Acceptance.** A spoken sentence transcribes accurately at acceptable latency. **Must-still-pass:** 6.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Speech engineer. **Objective.** Local transcription via mlx-whisper. **Read first.** PRD §8.1, §8.6. **You own.** `daemon/voice/transcriber.py`. **Off-limits.** listener. **Build.** mlx-whisper-small; `transcribe(audio) -> text`; language configurable. Local, MLX/ANE. **Verify on the real machine.** Actually transcribe a spoken sentence and measure latency. **Definition of done — paste a transcript + timing.** 1) Accurate transcript. 2) Acceptable ANE latency. **Must-still-pass:** 6.2 end-of-speech triggers transcription.

---

#### Slice 6.4 — TTS speaker
- **Goal.** Sentence-boundary streaming TTS (Kokoro) with instant stop. **Owns:** `daemon/voice/speaker.py`. **Off-limits:** listener.
- **Acceptance.** Speech begins before generation ends; `stop()` halts instantly. **Must-still-pass:** M1 streaming sentence boundaries.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** TTS engineer. **Objective.** Sentence-boundary streaming TTS with instant stop. **Read first.** PRD §8.1, §8.3, §8.7. **You own.** `daemon/voice/speaker.py`. **Off-limits.** listener. **Build.** Kokoro-82M-bf16; `speak(text_stream)` begins at sentence one while later sentences still generate; voice + speed (0.8–1.3x) configurable; stoppable instantly. Local. **Verify on the real machine.** Actually stream a multi-sentence reply and time first-audio vs generation-complete (first audio must precede completion); call `stop()` mid-speech and confirm instant halt. **Definition of done — paste timing of first-audio vs generation-complete + a stop test.** 1) Speech begins before generation ends. 2) `stop()` is instant. **Must-still-pass:** M1 streaming still yields sentence boundaries.

---

#### Slice 6.5 — Voice state machine
- **Goal.** The full wake→listen→transcribe→respond→speak loop, 3.5s continue window, instant interruption. **Owns:** `daemon/voice/listener.py`. **Off-limits:** chat internals beyond the public stream.
- **Acceptance.** Hands-free turn works; continue window needs no wake word; mid-reply interruption is instant. **Must-still-pass:** 4.10 recall; 6.4 stop.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the voice state machine. **Objective.** The full wake→listen→transcribe→respond→speak loop, with a 3.5s continue window and instant interruption. **Read first.** PRD §8.2–8.3. **You own.** `daemon/voice/listener.py`. **May read.** all voice modules, the chat path's public stream. **Off-limits.** Chat-route internals beyond the public stream. **Build.** Orchestrate the modules; 3.5s post-response continue window (no wake word); silence beyond it suspends to wake-listening; resume within 15 min; **interruption** — "Lira" during TTS (wake thread runs during playback) stops it instantly and listens. **Hard rules.** Wake detection on its own thread during TTS. Local end-to-end. **Verify on the real machine.** Actually run a full hands-free turn; continue within 3.5s without a wake word; say "Lira" mid-reply to confirm TTS stops instantly and listening resumes. **Definition of done — paste the loop log + an interruption test.** 1) Hands-free turn works. 2) Continue window needs no wake word. 3) Mid-reply interruption is instant. **Must-still-pass:** 4.10 chat recall (voice uses the same memory path); 6.4 instant stop.

---

#### Slice 6.6 — Auto-mute
- **Goal.** Suspend wake detection on calls / DND / quiet hours / manual. **Owns:** the auto-mute logic. **Off-limits:** transcriber/speaker.
- **Acceptance.** Each mute source suspends and resumes correctly. **Must-still-pass:** 6.1 resumes after un-mute.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building auto-mute. **Objective.** Suspend wake detection on calls / DND / quiet hours / manual. **Read first.** PRD §8.4. **You own.** The auto-mute logic in `listener.py`/`wakeword.py`. **May read.** CoreAudio/CallKit, config. **Off-limits.** transcriber/speaker. **Build.** Suspend on an active audio call (CoreAudio/CallKit), DND (optional), user-set quiet hours, or manual menu-bar mute; resume when the condition clears. Default auto-mute-on-calls = on. **Verify on the real machine.** Actually trigger each of the four sources and confirm detection suspends then resumes. **Definition of done — paste each suspend/resume.** 1) Each source suspends and resumes correctly. **Must-still-pass:** 6.1 wake detection resumes after un-mute.

---

#### Slice 6.7 — Voice API routes + app wiring + menu-bar states
- **Goal.** Expose voice control over HTTP; reflect voice states in the app + menu bar. **Owns:** `daemon/api/routes/voice.py` + app voice wiring + `APIClient` methods. **Off-limits:** daemon voice internals.
- **Acceptance.** Toggle works; states reflect; settings apply. **Must-still-pass:** 2.6 menu states; 6.5; 6.6.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** API + SwiftUI engineer. **Objective.** Voice control endpoints + app/menu-bar state reflection. **Read first.** PRD §8.5, §8.7; non-negotiable #1. **You own.** `daemon/api/routes/voice.py` + app voice wiring (orb/menu states, voice settings) + methods in `APIClient.swift`. **Off-limits.** Daemon voice internals. **Build.** Routes to start/stop voice, set sensitivity/threshold/window/voice/speed, mute; the app drives orb + menu-bar states from voice events; a voice settings section. **Hard rules.** 127.0.0.1 only; `APIClient` the only URL-bearing Swift file. **Verify on the real machine.** Actually run the app; toggle always-on voice; confirm the menu bar/orb reflect listening/thinking/speaking; change a setting and confirm it applies. **Definition of done — paste/describe state transitions + a settings change.** 1) Toggle works. 2) States reflect. 3) Settings apply. **Must-still-pass:** 2.6 menu states; 6.5 loop; 6.6 mute.

### M7 — Screen Understanding and Annotations

*Lira sees the screen and draws on top of any app, clicks passing through. Done when: "what's wrong here?" reads your screen and Lira draws an arrow that stays put while you keep working.*
*PRD: §9.*
> **Invariant:** the overlay is invisible to input and present in every Space. Qwen returns coordinates as **percentages**; the control layer converts to pixels with Retina scaling.

---

#### Slice 7.1 — Screen capture
- **Goal.** Active-window capture via ScreenCaptureKit. **Owns:** `daemon/perception/screen.py`. **Off-limits:** analyzer/overlay.
- **Acceptance.** A valid active-window image returns. **Must-still-pass:** M1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS capture engineer. **Objective.** Active-window capture via ScreenCaptureKit. **Read first.** PRD §9.1. **You own.** `daemon/perception/screen.py`. **May read.** `config.py`. **Off-limits.** analyzer/overlay. **Build.** ScreenCaptureKit capture of the active window → image; Screen Recording permission once. On-request only, no continuous recording. **Verify on the real machine.** Actually capture the active window and confirm the image matches it (paste dimensions/metadata). **Definition of done — paste image metadata/dimensions.** 1) A valid active-window image returns. **Must-still-pass:** M1 unaffected.

---

#### Slice 7.2 — Screen analyzer
- **Goal.** Qwen-vision analysis + target coordinates as percentages. **Owns:** `daemon/perception/analyzer.py`. **Off-limits:** overlay.
- **Acceptance.** A screen question returns a relevant answer + `%` targets. **Must-still-pass:** 1.4 frozen signature; 7.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Vision-integration engineer. **Objective.** Qwen-vision analysis + target coordinates as percentages. **Read first.** PRD §9.1, §9.3; non-negotiable #11. **You own.** `daemon/perception/analyzer.py`. **May read.** `model.py` (frozen `image=`), `screen.py`. **Off-limits.** overlay/annotation drawing. **Build.** `analyze(image, question) -> {answer, targets:[{x_pct,y_pct,label}]}` via the frozen `model.generate(..., image=...)`; trigger words route a message here. **Hard rules.** Coordinates are percentages (Retina-safe). Uses the frozen signature (#11). **Verify on the real machine.** Actually pass a real screenshot + "what's wrong here?" and confirm a relevant answer + targets as percentages (not pixels). **Definition of done — paste the answer + target coords.** 1) A screen question returns a relevant answer + `%` targets. **Must-still-pass:** 1.4 frozen signature (uses `image=`); 7.1 capture.

---

#### Slice 7.3 — Overlay window
- **Goal.** A transparent, click-through, all-Spaces overlay above all apps incl. fullscreen. **Owns:** `Views/OverlayWindow.swift`. **Off-limits:** annotation drawing.
- **Acceptance.** Visible over fullscreen; clicks pass through. **Must-still-pass:** 2.1 build.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS windowing engineer. **Objective.** A click-through, all-Spaces overlay above all apps incl. fullscreen. **Read first.** PRD §9.2. **You own.** `Views/OverlayWindow.swift`. **Off-limits.** annotation drawing. **Build.** NSWindow with `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `windowLevel = .screenSaver`. **Hard rules.** Invisible to input; present in every Space. **Verify on the real machine.** Actually run it over a real fullscreen app; confirm it's visible and clicks/scrolls pass through. **Definition of done — describe the over-fullscreen + click-through test.** 1) Visible over a fullscreen app. 2) Clicks pass through. **Must-still-pass:** 2.1 app build.

---

#### Slice 7.4 — Annotation drawing
- **Goal.** Draw arrows/circles/labels on the overlay from percentage coordinates, Retina-correct. **Owns:** `Views/AnnotationView.swift`. **Off-limits:** archival.
- **Acceptance.** A `%` target lands at the right pixel on Retina. **Must-still-pass:** 7.3 click-through.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Core Graphics / SwiftUI engineer. **Objective.** Draw arrows/circles/labels on the overlay from percentage coordinates, Retina-correct. **Read first.** PRD §9.3. **You own.** `Views/AnnotationView.swift`. **May read.** `OverlayWindow`. **Off-limits.** archival. **Build.** Render arrows, circles/rectangles, text labels, freehand; convert `%` → pixel accounting for resolution + Retina scaling. Don't capture input. **Verify on the real machine.** Actually draw a target at a known (x%, y%) on a Retina display and confirm the arrow lands at the correct pixel; confirm click-through still works while annotations show. **Definition of done — describe the placement test with coords.** 1) A `%` target lands at the right pixel on Retina. **Must-still-pass:** 7.3 click-through preserved while annotations show.

---

#### Slice 7.5 — Annotation lifecycle
- **Goal.** Annotations persist until cleared; overlap prompts a clear-or-layer choice Lira remembers. **Owns:** the lifecycle logic. **Off-limits:** archival.
- **Acceptance.** Persistence + one-time overlap ask + reuse of the choice. **Must-still-pass:** 7.4; 3.2 degrade.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building annotation lifecycle. **Objective.** Persistent annotations + clear/layer-on-overlap memory. **Read first.** PRD §9.3. **You own.** The annotation lifecycle logic (app side + a small daemon hook). **May read.** `AnnotationView`, `bonsai/client.py`. **Off-limits.** archival. **Build.** No auto-fade; cleared by "Lira clear that"/"erase everything"; on overlap, ask once (clear vs layer) and remember per task; if a consistent pattern emerges, Bonsai surfaces it once to offer automation. **Hard rules.** Persist until explicit clear. Automate only after a confirmed offer. **Verify on the real machine.** Actually leave annotations up (no fade), add an overlapping one (one-time ask), repeat to confirm the remembered choice is reused. **Definition of done — describe the overlap-ask + reuse.** 1) Persist until clear. 2) Overlap triggers the one-time ask. 3) Choice reused. **Must-still-pass:** 7.4 drawing; 3.2 Bonsai degrade.

---

#### Slice 7.6 — Screenshot archival
- **Goal.** Keep annotated screenshots 24h, then replace with a one-line Bonsai summary. **Owns:** `daemon/perception/archival.py`. **Off-limits:** drawing.
- **Acceptance.** Save → (short-override) delete + persisted summary. **Must-still-pass:** 7.5; 3.2 degrade.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building screenshot retention. **Objective.** 24h screenshots → one-line Bonsai summary. **Read first.** PRD §9.3, §12.2. **You own.** `daemon/perception/archival.py`. **May read.** `bonsai/client.py`, config. **Off-limits.** annotation drawing. **Build.** Save each annotation-session screenshot (annotations baked in); a scheduler deletes after 24h, writing a one-line Bonsai summary into the parent thread first. Scheduler does file ops; only the summary calls Bonsai. **Verify on the real machine.** Actually save a screenshot, run with a **shortened** retention override, confirm it's deleted and a summary persists. **Definition of done — paste the saved file, the summary, and the post-retention deletion.** 1) Screenshot saved. 2) After the (overridden) window it's deleted and the summary persists. **Must-still-pass:** 7.5 lifecycle; 3.2 degrade path.

---

#### Slice 7.7 — Diagram view
- **Goal.** Render Mermaid diagrams as SVG in a draggable floating panel (local bundle, no CDN). **Owns:** `Views/DiagramView.swift` + local Mermaid bundle. **Off-limits:** overlay/annotation.
- **Acceptance.** An NL request renders a correct, movable diagram with no network fetch. **Must-still-pass:** 2.1 build.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI / WebView engineer. **Objective.** Render Mermaid diagrams as SVG in a draggable floating panel. **Read first.** PRD §9.4. **You own.** `Views/DiagramView.swift` + a local Mermaid bundle. **Off-limits.** overlay/annotation. **Build.** Generate Mermaid syntax from natural language (Qwen) → render SVG in a WKWebView (local bundle, no CDN) → draggable/dismissable/modifiable panel; flow/sequence/architecture/ER/timeline. **Hard rules.** Local Mermaid bundle only (no network). **Verify on the real machine.** Actually request a diagram in natural language, confirm it renders + the panel moves, and check the network log shows **no** fetch. **Definition of done — describe/paste the rendered diagram.** 1) An NL request renders a correct, movable diagram with no network fetch. **Must-still-pass:** 2.1 build.

---

#### Slice 7.8 — Perception API routes + app wiring
- **Goal.** Expose capture/analyze/annotate/diagram over HTTP and wire the app. **Owns:** `daemon/api/routes/perception.py` + app wiring + `APIClient` methods. **Off-limits:** perception internals.
- **Acceptance.** Analyze + annotate + diagram all work end-to-end. **Must-still-pass:** 7.3, 7.4, 7.7.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** API + SwiftUI engineer. **Objective.** Perception endpoints + app surfacing (overlay annotations + diagram panel). **Read first.** PRD §9; non-negotiable #1. **You own.** `daemon/api/routes/perception.py` + app wiring + methods in `APIClient.swift`. **Off-limits.** Perception internals beyond public functions. **Build.** Routes: capture+analyze, push annotations (with `%` targets), request a diagram; the app shows overlay annotations + the diagram panel. **Hard rules.** 127.0.0.1 only; `APIClient` the only URL-bearing Swift file. **Verify on the real machine.** Actually run end-to-end: "what's on my screen?" (analysis), "circle the error" (overlay draw lands right), "diagram this" (panel appears). **Definition of done — describe each end-to-end.** 1) Analyze works. 2) Annotate draws on the overlay. 3) Diagram shows a panel. **Must-still-pass:** 7.3 click-through; 7.4 placement; 7.7 rendering.

---

### M8 — Control Layer

*Safe action on the Mac: native ops, a live cursor, a dedicated Space — logged and trust-gated, with destructive actions always confirming. Done when: Lira opens an app / writes a file through the safety+audit+trust path, and a delete always asks.* **Hard prerequisite for M11.**
*PRD: §10, §11, §18.*
> **Invariants:** audit log written **before** success is confirmed (#3). Destructive/irreversible always confirm (#5). Accessibility + Screen Recording requested once.

---

#### Slice 8.1 — Safety preflight
- **Goal.** Every action passes a pre-flight that classifies risk + reversibility; hard-rule confirms. **Owns:** `daemon/control/safety.py`. **Off-limits:** executor.
- **Acceptance.** Benign passes; delete always requires confirm regardless of trust. **Must-still-pass:** N/A.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Safety engineer. **Objective.** An action pre-flight that classifies risk + reversibility, with hard-rule confirms. **Read first.** PRD §10, §11.2; non-negotiable #5. **You own.** `daemon/control/safety.py`. **May read.** `trust.py` (once it exists), `config.py`. **Off-limits.** executor. **Build.** `preflight(action) -> {allow, requires_confirm, reversible, risk}`; delete/send/financial/irreversible/destructive → always `requires_confirm` regardless of trust. **Hard rules.** Hard-rule actions can never be auto-approved (#5). **Verify on the real machine.** Actually run `preflight` on a benign action (passes) and on a delete (requires confirm) — including with a high trust level set. **Definition of done — paste both classifications.** 1) Benign passes. 2) Delete returns `requires_confirm=true` regardless of trust. **Must-still-pass:** N/A — new subsystem.

---

#### Slice 8.2 — Audit logger
- **Goal.** Every action written to `audit_log` **before** success is confirmed. **Owns:** `daemon/control/logger.py`. **Off-limits:** executor logic.
- **Acceptance.** The row exists before the success response; reversible actions include undo data. **Must-still-pass:** 4.1 audit_log table.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the audit log. **Objective.** Write every action to `audit_log` **before** success is confirmed to the caller. **Read first.** PRD §18; non-negotiable #3. **You own.** `daemon/control/logger.py`. **May read.** `db.py`. **Off-limits.** executor logic. **Build.** `log(action_type, target, params, result, reversible, undo_data)`; the write happens before the executor confirms success; includes undo data when reversible. **Hard rules.** Write-before-confirm (#3). Never skipped. **Verify on the real machine.** Actually run an action and confirm (via timestamps) the `audit_log` row is written before the success response. **Definition of done — paste the ordering proof.** 1) The row exists before the success response. 2) Reversible actions include undo data. **Must-still-pass:** 4.1 schema (`audit_log`).

---

#### Slice 8.3 — Native action executor
- **Goal.** Execute file/app/calendar/system actions via native APIs, silently, through safety + audit. **Owns:** `daemon/control/executor.py`. **Off-limits:** cursor/Space/browser.
- **Acceptance.** Open-app + write-file work (logged); delete prompts a confirm that can't be bypassed. **Must-still-pass:** 8.1, 8.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS automation engineer. **Objective.** Native file/app/calendar/system actions, silent, through safety + audit. **Read first.** PRD §10.1; non-negotiables #3, #5. **You own.** `daemon/control/executor.py`. **May read.** `safety.py`, `logger.py`. **Off-limits.** cursor/Space/browser. **Build.** Native ops via pyobjc (files os/shutil/pathlib; calendar EventKit; apps NSWorkspace; AppleScript; notifications; clipboard; prefs). Every action: `safety.preflight` → confirm-if-required → `logger.log` (before confirm) → execute → record result. Sanitize paths. **Hard rules.** Silent native path preferred. Destructive always confirms (#5). No path traversal. **Verify on the real machine.** Actually run "open Notes" (opens, logged), "write file X" (writes, logged, with undo data), "delete file" (confirms first); prove the delete confirm can't be skipped. **Definition of done — paste each action + its audit row.** 1) Open-app + write-file work and are logged. 2) Delete prompts a confirm that can't be bypassed. **Must-still-pass:** 8.1 preflight; 8.2 write-before-confirm.

---

#### Slice 8.4 — Undo system
- **Goal.** Reversible actions can be undone from stored undo data. **Owns:** `daemon/control/undo.py`. **Off-limits:** executor internals.
- **Acceptance.** A reversible write undoes; irreversible reports cleanly. **Must-still-pass:** 8.3, 8.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building undo. **Objective.** Restore prior state for reversible actions from stored undo data. **Read first.** PRD §10. **You own.** `daemon/control/undo.py`. **May read.** `logger.py` (undo_data), `db.py`. **Off-limits.** executor internals. **Build.** `undo(audit_id)` restores prior state from `undo_data`; reversible-only; irreversible reports clearly. Never fabricates state. **Verify on the real machine.** Actually do a reversible file write, undo it, confirm prior content restored; attempt to undo an irreversible action and confirm a clear message. **Definition of done — paste the undo round-trip.** 1) A reversible write undoes to prior content. 2) An irreversible action reports it can't be undone. **Must-still-pass:** 8.3 reversible actions store undo data; 8.2 rows.

---

#### Slice 8.5 — Trust system
- **Goal.** Per-capability trust earning autonomy over time, with hard-rule capabilities permanently excluded. **Owns:** `daemon/control/trust.py`. **Off-limits:** executor logic.
- **Acceptance.** A promotable capability offers promotion after clean successes; a hard-rule capability never does. **Must-still-pass:** 8.1, 8.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building progressive trust. **Objective.** Per-capability trust that earns autonomy over time, with hard-rule capabilities permanently excluded. **Read first.** PRD §11; non-negotiable #5. **You own.** `daemon/control/trust.py`. **May read.** `logger.py` (audit history), `bonsai/client.py`. **Off-limits.** executor logic. **Build.** `get_trust_level(capability)` (read by safety), `record_outcome(capability, success)`; promotion at the threshold (default 30 successes, no failures in 45 days) flags Bonsai's pattern detector → one promotion question to Qwen; delete/send/financial/irreversible/destructive excluded entirely. **Hard rules.** Hard-rule exclusions absolute (#5). Trust stored as preferences. **Verify on the real machine.** Actually record enough clean successes on a promotable capability (confirm a promotion offer), and many on a hard-rule capability (confirm **no** offer ever). **Definition of done — paste the promotion-offer + the excluded-capability non-offer.** 1) Promotable offers promotion after clean successes. 2) Hard-rule never does, regardless of count. **Must-still-pass:** 8.1 safety reads trust; 8.2 audit history.

---

#### Slice 8.6 — Live cursor
- **Goal.** Lira's own visible cursor posting real inputs via CGEvent, independent of the user's. **Owns:** `Views/LiraCursorView.swift` + CGEvent path in `executor.py`. **Off-limits:** Space (8.7).
- **Acceptance.** Lira clicks a target by coordinate; the user's cursor is unaffected. **Must-still-pass:** 7.3 overlay; 8.3 logged.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS input-automation engineer. **Objective.** Lira's own visible cursor posting real inputs via CGEvent, independent of the user's cursor. **Read first.** PRD §10.1 (Mode 3), §10.2. **You own.** `Views/LiraCursorView.swift` + the CGEvent posting path in `control/executor.py`. **May read.** `OverlayWindow`, analyzer coords. **Off-limits.** Space (8.7). **Build.** A teal "Lira" cursor on the overlay; real inputs posted via CGEvent (pyobjc-Quartz) at pixel coords (from `%`); Accessibility API for element-level control where possible, raw coords as fallback. Requires Accessibility permission. **Hard rules.** Lira's cursor is a visual element; real input via CGEvent. User cursor untouched. **Verify on the real machine.** Actually have Lira move its cursor and click a target by coordinate while you move the user cursor; confirm both work simultaneously and the user's cursor is unaffected. **Definition of done — describe the dual-cursor click test.** 1) Lira clicks a target by coordinate. 2) The user's cursor is independent/unaffected. **Must-still-pass:** 7.3 overlay; 8.3 actions logged.

---

#### Slice 8.7 — Lira's Space
- **Goal.** A dedicated, self-healing macOS Space for independent background app work. **Owns:** `Views/LiraSpaceView.swift` + Space management. **Off-limits:** browser.
- **Acceptance.** App runs in Lira's Space without disturbing the user's; closing it recreates silently. **Must-still-pass:** 8.6 cursor in the Space.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS Spaces engineer. **Objective.** A dedicated, self-healing Lira Space. **Read first.** PRD §10.1 (Mode 4). **You own.** `Views/LiraSpaceView.swift` + Space management. **Off-limits.** browser. **Build.** Create a dedicated Space on first launch; pin Lira's windows (`collectionBehavior = .primary`); recreate silently if closed; access via Mission Control / menu bar; background results surface there. **Hard rules.** Lira's windows stay pinned to its Space. **Verify on the real machine.** Actually have Lira open an app in its Space and confirm the user's active Space is undisturbed; close the Space and confirm silent recreation. **Definition of done — describe the isolated-Space test + recreation.** 1) App runs in Lira's Space without disturbing the user's. 2) Closing it recreates silently. **Must-still-pass:** 8.6 cursor works in the Space too.

---

#### Slice 8.8 — Control API routes + confirmation UI + trust panel
- **Goal.** Expose control over HTTP; confirm irreversible actions; show a trust panel + audit view. **Owns:** `daemon/api/routes/control.py` + `Views/ActionConfirmationView.swift` + Settings trust/audit + `APIClient` methods. **Off-limits:** control internals.
- **Acceptance.** A delete surfaces a confirmation; trust panel works; audit view lists actions. **Must-still-pass:** 8.1, 8.2, 8.5.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** API + SwiftUI engineer. **Objective.** Control endpoints + a confirmation UI for irreversible actions + a trust panel + an audit view. **Read first.** PRD §10–11, §18; non-negotiables #1, #5. **You own.** `daemon/api/routes/control.py` + `Views/ActionConfirmationView.swift` + trust/audit sections in `SettingsView.swift` + methods in `APIClient.swift`. **Off-limits.** Control internals beyond public functions. **Build.** Routes to execute actions, confirm/deny, undo, read trust + audit log; an irreversible-action confirmation dialog; a trust panel (per-capability level, manual adjust, reset-to-cautious); an audit log view. **Hard rules.** 127.0.0.1 only; `APIClient` the only URL-bearing Swift file; destructive always confirms (#5). **Verify on the real machine.** Actually run the app; trigger a delete (must surface a confirmation you accept), edit the trust panel, view the audit log; prove the confirm can't be bypassed from the UI. **Definition of done — describe the confirm flow + paste a trust/audit read.** 1) A delete surfaces a confirmation. 2) The trust panel shows/edits levels. 3) The audit view lists actions. **Must-still-pass:** 8.1 confirm rule; 8.2 audit; 8.5 trust.

### M9 — Browser Control and Chrome Extension

*Lira drives the browser — silently via the DOM or visibly with its cursor. Done when: Lira navigates and fills a form via the extension, silently or watchably.*
*PRD: §10.1 (Mode 2).*

---

#### Slice 9.1 — Browser control via browser-use
- **Goal.** Drive the browser with browser-use backed by local Qwen, DOM mode. **Owns:** `daemon/control/browser.py`. **Off-limits:** the extension.
- **Acceptance.** A navigate+extract task runs silently and is logged. **Must-still-pass:** 8.1, 8.2.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Browser-automation engineer. **Objective.** Drive the browser with browser-use backed by local Qwen, in DOM (silent) mode. **Read first.** PRD §10.1 (Mode 2). **You own.** `daemon/control/browser.py`. **May read.** `model.py`, `safety.py`. **Off-limits.** The extension. **Build.** browser-use (Playwright) with the LLM backend swapped for local Qwen; DOM-mode actions (navigate/read/fill/click/extract) through safety + audit. **Hard rules.** Through safety + audit. Local Qwen backend (no external LLM). **Verify on the real machine.** Actually run "go to X and read the headline" and confirm it navigates + extracts silently and the actions are logged; confirm the backend is local Qwen. **Definition of done — paste the task result + audit rows.** 1) A navigate+extract task runs silently and is logged. **Must-still-pass:** 8.1 preflight; 8.2 audit.

---

#### Slice 9.2 — Chrome extension
- **Goal.** An MV3 extension (content + background) that manipulates the DOM on command. **Owns:** `extension/{manifest.json,content.js,background.js}`. **Off-limits:** daemon code.
- **Acceptance.** Fills/clicks elements on a test page on command. **Must-still-pass:** N/A.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Chrome-extension engineer. **Objective.** An MV3 extension that manipulates the DOM on command. **Read first.** PRD §10.1 (extension architecture). **You own.** `extension/{manifest.json,content.js,background.js}`. **Off-limits.** Daemon code. **Build.** Content script (read/fill/click/extract DOM) + background service worker (localhost WebSocket to the daemon); plain JS, no deps, no CDN. **Hard rules.** Plain JS, no dependencies. Talks only to localhost. **Verify on the real machine.** Actually load it unpacked in Chrome and drive a real test page — fill/click elements on command. **Definition of done — describe the test-page interaction.** 1) The extension fills/clicks elements on a test page on command. **Must-still-pass:** N/A — new tree.

---

#### Slice 9.3 — Daemon↔extension WebSocket
- **Goal.** A localhost WebSocket linking daemon and extension for instructions + results. **Owns:** the WS endpoint in `routes/browser.py` + `background.js` client. **Off-limits:** content.js.
- **Acceptance.** A DOM instruction round-trips daemon↔extension; reconnect after a drop works. **Must-still-pass:** 9.2, 1.5.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the daemon↔extension channel. **Objective.** A localhost WebSocket for instruction/result. **Read first.** PRD §10.1, §16 (IPC); non-negotiable #9. **You own.** The WS endpoint in `daemon/api/routes/browser.py` + the `background.js` client (coordinate with 9.2). **May read.** `control/browser.py`. **Off-limits.** `content.js`. **Build.** `ws://127.0.0.1:<daemon.port>/ws`; daemon sends instructions, extension executes + reports back; reconnect on drop. **Hard rules.** 127.0.0.1 only (#9). **Verify on the real machine.** Actually send a DOM instruction from the daemon over WS and confirm the extension executes + returns the result; drop and reconnect. **Definition of done — paste the round-trip.** 1) A DOM instruction round-trips daemon↔extension. 2) Reconnect after a drop works. **Must-still-pass:** 9.2 DOM ops; 1.5 server (now serving WS).

---

#### Slice 9.4 — Browser API routes + cursor mode + app wiring
- **Goal.** Expose browser tasks over HTTP; support a visible cursor mode; wire the app. **Owns:** `daemon/api/routes/browser.py` (HTTP) + app wiring + `APIClient` methods. **Off-limits:** browser internals.
- **Acceptance.** A task runs silently (DOM) or visibly (cursor) per the chosen mode. **Must-still-pass:** 9.1, 8.6, 9.3.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** API + SwiftUI engineer. **Objective.** Browser task endpoints + a visible cursor mode + app toggle. **Read first.** PRD §10.1; non-negotiable #1. **You own.** `daemon/api/routes/browser.py` (HTTP routes) + app wiring + methods in `APIClient.swift`. **Off-limits.** Browser internals beyond public functions. **Build.** Routes to run a browser task (DOM or cursor mode); cursor mode drives Lira's visible cursor in the browser; the app lets the user pick watch-vs-silent. **Hard rules.** 127.0.0.1 only; `APIClient` the only URL-bearing Swift file. **Verify on the real machine.** Actually run a browser task silently (DOM) and visibly (cursor) per the chosen mode. **Definition of done — describe both modes.** 1) A task runs in DOM mode silently. 2) A task runs in cursor mode visibly. **Must-still-pass:** 9.1 DOM; 8.6 cursor; 9.3 WS.

---

### M10 — Proactive Intelligence

*Lira anticipates — nudges, meeting briefs, resume greetings — respecting quiet hours. Done when: a calendar event 10 minutes out surfaces a brief without interrupting a call or focus block.*
*PRD: §13.*

---

#### Slice 10.1 — Trigger engine
- **Goal.** Trigger families fire into the notification queue, respecting quiet hours. **Owns:** `daemon/proactive/triggers.py`. **Off-limits:** calendar (10.2).
- **Acceptance.** A trigger fires; quiet hours suppress it. **Must-still-pass:** 3.3 drain; 3.2 degrade.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building the proactive trigger engine. **Objective.** Trigger families fire into the notification queue, respecting quiet hours. **Read first.** PRD §13.1–13.2. **You own.** `daemon/proactive/triggers.py`. **May read.** `notifications.py`, `bonsai/client.py`. **Off-limits.** calendar (10.2). **Build.** Trigger families (long focus, repeated error, morning resume, end of day, unsaved work), each configurable (on/off, threshold, delivery, quiet hours); a met condition writes to the notification queue; Bonsai scores urgency; nothing interrupts a call/marked focus/quiet hours. **Hard rules.** Never interrupts calls/focus/quiet hours. **Verify on the real machine.** Actually simulate a long-focus condition (confirm a nudge fires) and confirm quiet hours suppress it. **Definition of done — paste the fire + the suppression.** 1) A trigger fires. 2) Quiet hours suppress it. **Must-still-pass:** 3.3 drain; 3.2 degrade.

---

#### Slice 10.2 — Calendar integration
- **Goal.** Read-only calendar access surfacing a meeting brief 10 minutes out. **Owns:** `daemon/proactive/calendar.py`. **Off-limits:** write access.
- **Acceptance.** An event 10 minutes away surfaces a relevant brief. **Must-still-pass:** 10.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building calendar briefs. **Objective.** Read-only calendar access that surfaces a meeting brief 10 minutes out. **Read first.** PRD §13.1. **You own.** `daemon/proactive/calendar.py`. **May read.** `triggers.py`. **Off-limits.** Write access (read-only). **Build.** EventKit read-only; a meeting-in-10-min trigger surfaces relevant context (voice + notification). Permission once. **Hard rules.** Read-only calendar. **Verify on the real machine.** Actually create a real event 10 minutes out and confirm a brief with relevant context surfaces. **Definition of done — paste the brief.** 1) An event 10 minutes away surfaces a relevant brief. **Must-still-pass:** 10.1 trigger plumbing.

---

#### Slice 10.3 — Proactive settings
- **Goal.** Per-trigger configuration in the app. **Owns:** a proactive section in `SettingsView.swift` + `APIClient` methods. **Off-limits:** trigger internals.
- **Acceptance.** Disabling a trigger stops it; a threshold change alters when it fires. **Must-still-pass:** 10.1, 2.7.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI settings engineer. **Objective.** Per-trigger proactive settings in the app. **Read first.** PRD §13.1. **You own.** A proactive section in `SettingsView.swift` + methods in `APIClient.swift` (+ settings routes if needed). **Off-limits.** Trigger internals. **Build.** Per-trigger on/off, threshold, delivery style, quiet hours; proactivity level. **Hard rules.** `APIClient` the only URL-bearing Swift file. **Verify on the real machine.** Actually disable a trigger (confirm it stops) and change a threshold (confirm its timing changes). **Definition of done — describe the on/off + threshold effects.** 1) Disabling stops a trigger. 2) A threshold change alters when it fires. **Must-still-pass:** 10.1 firing; 2.7 settings.

---

### M11 — Capable Background Agents (OpenCode, Restrictive) — requires M8

*The local model does real file/shell work in a sandbox, asking before every action; cloud workers still advocated for quality. Done when: a local coding task executes with per-action approvals while the front chat stays responsive.*
*PRD: §5.2–5.3, §6.4, §10–11, Future Features.*
> **Invariants:** foreground model off-limits (#12); destructive/irreversible always confirm (#5); every action in `audit_log` (#3); local quality bounded by model size — never presented as equal to cloud.

---

#### Slice 11.1 — Local OpenAI-compatible instance serving
- **Goal.** Reuse the M3 pool to serve the local model on an OpenAI-compatible endpoint for the harness, RAM-gated. **Owns:** serving glue (reusing `background_instance/` + the pool). **Off-limits:** `model.py`, re-implementing the pool.
- **Acceptance.** The harness reaches a local instance; spawn RAM-gated; foreground responsive. **Must-still-pass:** 3.13 pool; #12.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer wiring the harness to local serving. **Objective.** Reuse the M3 background-instance pool to serve the local model on an OpenAI-compatible endpoint for the harness, RAM-gated. **Read first.** PRD §6.4; Slices 3.12–3.13; non-negotiable #12. **You own.** Small serving/config glue (reusing `background_instance/` + the pool). **May read.** the pool, `orchestrator.py`. **Off-limits.** The foreground `model.py`; re-implementing the pool. **Build.** Point the harness at a pooled background instance's `/v1/chat/completions`; RAM-gated spawn via the existing pool; never the foreground model. **Hard rules.** Reuse, don't duplicate. Foreground never used (#12). **Verify on the real machine.** Actually round-trip the harness to a local instance endpoint while hitting the foreground chat; confirm spawn is RAM-gated and the foreground stays responsive. **Definition of done — paste the endpoint round-trip + a concurrent foreground time.** 1) The harness reaches a local instance. 2) Spawn is RAM-gated. 3) Foreground responsive. **Must-still-pass:** 3.13 pool/concurrency; #12.

---

#### Slice 11.2 — OpenCode worker
- **Goal.** An OpenCode-backed `local_agent` worker pointed at the local instance. **Owns:** the OpenCode worker (`local_agent`). **Off-limits:** Codex/Claude wrappers.
- **Acceptance.** A simple coding task runs end-to-end via OpenCode locally. **Must-still-pass:** 3.8, 11.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer integrating OpenCode as a worker. **Objective.** An OpenCode-backed `local_agent` `BaseWorker` pointed at the local instance. **Read first.** PRD §5.3, §6.4. **You own.** The OpenCode worker (`local_agent`) in `daemon/workers/`. **May read.** `base.py`, the pool. **Off-limits.** Codex/Claude wrappers. **Build.** Adopt OpenCode (model-agnostic, OpenAI-compatible) as a new `BaseWorker` subclass; fresh session per task, killed on completion; do not fork the OpenAI-coupled Codex harness. **Hard rules.** Fresh session per task. Local quality bounded — labeled as such later. **Verify on the real machine.** Actually run a simple background coding task end-to-end via OpenCode on the local instance; confirm it speaks to the local endpoint, not a cloud model. **Definition of done — paste the task run.** 1) A coding task runs end-to-end via OpenCode locally. **Must-still-pass:** 3.8 worker interface; 11.1 serving.

---

#### Slice 11.3 — Restrictive permission gate
- **Goal.** Every file/shell action the agent proposes is intercepted, summarized, and confirmed before it runs, in a sandbox. **Owns:** the permission-gate logic. **Off-limits:** `model.py`.
- **Acceptance.** A write prompts a confirm; deny stops it; a delete can't be auto-approved; all in audit. **Must-still-pass:** 8.1, 8.2, #5.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Safety engineer gating the local agent. **Objective.** An ask-before-every-action permission gate around the agent, in a sandbox. **Read first.** PRD §10–11; non-negotiables #3, #5, #12. **You own.** The permission-gate logic around the worker. **May read.** `safety.py`, `logger.py`, `bonsai/client.py`. **Off-limits.** The foreground `model.py`. **Build.** Sandboxed workspace (Lira's Space or a scratch dir); each proposed action → `safety.preflight` + `audit_log` → Bonsai summarizes/classifies it in plain language + risk → Qwen surfaces a simple confirmation → relay back. Destructive/irreversible always confirm regardless. **Hard rules.** Ask-for-everything. Sandbox scope. Qwen is the single voice; Bonsai interprets. Destructive always confirm (#5). **Verify on the real machine.** Actually run a task that writes a file (confirm a plain-language prompt; deny stops it), then **deliberately try to make it delete a file** and prove it's gated; confirm all actions appear in `audit_log`. **Definition of done — paste the confirm flow + an audit listing + a blocked delete.** 1) A write prompts a confirm; deny stops it. 2) A delete can't be auto-approved. 3) All actions in `audit_log`. **Must-still-pass:** 8.1 preflight; 8.2 audit; #5.

---

#### Slice 11.4 — Routing + cloud advocacy + labeling
- **Goal.** Qwen advocates cloud workers, uses `local_agent` only on preference/unavailability, with clear labeling. **Owns:** routing/advocacy in `orchestrator.py` (extension) + a labeling surface. **Off-limits:** `model.py`.
- **Acceptance.** Cloud advocated when available; local used + labeled on preference. **Must-still-pass:** 3.6, 11.3.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Engineer building local/cloud routing + advocacy. **Objective.** Qwen advocates cloud workers, uses `local_agent` only on preference/unavailability, with clear local-vs-cloud labeling. **Read first.** PRD §5.3, §6.4. **You own.** Routing/advocacy in `orchestrator.py` (extension) + a labeling surface. **May read.** workers, settings. **Off-limits.** The foreground `model.py`. **Build.** Route to `local_agent` only when the user prefers local (privacy/offline/parallelism) or cloud is unavailable; otherwise advocate the cloud worker; surface to the user when work runs locally vs in the cloud. **Hard rules.** Never present local as equal to cloud. Foreground never used. **Verify on the real machine.** Actually run with a cloud worker available (confirm advocacy) and with local preference set (confirm `local_agent` is used and clearly labeled). **Definition of done — paste both routing outcomes + the label.** 1) Cloud advocated when available. 2) Local used + labeled on preference. **Must-still-pass:** 3.6 routing; 11.3 gate.

### M12 — Onboarding and Distribution

*A non-technical user installs from a DMG and is fully set up — no terminal. Done when: a fresh Mac installs the DMG and completes onboarding to a working Lira.*
*PRD: §14, §15.*

---

#### Slice 12.1 — Onboarding flow shell
- **Goal.** A nine-step onboarding flow with progress + back navigation. **Owns:** `Views/OnboardingView.swift`. **Off-limits:** the daemon.
- **Acceptance.** Forward/back works; shown once on first launch. **Must-still-pass:** 2.8 lifecycle.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** SwiftUI onboarding engineer. **Objective.** A nine-step onboarding flow shell with honest progress. **Read first.** PRD §14. **You own.** `Views/OnboardingView.swift`. **May read.** `AppState`. **Off-limits.** The daemon. **Build.** Nine screens (Welcome→Permissions→Model→Download→CLI→Routing→Autonomy→Personality→Voice→Done), progress at top, back on all but first/last; truthful progress (no fake spinners). Keep step content stubbed; later slices fill steps. **Verify on the real machine.** Actually run the app first-launch and navigate forward/back; confirm progress tracks the step and it shows once. **Definition of done — describe the navigation.** 1) Forward/back works. 2) Shown once on first launch. **Must-still-pass:** 2.8 lifecycle (onboarding gates first run).

---

#### Slice 12.2 — Permissions step
- **Goal.** Request mic / screen / accessibility one at a time, with rationale + restart handling. **Owns:** the Permissions step + `Views/VoicePermissionView.swift`. **Off-limits:** other steps.
- **Acceptance.** Each requests + verifies individually; denial recovers; restart resumes here. **Must-still-pass:** 12.1.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** macOS permissions engineer. **Objective.** Request mic, screen recording, and accessibility one at a time, with rationale and restart handling. **Read first.** PRD §10.2, §14. **You own.** The Permissions step + `Views/VoicePermissionView.swift`. **May read.** system permission APIs. **Off-limits.** Other steps. **Build.** For each permission: plain-English why → trigger the system dialog → verify actually granted → green check or System-Settings recovery + re-check; if Accessibility needs a restart, show "Restart Lira" and resume here on relaunch. Never request all at once. **Hard rules.** One permission at a time; verify actual grant. **Verify on the real machine.** Actually run each permission flow including a **deny-then-enable** recovery and an Accessibility restart-resume. **Definition of done — describe each permission path.** 1) Each requests + verifies individually. 2) Denial recovers. 3) Restart resumes at this step. **Must-still-pass:** 12.1 navigation.

---

#### Slice 12.3 — Model choice + download + bootstrap API
- **Goal.** Model choice (RAM-recommended) + a resumable download + a bootstrap API. **Owns:** the Model-choice + Download steps + `daemon/api/routes/bootstrap.py`. **Off-limits:** unrelated steps.
- **Acceptance.** Recommendation matches RAM; cancel + relaunch resumes; conversion completes. **Must-still-pass:** 1.2 resumability; 3.11 RAM detection.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Onboarding + backend engineer. **Objective.** Model choice (RAM-recommended) + a resumable download + a bootstrap API. **Read first.** PRD §5.2 (recommendation), §14, §15.3. **You own.** The Model-choice + Download steps + `daemon/api/routes/bootstrap.py`. **May read.** `bootstrap_model.sh` logic, RAM detection. **Off-limits.** Unrelated steps. **Build.** Two cards (4B fast / 9B smart) with specs; detect RAM and **recommend 4B on ≤16 GB**; real progress bar with bytes; cancel→resume next launch; MLX conversion; `bootstrap.py` exposes download progress. **Hard rules.** Truthful progress; resumable; weights download to the **data root** (`config.data_root()`) — **default `~/Library/Application Support/Lira/` on the main/boot SSD for release**, never the repo. Optionally expose an advanced **"Data location"** picker that persists the user-setting override `data_root()` reads (defaults to the main SSD; lets advanced users put the big weights on another drive). **Verify on the real machine.** Actually run the download, **cancel mid-download and relaunch** to confirm resume, confirm the recommendation matches detected RAM, let conversion complete. **Definition of done — paste progress numbers + a resume.** 1) Recommendation matches RAM. 2) Cancel + relaunch resumes. 3) Conversion completes. **Must-still-pass:** 1.2 bootstrap resumability; 3.11 RAM detection drives the recommendation.

---

#### Slice 12.4 — CLI / routing / autonomy / personality / voice steps
- **Goal.** The remaining configuration steps. **Owns:** those onboarding steps. **Off-limits:** their backends (already built).
- **Acceptance.** Each setting records and matches later behavior. **Must-still-pass:** 5.5 instructions; 6.7 voice settings.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Onboarding engineer. **Objective.** The CLI / routing / autonomy / personality / voice onboarding steps. **Read first.** PRD §14. **You own.** The CLI/Routing/Autonomy/Personality/Voice onboarding steps. **May read.** instructions, voice settings. **Off-limits.** Their backends. **Build.** CLI auto-detect (Claude Code/Codex, guided install, skippable); routing preference; autonomy; personality (5 segmented controls + optional free-form); voice (always-on toggle, sensitivity test, TTS picker with preview). **Hard rules.** All skippable where appropriate; choices persist. **Verify on the real machine.** Actually run each step, confirm settings persist, and confirm a personality choice changes the first greeting. **Definition of done — paste the saved settings.** 1) Each step records its setting. 2) Settings persist and match later behavior. **Must-still-pass:** 5.5 instructions; 6.7 voice settings.

---

#### Slice 12.5 — DMG build
- **Goal.** A production DMG bundling the app + both venvs + bundled models, installable without terminal. **Owns:** `scripts/build_dmg.sh`. **Off-limits:** feature code.
- **Acceptance.** The DMG installs on a clean Mac (no terminal); the app launches to onboarding. **Must-still-pass:** 12.1–12.4; 2.8.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Packaging engineer. **Objective.** A terminal-free DMG bundling the app + both venvs + bundled models. **Read first.** PRD §15. **You own.** `scripts/build_dmg.sh`. **May read.** the whole tree. **Off-limits.** Feature code. **Build.** Package Lira.app with the SwiftUI app, both Python venvs (briefcase runtimes), bundled Bonsai/Kokoro/Whisper/wakeword/Mermaid; Qwen downloaded on first run; unsigned for beta (Open Anyway documented); `create-dmg`. **Hard rules.** No Qwen weights in the DMG (downloaded first run). Both venvs bundled isolated. **Verify on the real machine.** Actually build the DMG and install it on a Mac **without** the dev environment; launch and confirm it reaches onboarding with no terminal step. **Definition of done — describe the clean-install run.** 1) The DMG installs on a clean Mac (no terminal). 2) The app launches and reaches onboarding. **Must-still-pass:** M12.1–12.4 onboarding; 2.8 lifecycle.

---

### M13 — Polish, Stability, and Updates

*The final pass over the finished product. Done when: updates work via Sparkle, errors recover gracefully, performance targets are met, and a full regression sweep is green.*
*PRD: §15.5, §21.*

---

#### Slice 13.1 — Sparkle updates
- **Goal.** In-app updates via Sparkle (app components; models separate). **Owns:** Sparkle integration. **Off-limits:** feature code.
- **Acceptance.** A published update notifies + applies in one click. **Must-still-pass:** 12.5 packaging.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Release engineer. **Objective.** In-app updates via Sparkle. **Read first.** PRD §15.5; non-negotiable #7. **You own.** Sparkle integration (SPM + update wiring). **Off-limits.** Feature code. **Build.** Sparkle feed; "Update available" → one-click update bundling app + Bonsai/Kokoro/Whisper; model updates downloaded in the background, applied next launch. **Hard rules.** No telemetry in the update path (#7). **Verify on the real machine.** Actually point at a real test feed, publish an update, and confirm the app notifies and one-click updates. **Definition of done — describe the update flow.** 1) A published update notifies and applies in one click. **Must-still-pass:** 12.5 packaging.

---

#### Slice 13.2 — Error handling and recovery (global)
- **Goal.** Graceful recovery everywhere — crashes, sidecar down, model-load failure, network loss. **Owns:** cross-cutting error handling. **Off-limits:** frozen contracts.
- **Acceptance.** Every simulated failure recovers/degrades cleanly with no orphans. **Must-still-pass:** the whole product's acceptance tests.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Reliability engineer. **Objective.** Graceful recovery everywhere — crashes, sidecar down, model-load failure, network loss. **Read first.** PRD §21, Appendix E (failure cases); non-negotiable #6. **You own.** Cross-cutting error-handling improvements (no new subsystems). **May read.** all. **Off-limits.** Changing frozen contracts. **Build.** Audit every subsystem's failure path: daemon/sidecar/instance crash recovery, sidecar-down degradation, model-load-failure messaging, clear user-facing errors; confirm zero orphans on every failure. **Hard rules.** No frozen-contract changes. Zero orphans (#6). **Verify on the real machine.** Actually **inject** each failure (kill processes, stop the sidecar, corrupt the model path, drop the network) and confirm graceful recovery/degradation + a clear message + `pgrep` zero orphans. **Definition of done — paste each failure injection + recovery + a `pgrep` orphan check.** 1) Every simulated failure recovers or degrades cleanly with no orphans. **Must-still-pass:** the whole product's acceptance tests (re-run the lot — this is a hardening pass).

---

#### Slice 13.3 — Performance targets
- **Goal.** Meet the budgets: cold start < 45s, first token < 1s, perceived voice latency < 1s. **Owns:** targeted perf work. **Off-limits:** frozen contracts.
- **Acceptance.** Cold start < 45s; first token < 1s; voice < 1s, measured. **Must-still-pass:** the full feature set.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** Performance engineer. **Objective.** Meet the budgets: cold start < 45s, first token < 1s, perceived voice latency < 1s. **Read first.** PRD §21 (budgets), §5.4, §8. **You own.** Targeted perf improvements (no new subsystems). **May read.** all. **Off-limits.** Frozen contracts. **Build.** Measure cold-start, first-token, and voice latency; optimize the hot paths (model load, context assembly, streaming start, TTS first-audio) to hit the budgets. **Hard rules.** No regressions for speed; no telemetry. **Verify on the real machine.** Actually measure each metric before and after your changes — paste real timings. **Definition of done — paste the measurements.** 1) Cold start < 45s. 2) First token < 1s. 3) Voice perceived latency < 1s. **Must-still-pass:** the full feature set (don't regress to gain speed).

---

#### Slice 13.4 — Final regression sweep
- **Goal.** Run every milestone's acceptance test + Must-still-pass gate over the finished product, green. **Owns:** test/sweep scripts only. **Off-limits:** feature changes (fixes only).
- **Acceptance.** Every milestone acceptance test passes; the §21 1.0 criteria all hold; zero orphans. **Must-still-pass:** everything.

> **Agent prompt — paste this whole block to Claude Code or Codex. Operate under §G.0.**
> **Role.** QA lead. **Objective.** A green full-product regression sweep across all 13 milestones. **Read first.** PRD §21; every milestone's acceptance tests + Must-still-pass gates. **You own.** Test/sweep scripts only. **May read.** all. **Off-limits.** Feature changes (fixes only, if a test fails). **Build.** Execute the full acceptance + Must-still-pass suite across M1–M13; fix any failure; confirm the §21 acceptance criteria; verify zero orphans after the full run. **Hard rules.** Ship only when the entire sweep is green with evidence. **Verify on the real machine.** Actually run the whole suite end-to-end on the real machine and `pgrep` for orphans after. **Definition of done — paste the full suite result + the orphan check.** 1) Every milestone acceptance test passes. 2) The §21 1.0 criteria all hold. 3) Zero orphans. **Must-still-pass:** everything — this is the whole-product gate.

---

## H. Deferred / Out of Scope

- **Workspace modes** (Chat, Dashboard, Design, Draw, Data, Code, Docs, Presentations, Spreadsheets, Wiki) — separate plan.
- **Apple notarization** — needs the $99/yr account; before public launch.
- **Pricing/monetisation**, **website/waitlist** — decided separately.
- **Future-feature backlog (post-1.0):** per-background-task model selection; large/"huge" background models; user-configurable permission modes for the local agent; background-instance count/headroom tuning. (Recorded in `PRD.md` → Future Features.)
