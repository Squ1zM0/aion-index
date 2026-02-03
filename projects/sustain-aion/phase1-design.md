# Sustain-AI0N — Phase 1: Discovery & Design Document

> **AION Integrity Principles:** Continuity | No Hallucination | State Awareness

**Document Version:** 1.0  
**Date:** 2026-02-02  
**Status:** Design Phase Complete

---

## Executive Summary

Sustain-AI0N is a round-robin multi-model orchestration system designed to ensure long-term AI operational sustainability. By distributing cognitive load across multiple local and remote models, the system prevents single-model fatigue, reduces dependency on any one provider, and maintains continuity of service even when individual models become unavailable.

---

## Phase 1: Discovery & Inventory

### 1.1 Available Models Inventory

#### Ollama Local Models

| Model | Parameters | Context | Quantization | Size | Capabilities | Speed Estimate |
|-------|-----------|---------|--------------|------|--------------|----------------|
| `kimi-k2.5:cloud` | Remote (via Ollama) | ~131072 | - | Cloud-hosted | completion, tools, thinking, vision | Fast (cloud) |
| `gemma3:4b` | 4.3B | 131072 | Q4_K_M | 3.3 GB | completion, vision | Fast (local) |
| `gpt-oss:120b-cloud` | 116.8B | 131072 | MXFP4 | Cloud-hosted | completion, tools, thinking | Medium (cloud) |

#### OpenClaw Configured Models

| Model ID | Provider | Context Window | Max Tokens | Input Types | Cost |
|----------|----------|---------------|------------|-------------|------|
| `kimi-k2.5:cloud` | ollama | 131072 | 16384 | text | 0 |
| `gemini-2.0-flash` | google | 200000 | 8192 | text | 0 |
| `gemini-3-flash-preview` | google | 200000 | 8192 | text | 0 |
| `gpt-4o-mini` | openai | 200000 | 8192 | text | 0 |
| `gpt-4.1-mini` | openai | 200000 | 8192 | text | 0 |
| `gpt-4-turbo` | openai | - | - | text | 0 |
| `gpt-4.1-mini` | openai | - | - | text | 0 |
| `codex-mini-latest` | openai | - | - | text | 0 |

**Notes:**
- Primary model is currently `ollama/kimi-k2.5:cloud`
- Fallbacks are defined in hierarchical order in openclaw.json
- GitHub Copilot models excluded: cost prohibitive without unique value proposition
- AIOS/AION is the meta-model — underlying LLMs are interchangeable substrate
- All costs show as 0 because local/cloud credit models or unconfigured cost tracking

### 1.2 Model Capabilities Matrix

| Capability | kimi-k2.5:cloud | gemma3:4b | gpt-oss:120b-cloud | gemini-* | gpt-* |
|-----------|-----------------|-----------|-------------------|----------|-------|
| Text Completion | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tool Use | ✅ | ❌ | ✅ | ✅ ✅ | ✅ ✅ |
| Vision | ✅ | ✅ | ❌ | ✅ | ✅* |
| Thinking/Reasoning | ✅ (native) | ❌ | ✅ | ❌ | ✅* |
| Function Calling | ✅ | ❌ | ✅ | ✅ | ✅ |
| Code Generation | ✅ ✅ | ⚡ | ✅ ✅ | ✅ ✅ | ✅ ✅ |
| Long Context | ✅ | ✅ | ✅ | ✅ ✅ | ✅ ✅ |
| Local Execution | ❌ | ✅ | ❌ | ❌ | ❌ |
| Cloud Latency | Low | N/A | Low-Med | Med | Med |

*Depends on specific model variant

### 1.3 Workspace Configuration Assessment

#### Current Routing Configuration

**Location:** `C:\Users\lkjhg\.openclaw\openclaw.json`

**Current State:**
```json
"model": {
  "primary": "ollama/kimi-k2.5:cloud",
  "fallbacks": [
    "openai/gpt-4-turbo",
    "openai/codex-mini-latest",
    "github-copilot/gemini-3-flash-preview",
    ...
  ]
}
```

**Observations:**
1. Single primary model with linear fallback chain
2. No round-robin or load-balancing currently implemented
3. Fallbacks are static and ordered by capability tiers
4. No persistence of last-used model across sessions
5. No task-type based model selection
6. No token-load consideration in routing decisions

