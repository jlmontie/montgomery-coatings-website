variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "montgomery-coatings"
}

variable "bucket_name" {
  description = "GCS bucket name (must be globally unique)"
  type        = string
  default     = "montgomerycoatings-com"
}
