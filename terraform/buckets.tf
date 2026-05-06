################################################################################
# S3 Buckets
# https://github.com/terraform-aws-modules/terraform-aws-s3-bucket/tree/master
###############################################################################

module "s3_buckets" {

  for_each = contains(local.dev_and_prod_envs, terraform.workspace) ? toset(local.schemas) : []

  # Module version
  source = "terraform-aws-modules/s3-bucket/aws"

  # Version
  version = "~> 3.14.0"

  # Bucket name
  bucket = format("%s-%s-%s-%s-%s", local.project, local.env, local.aws_region, local.aws_account_id, each.key)

  # Additional tags
  tags = {
    "project" = local.project,
    "schemas"   = each.value
  }

}