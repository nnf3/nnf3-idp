variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "credentials_file" {
  type        = string
  default     = "credentials.json"
  description = "Service account JSON key. Place it in this env directory. Do not commit it."
}

variable "region" {
  type    = string
  default = "asia-southeast1"
}

variable "neon_api_key" {
  type      = string
  sensitive = true
}

variable "neon_org_id" {
  type    = string
  default = ""
}

variable "smtp_connection_uri" {
  type      = string
  sensitive = true
}

variable "app_origin" {
  type    = string
  default = ""
}

variable "image_tag" {
  type        = string
  default     = "v26.2.0-r1"
  description = "Bootstrap image tag for initial Cloud Run creation. Image updates are applied by Cloud Build."
}

variable "first_party_client_id" {
  type    = string
  default = "nnf3-web"
}