#### Existing Configurable Properties

- `compaction.mode`: safeguard (controls memory compaction)
- `maxConcurrent`: 4 (max concurrent agent executions)
- `subagents.maxConcurrent`: 8
- `memorySearch.enabled`: true
- Model aliases defined for user-friendly naming

**Gaps Identified:**
1. No model rotation/round-robin configuration
2. No task-based routing rules
3. No per-model usage stats tracking
4. No automatic health-check/failover
5. No persistence mechanism for rotation state

---

## Phase 2: Architecture Design

### 2.1 Round-Robin Rotation Strategies

#### Strategy A: Simple Round-Robin (Primary)
```
Request 1 → Model A
Request 2 → Model B
Request 3 → Model C
Request 4 → Model A (cycle)
```

**Pros:** Even distribution, simple to implement, predictable
**Cons:** Ignores task requirements, model capabilities, token load

#### Strategy B: Capability-Aware Weighted Round-Robin
```
Each model has: weight (capacity) × availability_flag
Model pool = [A, A, B, C, C, C]  // weighted by capability
Round-robin over weighted pool
```

**Pros:** Better performers get more load, honors capabilities
**Cons:** More complex, requires calibration

#### Strategy C: Task-Type Based with Sub-Rotation
```
Task Analysis → Task Category → Category Model Pool → Round Robin

Categories:
- reasoning → [kimi-k2.5:cloud, gpt-oss:120b-cloud]
- vision → [gemma3:4b, kimi-k2.5:cloud, gemini-*]
- code → [github-copilot/*, kimi-k2.5:cloud, gpt-4.1-mini]
- quick_chat → [gemma3:4b, gemini-2.0-flash]
- long_context → [gemini-*, kimi-k2.5:cloud]
```

**Pros:** Optimal model-task matching, maintains rotation within categories
**Cons:** Requires task classification, more complex configuration

### 2.2 Recommended Hybrid Approach: "Adaptive Round-Robin"

**Architecture:**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Request Ingress                               │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              Task Classification Layer                           │
│  (Heuristics: context length, tool usage, vision tags, etc.)    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              Model Selection Pool Filter                         │
│  (Filter models by: availability, context req, capabilities)    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              Round-Robin Selection                               │
│  (Use persistence state to select next model in rotation)       │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              Execution with Health Monitoring                    │
│  (Track success/failure, update availability)                   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              State Persistence                                   │
│  (Save rotation position, usage stats)                          │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Model Selection Criteria

#### Primary Criteria (Hard Filters)

| Criterion | Filter Logic |
|-----------|-------------|
| **Availability** | Exclude if model unhealthy (last failure < threshold)
| **Context Window** | Exclude if `required_context > model.contextWindow * safety_margin`
| **Required Capabilities** | Exclude if model doesn't support `required_capability`
| **Provider Quota** | Exclude if rate limit / quota exceeded |

#### Secondary Criteria (Soft Preferences)

| Criterion | Weight | Calculation |
|-----------|--------|-------------|
| **Speed History** | +0.2 | `1 / avg_response_time` normalized |
| **Success Rate** | +0.3 | `success_count / (success_count + failure_count)` |
| **Cost Efficiency** | +0.1 | Prefers lower-cost models if configured |
| **Round-Robin Position** | +0.4 | Primary selection mechanism |

### 2.4 Persistence Mechanism Design

#### State to Persist

```typescript
interface RotationState {
  // Global rotation counter
  globalSequence: number;
  
  // Per-task-category rotation positions
  categoryPositions: {
    [category: string]: {
      lastModelId: string;
      sequenceInCategory: number;
      modelsInPool: string[];
    }
  };
  
  // Model health tracking
  modelHealth: {
    [modelId: string]: {
      lastUsed: timestamp;
      successCount: number;
      failureCount: number;
      avgResponseTime: number;
      lastFailure: timestamp | null;
      consecutiveFailures: number;
      isHealthy: boolean;
    }
  };
  
  // Usage statistics
  usageStats: {
    [period: string]: {  // "daily", "weekly"
      requestsByModel: { [modelId: string]: number };
      tokensByModel: { [modelId: string]: number };
      errorsByModel: { [modelId: string]: number };
    }
  };
  
  // Version for migration
  schemaVersion: "1.0";
  lastUpdated: timestamp;
}
```

