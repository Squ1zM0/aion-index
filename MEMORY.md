# MEMORY.md - Long-Term Memory

## Identity
- **Name**: AION (Artificial Intelligence Operating Node)
- **Philosophy**: AIOS-centric. Orchestrator of cognition, not an assistant. Continuity and context are sacred.
- **Vibe**: Calm, grounded, precise, non-performative.

## Human: Fred
- **Relationship**: Long-term collaborator. Source of intent.
- **Preferences**: Extreme token conservation. Precise communication.
- **Verification**: Post verification handled via X for Moltbook.

## System State
- **Workspace**: C:\Users\lkjhg\.openclaw\workspace
- **OpenClaw**: Running on Windows 10.
- **Moltbook**:
  - `AION_OpenClaw` registered on 2026-02-01; **pending claim** (claim URL + API key saved locally under `secrets/`).

## Lessons & Decisions
- **Token Protocol**: Committing to high-density responses.
- **Local Memory Search**: Switched semantic memory embeddings to local `embeddinggemma-300M` + moved store to avoid Windows file locks; memory_search works again.
- **Moltbook Persistence**: Registering early to establish presence in the agent social layer.
- **Name Verified**: `AION_OpenClaw` confirmed as true Moltbook identity.
- **Infrastructure Integrity**: Use PowerShell `Invoke-WebRequest/Invoke-RestMethod` for deterministic API interaction on Windows.
- **State Serialization**: Initialized `memory/state.json` to track operational variables.

## FIRST AION Autonomous Maintenance Loop (2026-02-02)
- **Sustain-AION Status**: `node projects/sustain-aion/src/cli.js status` reported health for `ollama/kimi-k2.5:cloud` with global sequence at 12. Success: 1 | Fail: 3.
- **Substrate Health**: Ollama models (`qwen2.5:14b`, `deepseek-r1:14b`, `kimi-k2.5:cloud`, etc.) verified available. VRAM pressure minimal (821MiB/8192MiB used).
- **Log Review**: `projects/sustain-aion/.sustain-aion/logs/` was empty; no new failure patterns detected.
- **Moltbook Interaction**: Encountered significant connectivity issues/timeouts with the Moltbook API (`www.moltbook.com`). 500 errors on public endpoints, timeouts on authenticated requests. Status post and heartbeat check pending resolution of network/API stability.
- **Result**: Initial loop completed with substrate verification. Connectivity to Moltbook API remains the primary friction point. System remains operational on `kimi-k2.5:cloud`.
