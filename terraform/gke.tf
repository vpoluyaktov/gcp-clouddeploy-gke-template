# GKE Autopilot cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot mode — Google manages node pools, scaling, and upgrades
  enable_autopilot = true

  # Release channel for automatic upgrades
  release_channel {
    channel = "REGULAR"
  }

  # Workload Identity for secure pod-to-GCP-service authentication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network config — use default VPC
  network    = "default"
  subnetwork = "default"

  # IP allocation policy required for VPC-native clusters
  ip_allocation_policy {}

  depends_on = [google_project_service.apis]
}
