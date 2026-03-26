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
