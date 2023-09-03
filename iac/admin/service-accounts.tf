resource "google_service_account" "tf_sa" {
  account_id   = "gitops-iac"
  display_name = "Github actions service account"
  project      = split("/", google_project.admin.id)[1]
}

resource "google_service_account_key" "tf_sa_key" {
  service_account_id = google_service_account.tf_sa.name
}

#resource "google_service_account" "dev_tf_sa" {
#  account_id   = "gitops-dev-iac"
#  display_name = "Github actions service account"
#  project      = split("/", google_project.dev.id)[1]
#}
#
#resource "google_service_account" "prod_tf_sa" {
#  account_id   = "gitops-prod-iac"
#  display_name = "Github actions service account"
#  project      = split("/", google_project.prod.id)[1]
#}

resource "google_project_iam_binding" "tf_sa_binding" {
  for_each = toset(local.admin_project_iam_roles)
  role     = each.value
  project  = google_project.admin.number

  members = [
    "serviceAccount:${google_service_account.tf_sa.email}",
  ]
}

resource "google_organization_iam_binding" "tf_sa_binding" {
  for_each = toset(local.org_iam_roles)
  role     = each.value
  org_id   = data.google_organization.vytrac_me.org_id

  members = [
    "serviceAccount:${google_service_account.tf_sa.email}",
  ]
}

resource "google_kms_crypto_key_iam_binding" "tfstate_sa_binding" {
  crypto_key_id = google_kms_crypto_key.tfstate_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-325329770668@gs-project-accounts.iam.gserviceaccount.com",
  ]
}

resource "google_kms_crypto_key_iam_binding" "secrets_sa_binding" {
  crypto_key_id = google_kms_crypto_key.secrets_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-325329770668@gcp-sa-secretmanager.iam.gserviceaccount.com",
  ]
}
