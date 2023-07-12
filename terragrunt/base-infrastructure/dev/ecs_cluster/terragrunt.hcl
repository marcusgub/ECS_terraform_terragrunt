include "root" {
  path   = find_in_parent_folders("root-config.hcl")
  expose = true
}

include "stage" {
  path   = find_in_parent_folders("stage.hcl")
  expose = true
}

locals {
  # merge tags
  local_tags = {
    "Name" = "ecs-cluster"
  }

  tags = merge(include.root.locals.root_tags, include.stage.locals.tags, local.local_tags)
}
dependency "aws_alb" {
  config_path = "${get_terragrunt_dir()}/..//aws_alb"
  mock_outputs_allowed_terraform_commands = ["apply"]
}

# dependency "aws_alb" {
#   config_path                             = "${get_parent_terragrunt_dir("root")}/base-infrastructure/dev/aws_alb"
#   mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
#   mock_outputs = {
#     aws_alb_arn          = "arn:aws:elasticloadbalancing:us-west-2:643202173500:loadbalancer/nginx/9XXX000XXX000XXX"
#     aws_sg_egress_all_id = "some-id"
#   }

generate "provider_global" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  backend "s3" {}
  required_version = "${include.root.locals.version_terraform}"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "${include.root.locals.version_provider_aws}"
    }
  }
}

provider "aws" {
  region = "${include.root.locals.region}"
}
EOF
}

inputs = {
  name = "ecs-cluster"
  tags = local.tags
}

terraform {
  source = "${get_parent_terragrunt_dir("root")}/..//terraform/ecs_cluster"
}