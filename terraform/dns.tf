# Static IP for the GKE LoadBalancer Service
resource "google_compute_address" "gke_lb_ip" {
  name         = "${var.service_name}-lb-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"

  depends_on = [google_project_service.apis]
}

# DNS A record in the ops project pointing to the static IP
resource "google_dns_record_set" "gke_a_record" {
  project      = var.dns_project_id
  managed_zone = var.dns_zone_name
  name         = "${var.custom_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.gke_lb_ip.address]
}
