# Artifact Registry Docker repository for container images
resource "google_artifact_registry_repository" "docker" {
  repository_id = var.ar_repository_name
  location      = var.region
  project       = var.project_id
  format        = "DOCKER"
  description   = "Docker repository for ${var.service_name}"

  depends_on = [google_project_service.apis]
}
