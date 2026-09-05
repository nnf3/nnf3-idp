data "google_project" "this" {
  project_id = var.project_id
}

locals {
  name   = "nnf3-idp-${var.environment}"
  prefix = "idp-${var.environment}"

  service = {
    kratos_public = "kratos-public-${var.environment}"
    kratos_admin  = "kratos-admin-${var.environment}"
    hydra_public  = "hydra-public-${var.environment}"
    hydra_admin   = "hydra-admin-${var.environment}"
    ui            = "idp-ui-${var.environment}"
  }

  job = {
    kratos_migrate      = "kratos-migrate-${var.environment}"
    hydra_migrate       = "hydra-migrate-${var.environment}"
    hydra_janitor       = "hydra-janitor-${var.environment}"
    hydra_create_client = "hydra-create-client-${var.environment}"
  }

  # Deterministic Cloud Run URLs (no extra load balancer).
  # https://cloud.google.com/run/docs/triggering/https-request
  kratos_public_url = "https://${local.service.kratos_public}-${data.google_project.this.number}.${var.region}.run.app"
  kratos_admin_url  = "https://${local.service.kratos_admin}-${data.google_project.this.number}.${var.region}.run.app"
  hydra_public_url  = "https://${local.service.hydra_public}-${data.google_project.this.number}.${var.region}.run.app"
  hydra_admin_url   = "https://${local.service.hydra_admin}-${data.google_project.this.number}.${var.region}.run.app"
  ui_url            = "https://${local.service.ui}-${data.google_project.this.number}.${var.region}.run.app"
  app_origin        = var.app_origin != "" ? var.app_origin : local.ui_url
  cors_origins      = join(",", distinct(compact([local.ui_url, local.app_origin])))
  return_urls       = join(",", distinct(compact([local.ui_url, local.hydra_public_url, local.app_origin])))

  repo         = "${var.region}-docker.pkg.dev/${var.project_id}/idp-${var.environment}"
  kratos_image = "${local.repo}/kratos:${var.image_tag}"
  hydra_image  = "${local.repo}/hydra:${var.image_tag}"
  ui_image     = "${local.repo}/ui:${var.image_tag}"

  kratos_dsn_pooled = format(
    "postgres://%s:%s@%s/%s?sslmode=require&pgbouncer=true",
    neon_role.kratos.name,
    urlencode(neon_role.kratos.password),
    neon_project.idp.database_host_pooler,
    neon_database.kratos.name,
  )
  kratos_dsn_direct = format(
    "postgres://%s:%s@%s/%s?sslmode=require",
    neon_role.kratos.name,
    urlencode(neon_role.kratos.password),
    neon_project.idp.database_host,
    neon_database.kratos.name,
  )
  hydra_dsn_pooled = format(
    "postgres://%s:%s@%s/%s?sslmode=require&pgbouncer=true",
    neon_role.hydra.name,
    urlencode(neon_role.hydra.password),
    neon_project.idp.database_host_pooler,
    neon_database.hydra.name,
  )
  hydra_dsn_direct = format(
    "postgres://%s:%s@%s/%s?sslmode=require",
    neon_role.hydra.name,
    urlencode(neon_role.hydra.password),
    neon_project.idp.database_host,
    neon_database.hydra.name,
  )
}
