variable VPC_NAME {
  description = "Name of VPC."
}

variable SSM_PATH {
  description = "The path where DB info is stored in SSM."
}

variable APP_NAME {
  description = "Name of App."
}

module "ecs" {
  source = "git::https://bitbucket.org/blackboardinsurance/tf-bbi-modules.git//modules/ecs"

  VPC_NAME     = "${var.VPC_NAME}"
  APP_NAME     = "${var.APP_NAME}"
  XRAY_IMAGE   = "ami-xray"
  XRAY_PORT    = "2000"
  APP_IMAGE    = "slate-api"
  APP_PROTOCOL = "HTTP"
  APP_PORT     = "80"
  APP_COUNT    = "2"
  CPU          = "512"
  MEMORY       = "1024"

  TAGS = "${local.common_tags}"

  SECRETS = <<SECRETS
[
  {
    "name": "DB_DATABASE",
    "valueFrom": "/${var.SSM_PATH}/DB_DATABASE"
  },
  {
    "name": "DB_HOST",
    "valueFrom": "/${var.SSM_PATH}/DB_HOST"
  },
  {
    "name": "DB_PASSWORD",
    "valueFrom": "/${var.SSM_PATH}/DB_PASSWORD"
  },
  {
    "name": "DB_USERNAME",
    "valueFrom": "/${var.SSM_PATH}/DB_USERNAME"
  },
  {
    "name": "FLASK_APP",
    "valueFrom": "/${var.SSM_PATH}/FLASK_APP"
  },
  {
    "name": "FLASK_ENV",
    "valueFrom": "/${var.SSM_PATH}/FLASK_ENV"
  }
]
SECRETS
}

output "image_url" {
  value = "${module.ecs.image_url}"
}

output "lb_hostname" {
  value = "${module.ecs.lb_hostname}"
}
