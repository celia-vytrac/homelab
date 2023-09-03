resource "random_string" "random" {
  count       = 3
  length      = 6
  min_numeric = 6
}

resource "google_project" "admin" {
  name       = "Admin"
  project_id = "admin-${random_string.random[0].result}"
  org_id     = data.google_organization.vytrac_me.org_id

  billing_account = data.google_billing_account.billing.id
}

resource "google_project_service" "admin_services" {
  for_each = toset(local.admin_apis)
  project  = google_project.admin.number
  service  = each.key
}

resource "google_project" "homelab_dev" {
  name       = "Homelab Dev"
  project_id = "homelab-dev-${random_string.random[1].result}"
  org_id     = data.google_organization.vytrac_me.org_id

  billing_account = data.google_billing_account.billing.id
}

resource "google_project" "homelab_prod" {
  name       = "Homelab Prod"
  project_id = "homelab-prod-${random_string.random[2].result}"
  org_id     = data.google_organization.vytrac_me.org_id

  billing_account = data.google_billing_account.billing.id
}

resource "google_kms_key_ring" "keyring" {
  name     = "homelab-keyring"
  location = "us-central1"
  project  = split("/", google_project.admin.id)[1]
}

resource "google_kms_crypto_key" "tfstate_key" {
  name            = "tfstate-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = "2592000s" // 30 days

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "secrets_key" {
  name            = "secrets-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = "2592000s" // 30 days

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket" "gcs_bucket" {
  name     = "tfstate.vytrac.me"
  location = "us-central1"
  project  = google_project.admin.number

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.tfstate_key.id
  }

  public_access_prevention = "enforced"
}
