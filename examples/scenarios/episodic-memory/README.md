# Scenario: `episodic-memory`

## Pitch (read this on the call)

> "Agents can remember lessons across sessions — but only when they choose to search. Guild stores episodic memories in a vector database; it does not silently inject them into every new chat. Let me show you store in one session, then recall in a fresh thread — and you will see the `memory_search` tool call in the trace."

## What this scenario wires

- `aios-foundation` — LLM secrets + models
- `aios-policies` — `dangerous_ops` guardrail on the tutor agent
- Inline `sg_agent` **`memory-tutor`** — `knowledge.memory_enabled = true`, no integrations

**Prerequisite:** the Guild tenant must have **Qdrant (or configured vector store) + embeddings** running. This scenario does not provision vector infrastructure.

## Run

```bash
make demo SCENARIO=episodic-memory
```

After apply:

```bash
cd examples/scenarios/episodic-memory
tofu output next_steps
tofu output -json demo_prompts | jq .
```

## Talk track (5 bullets, ~5 minutes)

1. **Open Guild → agent `memory-tutor`.** "This is the smallest possible memory demo — no Grafana, no AWS, just vector episodic memory."
2. **Act 1 — store.** Paste the Act 1 prompt from `tofu output demo_prompts`. Watch the trace for **`memory_store`** in namespace `agent:memory-tutor`.
3. **Memory Explorer.** Open `/memories`, filter namespace `agent:memory-tutor` and type `episodic`. "This is what operators audit — browse and delete, not auto-injected into chat."
4. **Act 2 — recall (new chat thread).** Start a **new** conversation. Paste Act 2 prompt. Watch **`memory_search`** then an answer grounded in the stored lesson.
5. **Close on the gotcha.** "If we skip Act 1, search returns empty — memory is pull-based, not magic. Production incident memory uses `shared:incidents`; see the `incident-triage` scenario."

## Two-act demo prompts

**Act 1 — store (session A):**

> Remember this operational lesson for future incidents: On 2026-06-01, `payments-api` in `checkout` OOM'd because node pool `checkout-np-2` ran out of memory during a traffic spike. Fix: raise container memory limit and add nodes to the pool. Store it in episodic memory with fingerprint `payments-api:checkout:oom`.

**Act 2 — recall (session B, new chat):**

> Before answering: search episodic memory for anything about `payments-api` memory or OOM in `checkout`. Then summarize what we learned last time.

## Optional bootstrap (skip Act 1 live)

```bash
cd scripts
export GUILD_URL=... STACKGEN_TOKEN=... GUILD_PROJECT_ID=...
./seed-memory.sh
```

Seeds two curated lessons from [`scripts/data/lessons.jsonl`](./scripts/data/lessons.jsonl) via the agent chat API.

## Verification checklist

- [ ] Act 1 trace shows `memory_store`
- [ ] Memory Explorer shows point in `agent:memory-tutor` with `type=episodic`
- [ ] Act 2 in a **new thread** shows `memory_search` and cites the lesson
- [ ] Act 2 without prior store/bootstrap returns empty search (expected gotcha)

## Property glossary

| Property / knob | Where set | What it does | Demo value |
|-----------------|-----------|--------------|------------|
| `knowledge.memory_enabled` | `sg_agent` in `main.tf` | Enables `memory_store`, `memory_search`, `memory_delete`, `memory_list`, `memory_merge`. Also enables Genie post-run episode storage (`type: episode`) but **not** automatic cross-session recall. | `true` |
| `knowledge.graph_enabled` | `sg_agent` | Enables `graph_store` / `graph_query` (knowledge graph — separate from episodic vectors). | omitted (`false`) |
| `memory_store` → `namespace` | tool arg at runtime | Logical bucket for vectors. Each agent gets a private namespace automatically. | `agent:memory-tutor` |
| `memory_store` → metadata `type` | tool / document metadata | `episodic` = readable by nightly diary job; `episode` = Genie auto-writes after runs; absent = "untyped" in Memory Explorer. | `episodic` |
| `memory_store` → metadata `fingerprint` | tool / document metadata | Stable key for operators and search bias (convention, not enforced by platform). | `payments-api:checkout:oom` |
| `memory_search` → `top_k`, `score_threshold` | tool args | Max hits and minimum similarity score. | `5`, `0.3` |
| Genie `WithRelevantPastContext` | Guild platform default | Would auto-inject "## Relevant Past Episodes" into the prompt — **disabled** in Guild. | not configurable per agent today |
| Qdrant / embeddings | Guild deploy config | Backend for all vector memories. Scenario assumes tenant already has this. | prerequisite |

Guild maps `memory_enabled` to orchestrator options in [stackgen-guild `memory_options.go`](https://github.com/appcd-dev/stackgen-guild/blob/main/internal/guild/agentbuilder/memory_options.go): tools on, storage on, **auto-recall off**.

## Gotchas

1. **Stored ≠ visible** — `memory_enabled` may write Genie `episode` vectors after runs, but Guild disables automatic cross-session recall. The agent must call `memory_search` for prior lessons to appear in context.
2. **`memory_enabled` without persona guidance** — tools exist in the registry but the LLM may skip search. This scenario's persona mandates search-before-recall.
3. **`type: episode` vs `type: episodic`** — Genie auto-writes `episode`; the nightly diary scrolls only `episodic`. The demo persona sets `type: episodic` explicitly on curated stores.
4. **Empty search on first run** — expected until Act 1 or `seed-memory.sh`.
5. **New chat thread for Act 2** — proves cross-session recall is tool-driven, not the same conversation history buffer.
6. **Memory Explorer ≠ session injection** — browsing `/memories` does not put content into the agent prompt.
7. **No promote-to-runbook UI** — Memory Explorer is browse/delete only. See [`docs/incident-triage-poc-limits.md`](../../docs/incident-triage-poc-limits.md).
8. **Production shared memory** — cross-agent incident reuse uses namespace `shared:incidents` and workflow stages. Use [`incident-triage`](../incident-triage/) for that pattern; this scenario uses private `agent:memory-tutor` only.

## Reset for the next prospect

```bash
make demo-reset SCENARIO=episodic-memory
```

Delete seeded memories in Memory Explorer if you ran Act 1 or `seed-memory.sh` against a shared tenant.

## Related

- Full incident memory + eval: [`incident-triage`](../incident-triage/)
- Honest limits: [`docs/incident-triage-poc-limits.md`](../../docs/incident-triage-poc-limits.md)
- Knowledge architecture: [stackgen-guild `docs/knowledge-architecture.md`](https://github.com/appcd-dev/stackgen-guild/blob/main/docs/knowledge-architecture.md)
