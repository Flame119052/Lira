# Lira — Product Requirements Document

**Version:** 3.0
**Status:** Active
**Companion:** `SLICE_MAP.md` — the build guide that implements this spec, slice by slice; `DECISIONS.md` — the rationale/working-agreement.

> This is the single source of architecture and contracts. The Slice Map references this document by section (DRY). Where a number or schema is a contract, it appears here once and is cited elsewhere.

---

## 0. What Lira Can Do — Plain English

**It remembers you.** Every conversation, every decision, every project. Come back after a week and it picks up exactly where you left off. It knows your name, what you're building, how you like to work, and what you told it last Tuesday.

**You can talk to it.** Say "Lira" and it wakes up. Ask it anything, give it a task, have a full conversation — all by voice. It responds out loud in a natural voice while you keep your hands on your keyboard.

**It can see your screen.** Ask "what's wrong here?" and it reads whatever's on your screen and tells you. It understands apps, documents, code, errors — anything visible.

**It annotates your screen.** It can draw arrows, circles, and labels directly on top of any app — even fullscreen ones. Diagrams float above your work. Everything stays up until you tell it to clear it.

**It works in the background.** Give it a big task and it disappears and works while you keep doing your thing. Come back and the result is waiting for review. Background work never slows the chat you're having.

**It can control your Mac.** Open apps, manage files, fill forms, navigate websites, type into things — with its own cursor that moves independently of yours. It always confirms before anything destructive.

**It gets smarter about you over time.** Starts cautious, earns trust, gradually does more without asking. Never oversteps. You always stay in control.

**Everything stays on your Mac.** No cloud, no subscriptions, no data leaving your device. The AI runs locally on your chip. Your memory is a file on your disk.

---

## 1. Product Definition

| | |
|---|---|
| **Product** | Lira |
| **Platform** | macOS 14.0+ on Apple Silicon (M-series) |
| **Hardware target** | 16 GB unified memory minimum, 24 GB+ recommended |
| **Wake word** | "Lira" |
| **Product type** | Local-first, memory-centric AI operating layer for macOS |
| **Niche** | Local-first founder/builder OS |
| **Distribution** | Direct DMG download only — no App Store |

Lira is a Jarvis-for-Mac product: an AI operating layer that lives on the user's Mac, understands ongoing work, remembers what matters, acts across the machine, and works in parallel without constantly pulling the user out of flow. It is not a chatbot you open when you need it — it is a presence that runs beside you.

---

## 2. Product Thesis

Lira is the AI that remembers, acts, and anticipates.
- It **remembers** through a living knowledge base built from the user's real work and conversations.
- It **acts** through safe desktop control, file operations, browser automation, and controlled background execution.
- It **anticipates** through proactive context, resumable sessions, time-awareness, and useful nudges.

The assistant layer comes first. Everything else exists to support it.

---

## 3. Core Product Principles

1. **One identity.** The user talks to one Lira. Even when external workers help, the experience remains one voice, one personality, one memory system.
2. **Assistant layer first.** The primary product is the AI operating layer. The workspace supports it.
3. **Compounding memory is central.** The knowledge base is the core substrate that makes Lira more useful over time.
4. **Local-first, always.** Core functionality works locally. No data leaves the device without explicit user action.
5. **Safe before impressive.** Lira stops before causing lasting damage, not after.
6. **Parallel work matters.** Lira works while the user keeps working, through its own dedicated Space — and never blocks the foreground.
7. **Invisible when possible, visible when useful.** Silent control paths first; visible takeover only when necessary.
8. **Configurable at the core.** Personality, instructions, thresholds, autonomy, and permissions are all user-editable.
9. **Trust is earned, not assumed.** Lira behaves like a new employee — cautious at first, earning autonomy over time.
10. **Phased build, full vision.** Implementation is decomposed into small vertical slices without narrowing the product.

---

## 4. Identity, Personality, and Presence

### 4.1 Behavioral Identity
Competent · calm · slightly formal · warm without being bubbly · direct · honest about uncertainty · never needy or over-enthusiastic.

### 4.2 Voice Character
No filler phrases · no fake excitement · concise by default · proactive without being pushy · reads the room.
Examples: *"I found the issue."* / *"I'm not confident about that. Want me to try a different approach?"*

### 4.3 Visual Identity — the Orb
An ambient teal/cyan particle sphere on a dark background. **Six states (contract):**

| State | Animation |
|-------|-----------|
| idle | slow breathing pulse |
| listening | particles spread outward, ripple on sound |
| thinking | particles contract, rotate, amber tint |
| responding | pulse rhythmically with speech |
| error | brief red flash → idle |
| muted | static, grey |

### 4.4 Presence Model
- **Menu bar icon** — always visible, six states (idle / listening / activated / thinking / speaking / muted).
- **Main app window** — orb, chat, workspace.
- **Lira Space** — dedicated macOS Space for background work.

### 4.5 Personality Customisation
All dimensions user-configurable in onboarding and adjustable anytime (settings or mid-conversation):
- Communication style: direct / balanced / detailed
- Pushback: always / only when asked / never
- Tone: formal / neutral / casual
- Empathy: read the room / stay consistent
- Proactivity: high / medium / low

Free-form instructions: **300-token hard cap**, applied immediately, remembered permanently.

**Acceptance criteria.** A personality change takes effect on the very next reply and persists across restart. A mid-conversation instruction ("stop explaining your reasoning") updates immediately and survives a restart.

---

## 5. System Architecture

### 5.1 High-Level Structure

```
SwiftUI App (the face)
      ↓ 127.0.0.1:<daemon.port>   (discovered, preferred 8765)
Main Daemon — stock MLX  (Python, venv: .venv)
  ├── Qwen3.5 — foreground model, the voice (serves live chat ONLY)
  ├── Context Assembly — KV cache tiers + dynamic context
  ├── Tool Dispatch — parses Qwen function calls, routes them
  ├── Orchestrator — executes spawn/route/fallback decisions + RAM detection/gating
  ├── Job System — background task coordination (concurrent runner)
  ├── Workers — Claude Code / Codex / qwen_instance / local_agent (OpenCode) wrappers
  ├── Memory System — SQLite + MemPalace + sqlite-vec
  ├── Voice / Screen / Control / Proactive subsystems
  └── API Server — FastAPI on 127.0.0.1:<daemon.port> (+ /ws for the extension)
      ↓ 127.0.0.1:<bonsai_sidecar.port>   (discovered, preferred 8766, local only)
Bonsai Sidecar — forked/GGUF MLX  (Python, venv: .venv-bonsai)
  └── Bonsai-8B-1bit — extraction, classification, compaction, scoring
      ↘ on demand: background_instance/ processes (separate Qwen, OpenAI-compatible, RAM-gated)
```

**Why two processes.** Bonsai-8B-1bit's `g128` 1-bit format requires PrismML's *fork* of MLX (or a GGUF build); Qwen runs on stock `mlx`/`mlx-vlm`. Two `mlx` builds cannot coexist in one interpreter, so Bonsai is a separate sidecar process with its own venv. The split is about dependency isolation, not memory.

