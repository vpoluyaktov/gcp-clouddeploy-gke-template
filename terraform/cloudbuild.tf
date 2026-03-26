# Cloud Build trigger — fires on push to the configured branch
resource "google_cloudbuild_trigger" "deploy" {
  name     = "${var.service_name}-deploy"
  project  = var.project_id
  location = var.region

  github {
    owner = var.github_repo_owner
    name  = var.github_repo_name

    push {
      branch = "^${var.branch_name}$"
    }
  }

  filename        = "cloudbuild.yaml"
  service_account = google_service_account.cloudbuild.id

  substitutions = {
    _AR_REGION         = var.region
    _AR_REPOSITORY     = var.ar_repository_name
    _SERVICE_NAME      = var.service_name
    _DEPLOY_REGION     = var.region
    _PIPELINE_NAME     = "${var.service_name}-pipeline"
    _ENVIRONMENT       = var.environment
    _FIRESTORE_DB_NAME = var.firestore_database_name
  }

  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.docker,
  ]
}
