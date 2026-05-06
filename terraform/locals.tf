locals {

  dev_and_prod_envs = ["development", "production"]

  # Environment short name
  short_envs_map = {
    "development" = "dev",
    "production"  = "prod"
  }

  # Environment Short
  env = local.short_envs_map[terraform.workspace]

  aws_region     = var.aws_region
  aws_profile    = var.aws_profile
  aws_account_id = data.aws_caller_identity.current.account_id
  project        = var.project
  schemas        = ["bronze", "metastore"]
}
