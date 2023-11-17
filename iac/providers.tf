terraform {
  backend "gcs" {
    bucket = "tfstate.vytrac.me"
    prefix = "terraform/state/admin-920455"
  }

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "4.19.0"
    }
    google = {
      source = "hashicorp/google"
      version = "5.6.0"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.4.0-alpha.0"
    }
  }
}

provider "cloudflare" {
  api_token = data.google_secret_manager_secret_version.cloudflare_api_token.secret_data
}

provider "google-beta" {
  project = "admin-920455"
  region  = "us-central1"
}

provider "google" {
  project = "admin-920455"
  region  = "us-central1"
}

provider "google" {
  alias   = "homelab"
  project = "homelab-735905"
  region  = "us-central1"
}
