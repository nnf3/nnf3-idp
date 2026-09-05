resource "neon_project" "idp" {
  name                      = local.name
  region_id                 = "aws-ap-southeast-1"
  pg_version                = 16
  history_retention_seconds = 21600
  org_id                    = var.neon_org_id != "" ? var.neon_org_id : null

  default_endpoint_settings {
    autoscaling_limit_min_cu = var.neon_autoscaling_min_cu
    autoscaling_limit_max_cu = var.neon_autoscaling_max_cu
  }
}

resource "neon_role" "kratos" {
  project_id = neon_project.idp.id
  branch_id  = neon_project.idp.default_branch_id
  name       = "kratos"
}

resource "neon_role" "hydra" {
  project_id = neon_project.idp.id
  branch_id  = neon_project.idp.default_branch_id
  name       = "hydra"
}

resource "neon_database" "kratos" {
  project_id = neon_project.idp.id
  branch_id  = neon_project.idp.default_branch_id
  name       = "kratos"
  owner_name = neon_role.kratos.name
}

resource "neon_database" "hydra" {
  project_id = neon_project.idp.id
  branch_id  = neon_project.idp.default_branch_id
  name       = "hydra"
  owner_name = neon_role.hydra.name
}
