variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name of the application/service"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "tfstate_bucket_name" {
  description = "Name of the GCS bucket for Terraform state"
  type        = string
}

variable "deploy_sa_email" {
  description = "Email of the deploy service account"
  type        = string
  default     = ""
}

variable "dns_project_id" {
  description = "GCP project ID where Cloud DNS zone is managed"
  type        = string
}

variable "dns_zone_name" {
  description = "Cloud DNS managed zone name"
  type        = string
}

variable "dns_domain" {
  description = "Base DNS domain (e.g., demo.devops-for-hire.com)"
  type        = string
}

variable "custom_domain" {
  description = "Full custom domain for the service (e.g., myapp.stage.demo.devops-for-hire.com)"
  type        = string
}

variable "firestore_database_name" {
  description = "Firestore database name (typically the repository name)"
  type        = string
}

variable "firestore_location" {
  description = "Firestore database location"
  type        = string
  default     = "nam5"
}

variable "ar_repository_name" {
  description = "Artifact Registry repository name"
  type        = string
}
