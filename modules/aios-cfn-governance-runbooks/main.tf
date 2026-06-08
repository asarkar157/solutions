terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

locals {
  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  sop_remote_orchestration_name  = "cfn-gov-remote-orchestration${local.suffix}"
  sop_contextual_compliance_name = "cfn-gov-contextual-compliance${local.suffix}"
  sop_hardened_synthesis_name    = "cfn-gov-hardened-synthesis${local.suffix}"
  sop_governed_deployment_name   = "cfn-gov-governed-deployment${local.suffix}"
  sop_continuous_governance_name = "cfn-gov-continuous-governance${local.suffix}"

  template_vars = {
    org_baseline_name         = var.org_baseline_name
    fedramp_profile           = var.fedramp_profile
    knowledge_base_path       = var.knowledge_base_path
    deployment_process_doc    = var.deployment_process_doc
    cfn_template_catalog_path = var.cfn_template_catalog_path
  }
}

resource "sg_runbook_sop" "remote_orchestration" {
  name        = local.sop_remote_orchestration_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-remote-orchestration.md.tftpl", local.template_vars))
}

resource "sg_runbook_sop" "contextual_compliance" {
  name        = local.sop_contextual_compliance_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-contextual-compliance.md.tftpl", local.template_vars))
}

resource "sg_runbook_sop" "hardened_synthesis" {
  name        = local.sop_hardened_synthesis_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-hardened-synthesis.md.tftpl", local.template_vars))
}

resource "sg_runbook_sop" "governed_deployment" {
  name        = local.sop_governed_deployment_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-governed-deployment.md.tftpl", local.template_vars))
}

resource "sg_runbook_sop" "continuous_governance" {
  name        = local.sop_continuous_governance_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-continuous-governance.md.tftpl", local.template_vars))
}
