---
layout: default
title: Module Catalog
nav_order: 2
permalink: module-catalog/
---

<link rel="stylesheet" href="{{ '/assets/css/module-catalog.css' | relative_url }}?v={{ site.time | date: '%s' }}">

<div id="catalog-app">

  <div class="catalog-hero">
    <h1>Module Catalog</h1>
    <p class="catalog-subtitle">Discover, explore, and compose production-ready Terraform modules for AI Operations. Filter by tag, copy the source URL, and wire modules into your IaC root.</p>
  </div>

  <div class="catalog-se-strip" markdown="1">

  > **Solutions engineer?** You probably want a **runnable scenario**, not a single module. Each scenario below is one Terraform root under [`examples/scenarios/`]({{ site.github.repository_url }}/tree/main/examples/scenarios) that finishes inside a 30-minute call.
  >
  > | Prospect asked… | Run | Modules wired |
  > |-----------------|-----|---------------|
  > | "Fix an AWS incident in front of me." | `make demo SCENARIO=aws-sre-demo` | foundation, policies, integration-aws, agent-aws-sre, integration-slack |
  > | "Show me FinOps." | `make demo SCENARIO=finops-weekly` | foundation, policies, integration-aws, agent-cost-optimizer, agent-resource-janitor, agent-schedules, integration-slack |
  > | "What does your CI insight look like?" | `make demo SCENARIO=pipeline-insights` | foundation, policies, integration-github, agent-pipeline-insights, agent-release-tracker, integration-slack |
  > | "Triage 200 Grafana alerts a day." | `make demo SCENARIO=incident-triage` | foundation, policies, integration-grafana, integration-slack, agent-sre, agent-alert-triage |
  > | "Take a legacy repo and make IaC." | `make demo SCENARIO=repo-to-iac` | foundation, policies, integration-github, agent-repo-to-iac |
  > | "How do we split this monolith into microservices?" | `make demo SCENARIO=monorepo-services-split` | foundation, policies, integration-github, integration-ubuntu, agent-monorepo-services-splitter (CCE-enhanced boundary scan); pair with **db-state-splitter** for IaC |
  > | "Block IAM surprises at PR time." | `make demo SCENARIO=pre-deploy-iam-gate` | foundation, policies, integration-github, agent-terraform-bot (CCE IAM gate) |
  > | "Scope incidents to services that call the API." | `make demo SCENARIO=incident-triage` | foundation, policies, integration-grafana, integration-github, agent-alert-triage (CCE incident-scoping) |
  > | "Generate compliance evidence on a schedule." | `make demo SCENARIO=compliance-evidence-factory` | foundation, policies, integration-github, agent-compliance-auditor |
  > | "GitOps rollback without nuking the cluster." | `make demo SCENARIO=gitops-incident-scope` | foundation, policies, agent-privatesaas-gitops-sre (GitLab/Argo/AWS/Slack secrets) |
  > | "Fix reachable CVEs only." | `make demo SCENARIO=cve-reachability-fix` | foundation, policies, integration-github, agent-supply-chain-security |
  > | "Self-service infra with entitlement-sized IAM." | `make demo SCENARIO=agentic-infra-entitlements` | agentic-infrastructure + repo-to-iac CCE |
  > | "We want Claude on AWS Bedrock." | `make demo SCENARIO=bedrock-sonnet-demo` | foundation-bedrock, policies, integration-aws, agent-aws-sre |
  > | "Intent → CloudFormation PR + drift management." | `make demo SCENARIO=cfn-author` | foundation-bedrock, policies, github, aws, agent-cfn-author |
  > | "Wipe to a clean baseline." | `make demo SCENARIO=clean-tenant-reset` | foundation, policies |
  >
  > Then browse the modules below if you want to compose your own root. The full prospect-question map lives in the [SE Playbook]({% include doc_url.html path="se-playbook.md" %}). For **deployment-profile** use cases (Azure SaaS, PrivateSaaS, multi-tenant RCA, self-hosted infra), see the [Use-case catalog]({% include doc_url.html path="use-case-catalog.md" %}).

  </div>

  <!-- Search + Filter Bar -->
  <div class="catalog-toolbar">
    <div class="catalog-search">
      <svg class="search-icon" aria-hidden="true" viewBox="0 0 20 20" fill="currentColor" width="18" height="18"><path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd"/></svg>
      <input type="text" id="module-search" aria-label="Search modules" placeholder="Search modules…" autocomplete="off">
    </div>
    <div class="tag-typeahead">
      <div class="tag-input-container">
        <input type="text" id="tag-input" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="tag-dropdown" aria-label="Filter by tags" placeholder="Filter by tags (e.g. aws, sre)…" autocomplete="off">
        <div id="tag-dropdown" role="listbox" aria-label="Suggested tags" class="tag-dropdown hidden"></div>
      </div>
      <div class="active-tags" id="active-tags" aria-live="polite"></div>
    </div>
  </div>

  <!-- Layer sections -->
  <div id="layer-0" class="catalog-layer">
    <div class="layer-header"><span class="layer-badge l0">Layer 0</span> Foundation</div>
    <div class="module-grid" id="grid-layer-0"></div>
  </div>
  <div id="layer-1" class="catalog-layer">
    <div class="layer-header"><span class="layer-badge l1">Layer 1</span> Integrations</div>
    <div class="module-grid" id="grid-layer-1"></div>
  </div>
  <div id="layer-2" class="catalog-layer">
    <div class="layer-header"><span class="layer-badge l2">Layer 2</span> Agents</div>
    <div class="module-grid" id="grid-layer-2"></div>
  </div>

  <div id="no-results" class="no-results" style="display:none">
    <p>No modules match your filters. Try removing a tag or clearing the search.</p>
  </div>

</div>

<script>
  window.__MODULES_JSON_URL__ = "{{ '/assets/data/modules.json' | relative_url }}?v={{ site.time | date: '%s' }}";
</script>
<script src="{{ '/assets/js/module-data.js' | relative_url }}?v={{ site.time | date: '%s' }}"></script>
<script src="{{ '/assets/js/module-catalog.js' | relative_url }}?v={{ site.time | date: '%s' }}"></script>
