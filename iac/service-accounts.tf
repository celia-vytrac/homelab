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

  homelab_project_iam_roles = [
    "roles/cloudkms.admin",
    "roles/storage.admin",
    "roles/secretmanager.viewer",
    "roles/secretmanager.secretAccessor",
  ]
}

resource "google_service_account" "controlplane" {
  account_id = "controlplane"
  project    = split("/", google_project.homelab.id)[1]
}

resource "google_service_account" "agents" {
  account_id = "cluster-agent"
  project    = split("/", google_project.homelab.id)[1]
}

resource "google_service_account" "tf_sa" {
  account_id   = "gitops-iac"
  display_name = "Github actions service account"
  project      = split("/", google_project.admin.id)[1]
}

resource "google_service_account_key" "tf_sa_key" {
  service_account_id = google_service_account.tf_sa.name
}

resource "google_organization_iam_binding" "tf_sa_binding" {
  for_each = toset(local.org_iam_roles)
  role     = each.value
  org_id   = data.google_organization.vytrac_me.org_id

  members = [
    "serviceAccount:${google_service_account.tf_sa.email}",
  ]
}

resource "google_project_iam_binding" "tf_sa_binding" {
  for_each = merge(
    { for role in local.admin_project_iam_roles : role => google_project.admin.number },
    { for role in local.homelab_project_iam_roles : role => google_project.homelab.number }
  )
  role    = each.key
  project = each.value

  members = [
    "serviceAccount:${google_service_account.tf_sa.email}",
  ]
}

resource "google_kms_crypto_key_iam_binding" "tfstate_sa_binding" {
  crypto_key_id = google_kms_crypto_key.keys["tfstate-key"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-325329770668@gs-project-accounts.iam.gserviceaccount.com",
  ]
}

resource "google_kms_crypto_key_iam_binding" "secrets_sa_binding" {
  crypto_key_id = google_kms_crypto_key.keys["secrets-key"].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-325329770668@gcp-sa-secretmanager.iam.gserviceaccount.com",
  ]
}
