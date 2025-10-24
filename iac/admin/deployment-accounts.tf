resource "google_service_account" "admin_infra_a" {
  project      = google_project.admin.project_id
  account_id   = "srv-tf-admin-infra-a"
  display_name = "Terraform Admin Infra A"
}

resource "google_service_account" "admin_infra_b" {
  project      = google_project.admin.project_id
  account_id   = "srv-tf-admin-infra-b"
  display_name = "Terraform Admin Infra B"
}

resource "google_service_account_iam_member" "admin_impersonate_b" {
  service_account_id = google_service_account.admin_infra_b.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_service_account.admin_infra_a.member

  depends_on = [
    google_service_account.admin_infra_a,
    google_service_account.admin_infra_b,
  ]
}

resource "google_service_account_iam_member" "admin_impersonate_a" {
  service_account_id = google_service_account.admin_infra_a.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:celia@${local.zone_name}"

  depends_on = [
    google_service_account.admin_infra_a,
  ]
}

resource "google_storage_bucket_iam_member" "admin_infra_a" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.admin_infra_a.member

  condition {
    title = "Admin State Prefix"
    description = format(
      "%s can only manage objects under prefix %s",
      google_service_account.admin_infra_a.name,
      "terraform/state/admin/"
    )
    expression = format(
      <<-EOT
        resource.name.startsWith("projects/_/buckets/%s/objects/%s")
      EOT
      ,
      google_storage_bucket.tfstate.name,
      "terraform/state/admin"
    )
  }
}
