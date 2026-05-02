terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.4, < 0.2.0" }
  }
}

# =============================================================================
# GCP Integration Module
# =============================================================================
# Provisions a Vault secret with GCP service account credentials and a
# containerized GCP MCP integration (gcloud CLI + kubectl).

resource "sg_secret" "gcp_vault" {
  name        = "${var.name_prefix}gcp-vault"
  description = "GCP service account credentials for cloud SRE operations"
  category    = "CloudProvider"
  subcategory = "gcp"
  metadata = {
    GOOGLE_APPLICATION_CREDENTIALS_JSON = var.gcp_credentials_json
    GCP_PROJECT_ID                      = var.gcp_project_id
    GCP_REGION                          = var.gcp_region
  }
}

resource "sg_guild_integration" "gcp" {
  name           = var.integration_name
  description    = "GCP cloud integration for GKE, Cloud SQL, IAM, and resource management via gcloud CLI."
  type           = "gcp"
  scope          = "PROJECT"
  secret_ref_ids = [sg_secret.gcp_vault.id]
  enabled        = true

  image = { name = var.integration_image }
}
