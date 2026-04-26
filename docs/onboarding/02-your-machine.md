---
layout: page
title: "2 — Your machine"
permalink: step-2/
nav_order: 11
parent: Onboarding
---

# Step 2 — Your machine

## 1. Install OpenTofu (preferred) or Terraform

This repository **prefers [OpenTofu](https://opentofu.org/)**. Install a **1.5+** CLI; CI uses the version in [`.opentofu-version`]({{ site.github.repository_url }}/blob/main/.opentofu-version) (see [workflow]({{ site.github.repository_url }}/blob/main/.github/workflows/ci.yml)).

- **OpenTofu:** [Installation](https://opentofu.org/docs/intro/install/)
- **HashiCorp Terraform (interchangeable):** [Install Terraform](https://developer.hashicorp.com/terraform/install)

Check one or both:

```bash
tofu version
terraform version
```

## 2. (Optional) Install OPA

Only needed if you will edit **`.rego`** policy files or run `make opa-*`.

- [OPA releases](https://github.com/open-policy-agent/opa/releases) — use a recent static binary; CI pins a specific version in the workflow file.

```bash
opa version
```

## 3. Clone the repository

```bash
git clone {{ site.github.repository_url }}.git
cd solutions   # or your checkout folder name
```

If your clone directory is not `solutions`, use that name in the commands below.

## 4. See available commands

This repo includes a **`Makefile`** wrapper around formatting, OPA checks, and Terraform validation.

```bash
make help
```

You should see targets such as `fmt`, `fmt-check`, `opa-check`, `validate`, and `check`.

---

**Next:** [Step 3 — Run checks]({% link onboarding/03-run-checks.md %})  
**Previous:** [Step 1 — Orientation]({% link onboarding/01-orientation.md %})