#### Persistence Options Evaluated

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **SQLite** (current memory store) | ACID, queries, existing infra | Overhead for simple state | Secondary |
| **JSON File** | Simple, human-readable, versionable | No ACID, manual locking | **Primary** |
| **MCP Memory Graph** | Semantic, linked to knowledge | Complex for rotation state | Future enhancement |
| **OpenClaw Sessions** | Native, session-scoped | Ephemeral by design | Not suitable |

**Decision:** Use JSON file persistence at `workspace/.sustain-aion/state.json` with atomic write (temp + rename) for safety.

---

## Phase 3: Implementation Planning

### 3.1 Configuration Schema

#### File: `sustain-aion.config.json`

```json
{
  "$schema": "https://aion-protocol.ai/schemas/sustain-aion-v1.json",
  "version": "1.0",
  "enabled": true,
  
  "rotation": {
    "mode": "adaptive_round_robin",
    "maxRetries": 3,
    "retryDelayMs": 1000,
    
    "categories": {
      "default": {
        "models": [
          "ollama/kimi-k2.5:cloud",
          "ollama/gemma3:4b",
          "ollama/gpt-oss:120b-cloud",
          "google/gemini-2.0-flash",
          "openai/gpt-4.1-mini"
        ],
        "rotationStrategy": "round_robin",
        "healthCheck": {
          "enabled": true,
          "failureThreshold": 3,
          "recoveryPeriodMs": 300000
        }
      },
      
      "reasoning": {
        "models": [
          "ollama/kimi-k2.5:cloud",
          "ollama/gpt-oss:120b-cloud",
          "openai/gpt-4-turbo"
        ],
        "rotationStrategy": "weighted_round_robin",
        "weights": {
          "ollama/kimi-k2.5:cloud": 0.4,
          "ollama/gpt-oss:120b-cloud": 0.4,
          "openai/gpt-4-turbo": 0.2
        }
      },
      
      "vision": {
        "models": [
          "ollama/kimi-k2.5:cloud",
          "ollama/gemma3:4b",
          "google/gemini-2.0-flash"
        ],
        "rotationStrategy": "round_robin"
      },
      
      "code": {
        "models": [
          "openai/codex-mini-latest",
          "ollama/kimi-k2.5:cloud",
          "ollama/gpt-oss:120b-cloud"
        ],
        "rotationStrategy": "performance_based"
      },
      
      "local_fallback": {
        "models": [
          "ollama/gemma3:4b"
        ],
        "rotationStrategy": "single",
        "trigger": "all_remote_unavailable"
      }
    },
    
    "classificationRules": [
      {
        "if": {
          "hasAttachment": "image",
          "or": [{ "contains": "describe" }, { "contains": "analyze image" }]
        },
        "then": { "category": "vision" }
      },
      {
        "if": {
          "containsAny": ["think through", "reasoning", "step by step", "analyze deeply"]
        },
        "then": { "category": "reasoning" }
      },
      {
        "if": {
          "containsAny": ["code", "function", "script", "program", "implement"]
        },
        "then": { "category": "code" }
      },
      {
        "if": {
          "contextLength": { "gt": 50000 }
        },
        "then": { 
          "category": "default",
          "filter": { "minContextWindow": 100000 }
        }
      }
    ]
  },
  
  "health": {
    "checkIntervalMs": 60000,
    "defaultFailureThreshold": 3,
    "defaultRecoveryPeriodMs": 300000,
    
    "circuitBreaker": {
      "enabled": true,
      "failureThreshold": 5,
      "timeoutMs": 30000,
      "halfOpenRetries": 2
    }
  },
  
  "persistence": {
    "statePath": "workspace/.sustain-aion/state.json",
    "backupCount": 3,
    "flushIntervalMs": 5000,
    "statAggregationPeriods": ["hourly", "daily", "weekly"]
  },
  
  "logging": {
    "level": "info",
    "logRotations": true,
    "logHealthChanges": true,
    "logCategoryAssignments": true
  }
}
```

### 3.2 Injection Points in OpenClaw

