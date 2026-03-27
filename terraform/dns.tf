# Global static IP for the GKE Ingress
# IMPORTANT: GKE Ingress requires a GLOBAL static IP (not regional).
# This IP is referenced by NAME in the Ingress annotation:
#   kubernetes.io/ingress.global-static-ip-name
# The IP address value is used in the DNS A record below.
resource "google_compute_global_address" "gke_ingress_ip" {
  name    = "${var.service_name}-lb-ip"
  project = var.project_id

  depends_on = [google_project_service.apis]
}

# DNS A record in the ops project pointing to the global static IP
resource "google_dns_record_set" "gke_a_record" {
  project      = var.dns_project_id
  managed_zone = var.dns_zone_name
  name         = "${var.custom_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.gke_ingress_ip.address]
}
