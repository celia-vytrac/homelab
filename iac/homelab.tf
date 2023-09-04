locals {
  homelab_apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}

resource "google_project" "homelab" {
  name       = "Homelab"
  project_id = "homelab-${random_string.random[1].result}"
  org_id     = data.google_organization.vytrac_me.org_id

  billing_account = data.google_billing_account.billing.id
}

resource "google_project_service" "homelab_services" {
  for_each = toset(local.homelab_apis)
  project  = google_project.homelab.number
  service  = each.key
}