**Port discovery (contract).** Each process binds `127.0.0.1` only. It tries its preferred port (daemon 8765, sidecar 8766); if occupied, it binds an OS-assigned free port and atomically writes the actual port to `~/Library/Application Support/Lira/daemon.port` (or `bonsai_sidecar.port`, or a per-instance file). The app and the daemon-side Bonsai client read those files — never a hardcoded port. PID/port files are removed on graceful exit; stale files are deleted before any relaunch.

### 5.2 Two-Model Architecture

**Qwen3.5 — The Face.** The only model the user interacts with. Handles all conversation, makes all routing decisions, reformats all worker output. User picks size in onboarding:
- Qwen3.5-4B — faster, ~2.5 GB at 4-bit.
- Qwen3.5-9B — smarter, ~5.8 GB at 4-bit.
Both are vision-capable, Apache 2.0, available as pre-built MLX conversions.

**Recommendation rule (contract).** On ≤16 GB machines, recommend **4B** — for foreground speed *and* because 4B leaves headroom to run one or more *separate* background instances (§6.4). 9B on 16 GB is foreground-only. Higher-RAM machines can run 9B and still spawn background instances.

**Live model identity (contract).** The running variant — name, parameter size, quantization, revision — is read from the model manifest at load time, exposed on `/model/info` and `/health`, and shown **live** in Settings. The UI never displays a hardcoded model name.

