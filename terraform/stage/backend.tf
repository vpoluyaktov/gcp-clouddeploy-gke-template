terraform {
  backend "gcs" {
    bucket = "dfh-stage-tfstate"
    prefix = "gcp-clouddeploy-gke-template/state"
  }
}
