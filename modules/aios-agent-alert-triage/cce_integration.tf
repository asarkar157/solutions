# CCE incident scoping — evidence-first RCA (file:line call site proof).

locals {
  sop_cce_incident_scope  = "cce-incident-scoping${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"

  provision_ubuntu_cce = var.enable_cce && trimspace(var.existing_ubuntu_integration_name) == "" && (
    trimspace(var.github_token) != "" || trimspace(var.github_secret_id) != "" || trimspace(var.existing_github_integration_name) != ""
  )

  resolved_ubuntu_integration_name = trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : (
    local.provision_ubuntu_cce ? module.ubuntu_integration_cce[0].integration_name : ""
  )

  cce_stages_enabled = var.enable_cce && trimspace(local.resolved_ubuntu_integration_name) != ""
}

module "cce_scripts" {
  count  = var.enable_cce ? 1 : 0
  source = "../aios-cce-scripts"
}

module "ubuntu_integration_cce" {
  count  = local.provision_ubuntu_cce ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id])
  install_tools    = ["gh", "git", "curl", "jq", "cce"]
  env_vars = {
    CCE_PACK_VERSION = module.cce_scripts[0].cce_pack_version
    CCE_PACK_DIR     = module.cce_scripts[0].cce_pack_dir
    CCE_PACK_B64     = module.cce_scripts[0].cce_pack_tarball_b64
    CCE_USE_CASE     = "incident-scoping"
  }
}

resource "sg_runbook_sop" "cce_incident_scoping" {
  count       = var.enable_cce ? 1 : 0
  name        = local.sop_cce_incident_scope
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cce-incident-scoping.md.tftpl", local.investigation_template_vars))
}
