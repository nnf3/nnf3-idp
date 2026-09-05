module "idp" {
  source = "../../modules/idp"

  environment           = "dev"
  project_id            = var.project_id
  region                = var.region
  neon_org_id           = var.neon_org_id
  smtp_connection_uri   = var.smtp_connection_uri
  app_origin            = var.app_origin
  image_tag             = var.image_tag
  first_party_client_id = var.first_party_client_id

  min_instance_count      = 0
  max_instance_count      = 1
  deletion_protection     = false
  neon_autoscaling_max_cu = 1
}
