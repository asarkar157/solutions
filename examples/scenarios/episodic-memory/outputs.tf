locals {
  act1_store_prompt = trimspace(<<-EOT
    Remember this operational lesson for future incidents: On 2026-06-01, payments-api in checkout OOM'd because node pool checkout-np-2 ran out of memory during a traffic spike. Fix: raise container memory limit and add nodes to the pool. Store it in episodic memory with fingerprint payments-api:checkout:oom.
  EOT
  )

  act2_recall_prompt = trimspace(<<-EOT
    Before answering: search episodic memory for anything about payments-api memory or OOM in checkout. Then summarize what we learned last time.
  EOT
  )
}

output "agent_name" {
  description = "Memory tutor agent registered by this scenario."
  value       = sg_agent.memory_tutor.name
}

output "memory_namespace" {
  description = "Private vector namespace for this agent's episodic memories."
  value       = "agent:${sg_agent.memory_tutor.name}"
}

output "demo_prompts" {
  description = "Copy-paste prompts for the two-act episodic memory demo."
  value = {
    act1_store  = local.act1_store_prompt
    act2_recall = local.act2_recall_prompt
  }
}

output "next_steps" {
  description = "Copy-paste checklist to open Guild and run the demo."
  value       = <<-EOT

    Episodic memory demo ready.

    Prerequisites: Guild tenant must have Qdrant + embeddings configured (vector store).

    Act 1 — store (session A):
      1. Open Guild: ${var.stackgen_url}
      2. Chat with agent: ${sg_agent.memory_tutor.name}
      3. Paste Act 1 prompt (see: tofu output -json demo_prompts)
      4. Watch trace: memory_store tool call → confirmation with point id

    Act 2 — recall (session B, new chat thread):
      1. Start a new chat with ${sg_agent.memory_tutor.name}
      2. Paste Act 2 prompt (see: tofu output -json demo_prompts)
      3. Watch trace: memory_search → answer cites stored lesson

    Optional fast path (skip Act 1 live):
      cd examples/scenarios/episodic-memory/scripts
      GUILD_URL=... STACKGEN_TOKEN=... GUILD_PROJECT_ID=... ./seed-memory.sh

    Verify in Memory Explorer: filter namespace agent:${sg_agent.memory_tutor.name}, type episodic.

    Full glossary and gotchas: ./README.md

  EOT
}
