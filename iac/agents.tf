resource "google_compute_subnetwork" "agents" {
  name          = "cluster-agents"
  network       = google_compute_network.homelab.self_link
  region        = "us-central1"
  ip_cidr_range = "172.16.2.0/24"

  private_ip_google_access = true
}

resource "google_compute_router" "agents" {
  name    = "cluster-agents"
  region  = "us-central1"
  network = google_compute_network.homelab.self_link
}

resource "google_compute_router_nat" "agents" {
  name                               = "cluster-agents"
  router                             = google_compute_router.agents.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.agents.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_region_instance_template" "agents" {
  name_prefix = "agent-instance-template-"
  project     = google_project.homelab.number

  instance_description = "agent node"
  machine_type         = "e2-medium"

  tags = ["k8s"]

  disk_encryption_key = google_kms_crypto_key.keys["talos-disk-key"].id

  // Create a new boot disk from an image
  disk {
    source_image = google_compute_image.talos.self_link
    auto_delete  = true
    boot         = true
    // backup the disk every day
    resource_policies = [google_compute_resource_policy.daily.id]
  }

  network_interface {
    network    = google_compute_network.homelab.self_link
    subnetwork = google_compute_subnetwork.agents.id
  }

  service_account {
    email = google_service_account.agents.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "agents" {
  name    = "cluster-agents"
  project = google_project.homelab.number

  base_instance_name = "agent"
  region             = "us-central1"

  version {
    instance_template = google_compute_region_instance_template.agents.id
  }

  // Setting three for now
  // Eventually this will be autoscaled
  target_size = 3

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "https"
    port = 443
  }

  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 3
  }

  depends_on = [google_compute_router_nat.agents]
}
