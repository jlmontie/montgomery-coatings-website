output "ip_address" {
  value       = google_compute_global_address.website.address
  description = "Add this as an A record in Squarespace DNS for both montgomerycoatings.com and www.montgomerycoatings.com"
}

output "bucket_name" {
  value       = google_storage_bucket.website.name
  description = "GCS bucket — use as the GCS_BUCKET_NAME GitHub secret"
}

output "website_url" {
  value = "https://montgomerycoatings.com"
}
