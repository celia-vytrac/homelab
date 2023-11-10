locals {
  homelab_apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}

resource "google_project" "homelab" {
  name       = "Homelab"
  project_id = "homelab-${random_string.random[1].result}"
  org_id     = data.google_organization.vytrac_me.org_id

  billing_account = data.google_billing_account.billing.id
}

resource "google_project_service" "homelab_services" {
  for_each = toset(local.homelab_apis)
  project  = google_project.homelab.number
  service  = each.key
}

resource "google_compute_health_check" "controlplane" {
  name                = "autohealing-health-check"
  project  = google_project.homelab.number
  unhealthy_threshold = 10 # 50 seconds

  tcp_health_check {
    port         = "6443"
  }
}

resource "google_compute_target_pool" "controlplane" {
  name = "controlplane-pool"
  project  = google_project.homelab.number
  region                     = "us-central1"

  instances = [
    for i in google_compute_instance.controlplane: i.id
  ]
}

resource "google_compute_region_instance_template" "default" {
  name        = "appserver-template"
  description = "This template is used to create app server instances."

  tags = ["foo", "bar"]

  labels = {
    environment = "dev"
  }

  instance_description = "description assigned to instances"
  machine_type         = "e2-medium"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image      = "debian-cloud/debian-11"
    auto_delete       = true
    boot              = true
    // backup the disk every day
    resource_policies = [google_compute_resource_policy.daily_backup.id]
  }

  // Use an existing disk resource
  disk {
    source      = google_compute_region_disk.foobar.self_link
    auto_delete = false
    boot        = false
  }

  network_interface {
    network = "default"
  }

  metadata = {
    foo = "bar"
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_region_instance_group_manager" "controlplane" {
  name = "ctrl-mig"
  project  = google_project.homelab.number

  base_instance_name         = "ctrl"
  region                     = "us-central1"

  version {
    instance_template = google_compute_instance_template.appserver.self_link_unique
  }

  target_pools = [google_compute_target_pool.controlplane.id]
  target_size  = 3

  auto_healing_policies {
    health_check      = google_compute_health_check.controlplane.id
    initial_delay_sec = 300
  }
}

gcloud compute instance-groups unmanaged create talos-ig \
  --zone $REGION-b

# Create port for IG
gcloud compute instance-groups set-named-ports talos-ig \
    --named-ports tcp6443:6443 \
    --zone $REGION-b

# Create health check
gcloud compute health-checks create tcp talos-health-check --port 6443

# Create backend
gcloud compute backend-services create talos-be \
    --global \
    --protocol TCP \
    --health-checks talos-health-check \
    --timeout 5m \
    --port-name tcp6443

# Add instance group to backend
gcloud compute backend-services add-backend talos-be \
    --global \
    --instance-group talos-ig \
    --instance-group-zone $REGION-b

# Create tcp proxy
gcloud compute target-tcp-proxies create talos-tcp-proxy \
    --backend-service talos-be \
    --proxy-header NONE

# Create LB IP
gcloud compute addresses create talos-lb-ip --global

# Forward 443 from LB IP to tcp proxy
gcloud compute forwarding-rules create talos-fwd-rule \
    --global \
    --ports 443 \
    --address talos-lb-ip \
    --target-tcp-proxy talos-tcp-proxy

# Create firewall rule for health checks
gcloud compute firewall-rules create talos-controlplane-firewall \
     --source-ranges 130.211.0.0/22,35.191.0.0/16 \
     --target-tags talos-controlplane \
     --allow tcp:6443

# Create firewall rule to allow talosctl access
gcloud compute firewall-rules create talos-controlplane-talosctl \
  --source-ranges 0.0.0.0/0 \
  --target-tags talos-controlplane \
  --allow tcp:50000

# Create the control plane nodes.
for i in $( seq 1 3 ); do
  gcloud compute instances create talos-controlplane-$i \
    --image talos \
    --zone $REGION-b \
    --tags talos-controlplane \
    --boot-disk-size 20GB \
    --metadata-from-file=user-data=./controlplane.yaml
    --tags talos-controlplane-$i
done

# Add control plane nodes to instance group
for i in $( seq 1 3 ); do
  gcloud compute instance-groups unmanaged add-instances talos-ig \
      --zone $REGION-b \
      --instances talos-controlplane-$i
done

# Create worker
gcloud compute instances create talos-worker-0 \
  --image talos \
  --zone $REGION-b \
  --boot-disk-size 20GB \
  --metadata-from-file=user-data=./worker.yaml
  --tags talos-worker-$i
