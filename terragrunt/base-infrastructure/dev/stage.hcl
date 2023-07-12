locals {
  stage = "dev"

  tags = {
    environment = local.stage
  }
}