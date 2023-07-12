locals {
  region = "us-west-2"

  version_terraform    = ">=1.2.1"
  version_terragrunt   = ">=0.37.1"
  version_provider_aws = ">=4.15.1"

  root_tags = {
    project = "ecs-terraform-terragrunt"
  }
}

generate "provider_global" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = "${local.version_terraform}"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "${local.version_provider_aws}"
    }
  }
}

provider "aws" {
  region = "${local.region}"
}
EOF
}


remote_state {
  backend = "s3"
  config = {
    bucket         = "bucket-bkp-velero"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    encrypt        = true
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-table"
  }
}