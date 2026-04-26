---
layout: page
title: "3 — Run checks"
permalink: step-3/
nav_order: 12
parent: Onboarding
---

# Step 3 — Run checks

Run these from the **repository root** (where the `Makefile` lives).

## 1. No registry token required

These use only the files in your clone:

```bash
make fmt-check      # Terraform formatting (must match CI)
make opa-fmt-check  # Rego formatting (needs opa on PATH)
make opa-check      # Rego parse / check per policy file (needs opa)
```

If `opa` is not installed, skip the `opa-*` targets until you need them.

To auto-fix Terraform format:

```bash
make fmt
```

## 2. Terraform validate (optional here)

`make validate` runs **`tofu init`** and **`tofu validate`** in each module and example when OpenTofu is installed; otherwise it uses **`terraform`** (same flags). That requires:

- **Network** access to download providers.
- A **token** or other credentials for **`releases.stackgen.com`** if your network or registry policy requires them (see the repository README).

Set the environment variable (works for **OpenTofu and Terraform**):

```bash
export TF_TOKEN_releases_stackgen_com="<your-token>"
make validate
```

Details and alternatives (for example `~/.terraformrc` / OpenTofu CLI config) are in the repository [README — Local verification]({{ site.github.repository_url }}/blob/main/README.md#local-verification).

## 3. One-shot “like CI”

```bash
make check
```

This runs format checks, OPA checks, and `validate`. If `validate` fails on provider download, configure registry credentials as in the README.

## 4. Clean up after experiments

```bash
make clean
```

Removes `.terraform` directories under `modules/` and `examples/` from local `init` runs.

---

**Next:** [Step 4 — Use a module]({% link onboarding/04-use-a-module.md %})  
**Previous:** [Step 2 — Your machine]({% link onboarding/02-your-machine.md %})
