terraform {
  backend "gcs" {
    bucket = "tfstate.vytrac.me"
    prefix = "terraform/state/admin"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = data.google_secret_manager_secret_version.cloudflare_api_token.secret_data
}

provider "google-beta" {
  region = "us-central1"
}

provider "google" {
  region                      = "us-central1"
  impersonate_service_account = "srv-tf-admin-infra-a@admin-705425.iam.gserviceaccount.com"
}
