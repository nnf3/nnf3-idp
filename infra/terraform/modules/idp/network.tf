# Direct VPC (no connector, no NAT). Callers of internal Cloud Run send
# run.app traffic through the VPC so ingress=internal accepts it.
# PRIVATE_RANGES_ONLY keeps Neon / SMTP on the default internet egress.

resource "google_compute_network" "idp" {
  name                    = "${local.prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.services]
}

resource "google_compute_subnetwork" "idp" {
  name                     = "${local.prefix}-${var.region}"
  ip_cidr_range            = "10.8.0.0/26"
  region                   = var.region
  network                  = google_compute_network.idp.id
  private_ip_google_access = true
}

resource "google_dns_managed_zone" "run_app" {
  name        = "${local.prefix}-run-app"
  dns_name    = "run.app."
  visibility  = "private"
  description = "Resolve Cloud Run URLs to private.googleapis.com so internal ingress works."

  private_visibility_config {
    networks {
      network_url = google_compute_network.idp.id
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_dns_record_set" "run_app" {
  for_each = toset([
    "*.run.app.",
    "*.a.run.app.",
    "*.${var.region}.run.app.",
  ])

  name         = each.value
  managed_zone = google_dns_managed_zone.run_app.name
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
}
