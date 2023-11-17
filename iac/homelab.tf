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

resource "google_compute_resource_policy" "daily" {
  name    = "daily-backup"
  project = google_project.homelab.number
  region  = "us-central1"
  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "04:00"
      }
    }
  }
}

resource "google_compute_network" "homelab" {
  name                    = "homelab"
  auto_create_subnetworks = "false"
}

resource "google_compute_firewall" "homelab" {
  name    = "homelab-allow-internal"
  network = google_compute_network.homelab.id
  allow {
    protocol = "all"
  }
  source_tags = ["k8s"]
  target_tags = ["k8s"]
}
