output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "runtime_service_account_email" {
  description = "Email of the runtime service account"
  value       = google_service_account.runtime.email
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "custom_domain_url" {
  description = "Custom domain URL for the service"
  value       = "https://${var.custom_domain}"
}

output "firestore_database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.main.name
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository path"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "clouddeploy_pipeline_name" {
  description = "Cloud Deploy pipeline name"
  value       = google_clouddeploy_delivery_pipeline.pipeline.name
}

output "gke_lb_ip" {
  description = "Global static IP address reserved for the GKE Ingress"
  value       = google_compute_global_address.gke_ingress_ip.address
}

# The IP resource NAME is used in the Ingress annotation:
#   kubernetes.io/ingress.global-static-ip-name
# This is different from the IP address value — Ingress needs the NAME, not the address.
output "gke_lb_ip_name" {
  description = "Name of the global static IP resource (used in Ingress annotation)"
  value       = google_compute_global_address.gke_ingress_ip.name
}