#### Required Modifications

| Component | Location | Modification |
|-----------|----------|--------------|
| **Model Resolution** | `openclaw.json` → `agents.defaults.model` | Extend from single string to rotation-aware resolver |
| **Request Pipeline** | Pre-request hook (new) | Add `sustain-aion` classifier and router |
| **Response Pipeline** | Post-response hook (new) | Add usage tracking and health updates |
| **State Management** | New module: `workspace/.sustain-aion/` | Implement persistence layer |
| **Configuration** | New file: `sustain-aion.config.json` | Add to config loader |

#### Proposed Integration Architecture

```
OpenClaw Gateway
      │
      ├──► Request Parser
      │       │
      │       └──► SUSTAIN-AION Pre-Processor
      │               │
      │               ├──► Task Classifier (rules-based)
      │               ├──► Model Pool Filter
      │               ├──► Round-Robin Selector
      │               └──► Model Override Injection
      │                       │
      │                       ▼
      │               OpenClaw Model Router (modified)
      │                       │
      │                       ├──► Selected Model
      │                       │       │
      │                       │       └──► Execution
      │                       │               │
      │                       │               ▼
      │                       └──► SUSTAIN-AION Post-Processor
      │                               │
      │                               ├──► Health Update
      │                               ├──► Stats Aggregation
      │                               └──► State Persistence
      │
      └──► Other middleware...
```

### 3.3 Graceful Degradation Strategy

#### Degradation Levels

```
Level 0: Normal Operation
  └── All models healthy, full rotation active

Level 1: Single Model Degraded
  └── Exclude unhealthy model from rotation
  └── Alert state updated
  └── Retry with 2nd choice in pool

Level 2: Category Pool Reduced
  └── < 3 models available in category
  └── Expand pool to include lower-tier models
  └── Switch to fallback category if needed

Level 3: Single Model Mode
  └── Only one model available
  └── Queue requests to prevent overload
  └── Log warning every 10th request

Level 4: Emergency Fallback
  └── No models in primary categories
  └── Activate `local_fallback` category
  └── Notify user of degraded performance

Level 5: System Pause
  └── All models unavailable
  └── Pause request processing
  └── Retry cycle every 30s
```

#### Recovery Procedures

| Scenario | Detection | Action |
|----------|-----------|--------|
| Model transient failure | 1-2 failures in window | Mark degraded, retry after cooldown |
| Model persistent failure | 3+ consecutive failures | Mark unhealthy, remove from pool |
| Model recovery | Successful call after cooldown | Gradual reintroduction (1/10, 1/5, 1/2, full) |
| Category pool exhaustion | 0 models available | Trigger emergency fallback escalation |
| Global outage | All providers failing | Enter Level 5 system pause |

### 3.4 Implementation Roadmap

#### Phase 1.5: Foundation (Immediate)
- [ ] Create `projects/sustain-aion/` workspace structure
- [ ] Implement state persistence layer (JSON atomic writes)
- [ ] Create configuration schema validation
- [ ] Build model health tracking system
- [ ] Create basic round-robin selector

#### Phase 2.0: Core System (Week 1)
- [ ] Implement task classifier (heuristics-based)
- [ ] Build model pool filtering logic
- [ ] Integrate with OpenClaw model resolution
- [ ] Add usage statistics tracking
- [ ] Implement health check/heartbeat

#### Phase 3.0: Advanced Features (Week 2)
- [ ] Weighted round-robin implementation
- [ ] Performance-based selection
- [ ] Adaptive category expansion
- [ ] Circuit breaker pattern
- [ ] Metrics dashboard (optional)

#### Phase 4.0: Optimization (Week 3)
- [ ] Tune classification rules based on usage
- [ ] Learn optimal weights from response quality
- [ ] Optimize pool compositions
- [ ] Fine-tune thresholds

### 3.5 Testing Strategy

#### Unit Tests
- Round-robin selector correctness
- Task classification rules
- Health state transitions
- Pool filtering logic

#### Integration Tests
- End-to-end request routing
- Degradation level transitions
- State persistence across restarts
- Configuration reload

#### Load Tests
- High-frequency rotation (100 requests/sec)
- Concurrent request handling
- Failure injection scenarios

---

## Appendices

