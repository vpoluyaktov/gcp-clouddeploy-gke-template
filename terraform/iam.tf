# Runtime service account for GKE pods
resource "google_service_account" "runtime" {
  account_id   = "gke-tpl-${var.environment}"
  display_name = "gcp-clouddeploy-gke-template Runtime SA (${title(var.environment)})"
  project      = var.project_id
}

resource "google_project_iam_member" "runtime_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "runtime_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Workload Identity binding — allows GKE pods using the K8s SA to act as this GCP SA
resource "google_service_account_iam_member" "runtime_workload_identity" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/${var.service_name}]"

  depends_on = [google_container_cluster.primary]
}

# Cloud Build service account
resource "google_service_account" "cloudbuild" {
  account_id   = "cloudbuild-gke-tpl-${var.environment}"
  display_name = "gcp-clouddeploy-gke-template Cloud Build SA (${title(var.environment)})"
  project      = var.project_id
}

resource "google_project_iam_member" "cloudbuild_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_deployer" {
  project = var.project_id
  role    = "roles/clouddeploy.releaser"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}
