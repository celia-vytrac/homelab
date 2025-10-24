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
}

resource "random_string" "random" {
  length      = 6
  min_numeric = 6
}

resource "google_project" "admin" {
  name       = "Admin"
  project_id = "admin-${random_string.random.result}"
  org_id     = data.google_organization.vytrac_me.org_id

  billing_account = data.google_billing_account.billing.id
}

resource "google_project_service" "admin_services" {
  for_each = toset(local.admin_apis)
  project  = google_project.admin.number
  service  = each.key
}

resource "google_storage_bucket" "tfstate" {
  name     = "tfstate.${local.zone_name}"
  location = "us-central1"
  project  = google_project.admin.number

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}

moved {
  from = google_storage_bucket.gcs_bucket
  to   = google_storage_bucket.tfstate
}
