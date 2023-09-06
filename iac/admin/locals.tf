locals {
  org_iam_roles = [
    "roles/billing.viewer",
    "roles/resourcemanager.projectCreator",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/resourcemanager.organizationAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
  ]

  admin_project_iam_roles = [
    "roles/cloudkms.admin",
    "roles/storage.admin",
    "roles/secretmanager.viewer",
    "roles/secretmanager.secretAccessor",
  ]

  admin_apis = [
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
  ]

  mx_priorities         = [24, 13, 75]
  cloudflare_account_id = "45fca7176e51443ab5651be59269cbef"
  personal_email        = "celia.j.vytrac@gmail.com"

  # data comes in from secret manager as a list of string separate by newlines
  gcloud_domain_verifications = [for line in split("\n", data.google_secret_manager_secret_version.gcloud_domain_verifications.secret_data) : chomp(line)]
  github_domain_verifications = [for line in split("\n", data.google_secret_manager_secret_version.github_domain_verifications.secret_data) : chomp(line)]
}
