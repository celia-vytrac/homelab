locals {
  org_iam_roles = [
    "roles/resourcemanager.projectCreator",
    "roles/billing.viewer",
  ]

  admin_project_iam_roles = [
    "roles/cloudkms.admin",
    "roles/storage.admin",
  ]

  admin_apis = [
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
  ]

  mx_priorities         = [24, 13, 75]
  cloudflare_account_id = "45fca7176e51443ab5651be59269cbef"
  personal_email        = "celia.j.vytrac@gmail.com"

  # data comes in from secret manager as a list of string separate by newlines
  gcloud_domain_verifications = [for line in split("\n", data.google_secret_manager_secret_version.gcloud_domain_verifications.secret_data) : chomp(line)]
}
