terraform {
  backend "gcs" {
    bucket = "tfstate.vytrac.me"
    prefix = "terraform/state/admin-920455"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
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