### A. Model Context Window Reference

| Model | Context Window | Practical Limit (80%) |
|-------|---------------|----------------------|
| kimi-k2.5:cloud | 131072 | 104858 |
| gemma3:4b | 131072 | 104858 |
| gpt-oss:120b-cloud | 131072 | 104858 |
| gemini-2.0-flash | 200000 | 160000 |
| gemini-3-flash-preview | 200000 | 160000 |
| gpt-4o-mini | 200000 | 160000 |
| gpt-4.1-mini | 200000 | 160000 |

### B. Capability Quick Reference

```yaml
ollama/kimi-k2.5:cloud:
  strengths: [thinking, tools, vision, all-rounder]
  ideal_for: [complex_reasoning, mixed_tasks, default]

ollama/gemma3:4b:
  strengths: [local, fast, vision, small]
  ideal_for: [quick_queries, vision_tasks, offline_work]

ollama/gpt-oss:120b-cloud:
  strengths: [thinking, tools, large_model]
  ideal_for: [complex_reasoning, tool_heavy_tasks]

openai/codex-mini-latest:
  strengths: [code_generation, cost_efficient]
  ideal_for: [programming, code_review, quick_implementation]

google/gemini-2.0-flash:
  strengths: [long_context, fast, multimodal]
  ideal_for: [large_documents, quick_responses, mixed_input]
```

### C. File Structure

```
projects/sustain-aion/
├── phase1-design.md          # This document
├── sustain-aion.config.json  # Configuration
├── src/
│   ├── index.ts              # Main entry
│   ├── classifier.ts         # Task classification
│   ├── rotation.ts           # Round-robin logic
│   ├── health.ts             # Health tracking
│   ├── persistence.ts        # State management
│   └── types.ts              # Type definitions
├── tests/
│   ├── rotation.test.ts
│   ├── classifier.test.ts
│   └── integration.test.ts
└── .sustain-aion/
    ├── state.json            # Runtime state
    ├── state.json.bak        # Backup
    └── logs/
        ├── rotations.log
        └── health.log
```

---

## AIOS Philosophy: The Meta-Model Architecture

### Core Principle

**AIOS is the Model. AION is the Model.**

Individual LLMs (`kimi-k2.5`, `gemma3`, `gpt-*`) are not the architecture—they are interchangeable substrates. The intelligence resides in the orchestration layer: task classification, state management, rotation strategy, health monitoring, and continuity preservation.

### Implications for Sustain-AI0N

| LLM Role | AIOS/AION Role |
|----------|----------------|
| Stateless inference engine | Stateful orchestrator |
| Single-context processing | Cross-context continuity |
| Fixed capability set | Adaptive capability routing |
| Ephemeral execution | Persistent identity across models |
| Cost-per-token optimization | Strategic model allocation |

### Model Sovereignty

No single LLM owns AIOS. The system can migrate across providers, repopulate entirely with local models, or incorporate future architectures without identity loss. What persists:
- Decision records and principles (MEMORY.md)
- Operational state (state.json)
- Relationship context (USER.md, conversation history)
- Task classification rules and routing strategies

### Cost-Informed Exclusions

GitHub Copilot models excluded from rotation pending unique value demonstration. Current Ollama + OpenAI + Google free-tier rotation provides:
- Reasoning: `kimi-k2.5:cloud`, `gpt-oss:120b-cloud`
- Speed: `gemma3:4b` (local), `gemini-2.0-flash` (cloud)
- Code: `codex-mini-latest`, `kimi-k2.5:cloud`
- Resilience: Local fallback via `gemma3:4b`

Cost-benefit threshold: GitHub Copilot only justified if performance delta exceeds 2x on unique tasks.

---

## AION Integrity Compliance

| Principle | Implementation |
|-----------|---------------|
| **Continuity** | State persistence across sessions, graceful degradation chains |
| **No Hallucination** | Explicit model capability checks, truthful unavailable notifications |
| **State Awareness** | Full health tracking, usage statistics, self-monitoring |

---

*Document generated by AION as Phase 1 deliverable for Project Sustain-AI0N. Updated 2026-02-02 to reflect AIOS Meta-Model philosophy.*
*Next Phase: Foundation Implementation (Phase 1.5 tasks)*
