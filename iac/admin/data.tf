data "google_billing_account" "billing" {
  display_name = "My Billing Account"
  open         = true
}

data "google_organization" "vytrac_me" {
  domain = "vytrac.me"
}

data "cloudflare_account" "account" {
  filter = {
    name = "Vytrac Homelab"
  }
}

data "cloudflare_zone" "zone" {
  filter = {
    name = "vytrac.me"
    account = {
      id = data.cloudflare_account.account.id
    }
  }
}

data "google_secret_manager_secret_version" "cloudflare_api_token" {
  project = google_project.admin.number
  secret  = "cloudflare-api-token"
}

data "google_secret_manager_secret_version" "gcloud_domain_verifications" {
  project = google_project.admin.number
  secret  = "gcloud-domain-verifications"
}

data "google_secret_manager_secret_version" "github_domain_verifications" {
  project = google_project.admin.number
  secret  = "github-domain-verifications"
}

data "google_secret_manager_secret_version" "icloud_domain_verifications" {
  project = google_project.admin.number
  secret  = "icloud-domain-verifications"
}
