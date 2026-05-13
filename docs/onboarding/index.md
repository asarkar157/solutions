---
layout: page
title: Onboarding
nav_order: 4
---

# Onboarding

For **solutions engineers** wiring StackGen with Terraform or OpenTofu. Pick **one step at a time** — each page is short, you can stop and come back later.

> **If you only have 30 minutes and a prospect on Zoom**, you do not need onboarding. Skip to the [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) and run `make demo SCENARIO=<name>`. Come back to these pages when you want to compose your own root or change a module.

| Step | What you will do | Time (approx.) |
|------|-------------------|----------------|
| [1 — Orientation]({% include doc_url.html path="onboarding/01-orientation.md" %}) | Understand what this repo is and the three SE jobs it serves. | ~3 min |
| [2 — Your machine]({% include doc_url.html path="onboarding/02-your-machine.md" %}) | Install Terraform (and optionally OPA), clone the repo. | ~10 min |
| [3 — Run checks]({% include doc_url.html path="onboarding/03-run-checks.md" %}) | Format checks, policy checks, optional **`tofu validate`** (or `terraform validate`). | ~10 min |
| [4 — Use a module]({% include doc_url.html path="onboarding/04-use-a-module.md" %}) | Point Terraform at a module `source` and plan a minimal stack. | ~15 min |
| [5 — Go deeper]({% include doc_url.html path="onboarding/05-go-deeper.md" %}) | CI, registry tokens, full example, architecture — when you need them. | reference |

[**Begin with step 1 →**]({% include doc_url.html path="onboarding/01-orientation.md" %})
