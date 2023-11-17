resource "google_compute_subnetwork" "controlplane" {
  name          = "controlplane"
  network       = google_compute_network.homelab.self_link
  region        = "us-central1"
  ip_cidr_range = "172.16.1.0/24"

  private_ip_google_access = true
}

resource "google_compute_address" "controlplane_internal" {
  name         = "controlplane-internal"
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  region       = "us-central1"
  subnetwork   = google_compute_subnetwork.controlplane.id
}

resource "google_compute_address" "controlplane_external" {
  name   = "controlplane-external"
  region = "us-central1"
}

resource "google_compute_firewall" "controlplane_api_allow_hc" {
  name    = "controlplane-api-allow-hc"
  network = google_compute_network.homelab.self_link
  // got from here https://cloud.google.com/load-balancing/docs/health-checks#fw-rule
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  allow {
    protocol = "tcp"
    ports    = [6443]
  }
  target_tags = ["controlplane"]
  direction   = "INGRESS"
}

resource "google_compute_firewall" "controlplane_api_authorized_networks" {
  name          = "controlplane-api-authorized-networks"
  network       = google_compute_network.homelab.self_link
  source_ranges = ["198.54.133.104/32"]
  allow {
    protocol = "tcp"
    ports    = [6443]
  }
  target_tags = ["controlplane"]
  direction   = "INGRESS"
}

resource "google_compute_router" "controlplane" {
  name    = "controlplane"
  region  = "us-central1"
  network = google_compute_network.homelab.self_link
}

resource "google_compute_router_nat" "controlplane" {
  name                               = "controlplane"
  router                             = google_compute_router.controlplane.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.controlplane.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_health_check" "controlplane_internal" {
  name = "controlplane-internal"

  timeout_sec        = 1
  check_interval_sec = 5

  tcp_health_check {
    port = 6443
  }
}

resource "google_compute_region_health_check" "controlplane_external" {
  name   = "controlplane-external"
  region = "us-central1"

  timeout_sec        = 1
  check_interval_sec = 5

  tcp_health_check {
    port = 6443
  }
}

resource "google_compute_region_backend_service" "api_server_internal" {
  name                  = "api-server-internal"
  region                = "us-central1"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_health_check.controlplane_internal.id]
  backend {
    group = google_compute_region_instance_group_manager.controlplane.instance_group
  }
}

resource "google_compute_forwarding_rule" "api_server_internal" {
  name                  = "api-server-internal"
  region                = "us-central1"
  load_balancing_scheme = "INTERNAL"
  allow_global_access   = true
  ip_address            = google_compute_address.api_server_internal.address
  backend_service       = google_compute_region_backend_service.api_server_internal.id
  ports                 = [6443]
  subnetwork            = google_compute_subnetwork.controlplane.self_link
}

resource "google_compute_region_backend_service" "api_server_external" {
  name                  = "api-server-external"
  region                = "us-central1"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_region_health_check.controlplane_external.id]
  backend {
    group = google_compute_region_instance_group_manager.controlplane.instance_group
  }
}

resource "google_compute_forwarding_rule" "api_server_external" {
  name                  = "api-server-external"
  region                = "us-central1"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_address.api_server_external.address
  backend_service       = google_compute_region_backend_service.api_server_external.id
  port_range            = "6443-6443"
}

resource "google_compute_region_instance_template" "controlplane" {
  name_prefix = "controlplane-instance-template-"
  project     = google_project.homelab.number

  instance_description = "controlplane node"
  machine_type         = "e2-medium"

  tags = ["controlplane", "k8s"]


  // Create a new boot disk from an image
  disk {
    source_image = google_compute_image.talos.self_link
    auto_delete  = true
    boot         = true
    // backup the disk every day
    resource_policies   = [google_compute_resource_policy.daily.id]
    disk_encryption_key = google_kms_crypto_key.keys["talos-disk-key"].id
  }

  network_interface {
    network    = google_compute_network.homelab.self_link
    subnetwork = google_compute_subnetwork.controlplane.id
  }

  service_account {
    email = google_service_account.controlplane.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "controlplane" {
  name    = "controlplane"
  project = google_project.homelab.number

  base_instance_name = "ctrl"
  region             = "us-central1"

  version {
    instance_template = google_compute_region_instance_template.controlplane.id
  }

  target_size = 3

  named_port {
    name = "k8s"
    port = 6443
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.controlplane.id
    initial_delay_sec = 300
  }

  depends_on = [google_compute_router_nat.controlplane]
}
