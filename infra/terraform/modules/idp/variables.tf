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
  type        = string
  default     = "v26.2.0-r1"
  description = "Bootstrap image tag for initial Cloud Run creation. Image updates are applied by Cloud Build."
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

  description = "GitHub-connected Cloud Build trigger (第 1 世代). Console でリポジトリ連携済みなら enabled=true だけでよい."

  validation {
    condition = !var.github_deploy.enabled || (
      var.github_deploy.owner != "" &&
      var.github_deploy.repository != "" &&
      (
        (var.github_deploy.branch_pattern != null && var.github_deploy.tag_pattern == null) ||
        (var.github_deploy.branch_pattern == null && var.github_deploy.tag_pattern != null)
      )
    )
    error_message = "When github_deploy.enabled is true, set owner, repository, and exactly one of branch_pattern or tag_pattern."
  }
}
