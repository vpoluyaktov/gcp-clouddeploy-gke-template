# DNS A record in the ops project pointing to the GKE LoadBalancer IP.
#
# NOTE: On initial deployment, the LoadBalancer external IP may not yet be
# allocated. In that case, set dns_lb_ip to a placeholder (e.g., "0.0.0.0")
# and update it after the Kubernetes Service gets an external IP:
#
#   kubectl get svc gcp-clouddeploy-gke-template -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
#
# Then re-run terraform apply with the actual IP.

variable "dns_lb_ip" {
  description = "External IP of the GKE LoadBalancer Service for DNS A record"
  type        = string
  default     = ""
}

resource "google_dns_record_set" "gke_a_record" {
  count = var.dns_lb_ip != "" ? 1 : 0

  project      = var.dns_project_id
  managed_zone = var.dns_zone_name
  name         = "${var.custom_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.dns_lb_ip]
}
