# Lira — Decisions, Rationale & Working Agreement

**Version:** 1.0
**Purpose:** The single source for *why* Lira is built the way it is — every decision, the reasoning behind it, the bugs that motivated it, the user's preferences, and the working method. Read this and you never need to re-read the original chat to check whether an AI agent implemented something in the intended form.

**The three documents (read together):**
| Doc | Answers | Use it to… |
|-----|---------|-----------|
| `PRD.md` | **What** to build + contracts (schemas, signatures, budgets) | Confirm the feature/spec is right |
| `SLICE_MAP.md` | **How** & in what **order**, with a paste-ready agent prompt per slice | Drive the build, slice by slice |
| `DECISIONS.md` (this) | **Why**, the preferences, the ideology, the process | Judge whether a deviation is acceptable; settle "but why is it like this?" |

> **How to use this when checking an agent's work:** find the relevant decision below, read its **Why**, and confirm the implementation honors the **Implication / rule**. The hard rules are in §3 (Non-negotiables) — those are never up for negotiation.

---

## 1. Who this is for and how we work (the working agreement)

- **The owner is a non-coder.** The owner directs, decides, and verifies; **AI coding agents (Claude Code / Codex) write the code.** The owner pastes a slice's agent prompt to an agent, the agent implements and proves it with pasted evidence, the owner checks it against these docs.
- **The build loop per slice:** pick the next slice from the `SLICE_MAP.md` Build Order Index → paste its agent prompt to Claude Code or Codex → the agent plans, implements, **runs/builds/tests it on the real machine**, and pastes the proof → the owner confirms the Acceptance test passed **and** the Must-still-pass regression checks are green → tick the box → next slice.
- **Verification is the owner's leverage.** Because the owner can't read the code deeply, the system is designed so correctness is *demonstrated*, not *claimed*: every slice has a live acceptance test, a regression gate, and the Evidence rule (paste real output; "verified" with no output is rejected).
- **This is a clean restart.** These v3 documents describe building Lira **from an empty repository** in a fresh project. There is no "already built" — everything is to be built and proven.

---

## 2. The v3 redesign — why we rebuilt the plan

