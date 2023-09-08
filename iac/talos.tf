locals {
  talos_version = "v1.6.0-alpha.0"
  talos_image   = "https://github.com/siderolabs/talos/releases/download/${local.talos_version}/gcp-amd64.raw.tar.gz"
}

resource "google_compute_image" "talos" {
  name    = "talos-image"
  project = google_project.homelab.number

  raw_disk {
    source = local.talos_image
  }
}

resource "talos_machine_secrets" "secrets" {
  talos_version = local.talos_version
}

data "talos_cluster_kubeconfig" "kubeconfig" {
  for_each             = toset(local.node_ips)
  client_configuration = talos_machine_secrets.secrets.client_configuration
  node                 = each.value

  depends_on = [
    talos_machine_bootstrap.bootstrap
  ]
}

data "talos_machine_configuration" "config" {
  cluster_name     = "homelab"
  machine_type     = "controlplane"
  cluster_endpoint = "https://cluster.local:6443"
  machine_secrets  = talos_machine_secrets.secrets.machine_secrets
}

data "talos_client_configuration" "config" {
  cluster_name         = "homelab"
  client_configuration = talos_machine_secrets.secrets.client_configuration
  nodes                = local.node_ips
}

resource "talos_machine_configuration_apply" "config" {
  for_each                    = toset(local.node_ips)
  client_configuration        = talos_machine_secrets.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.config.machine_configuration
  node                        = each.value
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sdd"
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "boostrap" {
  for_each             = toset(local.node_ips)
  client_configuration = talos_machine_secrets.secrets.client_configuration
  node                 = each.value

  depends_on = [
    talos_machine_configuration_apply.config
  ]
}
