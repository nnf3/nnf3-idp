variable "environment" {
  type        = string
  description = "Environment name. Used in resource names so dev and prd can share a GCP project."

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "environment must be dev or prd."
  }
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Cloud Run region. Keep next to Neon Singapore."
  default     = "asia-southeast1"
}

variable "neon_org_id" {
  type        = string
  default     = ""
  description = "Optional Neon org id. Leave empty for a personal account."
}

variable "smtp_connection_uri" {
  type        = string
  sensitive   = true
  description = "Kratos courier SMTP URI, e.g. smtps://user:pass@smtp.resend.com:465"
}

variable "app_origin" {
  type        = string
  description = "First-party app origin for CORS and allowed return URLs. Use the UI URL until the app exists."
  default     = ""
}

variable "image_tag" {
  type    = string
  default = "v26.2.0-r1"
}

variable "first_party_client_id" {
  type    = string
  default = "nnf3-web"
}

variable "min_instance_count" {
  type    = number
  default = 0
}

variable "max_instance_count" {
  type    = number
  default = 1
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Protect Cloud Run services and jobs from terraform destroy."
}

variable "neon_autoscaling_min_cu" {
  type    = number
  default = 0.25
}

variable "neon_autoscaling_max_cu" {
  type    = number
  default = 1
}
