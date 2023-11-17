locals {
  admin_apis = [
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
  ]

  kms_keys = [
    "tfstate-key",
    "secrets-key",
    "talos-disk-key",
  ]
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

resource "google_kms_key_ring" "keyring" {
  name     = "homelab-keyring"
  location = "us-central1"
  project  = split("/", google_project.admin.id)[1]
}

resource "google_kms_crypto_key" "keys" {
  for_each        = toset(local.kms_keys)
  name            = each.value
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
    default_kms_key_name = google_kms_crypto_key.keys["tfstate-key"].id
  }

  public_access_prevention = "enforced"
}
