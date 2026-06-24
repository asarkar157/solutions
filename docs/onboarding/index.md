---
layout: page
title: Onboarding
nav_order: 4
---

# Onboarding

For **solutions engineers** composing StackGen modules in Terraform or OpenTofu. This is the **compose-path deep dive** — if you are not sure which path to take, start at [Adopt the repo]({% include doc_url.html path="adopt.md" %}).

> **If you only have 30 minutes and a prospect on Zoom**, skip onboarding. Go to the [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) and run `make demo SCENARIO=<name>`.

| Step | What you will do | Time (approx.) |
|------|-------------------|----------------|
| [1 — Orientation]({% include doc_url.html path="onboarding/01-orientation.md" %}) | Understand what this repo is and the three SE jobs it serves. | ~3 min |
| [2 — Your machine]({% include doc_url.html path="onboarding/02-your-machine.md" %}) | Install Terraform (and optionally OPA), clone the repo. | ~10 min |
| [3 — Run checks]({% include doc_url.html path="onboarding/03-run-checks.md" %}) | Format checks, policy checks, optional **`tofu validate`** (or `terraform validate`). | ~10 min |
| [4 — Use a module]({% include doc_url.html path="onboarding/04-use-a-module.md" %}) | Point Terraform at a module `source` and plan a minimal stack. | ~15 min |
| [5 — Go deeper]({% include doc_url.html path="onboarding/05-go-deeper.md" %}) | CI, registry tokens, full example, architecture — when you need them. | reference |

[**Begin with step 1 →**]({% include doc_url.html path="onboarding/01-orientation.md" %})
