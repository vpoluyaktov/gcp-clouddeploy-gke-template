# Cloud Deploy delivery pipeline
resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  name     = "${var.service_name}-pipeline"
  location = var.region
  project  = var.project_id

  description = "Delivery pipeline for ${var.service_name}"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.target.name
      profiles  = [var.environment]
    }
  }

  depends_on = [google_project_service.apis]
}

# Cloud Deploy GKE target
resource "google_clouddeploy_target" "target" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  description      = "GKE target for ${var.service_name} (${var.environment})"
  require_approval = false

  gke {
    cluster = "projects/${var.project_id}/locations/${var.region}/clusters/${var.cluster_name}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy_execution.email
  }

  depends_on = [
    google_project_service.apis,
    google_container_cluster.primary,
  ]
}

# Cloud Deploy execution service account (used by Cloud Deploy to render and deploy)
resource "google_service_account" "clouddeploy_execution" {
  account_id   = "deploy-gke-tpl-${var.environment}"
  display_name = "gcp-clouddeploy-gke-template Cloud Deploy Execution SA (${title(var.environment)})"
  project      = var.project_id
}

resource "google_project_iam_member" "clouddeploy_exec_gke" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.clouddeploy_execution.email}"
}

resource "google_project_iam_member" "clouddeploy_exec_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.clouddeploy_execution.email}"
}

resource "google_project_iam_member" "clouddeploy_exec_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.clouddeploy_execution.email}"
}

resource "google_project_iam_member" "clouddeploy_exec_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.clouddeploy_execution.email}"
}