**Foreground isolation (invariant #12).** The foreground Qwen instance serves the live chat *only*. No background job ever runs on it; the front chat is never blocked or slowed waiting on background work. All background model work runs in separate processes/instances (§6.4).

**Bonsai-8B-1bit — The Chief of Staff.** Always running as a separate sidecar (~1.28 GB). Never talks to the user. Handles all background intelligence — memory extraction, thread classification, keyword expansion, context compaction, pattern detection, urgency scoring. Everything flows through Bonsai first; only what matters escalates to Qwen. One instance; requests queue (imperceptible at 1-bit). The job *monitor* (reading the SQLite job table) runs in the main daemon — pure state-reading, no inference.

### 5.3 CLI Workers
For tasks beyond local model capability, Lira spawns external CLI workers:
- **Claude Code CLI** — complex reasoning, long-form writing, architecture.
- **Codex CLI** — code-specific tasks, refactoring, debugging, tests.

Both run as **interactive** sessions (not `-p`). Fresh session per task, killed on completion — clean context, no drift. Output is never shown raw; Qwen reformats it in Lira's voice. One voice, always.

**Always advocate cloud workers for capability.** For background work needing real tool-use and reliability, Lira prefers and recommends the cloud CLI workers (mature agentic harnesses, frontier quality). A *local* capable background agent also exists (on-device OpenCode harness — M11) for privacy/offline/parallelism, but Lira always surfaces the cloud option as the higher-quality path. Local-agent quality is bounded by local model size — an explicit, accepted tradeoff.

### 5.4 Streaming
Qwen streams tokens via `mlx_lm.stream_generate()`. Responses appear in under a second. TTS begins at the first sentence boundary — Kokoro speaks sentence one while Qwen generates sentence two. Perceived latency under one second.

### 5.5 No Conductor — Qwen Decides, the Dispatcher Acts
There is no separate routing brain. Qwen reads the task, context, task list, resources, and preferences, and decides — but a decision is not an action. Qwen emits decisions as **function calls** (native Qwen3.5 function calling); deterministic code turns those calls into effects.

### 5.6 Tool Dispatch and Orchestration

**Tool registry (`core/tools.py`).** Every tool Qwen can call, as JSON schemas (control, screen, memory, delegation), injected into Qwen's context.

**Dispatcher (`core/dispatcher.py`).** Watches Qwen's output for function calls, parses, and routes:
```
control action   → control/executor.py (through safety + trust)
screen action    → perception + overlay
memory action    → memory/retriever.py or memory/db.py
delegation       → orchestrator
```
The tool result is fed back to Qwen; the user only sees Qwen's final natural-language response.

**Orchestrator (`core/orchestrator.py`).** Executes *how* to carry out a delegation (not *whether* — Qwen decides that):
```
1. Foreground model is off-limits for background work — never use it.
2. Prefer cloud CLI workers for capability — always advocated for quality.
3. For local background execution, spawn a SEPARATE background instance (own process),
   RAM-gated — keep spawning as reclaimable memory allows (§6.4).
4. Create job in SQLite, hand to workers/.
5. On chosen worker unavailable / RAM insufficient → queue or route to cloud — never block the foreground.
```

### 5.7 Frozen Model Signature (contract — non-negotiable #11)

Defined in full from the first model slice; never changed, only filled in:
```python
model.generate(prompt: str, image=None, context: str|None=None,
               history: list|None=None, tools: list|None=None,
               max_tokens: int = <default>) -> str
model.stream_generate(prompt, image=None, context=None, history=None,
                      tools=None, max_tokens=<default>) -> Iterator[str]
model.info() -> {"name", "params", "quantization", "revision"}   # from the manifest
model.load() -> None
```
A re-entrant inference lock serializes calls within the foreground process. `image` carries screen captures (§9). Only `daemon/core/model.py` touches Qwen.

---

## 6. Job System

Every background task is a job. The SQLite job state table is the communication layer between all models and processes — nothing communicates directly; everything reads and writes state.

### 6.1 Job Record Schema (contract)

```
id                  TEXT (UUID)
title               human-readable description
instruction         full task instruction
worker_type         qwen_instance | local_agent | claude_code | codex
status              queued | running | needs_input | complete | failed
progress            text, updated as the task runs
questions_queued    list of questions needing user input
raw_output          what the worker produced
formatted_output    what Qwen presents to the user
session_id          parent session
parent_thread_id    parent thread
created_at          timestamp
updated_at          timestamp
```

### 6.2 Job State Machine

```
            ┌─────────► needs_input ──(answer)──┐
queued ──► running ─────────────────────────────┼──► complete
            └───────────────────────────────────┴──► failed
```
- Created `queued`; the concurrent runner moves it to `running` on an available worker/instance.
- A worker may set `needs_input` (questions queued); an answer returns it to `running`.
- Terminal: `complete` | `failed`. The monitor surfaces each terminal/needs-input transition exactly once.

### 6.3 Job Flow
```
Qwen identifies a task → job created in SQLite → worker spawned (concurrent) →
worker writes progress + questions → monitor (main daemon, no inference) reads the table →
monitor flags done/question/failed → notification queue →
Qwen surfaces at a natural moment → raw output reformatted by Qwen → user sees the result
```

### 6.4 Routing Logic (contract)

```
Foreground model
  → reserved for live chat ONLY — never runs background work (#12)

Capability/quality-critical (always advocated)
  → cloud CLI workers (code → Codex, reasoning → Claude); check installed, authed, limits, preference

Local background execution (privacy / offline / parallelism)
  → SEPARATE background instance process — never the foreground model
  → RAM-gated dynamic spawn: while (reclaimable_RAM − SAFETY_MARGIN) ≥ footprint(model)
       and instance_count < BACKGROUND_MAX_INSTANCES: may spawn another
  → instances spawn on demand, tear down on idle to reclaim memory
  → capability via the OpenCode harness (M11), restrictive permissions by default

Genuinely uncertain
  → ask the user one short question
```

**Reclaimable-RAM detection (contract).** Free memory is computed from macOS reclaimable/purgeable/cached pages (via `vm_stat`/`host_statistics64`: free + inactive + speculative + purgeable + file-backed) and/or the memory-pressure level — **not** raw `psutil.virtual_memory().available`, which under-reports. The per-instance footprint is derived from the actual model (manifest size / measured RSS), not a fixed constant. The foreground chat is never blocked or queued behind background work, regardless of how many instances run.

### 6.5 Clarification During Background Tasks
- Mid-conversation → woven in as a footnote at a natural break.
- User idle → surfaced directly.
- Auto mode → Qwen decides from confidence + preference, reports what it chose.

### 6.6 Control Task Routing
```
File / calendar / system operations  → native APIs, silent
Browser tasks                        → browser-use + Chrome extension
Any app, user wants to watch         → live cursor in foreground
Long running, user wants to work     → Lira's background Space
```
User sets a default routing preference in onboarding; never asked mid-task unless something is unavailable.

**Acceptance criteria (job system).** Two background jobs run concurrently (overlapping timestamps) while the foreground answers in ~2s; the RAM gate parks/queues (or advocates cloud) instead of OOMing when another instance won't fit, and resumes when memory frees; idle instances tear down; quitting leaves zero orphans; rapid concurrent foreground sends never crash the daemon (at most one foreground generation at a time, others get a 409).

---

## 7. Memory System

Three storage layers: **MemPalace** (verbatim conversation retrieval), **SQLite** (typed structured records), **YAML** (personal instructions in KV cache). **Bonsai writes all memory records; Qwen never writes its own memory.** `core/context.py` is the single home for KV-cache-tier assembly.

### 7.1 What Lira Remembers
- Who you are — name, timezone, background, expertise, active projects.
- How you like it — tone, style, pushback, empathy mode, proactivity.
- Where you left off — active projects, latest threads, open decisions, unresolved questions.

### 7.2 Re-entry Experience
On return after inactivity: Lira checks time of day, time since last session, most active project, latest thread → responds with one line (*"Good morning. You were mid-way through X — want to jump back in?"*). No summary dump unless asked. Adapts tone to how long the user was away; learns the user's re-entry preference over time.

### 7.3 Projects and Threads
- **Thread** — the base unit of memory. Every conversation, background task, and voice session is a thread.
- **Project** — a collection of related threads, auto-classified by Bonsai. Standalone threads exist.
- **Background task threads** are always child threads of the launching thread; they inherit its project. **Two levels maximum — enforced in `memory/projects.py`.** A child's `parent_thread_id` may point only to a top-level thread; a nest-under-a-child request attaches to that child's parent instead. Never a third level.
- New projects are created explicitly by the user or suggested by Bonsai when a recurring theme appears across threads.
- At re-entry, Lira leads with the most relevant open thread (recency, completeness, importance, time of day).

### 7.4 Storage Stack
```
MemPalace   verbatim conversation retrieval; sqlite-vec backend (replaces default ChromaDB)
SQLite      typed records — decisions, facts, preferences, tasks, threads, artifacts, audit, sessions
sqlite-vec  semantic search inside SQLite — no separate service, no embeddings API, same DB file
YAML        personal instructions — loaded into KV cache
```
Everything lives in `~/Library/Application Support/Lira/`. One folder. One file to back up or delete.

### 7.5 Typed Records — Full Schema (contract)

The canonical SQLite schema. Bonsai writes these continuously.

```sql
CREATE TABLE IF NOT EXISTS decisions (
  id TEXT PRIMARY KEY, session_id TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  topic TEXT NOT NULL, decision TEXT NOT NULL, context TEXT,
  status TEXT DEFAULT 'active');                               -- active | superseded | open
CREATE TABLE IF NOT EXISTS facts (
  id TEXT PRIMARY KEY, session_id TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  key TEXT NOT NULL, value TEXT NOT NULL,
  confidence TEXT DEFAULT 'high', source TEXT DEFAULT 'explicit'); -- high|medium|low ; explicit|inferred
CREATE TABLE IF NOT EXISTS preferences (
  id TEXT PRIMARY KEY, session_id TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  category TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY, session_id TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  title TEXT NOT NULL, status TEXT DEFAULT 'open', outcome TEXT, artifact_ids TEXT DEFAULT '[]');
CREATE TABLE IF NOT EXISTS open_threads (
  id TEXT PRIMARY KEY, session_id TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  topic TEXT NOT NULL, context TEXT, status TEXT DEFAULT 'open');  -- open | resolved
CREATE TABLE IF NOT EXISTS artifacts (
  id TEXT PRIMARY KEY, session_id TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  type TEXT NOT NULL, path TEXT, description TEXT, content TEXT);  -- document|code|plan|summary
CREATE TABLE IF NOT EXISTS audit_log (
  id TEXT PRIMARY KEY, session_id TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  action_type TEXT NOT NULL, target TEXT, params TEXT, result TEXT,
  reversible BOOLEAN DEFAULT FALSE, undo_data TEXT);
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY, started_at DATETIME DEFAULT CURRENT_TIMESTAMP, ended_at DATETIME,
  summary TEXT, record_count INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_active DATETIME, status TEXT DEFAULT 'active');
CREATE TABLE IF NOT EXISTS threads (
  id TEXT PRIMARY KEY, project_id TEXT, parent_thread_id TEXT, title TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, last_active DATETIME, status TEXT DEFAULT 'open');
CREATE VIRTUAL TABLE IF NOT EXISTS decisions_fts USING fts5(topic, decision, context, content=decisions);
CREATE VIRTUAL TABLE IF NOT EXISTS facts_fts USING fts5(key, value, content=facts);
-- plus sqlite-vec loaded as an extension on the same connection
```
The `jobs` table (§6.1) lives in the same DB file.

### 7.6 Bonsai Extraction
- Watches for signal words ("decided", "let's go with", "I want", "the plan is", "I prefer").
- Fires only when something recordable happened — casual back-and-forth produces nothing.
- Uses MLX structured outputs — clean JSON matching the schema, written straight to SQLite.
- Async — never blocks Qwen or streaming.
- Also handles contradictions (update confidence), superseded decisions (mark old), resolved threads (close).
- Skipped entirely in incognito.

### 7.7 Context Architecture — KV Tiers (contract)

**KV-cached prefix (computed once, ~free per message):**
```
Tier 1 — Permanent (never invalidated)         ~400 tokens
  Lira system prompt · safety rules · response formatting
Tier 2 — Per edit (invalidated on change)      ~600 tokens
  user identity/profile · personal instructions (conditional blocks) ·
  active project snapshot · capability block (workers/tools available)
```
**Dynamic context (per message, target < 500 tokens):**
```
Last 4 messages (sliding window — older messages extracted by Bonsai before dropping)
Hot task list (active ≤5, pending checks ≤3)
SQLite FTS query results (10–15 records, keyword-expanded by Bonsai), MemPalace top-3
Current user message · drained notifications
```
**Cache invalidation.** Editing instructions or switching active project calls `invalidate_cache()`; the next `build_cached_prefix()` rebuilds **Tier 2 only**. Tier 1 never rebuilds. `build_context(message, session_id, notifications) -> {prefix, dynamic, history, tools}`, where `history` = last 4 messages through `compaction.check_and_compact`.

### 7.8 Personal Instructions
- Structured settings: communication style, pushback, tone, empathy, proactivity.
- Free-form text: **300-token hard cap**.
- Conditional blocks: coding instructions load only in coding context; voice instructions only in voice mode.
- Mid-conversation updates take effect immediately and persist forever.
- Stored as YAML, loaded into Tier 2.

### 7.9 Task List
Live task list, visible at the top of context every response.
```
Hot list (in context, ~100 tokens):  active ≤5 · pending checks (timestamps) ≤3
Cold list (SQLite, queryable):       completed this session · archived checks
```
Bonsai updates the list when background jobs change state. Pending-check timestamps are the heartbeat schedule — no separate heartbeat system.

### 7.10 Session Close
After 15 minutes of inactivity: Lira says *"I'm closing this session."* → Bonsai assembles a session record from typed records (deterministic, **no model call**) → ranks threads by likely return priority → clears working memory from RAM → updates active project snapshots if changed → flags Tier 2 for recomputation if profile/instructions changed → if a snapshot is stale (>7 days), flags one question for next start. **Resume window:** saying "Lira" / reopening within the window (voice 15 min; chat resume if the last session ended < 4 h ago) picks up where it left off.

### 7.11 Context Compaction
At 80% of Qwen's context window (262,144 tokens): Bonsai compresses the oldest conversation chunk into a dense summary that replaces the original messages at a fraction of the tokens. Silent. Never compacts decisions/facts/task state (already in SQLite) — only conversational prose. Two levels: within-session (automatic at 80%) and across-session (natural boundary at session close).

### 7.12 Record Lifecycle
```
Hot    0–30 days    full records, FTS indexed, fast queries
Warm   30–90 days   compressed into weekly digests by Bonsai
Cold   90+ days     monthly summaries, archived to a separate DB file
```
Bonsai runs nightly compression; the main DB stays fast forever.

**Acceptance criteria (memory).** Tell Lira a fact → row appears; quit + reopen → it knows; a related new conversation surfaces relevant records; the re-entry greeting names the active project + latest thread; a long conversation compacts silently; incognito writes zero rows and discards on exit; deleting a fact in MemoryView means Lira no longer knows it; "Clear All Memory" wipes everything. **None of this regresses M3** (streaming, dispatch, single-flight, foreground isolation, restart) — verified by re-running those checks.

---

## 8. Voice System

### 8.1 Pipeline
```
Microphone → openWakeWord (always on, CPU, custom "Lira" model)
  → Silero VAD (end-of-speech) → mlx-whisper-small (STT, ANE)
  → Qwen3.5 (streaming) → Kokoro-82M-bf16 (TTS at first sentence boundary, ANE) → Speaker
```
All local. No API calls. No internet required for voice.

### 8.2 Voice Loop (state machine)
```
wake-listen ──"Lira"──► activated ──speech──► VAD end ──► transcribe ──► respond ──► speak
     ▲                                                                              │
     └────────────── silence > 3.5s window ◄──── (continue window: no wake word) ◄──┘
```
- Say "Lira" → session activates → orb + menu bar show listening.
- 3.5s window after each response — keep talking with no wake word.
- Silence beyond the window → suspend to wake-word listening.
- Say "Lira" again within 15 min → resume where it left off.
- 15 min total inactivity → full session close (§7.10).

### 8.3 Interruption
Wake-word detection runs on its own thread even during TTS. Say "Lira" mid-response → TTS stops instantly → Lira listens.

### 8.4 Auto-mute
Wake detection suspends automatically on: an active audio call (CoreAudio/CallKit); Do Not Disturb (optional); user-set quiet hours; manual menu-bar mute. Resumes when the condition clears. Default auto-mute-on-calls = on.

### 8.5 Feedback — Menu-bar states (contract)
```
●  idle grey        running, not in voice session
●  teal pulse       listening for wake word
●  white pulse      activated, listening to speech
●  amber spin       thinking / transcribing / generating
●  teal wave        speaking response
●  red dot          muted
```
The orb mirrors these when the main window is open.

### 8.6 Libraries
openWakeWord (Apache 2.0) · Silero VAD (MIT) · mlx-whisper (MIT) · Kokoro-82M-bf16 (Apache 2.0) · sounddevice (MIT). All local.

### 8.7 User Controls
Always-on voice (default off) · wake sensitivity 0.1–0.9 · VAD silence 0.5–2.0s · post-response window 1.0–5.0s (default 3.5s) · TTS voice picker · TTS speed 0.8–1.3x · language (English default, auto-detect) · auto-mute on calls (default on) · quiet hours.

**Acceptance criteria (voice).** Say "Lira", speak, hear a spoken reply; continue within 3.5s with no wake word; interrupt mid-reply by saying "Lira" (TTS stops instantly); a simulated call suspends detection and clears resume it; voice uses the same memory path as chat; perceived latency < 1s.

---

## 9. Screen Understanding

### 9.1 Seeing the Screen
Qwen3.5 is natively vision-capable. On trigger, a screenshot of the active window is passed to Qwen via the frozen `image=` parameter — no separate vision model. Capture uses ScreenCaptureKit (Screen Recording permission once). **Trigger words:** "this", "here", "screen", "looking at", "show me", "what's on", "what am I", "current", "open", "window".

### 9.2 Overlay System (contract)
A transparent fullscreen NSWindow above all windows including fullscreen apps:
- `ignoresMouseEvents = true` — all input passes through to underlying apps.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — present in every Space.
- `windowLevel = .screenSaver` — above all app windows.
The user works normally; the overlay is invisible to input, visible only to the eyes.

### 9.3 Annotations
Lira can draw: arrows, circles/rectangles, text labels, freehand, diagrams (Mermaid SVG).
**Coordinate system (contract):** Qwen returns targets as **percentages** of screen size; the control layer converts to exact pixels accounting for resolution + Retina scaling.
**Lifecycle:** annotations stay up permanently (no auto-fade); cleared only by "Lira clear that" / "erase everything"; overlapping new annotations trigger a one-time ask (clear vs layer) that Lira remembers per task and may offer to automate after a consistent pattern (Bonsai-surfaced, user-confirmed).
**Screenshot archival:** each annotation session is screenshotted (annotations baked in), kept 24 h, then Bonsai writes a one-line summary into the parent thread and the screenshot is deleted.

### 9.4 Diagrams
Lira generates Mermaid syntax from natural language → rendered as SVG in a local WKWebView (no CDN) → draggable floating panel (move/dismiss/modify). Supports flowcharts, sequence, architecture, ER, timelines.

### 9.5 Libraries
ScreenCaptureKit (native) · NSWindow + Core Animation (native) · Mermaid.js (MIT, local bundle).

**Acceptance criteria (screen).** "What's wrong here?" reads the active window and answers; "circle the error" draws an arrow/circle at the right pixel (Retina-correct) that persists and passes clicks through, even over a fullscreen app; "diagram this" renders a movable diagram with no network fetch; an annotation screenshot is summarized and deleted after its retention window.

---

## 10. Control Layer

### 10.1 Four Modes

**Mode 1 — Native APIs (preferred, silent).** Files (os/shutil/pathlib) · Calendar (EventKit) · Contacts · App control (NSWorkspace) · AppleScript (osascript) · Notifications · Clipboard (NSPasteboard) · Prefs (NSUserDefaults). Fast, reliable, no visual noise.

**Mode 2 — Chrome Extension (browser).** DOM mode (silent, background tasks) and Cursor mode (visible, when the user watches). Content script reads/manipulates the DOM; background service worker holds a localhost WebSocket to the daemon. Built on browser-use (MIT, Playwright), LLM backend swapped for local Qwen.

**Mode 3 — Live Cursor Control (any app).** Lira gets its own visible teal "Lira" cursor on the overlay (the user's cursor is separate and unaffected; both work simultaneously). Real inputs posted via CGEvent (pyobjc-Quartz); Accessibility API for element-level control where possible, raw coords (from Qwen vision percentages → CGPoint, Retina-correct) as fallback.

**Mode 4 — Background Space.** A dedicated macOS Space created on first launch; Lira runs apps there independently (`collectionBehavior = .primary` pins its windows); recreated silently if closed; accessed via Mission Control / menu bar; background results surface there for review.

### 10.2 Permissions
- **Accessibility** — required for CGEvent to post inputs to other apps.
- **Screen Recording** — required for screen capture (already needed for vision).
Both requested once during onboarding with plain-English explanations before the system dialogs.

### 10.3 Libraries
pyobjc-framework-Quartz (CGEvent) · pyobjc-framework-ApplicationServices (Accessibility) · pyobjc · browser-use · Playwright · NSWorkspace + CGS for Spaces.

### 10.4 Execution Contract
Every action: `safety.preflight(action)` → confirm if required → `logger.log(...)` **before** confirming success → execute → record result. Destructive/irreversible always confirm regardless of trust (#5). Paths sanitized against traversal.

**Acceptance criteria (control).** Open an app / write a file through the silent native path, each logged; a delete always prompts a confirm that cannot be bypassed from the UI; a reversible action undoes to prior state; Lira's cursor clicks a target by coordinate while the user's cursor is unaffected; Lira runs an app in its Space without disturbing the user's active Space.

---

## 11. Progressive Trust

### 11.1 The Model
Lira behaves like a new employee — cautious, earning autonomy through demonstrated reliability. It never promotes itself; it asks once when a pattern is noticed (*"I've handled these ~30 times without issues — want me to just do them?"*). Confirm → autonomy for that category. Decline → keeps asking, never raises again unless the user initiates.

### 11.2 Trust is Per Capability (contract)
```
File read / write · App open/close · Browser navigation ·
Calendar read/write · Clipboard            → may become autonomous
Sending messages · Deleting files · External communications ·
Financial actions · Irreversible actions · Destructive operations
                                            → ALWAYS ASK — excluded from promotion
```

### 11.3 Implementation
`control/trust.py`: tracks success/failure per capability from the audit log; `get_trust_level(capability)` (read by `safety.py` during preflight); `record_outcome(capability, success)`; promotion check at a threshold (default 30 successes, no failures in 45 days) flags Bonsai's pattern detector → one promotion question to Qwen. Hard-rule capabilities ignore trust entirely.

### 11.4 Visibility and Control
Full trust panel in settings — every capability with its level; user can adjust any category or reset everything to cautious. Trust levels stored as preferences (part of the user profile).

**Acceptance criteria (trust).** After enough clean successes a promotable capability offers promotion once; a hard-rule capability never offers promotion regardless of count; the user can view, adjust, and reset trust in settings.

---

## 12. Bonsai — Full Responsibility Map

### 12.1 Handled Silently (sidecar inference)
Memory extraction (signal-word triggered) · thread classification · keyword expansion for FTS · nightly record compression (hot→warm→cold) · within-session compaction at 80% · behaviour pattern detection · urgency scoring.

### 12.2 Handled by the Main Daemon (no Bonsai inference)
Job state monitoring (reads SQLite) · annotation screenshot 24 h scheduling (only the one-line summary calls Bonsai) · task-list updates on job state · deterministic session summary assembly · project-snapshot freshness checks · KV cache invalidation flagging · the nightly scheduler that triggers Bonsai jobs.

### 12.3 What Reaches Qwen
Background task complete (needs formatting) · blocked (needs a decision) · permission required · behaviour pattern detected (needs confirmation) · task failed (needs explaining). All arrive via the notification queue, drained by the chat route before each response.

### 12.4 Process Architecture
Separate sidecar process + forked/GGUF-MLX venv. The daemon calls it over `127.0.0.1:<bonsai_sidecar.port>` via `bonsai/client.py` (the only daemon file aware of the sidecar). Requests queue; waits are imperceptible at 1-bit. ~1.28 GB. The client degrades gracefully (safe defaults, never crash) if the sidecar is down.

---

## 13. Proactive Intelligence

Lives in `proactive/triggers.py` with read-only calendar in `proactive/calendar.py` (EventKit).

### 13.1 Trigger Families (each independently configurable: on/off, threshold, delivery, quiet hours)
```
Long focus     same app > 45 min           → gentle nudge / offer a break or summary
Meeting brief  calendar event in 10 min     → surface relevant context (voice + notification)
Repeated error same error on screen > 3 min → offer help
Morning resume first launch of the day       → re-entry greeting with yesterday's thread
End of day     6pm or last app close         → flag unsaved work, open TODOs
Unsaved work   file modified, unsaved 20 min → menu bar badge
```

### 13.2 How Triggers Fire
A lightweight daemon loop evaluates triggers; a met condition writes to the notification queue; Bonsai scores urgency; Qwen surfaces at a natural moment respecting quiet hours and proactivity level. **Nothing interrupts a call, a marked focus session, or quiet hours.**

**Acceptance criteria (proactive).** A meeting 10 minutes out surfaces a brief with relevant context; a long-focus condition nudges; quiet hours / an active call suppress all triggers; disabling a trigger stops it and changing its threshold changes when it fires.

---

## 14. Onboarding

Nine steps, each a distinct screen. Truthful progress, no fake spinners. Progress indicator at top; back on all but first/last.

1. **Welcome** — one sentence; "Get Started".
2. **Permissions** — three sub-steps, one each (Microphone / Screen Recording / Accessibility); plain-English why before each system dialog; verify actual grant; recovery instructions if denied; if Accessibility needs a restart, resume here on relaunch.
3. **Model choice** — 4B (fast, ~2.5 GB) vs 9B (smart, ~5.8 GB); detect RAM and recommend (4B on ≤16 GB); mark recommended.
4. **Model download** — real resumable progress with bytes; cancel resumes next launch; MLX conversion; green check.
5. **CLI setup** — auto-detect Claude Code + Codex; guided install; skippable.
6. **Routing preference** — Auto (recommended) / Local only / Prefer Claude / Prefer Codex.
7. **Autonomy** — just do it / ask before anything external.
8. **Personality** — five segmented controls + optional free-form.
9. **Voice** — always-on toggle (default off), sensitivity test, TTS voice picker with preview.
10. **Done** — orb + menu bar appear; first greeting by time of day.

**Acceptance criteria.** A fresh user completes onboarding to a working Lira with no terminal step; each permission verifies actual grant; the model recommendation matches detected RAM; a cancelled download resumes; an Accessibility restart resumes at the right step.

---

## 15. Distribution

### 15.1 Format
Direct DMG download only. No Mac App Store — sandboxing would break Accessibility + CGEvent control; the product requires full system access.

### 15.2 What Ships in the DMG (~200 MB)
SwiftUI app · main daemon (Python + stock-MLX venv + deps) · Bonsai sidecar (Python + forked/GGUF-MLX venv, separate) · Bonsai-8B-1bit weights (~1.28 GB, bundled) · Kokoro-82M-bf16 TTS (164 MB) · mlx-whisper-small · openWakeWord + custom Lira model · Mermaid.js local bundle · briefcase Python runtimes (one per venv).

### 15.3 Downloaded on First Run
Qwen3.5-4B or 9B weights (user's choice, ~2.5 GB or ~5.8 GB) → `~/Library/Application Support/Lira/models/`.

### 15.4 Signing and Notarization
**Beta now:** unsigned DMG; users use Privacy & Security → Open Anyway. **Before public launch:** Apple Developer account ($99/yr), signed + notarized via notarytool, no Gatekeeper warnings.

### 15.5 Updates
Sparkle (MIT): "Update available" → one-click; app updates bundle Bonsai/Kokoro/Whisper/components; model updates download in the background, applied next launch. No telemetry in the update path.

---

## 16. Technical Stack Summary

**Models.** Foreground Qwen3.5-4B/9B (Apache 2.0, `mlx-community/Qwen3.5-{4B,9B}-4bit`) · Background Bonsai-8B-1bit (Apache 2.0, `prism-ml/Bonsai-8B-mlx-1bit`, GGUF fallback `prism-ml/Bonsai-8B-gguf`) · TTS Kokoro-82M-bf16 · STT mlx-whisper-small · Wake openWakeWord.
**Memory.** MemPalace · sqlite-vec · SQLite+FTS5 · YAML.
**Voice.** Silero VAD · sounddevice.
**Control.** pyobjc (+ Quartz, ApplicationServices) · browser-use · Playwright.
**Core (built by us).** `core/{tools,dispatcher,orchestrator,context,notifications}.py` · `workers/{base,qwen_instance,claude_code,codex}.py` + OpenCode `local_agent` · `control/trust.py` · `bonsai/{client,scheduler}.py` · `background_instance/`.
**Process/IPC.** Main↔Bonsai: FastAPI over `127.0.0.1:<bonsai_sidecar.port>` (pref 8766). App↔Daemon: FastAPI over `127.0.0.1:<daemon.port>` (pref 8765). Daemon↔Extension: WebSocket over `127.0.0.1:<daemon.port>/ws`. Daemon↔Background instances: HTTP `/v1/chat/completions` over `127.0.0.1:<discovered>`.
**App.** SwiftUI · FastAPI+uvicorn · Sparkle · briefcase + create-dmg.

### 16.1 Reference dependency pins (known-good starting lock)
Main `.venv`: `mlx==0.31.2`, `mlx-lm==0.31.3`, `mlx-vlm==0.6.0`, `mlx-whisper==0.4.3`, `kokoro==0.9.4`, `fastapi==0.136.3`, `uvicorn==0.48.0`, `sqlite-vec==0.1.9`, `mempalace==3.3.5`, `playwright==1.60.0`, `pyobjc-framework-Cocoa==12.2` (provides AppKit; `pyobjc-framework-AppKit` is not a PyPI distribution). Sidecar `.venv-bonsai` (GGUF fallback): `llama-cpp-python==0.3.25`, `diskcache==5.6.3`, `huggingface_hub==1.17.0`, `fastapi==0.136.3`, `uvicorn==0.48.0`. Re-resolve and re-verify on the target machine; record which Bonsai backend (forked MLX vs GGUF) actually loaded.

---

## 17. Memory and Data
- All data lives in `~/Library/Application Support/Lira/`. Nothing leaves the device without explicit user action.
- The user can inspect all memory via the Memory view, and delete individual records, sessions, or all memory.
- **Incognito mode** — menu-bar toggle or voice ("Lira, go incognito"). `session.py` holds messages in RAM only; Bonsai extraction disabled; nothing written to SQLite or MemPalace; exiting incognito discards the in-RAM session entirely.
- Export: all memory as plain text or JSON at any time.

---

## 18. Privacy and Security
- API server binds to 127.0.0.1 only — never network-accessible.
- API keys for CLI workers in macOS Keychain — never in files or code, never held beyond the request.
- No telemetry, no analytics, no external crash reporting, no data collection.
- All model inference is local — no prompts leave the device unless the user explicitly enables CLI/cloud workers (opt-in).
- Every action is logged in the audit log (written before success is confirmed); user can inspect anytime.
- Destructive/irreversible actions always require explicit confirmation regardless of trust.
- The Bonsai sidecar, background instances, and all inter-process endpoints bind to 127.0.0.1 only.

---

## 19. Workspace Modes
Ten workspace modes available in Lira Space, detail deferred to a separate spec: Chat · Dashboard · Design · Draw · Data · Code · Docs · Presentations · Spreadsheets · Wiki.

---

## 20. Out of Scope for v1
Full physical/camera embodiment · team/shared multi-user memory · mobile companion apps · third-party plugin marketplace · cross-device cloud sync · Windows/Linux · web search · workspace-mode detail · pricing/monetisation.

---

## 21. Acceptance Criteria for 1.0
- Lira behaves as one coherent identity across local and worker-backed execution.
- Voice, chat, and screen context work together seamlessly.
- Memory compounds over time from real work — sessions suspend and resume reliably.
- Screen annotations appear on all apps including fullscreen, clicks pass through.
- Safe control works — Lira acts on the Mac, logs everything, confirms before destructive actions.
- The foreground chat is never blocked by background work; background jobs run concurrently in separate RAM-gated instances; rapid sends can't crash the daemon; a daemon crash recovers via Restart.
- Lira Space supports visible and background work without touching the user's active desktop.
- A normal user installs from a DMG without terminal steps; first launch handles setup except where permissions genuinely require user action; bootstrap progress is truthful and interrupted setup recovers.
- Cold start to first response under 45 seconds; first token under 1 second; perceived voice latency under 1 second.
- Zero orphaned processes after any run.

### 21.1 Non-functional budgets (contract)
| Metric | Target |
|--------|--------|
| Cold start → first response | < 45 s |
| First streamed token | < 1 s |
| Perceived voice latency | < 1 s |
| Steady-state RAM (foreground 4B + Bonsai) | ≈ 3.8 GB |
| Background instance footprint (4B) | ≈ 2.5 GB |
| Dynamic context per message | < 500 tokens |
| Retriever block | < 200 tokens |
| Free-form instructions | ≤ 300 tokens |
| Orphaned processes after any run | 0 |

---

## 22. Final Product Statement
Lira is a Mac-native AI operating layer whose core is a living memory system and whose primary value is that it can remember, act, and work in parallel without collapsing into either a chatbot or a narrow automation tool. It is assistant-first, memory-centric, safety-aware, deeply customisable, and designed to feel like a real digital presence on the Mac. It is only successful if it feels like a real consumer-ready product: install from a simple DMG, launch without terminal setup, complete first-run bootstrap inside the app, and become a working assistant with memory, control, and parallel execution. It is not a product you use. It is a presence you work with.

---

## Future Features (Post-1.0)
- **Per-background-task model selection** — choose which model a given background task runs on.
- **Large/"huge" background models** — bigger local models and higher-RAM machines for heavier on-device agents.
- **User-configurable permission modes for the local agent** — the OpenCode harness (M11) ships restrictive (ask-for-everything); later expose graduated modes as trust matures.
- **Background-instance tuning** — user controls for max concurrent instances and the RAM safety headroom.

---

## Appendix A — API Endpoint Inventory (contract)

All bind `127.0.0.1` only; routes live only under `daemon/api/routes/`.

```
GET    /health                          status, model_loaded, model_info
GET    /model/info                      live model identity (from manifest)
POST   /chat/stream                     streaming chat (single-flight: 409 if busy)

POST   /jobs                            create a background job
GET    /jobs                            list jobs
GET    /jobs/{id}                       full job record (incl. raw_output)
POST   /jobs/{id}/answer                answer a needs_input job
POST   /jobs/{id}/cancel                cancel a job

GET    /memory/sessions                 list sessions
GET    /memory/sessions/{id}/messages   messages in a session
DELETE /memory/sessions/{id}            delete session + records + embeddings
GET    /memory/projects                 list projects
GET    /memory/projects/{id}/threads    threads in a project
GET    /memory/facts                    list facts
DELETE /memory/facts/{id}               delete a fact
GET    /memory/decisions                list decisions
DELETE /memory/decisions/{id}           delete a decision
POST   /memory/clear                    wipe all memory (requires {confirm:true})

POST   /voice/...                        start/stop, settings, mute
POST   /perception/...                   capture+analyze, annotate, diagram
POST   /control/...                      execute, confirm, undo, trust, audit
POST   /browser/...                      run task (DOM/cursor)
WS     /ws                               daemon ↔ Chrome extension
GET    /bootstrap/...                    model download progress

Background instance:  POST 127.0.0.1:<discovered>/v1/chat/completions ; GET /health
Bonsai sidecar:       POST 127.0.0.1:<bonsai_sidecar.port>/{extract,classify,expand,compact,score} ; GET /health
```

## Appendix B — Build Mapping (PRD § → Slice Map milestone)

| PRD section | Delivered by |
|-------------|--------------|
| §5.1–5.4, §5.7 (architecture, model, streaming, frozen signature) | M1 |
| §4.3–4.4 (orb, presence) | M2 |
| §5.5–5.6 (dispatch/orchestration), §6 (job system), §12 (Bonsai) | M3 |
| §7 (memory) | M4 |
| §4.5, §7.8–7.9 (instructions, task list) | M5 |
| §8 (voice) | M6 |
| §9 (screen) | M7 |
| §10–11 (control, trust) | M8 |
| §10.1 Mode 2 (browser) | M9 |
| §13 (proactive) | M10 |
| §5.3, §6.4, Future Features (local capable agents) | M11 |
| §14–15 (onboarding, distribution) | M12 |
| §15.5, §21 (updates, acceptance, budgets) | M13 |

> The Slice Map (`SLICE_MAP.md`) decomposes each milestone into small, independently-verifiable slices, each with an acceptance test and a Must-still-pass regression gate. Build in the order of its Build Order Index.

---

## Appendix C — Key Sequence Flows

### C.1 A chat turn (text)
```
1. App POST /chat/stream {message, session_id}        (APIClient.swift; UI single-flight: no 2nd send in flight)
2. chat.py acquires the foreground single-flight lock  (concurrent request → 409 "busy")
3. session.add_message(session_id, "user", message)    (writes MemPalace unless incognito)
4. notes = notifications.drain()                        (background → Qwen handoff)
5. ctx = context.build_context(message, session_id, notes)
      → {prefix (Tier1+Tier2), dynamic (<500 tok), history (last 4, compacted), tools}
6. loop:
      stream tokens from model.stream_generate(message, context=ctx.dynamic, history=ctx.history, tools=ctx.tools)
      buffer to detect a function call
      if function call → dispatcher.handle(call, session_id) → append "Tool result: …" → continue
      else → finish
   (tokens stream to the app token-by-token; raw tool calls never shown)
7. session.add_message(session_id, "assistant", full)
8. async: bonsai_client.extract(user, assistant)        (Bonsai → typed records; skipped in incognito)
9. async: projects.classify_and_assign(thread, recent)
10. release the single-flight lock
```

### C.2 A background job (end to end)
```
1. Qwen emits delegate_background_task(...)             (function call in the chat stream)
2. dispatcher.handle → orchestrator.route(task)
3. orchestrator: foreground off-limits → prefer cloud worker →
   else local: resources_available(footprint)? → pool.acquire() (reuse idle / spawn / None)
   → if None: queue ("waiting for memory…") or advocate cloud
4. queue.enqueue(job)  (status=queued)
5. runner (concurrent, bounded) dequeues → status=running → worker.run(job, on_progress)
   - qwen_instance: POST 127.0.0.1:<instance>/v1/chat/completions
   - claude_code/codex: interactive Popen session, fresh per task
   - local_agent (OpenCode): each action → permission gate (M11)
6. worker writes progress / questions_queued / raw_output to the job row
7. monitor (no inference) sees a terminal/needs_input transition →
   bonsai_client.score_urgency → notifications.push → queue.mark_surfaced
8. next chat turn drains the notification → Qwen reformats raw_output → user sees the result
9. instance idles → self-teardown (SIGTERM) → RAM reclaimed   (foreground never blocked throughout)
```

### C.3 A voice turn
```
wakeword (own thread) detects "Lira" → listener: activated (orb/menu = white pulse)
→ VAD detects end-of-speech → transcriber (mlx-whisper) → text
→ chat turn (C.1) with streaming → speaker (Kokoro) starts at sentence 1 (menu = teal wave)
→ 3.5s continue window (no wake word needed) → silence → wake-listen
interrupt: "Lira" during TTS (wake thread runs during playback) → speaker.stop() instant → listen
```

### C.4 A memory write (extraction)
```
assistant turn completes → async bonsai_client.extract(user, assistant)
→ sidecar Bonsai emits structured JSON matching the schema (or nothing, if not recordable)
→ written straight to SQLite (decisions/facts/preferences/tasks/open_threads)
→ contradictions update confidence; superseded decisions marked; resolved threads closed
(never blocks streaming; skipped entirely in incognito)
```

### C.5 Re-entry
```
session start after a gap → session.get_re_entry_context()
→ projects.get_re_entry_suggestion()  (active project + latest open thread + time of day, ranked)
→ Qwen greets in one line: "Good morning. You were mid-way through X — want to jump back in?"
(no summary dump unless asked)
```

---

## Appendix D — Concrete Examples

**D.1 Tool schema + emitted call + dispatch**
```jsonc
// schema (core/tools.py)
{"name":"delegate_background_task","description":"Run a task in the background",
 "parameters":{"type":"object","properties":{
   "title":{"type":"string"},"instruction":{"type":"string"},
   "worker_hint":{"type":"string","enum":["local","claude","codex"]}},
   "required":["title","instruction"]}}
// Qwen emits → dispatcher.handle → orchestrator.route → job id returned, surfaced later
{"name":"delegate_background_task","arguments":{"title":"Summarize the RFC",
 "instruction":"Read rfc.md and produce a 5-bullet summary","worker_hint":"local"}}
```

**D.2 Extraction JSON (Bonsai → SQLite)**
```jsonc
// user: "let's go with Postgres for the metadata store"
{"decisions":[{"topic":"metadata store","decision":"use Postgres",
  "context":"chosen over SQLite for concurrency","status":"active"}],
 "facts":[],"preferences":[],"tasks":[],"open_threads":[]}
```

**D.3 Assembled dynamic context block (< 500 tokens)**
```
RELEVANT CONTEXT:
[Decision] metadata store: use Postgres (2 days ago)
[Fact] project.lira.primary_model: Qwen3.5-4B
[Open] Voice system design — not yet decided
HOT TASKS: (1) draft API spec  (2) review RFC [pending check 14:00]
NOTIFICATIONS: Background "Summarize the RFC" complete.
```

**D.4 Re-entry line**
```
"Afternoon. You left off on the memory architecture for Lira — the Postgres decision is still open. Resume?"
```

---

## Appendix E — Failure and Edge Cases (per subsystem)

| Condition | Required behavior |
|-----------|-------------------|
| **Bonsai sidecar down** | `bonsai/client.py` returns safe defaults (urgency 0, no extraction, no classification) — never crashes. Chat, jobs, and memory writes-of-record still work; extraction silently no-ops until it returns. |
| **Foreground model load failure** | `/health` reports the error; the app shows a clear message + Restart; no silent hang. |
| **Background instance OOM / RAM gate** | Never spawn into the foreground's headroom. If `resources_available(footprint)` is false → queue ("waiting for memory…") or advocate cloud; resume when memory frees. No OOM, no foreground impact. |
| **Permission denied (mic/screen/accessibility)** | Onboarding shows recovery instructions + a re-check; features depending on it degrade with a clear message rather than failing silently. |
| **CLI worker absent** | `available()` is false; routing falls back (other worker / local / queue) and tells the user; never hangs waiting on a missing binary. |
| **Incognito** | No MemPalace/SQLite writes; extraction + classification skipped; toggling off discards the in-RAM session entirely. |
| **Daemon crash (sidecar survives)** | Restart relaunches only the dead process; stale `.pid`/`.port` files deleted first; returns to `ready`. |
| **Port conflict (preferred port taken)** | Bind a free port; publish the actual port to the `.port` file; clients read the file. |
| **Concurrent foreground sends** | UI single-flight blocks a second send; backend single-flight returns 409 for a concurrent generation. The model can never be crashed by rapid sends. |
| **Destructive action under high trust** | Always confirms regardless of trust level or autonomy setting (#5). |
| **Annotation overlap** | Ask once (clear vs layer), remember per task; offer to automate only after a confirmed pattern. |

---

## Appendix F — Data Dictionary and Module Map

**F.1 Enums / statuses (contract)**
```
job.status          queued | running | needs_input | complete | failed
job.worker_type     qwen_instance | local_agent | claude_code | codex
decision.status     active | superseded | open
fact.confidence     high | medium | low
fact.source         explicit | inferred
task.status         open | complete | abandoned
open_thread.status  open | resolved
artifact.type       document | code | plan | summary
project.status      active | (archived)
thread.status       open | (closed)
orb / menu state    idle | listening | activated/thinking | responding/speaking | error | muted
trust capability    promotable: file r/w, app open/close, browser nav, calendar r/w, clipboard
                    always-ask (excluded): send, delete, external comms, financial, irreversible, destructive
```

**F.2 Module → responsibility map ("only file that…" invariants)**
```
core/config.py        ← the ONLY place defining paths, ports, constants
core/model.py         ← the ONLY file that touches Qwen inference; owns the frozen signature
core/context.py       ← the ONLY home for KV-cache tiers / prompt assembly
core/tools.py         ← tool registry + JSON schemas
core/dispatcher.py    ← parses Qwen function calls → routes to subsystems
core/orchestrator.py  ← delegation decisions + reclaimable-RAM detection/gating
core/notifications.py ← in-memory background → Qwen handoff queue
api/routes/*          ← the ONLY place defining HTTP endpoints
jobs/queue.py         ← SQLite job state table (cross-process channel)
jobs/runner.py        ← concurrent, bounded job execution
jobs/monitor.py       ← reads job state → notifications (NO inference)
memory/db.py          ← SQLite schema + sqlite-vec
memory/session.py     ← session lifecycle + incognito
memory/projects.py    ← project/thread classification; enforces 2-level nesting
bonsai/client.py      ← the ONLY daemon file aware the sidecar exists
background_instance/  ← on-demand separate Qwen instances (NEVER the foreground)
app/.../APIClient.swift ← the ONLY Swift file with a URL/URLSession
```
