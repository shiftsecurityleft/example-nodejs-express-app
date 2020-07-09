variable FAMILY {
  default = "examples"
}

variable APP_PREFIX {
  default = "example-nodejs"
}


module "vpc" {
  source = "../modules/vpc"

  VPC_NAME = var.FAMILY
  VPC_CIDR = "10.1.0.0/16"

  TAGS = local.common_tags
}

module "iam_role_demo" {
  source = "../modules/iam/iam-apps/iam-ecs"

  APP_FAMILY = var.FAMILY
  APP_PREFIX = var.APP_PREFIX

  TAGS = local.common_tags
}

module "lb-ext" {
  source = "../modules/alb"

  LB_NAME  = "${var.FAMILY}-ext"
  VPC_ID = module.vpc.vpc_id
  SUBNETS = [ module.vpc.public_subnets ]

  SOURCE_CIDRS = [ "0.0.0.0/0" ]

  TAGS = local.common_tags
}