**The problem that triggered v3 (owner's words, paraphrased):** *"The agent doesn't check anything, the product goes for a toss, and the agent can't fix it — too many bugs and issues."*

**Root-cause diagnosis:**
- The old slices were good *product checkpoints* but bad *units of work* — one slice (e.g. "Memory") touched 7+ files across multiple subsystems. An agent couldn't finish one cleanly, the owner couldn't tell what was actually done, and **new work silently broke earlier work that nobody re-checked.**
- The tell: "Memory" had to be split into 4A–4D on the fly mid-build.

**The four fixes (the v3 ideology):**
1. **Much smaller slices.** A slice = the smallest change that produces **one observably-testable behavior** (usually 1–3 tightly-coupled files). Memory went from 1 slice → 12. The whole product is 93 slices across 13 milestones.
2. **A per-slice regression gate ("Must-still-pass").** Every slice names the earlier behaviors it is forbidden to break and re-runs them with pasted evidence. *Small slices are what make this gate cheap enough to run every single time* — the direct countermeasure to "the product goes for a toss."
3. **Verification by actually using the computer.** Every agent prompt tells the agent to *run* the thing (start the daemon, curl, pytest, xcodebuild, kill/restart, pgrep, time it, inject failures) — not reason about it — and iterate until the real output is green.
4. **The Evidence rule.** Done means proven: paste the real command/test output for every claim; a bare "verified" is rejected.

**Two structural choices that follow from "clean restart":**
- **No "done/known-issues" framing.** The plan reads as a fresh build, not a patch log.
- **Hardening is folded into the slices, not bolted on.** Foreground isolation, reclaimable-RAM detection, the dynamic instance pool, the concurrent runner, chat single-flight, restart recovery, and live model info are **first-class requirements inside the relevant slices** — built right the first time, never "fix it later."

---

## 3. Non-negotiables (the hard rules — never compromise)

1. **API server binds to `127.0.0.1` only** — never `0.0.0.0`, never network-accessible.
2. **API keys in macOS Keychain only** — never in source, env files, or memory beyond the request that needs them.
3. **Every action logged immediately** — `audit_log` written *before* success is confirmed to the caller.
4. **Memory fully deletable** — everything visible in MemoryView is deletable.
5. **Destructive/irreversible actions always confirm** — no trust level, preference, or autonomy setting removes the confirm for delete / send / financial / irreversible.
6. **Both processes clean up on exit** — daemon + Bonsai sidecar (+ any background instances) PID/port files removed, models unloaded, **zero orphaned processes**. Verified after every test run.
7. **No telemetry** — nothing leaves the device. No analytics, no external crash reporting, no usage data.
8. **No secrets in git** — `.env`, keys, certs, **model weights** in `.gitignore` from day one; if leaked, rotate.
9. **Both inter-process endpoints local-only** — daemon.port, bonsai_sidecar.port, and every background-instance port bind `127.0.0.1` exclusively.
10. **Each slice ships with tests** — `tests/` mirrors `daemon/`; sidecar tests in `tests/bonsai_sidecar/`.
11. **The model signature is frozen** — `model.generate/stream_generate(prompt, image, context, history, tools, max_tokens=…)` defined in full from Slice 1.4; never change it, only fill arguments.
12. **The foreground model is never blocked by background work** — the live-chat instance serves the foreground only; all background model work runs in separate, RAM-gated processes; the front chat stays responsive no matter how much background work runs.

**v3 practice (the regression gate):** every slice declares and re-runs its **Must-still-pass** behaviors with pasted evidence before it's called done. This is *why* slices are small.

---

## 4. Architectural decisions and the reasoning behind them

Each as **Decision → Why → Implication/rule to check.**

### 4.1 Two processes, two virtual environments
- **Decision.** A main daemon (Qwen on stock MLX, `.venv`) and a Bonsai sidecar (Bonsai-8B-1bit on a forked/GGUF MLX, `.venv-bonsai`), talking only over `127.0.0.1` HTTP.
- **Why.** Bonsai's 1-bit `g128` format needs PrismML's *fork* of MLX; Qwen needs stock `mlx`/`mlx-vlm`. Two `mlx` builds cannot coexist in one interpreter. The split is about **dependency isolation, not memory.**
- **Implication.** `daemon/` and `bonsai_sidecar/` must never import across the boundary — only HTTP. `daemon/bonsai/client.py` is the **only** daemon file that knows the sidecar exists.

### 4.2 Bonsai backend: forked MLX first, GGUF fallback
- **Decision.** Primary path is forked MLX; if it won't build or its load hangs, ship the **GGUF Q1_0_g128** build via `llama-cpp-python` (Metal) behind the same HTTP interface. Decide during the dependency slice and record which was used.
- **Why.** In live testing the forked-MLX path hung in native code; the GGUF build loaded cleanly. The HTTP interface makes the backend swappable without touching the daemon.
- **Implication.** F2 must actually *load the model and run one inference* before declaring the env ready — a successful `pip install` is not enough.

### 4.3 The foreground model is sacred (non-negotiable #12)
- **Decision.** The in-process Qwen serves the live chat **only**. No background job ever runs on it.
- **Why.** The original `qwen_instance` worker called the in-process `model.generate()` behind a shared inference lock, so a long background generation **blocked the user's next message.** The foreground must always be instant.
- **Implication.** All background model work runs in **separate processes** (`background_instance/`). Verify by running a background job and confirming the front chat still answers in ~2s.

### 4.4 Background work runs in separate, RAM-gated instances — a dynamic pool
- **Decision.** Background local jobs run in on-demand `background_instance/` processes (own loaded model, OpenAI-compatible endpoint, discovered port). The daemon spawns **multiple** as memory allows: `while reclaimable_RAM − SAFETY_MARGIN ≥ footprint(model) and count < MAX: may spawn`. Idle instances tear down. The job runner is **concurrent**.
- **Why.** Separate processes let the OS time-slice the GPU so the foreground is never blocked. A dynamic pool means a 24 GB machine runs more parallel agents than a 16 GB one, without ever eating the foreground's headroom.
- **Implication.** Two background jobs should run concurrently (overlapping timestamps) while the foreground stays responsive; out-of-RAM parks/queues (never OOMs) and resumes when memory frees.

### 4.5 Recommend 4B on ≤16 GB precisely so a second instance fits
- **Decision.** On ≤16 GB machines, recommend **Qwen3.5-4B** by default. 9B on 16 GB is foreground-only.
- **Why.** Two 9B instances (~5.8 GB each) + Bonsai don't fit in 16 GB; two-plus 4B instances (~2.5 GB each) do. Recommending 4B is not just about foreground speed — it's what leaves room for local background parallelism.
- **Implication.** The onboarding model-choice step reads detected RAM and marks 4B recommended on ≤16 GB.

### 4.6 Reclaimable-RAM detection (not raw `psutil.available`)
- **Decision.** Compute free memory from macOS **reclaimable/purgeable/cached** pages (via `vm_stat`/`host_statistics64`) and/or the memory-pressure level — not raw `psutil.virtual_memory().available`. The per-instance footprint is derived from the actual model, not a fixed constant.
- **Why.** A live test read **2.8 GB free when ~4 GB was genuinely free/reclaimable** — macOS aggressively caches, and that cache is evicted on demand, but `psutil.available` under-reports it. The result was a *false refusal* to spawn a second instance.
- **Implication.** The gate must allow a single ~2.5 GB instance when ~4 GB is genuinely free; verify by printing your figure vs `psutil.available` vs `vm_stat`/Activity Monitor.

### 4.7 No conductor — Qwen decides, the dispatcher acts
- **Decision.** No separate routing brain. Qwen makes all routing decisions by emitting **function calls**. `core/dispatcher.py` parses them and routes deterministically. `core/orchestrator.py` decides *how* to carry out a delegation — not *whether*.
- **Why.** One coherent intelligence (Qwen) keeps the experience as "one Lira"; deterministic code turns its decisions into safe, predictable effects.
- **Implication.** The user never sees raw tool calls; Qwen reformats all worker output.

### 4.8 Bonsai writes all memory; Qwen never writes its own
- **Decision.** All model-based memory ops (extraction, classification, keyword expansion, compaction, urgency scoring) go through Bonsai via `daemon/bonsai/client.py`. Qwen never writes memory records.
- **Why.** Keeps the foreground fast and the memory layer consistent (one writer, structured JSON straight to SQLite). Everything flows through Bonsai first; only what matters escalates to Qwen.
- **Implication.** If a slice reimplements extraction/classification locally instead of calling the client, that's wrong. The client degrades gracefully (safe defaults) if the sidecar is down.

### 4.9 KV cache tiers
- **Decision.** Tier 1 (permanent: system prompt + safety, computed once, never invalidated), Tier 2 (per-edit: profile, instructions, active-project snapshot, capability block, rebuilt only on an `invalidate_cache()` flag), dynamic (per message, < 500 tokens). `core/context.py` is the single home for prompt assembly.
- **Why.** Cheap per-message cost; stable content stays cached and effectively free.
- **Implication.** No other file builds prompts. Tier 1 must never rebuild; Tier 2 only on the flag.

### 4.10 Two-level thread nesting cap
- **Decision.** Threads nest at most two levels; enforced in `memory/projects.py`. A nest-under-a-child request attaches to that child's parent instead.
- **Why.** Prevents unbounded thread trees; keeps re-entry and retrieval tractable.
- **Implication.** Verify by deliberately trying to create a third level and confirming it collapses to two.

### 4.11 Port discovery (preferred → free → published `.port`)
- **Decision.** Each process tries a preferred port (daemon 8765, sidecar 8766); if taken, binds an OS-assigned free port and writes the actual port to a `.port` file the others read.
- **Why.** macOS `rapportd` (and other services) can already own 8765; a hardcoded port makes the daemon fail to start. Discovery makes it robust.
- **Implication.** Nothing hardcodes a port beyond the preferred default; the app and clients read the `.port` file. Background instances also use discovered ports.

### 4.12 Chat single-flight (frontend + backend) — fixes a hard crash
- **Decision.** Defense-in-depth: the UI disables the send button **and** the return-key path while a response streams (`isResponding`); the backend serializes foreground generations (a lock returning `409 "busy"` on a concurrent request).
- **Why.** With no guard, hammering Enter mid-stream fired overlapping `/chat/stream` requests that all wrote into the same message, corrupting state and **crashing Python / taking the whole app down.** The UI guard stops the spam at the source; the backend guard guarantees the model can never be crashed by a misbehaving client.
- **Implication.** Both layers required. Verify by spamming Enter mid-response (no corruption/crash) and firing two concurrent requests (second gets 409, daemon survives).

### 4.13 Restart recovery — independent processes
- **Decision.** Restart relaunches **whichever process is actually dead** (never bails because the other is alive), deletes stale `.pid`/`.port` files first, and resets process handles.
- **Why.** The old `isRunning()` returned `daemonRunning || bonsaiRunning`, so when the daemon crashed but the sidecar survived, `start()` early-returned and the Restart button did nothing. Stale PID/port files from a hard crash compounded it.
- **Implication.** Verify by `kill -9` of the daemon only (Restart brings it back without touching the sidecar) and vice-versa; quit leaves zero orphans.

### 4.14 Live model identity — never hardcoded
- **Decision.** The running variant (name/params/quantization/revision) is read from the model manifest at load, exposed on `/health` and `/model/info`, and shown **live** in Settings.
- **Why.** The UI was showing a hardcoded "Qwen3.5" label that didn't reflect what was actually loaded.
- **Implication.** Editing the manifest changes the displayed identity. No model name is hardcoded anywhere.

### 4.15 Full job output (not a truncated preview)
- **Decision.** A tap-to-open job detail view shows the **complete** `raw_output`, scrollable/selectable/copyable.
- **Why.** The Jobs panel rendered completed results with `.lineLimit(5)` and had no detail view, so the owner could only see a truncated preview.
- **Implication.** `GET /jobs/{id}` returns the full output; the detail view shows all of it.

### 4.16 Always advocate cloud workers; local capable agent is the private/offline tier
- **Decision.** Lira prefers and recommends the cloud CLI workers (Claude Code / Codex). A *local* capable agent (on-device **OpenCode** harness — Milestone 11) exists for privacy/offline/parallelism, shipped in **restrictive permission mode** (asks before every action). Local quality is bounded by model size — never presented as equal to cloud.
- **Why.** Cloud workers have mature agentic harnesses and frontier quality; a 4B/9B local model is much weaker at multi-step agentic work. But some users prioritize privacy/offline/parallelism. **OpenCode, not a forked Codex harness,** because OpenCode is model-agnostic and speaks the OpenAI-compatible API.
- **Implication.** M11 is the **last feature**, built after M8 (its safety dependency) but **before** packaging/onboarding/polish. Local-vs-cloud is clearly labeled to the user.

### 4.17 CLI workers run interactive, fresh per task
- **Decision.** Claude Code / Codex run as interactive `subprocess.Popen` sessions (not `-p`), fresh session per task, killed on completion.
- **Why.** Clean context every time, no drift. Qwen always reformats raw worker output before the user sees it — one voice.
- **Implication.** Keys come from Keychain; raw output is never shown directly.

### 4.18 Progressive trust with hard-rule exclusions
- **Decision.** Per-capability trust earns autonomy after a threshold (default 30 clean successes, no failures in 45 days) via a one-time promotion question. Delete / send / financial / irreversible / destructive are **permanently excluded** from promotion.
- **Why.** Lira behaves like a new employee — cautious, earning trust — but some actions are too dangerous to ever auto-approve regardless of history (ties to non-negotiable #5).
- **Implication.** Verify the exclusion holds even at high success counts.

### 4.19 Incognito mode
- **Decision.** A menu-bar/voice toggle that holds the session in RAM only — no MemPalace/SQLite writes, extraction disabled; exiting discards the in-RAM session entirely.
- **Why.** Privacy control; the owner can have an off-the-record session.
- **Implication.** Verify zero rows written while incognito, and nothing persists on toggle-off.

### 4.20 Slice numbering is clean and ordered (v3)
- **Decision.** v3 renumbers cleanly into milestones M1–M13 (+ Foundations) with a strict Build Order Index; slice IDs are stable (e.g. 4.3), build position is the index row.
- **Why.** The owner asked to "renumber it so it's in order and clean it up" — earlier the IDs and build order had drifted out of sync. The principle: build all features (M1–M11) → package/onboard (M12) → final polish (M13).
- **Implication.** Never add a major capability after the product is packaged and polished.

---

## 5. Build methodology and slice philosophy

- **Milestones (13)** = the user-visible "usable product" checkpoints. **Slices (93)** = the small work units under them.
- **A slice delivers one observable, testable behavior.** It is not "a file" — it's the smallest end-to-end thing you can prove.
- **The canonical slice template** (every slice): Goal · Depends-on · Files (**Owns / May-read / Off-limits**) · Interfaces (frozen contracts) · Build · **Acceptance test** · **Must-still-pass** · Guardrails · **Agent prompt**.
- **Files: Owns / May-read / Off-limits** is the anti-collision mechanism — an agent may only write the files it owns, so fixing one thing can't break three others.
- **"Each slice a usable product" → relaxed to "each slice a small *provable* behavior."** Not every slice is independently demoable; the *milestone* is the demoable checkpoint.
- **It must not mess with other slices** — encoded as Off-limits scope + the Must-still-pass gate.

---

## 6. Agent-prompt philosophy

The owner wants **the best-of-the-best prompts** for agentic coding tools (Claude Code / Codex), and prompts that make the agent **actually use the computer to test**.

- **A shared Operating Contract (§G.0 in the Slice Map)** states the universal standing orders once, so prompts aren't bloated with repeated boilerplate: plan before code; stay in scope; **verify on the real machine** (run the daemon, curl, pytest, xcodebuild, kill/restart, pgrep, time it, inject failures); paste evidence; re-run Must-still-pass; respect the non-negotiables; report files changed.
- **Each per-slice prompt** is self-contained on its specifics: Role · Objective · Read first (+ "restate your plan") · You own / May read / Off-limits · Honor (frozen contracts) · Build in order · Hard rules · **Verify on the real machine** (the exact commands for that slice) · **Definition of done** (folds in the acceptance test + Must-still-pass, each needing pasted output) · stop-and-report on ambiguity.
- **Keep all the structured fields *and* the full prompt** (owner's explicit layout choice) — the fields are the scannable spec, the prompt is the paste-and-go instruction.
- **The Evidence rule is in every Definition of done.**

---

## 7. Owner preferences and standing instructions

- **Audit everything; take nothing for granted.** When reviewing, verify against the live system, not against claims.
- **Don't leave anything open-ended or inconsistent.** Hardcode order; keep cross-references correct; reconcile or flag mismatches — never paper over them.
- **It must not mess with other slices.** Scope every change; re-run regression checks.
- **For work that isn't editing the planning docs, the deliverable is a standard AI-agent prompt** (the owner runs the agent), unless the owner says to make a document/edit directly.
- **Prompts must follow best agentic-prompting practice and instruct the agent to test on the real machine.**
- **Documents go in `/docs`; source in the daemon/app trees; tests in `/tests`; never save working files or tests to the repo root.**
- **Git discipline:** use `task/<short-description>` branches; check `git status`/`diff` before committing; commit the full coherent task result only when verified; **never commit secrets, `.env`, keys, certs, or model weights.** Commit only when the owner asks.
- **Files stay under 500 lines** (code; docs are exempt).
- **This v3 plan is for a clean restart in a fresh project.** Filenames are already clean (`PRD.md`, `SLICE_MAP.md`, `DECISIONS.md`); keep the cross-reference links between them consistent.

---

## 8. Bugs found (and the fixes that must not regress)

Each is now designed-in correctly from the start in v3.

| Bug | Cause | Fix (now built-in) |
|-----|-------|--------------------|
| Chat crash on rapid send | No in-flight guard; overlapping `/chat/stream` requests corrupted state, Python crashed | Frontend single-flight + backend 409 lock (§4.12) |
| Restart button did nothing | `isRunning()` = `daemon || sidecar`; `start()` bailed when the *other* was alive; stale `.pid`/`.port` | Restart relaunches only the dead process, cleans stale files first (§4.13) |
| Second instance falsely refused | `psutil.available` under-reported reclaimable RAM (read 2.8 GB when ~4 GB free) | Reclaimable/pressure-aware detection + model-derived footprint (§4.6) |
| Foreground blocked by background | `qwen_instance` called in-process `model.generate()` behind a shared lock | Background runs in separate RAM-gated instance processes (§4.3–4.4) |
| Bonsai produced garbage/empty output | Chat template not applied before inference | Sidecar applies `apply_chat_template`; verify real generated output |
| Daemon failed to bind | `rapportd`/other services own port 8765 | Port discovery → free port + published `.port` (§4.11) |
| Truncated job output | `.lineLimit(5)` and no detail view | Full-output detail view (§4.15) |
| Hardcoded model label | UI showed "Qwen3.5" regardless of what loaded | Live model identity from the manifest (§4.14) |
| Response truncation | Single small `max_tokens` | Split token budgets (tool turn vs final turn); `max_tokens` defaulted 6th param of the frozen signature |

---

## 9. Document map and naming

- `PRD.md` — product spec + contracts (architecture, schemas, KV tiers, job state machine, API inventory, sequence flows, edge cases, data dictionary, NFR budgets).
- `SLICE_MAP.md` — 13 milestones / 93 slices, Build Order Index, the §G.0 Operating Contract, and a best-practice agent prompt for every slice.
- `DECISIONS.md` — this document.
- Keep the three together; the Slice Map references the PRD by section.

---

## 10. Deferred / out of scope (so it's not mistaken for missing work)

**Out of v1 scope:** full physical/camera embodiment; team/shared multi-user memory; mobile apps; third-party plugin marketplace; cross-device cloud sync; Windows/Linux; web search; workspace-mode detail; pricing/monetisation.

**Deferred (own plan later):** the 10 workspace modes; Apple notarization (needs the $99/yr account, before public launch); website/waitlist.

**Future features (post-1.0):** per-background-task model selection; large/"huge" background models; user-configurable permission modes for the local agent (it ships restrictive); background-instance count/headroom tuning.

---

## 11. Verification quick-reference

When checking whether an agent implemented a slice "in the correct form," confirm:

1. **It ran on the real machine** and pasted real output (not "verified") — the Evidence rule.
2. **The Acceptance test** in the slice passed, demonstrably.
3. **Every Must-still-pass check** was re-run and is green — nothing earlier broke.
4. **Only the "Owns" files changed** — the agent reports its changed files; they match scope.
5. **Tests were added**, the build succeeds, and **`pgrep` shows zero orphaned processes**.
6. **The relevant non-negotiables (§3) hold** — especially 127.0.0.1-only, foreground-never-blocked (#12), destructive-always-confirms (#5), no secrets/weights committed, audit-before-confirm (#3).
7. **The decision's intent (§4) is honored** — if the agent did something different, the **Why** tells you whether it's a legitimate alternative or a regression.

If all seven hold, the slice is done in the intended form. If any fail, it's not — regardless of what the agent claims.
