data "google_billing_account" "billing" {
  display_name = "My Billing Account"
  open         = true
}

data "google_organization" "vytrac_me" {
  domain = "vytrac.me"
}

data "cloudflare_zone" "zone" {
  account_id = local.cloudflare_account_id
  name       = "vytrac.me"
}

data "google_secret_manager_secret_version" "cloudflare_api_token" {
  project = google_project.admin.number
  secret  = "cloudflare-api-token"
}

data "google_secret_manager_secret_version" "gcloud_domain_verifications" {
  project = google_project.admin.number
  secret  = "gcloud-domain-verifications"
}
