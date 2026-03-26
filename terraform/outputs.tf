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
  description = "Static IP reserved for the GKE LoadBalancer"
  value       = google_compute_address.gke_lb_ip.address
}
