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

variable "github_deploy" {
  type = object({
    enabled                = bool
    owner                  = string
    repository             = string
    branch_pattern         = optional(string)
    tag_pattern            = optional(string)
    trigger_location       = optional(string, "global")
    image_tag_substitution = optional(string, "$SHORT_SHA")
    included_files = optional(list(string), [
      "deploy/**",
      "config/kratos/**",
      "config/hydra/**",
    ])
  })

  default = {
    enabled    = false
    owner      = ""
    repository = ""
  }

  description = "GitHub-connected Cloud Build trigger (第 1 世代). dev: branch_pattern = ^main$."
}
