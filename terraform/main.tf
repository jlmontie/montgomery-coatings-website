terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "montgomery-coatings-tf-state"
    prefix = "website"
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# ── APIs ───────────────────────────────────────────────────────────────────────

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_credentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

# ── Storage bucket (static hosting) ───────────────────────────────────────────

resource "google_storage_bucket" "website" {
  name          = var.bucket_name
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ── Networking ─────────────────────────────────────────────────────────────────

resource "google_compute_global_address" "website" {
  name       = "montgomery-coatings-ip"
  depends_on = [google_project_service.compute]
}

# ── SSL certificate ────────────────────────────────────────────────────────────
# Note: will stay in PROVISIONING state until DNS A records point to the IP.

resource "google_compute_managed_ssl_certificate" "website" {
  name = "montgomery-coatings-ssl"
  managed {
    domains = [
      "montgomerycoatings.com",
      "www.montgomerycoatings.com",
    ]
  }
  depends_on = [google_project_service.compute]
}

# ── CDN-backed bucket ──────────────────────────────────────────────────────────

resource "google_compute_backend_bucket" "website" {
  name        = "montgomery-coatings-backend"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = true

  cdn_policy {
    cache_mode  = "CACHE_ALL_STATIC"
    default_ttl = 3600
    max_ttl     = 86400
  }
}

# ── HTTPS load balancer ────────────────────────────────────────────────────────

resource "google_compute_url_map" "https" {
  name            = "montgomery-coatings-urlmap"
  default_service = google_compute_backend_bucket.website.self_link
}

resource "google_compute_target_https_proxy" "website" {
  name             = "montgomery-coatings-https-proxy"
  url_map          = google_compute_url_map.https.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.website.self_link]
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "montgomery-coatings-https"
  target     = google_compute_target_https_proxy.website.self_link
  port_range = "443"
  ip_address = google_compute_global_address.website.address
}

# ── HTTP → HTTPS redirect ──────────────────────────────────────────────────────

resource "google_compute_url_map" "redirect" {
  name = "montgomery-coatings-redirect"
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "montgomery-coatings-http-proxy"
  url_map = google_compute_url_map.redirect.self_link
}

resource "google_compute_global_forwarding_rule" "http" {
  name       = "montgomery-coatings-http"
  target     = google_compute_target_http_proxy.redirect.self_link
  port_range = "80"
  ip_address = google_compute_global_address.website.address
}
