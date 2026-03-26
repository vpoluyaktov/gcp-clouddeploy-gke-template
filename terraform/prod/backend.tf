terraform {
  backend "gcs" {
    bucket = "dfh-prod-tfstate"
    prefix = "gcp-clouddeploy-gke-template/state"
  }
}
