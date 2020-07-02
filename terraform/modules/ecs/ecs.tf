variable "VPC_NAME" {}

# temporary variable for listener rule
variable "DOMAIN" {}

variable "APP_NAME" {
  description = "Name of the App"
}

variable "APP_IMAGE" {
  description = "Docker image in ECR to run in the ECS cluster"
}

variable "APP_IMAGE_TAG" {
  description = "Docker image tag in ECR to run in the ECS cluster"
}

variable "APP_PROTOCOL" {
  description = "App's protocol"
}

variable "APP_PORT" {
  description = "Port exposed by the docker image to redirect traffic to"
}

variable "DATADOG_IMAGE" {
  description = "Docker image in ECR to run in the ECS cluster"
  default     = "datadog/agent"
}

variable "DATADOG_IMAGE_TAG" {
  default = "latest"
}

variable "DATADOG_APP_KEY" {
  default = ""
} 

variable "DATADOG_API_KEY" {
  default = ""
}

variable "DATADOG_ENABLED" {
  default = false
}


variable "APP_COUNT" {
  description = "Number of docker containers to run"
}

variable "CPU" {
  description = "Fargate instance CPU units.  Refer https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html"
}

variable "MEMORY" {
  description = "Fargate instance memory.  Refer https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html"
}

variable "SECRETS" {
  description = "JSON format of secrets from SSM"
  default     = "null"
}

variable "ENVIRONMENT" {
  description = "JSON format of env vars"
  default     = "null"
}

variable DNS_NAME {}

variable "ROLE_NAME" {
  default = ""
}

variable "TAGS" {
  type = "map"
}

variable "HEALTHCHECK_URI" {}

variable "HEALTHCHECK_GRACE_PERIOD_SEC" {
  default = 30
}

variable "OIDC_AUTHENTICATION" {
  default = false
}

variable "OIDC_CLIENT_SECRET" {
  default = "null"
}

variable "OIDC_CLIENT_ID" {
  default = "null"
}

variable "OIDC_ISSUER" {
  default = "null"
}

variable "INTERNAL_ONLY" {
  default = false
}

variable "INTERNAL_DOMAIN" {
  default = "null"
}

variable "LB_EXT_POSTFIX" {
  default = "-ext"
}

variable "SECURITYGROUP_EXT_POSTFIX" {
  default = "-ext"
}

# provider "datadog" {
#   api_key = "${var.DATADOG_API_KEY}"
#   app_key = "${var.DATADOG_APP_KEY}"
# }

data "aws_iam_account_alias" "current" {}

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.VPC_NAME}"]
  }
}

data "aws_region" "current" {}

# Fetch AZs in the current region
data "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.ROLE_NAME == "" ? var.VPC_NAME : var.ROLE_NAME}"
}

data "aws_ecr_repository" "app" {
  name = "${var.APP_IMAGE}"
}

data "aws_subnet_ids" "private" {
  vpc_id = "${data.aws_vpc.main.id}"

  tags = {
    Tier = "private"
  }
}

data "aws_security_group" "lb" {
  name = "${var.VPC_NAME}${var.INTERNAL_ONLY ? "-int":"${var.SECURITYGROUP_EXT_POSTFIX}"}"
}

data "aws_lb" "main" {
  name = "${var.VPC_NAME}${var.INTERNAL_ONLY ? "-int":"${var.LB_EXT_POSTFIX}"}"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = "${data.aws_lb.main.arn}"
  port              = 443
}

locals {
  DOMAIN = "${var.INTERNAL_ONLY ? var.INTERNAL_DOMAIN:var.DOMAIN}"
}

### Security

resource "aws_security_group_rule" "allow_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.ecs_tasks.id}"

  security_group_id = "${data.aws_security_group.lb.id}"
}

# Traffic to the ECS Cluster should only come from the lb
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.APP_NAME}-ecs-tasks"
  description = "allow inbound access from the lb only"
  vpc_id      = "${data.aws_vpc.main.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.APP_PORT}"
    to_port         = "${var.APP_PORT}"
    security_groups = ["${data.aws_security_group.lb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.APP_NAME}-ecs-tasks"
		)
	)}"
}

# Redirect all traffic from the lb to the target group
resource "aws_lb_target_group" "app" {
  name        = "${var.APP_NAME}"
  port        = "${var.APP_PORT}"
  protocol    = "${var.APP_PROTOCOL}"
  vpc_id      = "${data.aws_vpc.main.id}"
  target_type = "ip"

  health_check {
    protocol = "${var.APP_PROTOCOL}"
    port = "traffic-port"
    path    = "${var.HEALTHCHECK_URI}"
    matcher = "200-299"
  }

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.APP_NAME}"
		)
	)}"
}

# Redirect all traffic from the lb to the target group
resource "aws_lb_listener_rule" "status" {
  listener_arn = "${data.aws_lb_listener.https.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.app.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["${var.HEALTHCHECK_URI}"]
  }

  condition {
    field  = "host-header"
    values = ["${var.DNS_NAME}.${local.DOMAIN}"]
  }
}

# Provision only if OIDC_AUTHENTICATION is false
resource "aws_lb_listener_rule" "host_based_routing" {
  count = "${var.OIDC_AUTHENTICATION ? 0:1}"

  listener_arn = "${data.aws_lb_listener.https.arn}"

  #priority = 99

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.app.arn}"
  }
  condition {
    field  = "host-header"
    values = ["${var.DNS_NAME}.${local.DOMAIN}"]
  }
  depends_on = ["aws_lb_listener_rule.status"]
}

# Provision only if OIDC_AUTHENTICATION is true
resource "aws_lb_listener_rule" "host_based_routing_with_oidc" {
  count = "${var.OIDC_AUTHENTICATION ? 1:0}"

  listener_arn = "${data.aws_lb_listener.https.arn}"

  action {
    type = "authenticate-oidc"

    authenticate_oidc {
      authorization_endpoint = "${var.OIDC_ISSUER}/v1/authorize"
      client_id              = "${var.OIDC_CLIENT_ID}"
      client_secret          = "${var.OIDC_CLIENT_SECRET}"
      issuer                 = "${var.OIDC_ISSUER}"
      token_endpoint         = "${var.OIDC_ISSUER}/v1/token"
      user_info_endpoint     = "${var.OIDC_ISSUER}/v1/userinfo"
    }
  }

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.app.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${var.DNS_NAME}.${local.DOMAIN}"]
  }

  depends_on = ["aws_lb_listener_rule.status"]
}

### ECS
resource "aws_ecs_cluster" "main" {
  name = "${var.APP_NAME}"
  capacity_providers = ["FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = "1"
    base = "1"
  }

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.APP_NAME}"
		)
	)}"
}

resource "aws_cloudwatch_log_group" "log" {
  name = "/ecs/${var.APP_NAME}"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","/ecs/${var.APP_NAME}"
		)
	)}"
}

resource "aws_ecs_task_definition" "app" {
  count                    = "${var.DATADOG_ENABLED == "YES" ? 0 : 1}"
  family                   = "${var.APP_NAME}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.CPU}"
  memory                   = "${var.MEMORY}"
  execution_role_arn       = "${data.aws_iam_role.ecs_task_execution_role.arn}"
  task_role_arn            = "${data.aws_iam_role.ecs_task_execution_role.arn}"

  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.CPU},
    "image": "${data.aws_ecr_repository.app.repository_url}:${var.APP_IMAGE_TAG}",
    "memory": ${var.MEMORY},
    "name": "${var.APP_NAME}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${var.APP_PORT},
        "hostPort": ${var.APP_PORT}
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.log.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "ecs"
      }
    },    
    "secrets": ${var.SECRETS},
    "environment": ${var.ENVIRONMENT}
  }
]
DEFINITION

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.APP_NAME}"
		)
	)}"
}

resource "aws_ecs_task_definition" "app_with_sidecar" {
  count                    = "${var.DATADOG_ENABLED == "YES" ? 1 : 0}"
  family                   = "${var.APP_NAME}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.CPU}"
  memory                   = "${var.MEMORY}"
  execution_role_arn       = "${data.aws_iam_role.ecs_task_execution_role.arn}"
  task_role_arn            = "${data.aws_iam_role.ecs_task_execution_role.arn}"

  container_definitions = <<DEFINITION
[
  {
    "cpu": 0,
    "name": "datadog",
    "image": "${var.DATADOG_IMAGE}:${var.DATADOG_IMAGE_TAG}",
    "memory": null,
    "essential": true,
    "environment": [
      {
        "name": "DD_API_KEY",
        "value": "${var.DATADOG_API_KEY}"
      },
      {
        "name": "DD_SITE",
        "value": "datadoghq.com"
      },
      {
        "name": "ECS_FARGATE",
        "value": "true"
      },
      {
        "name": "DD_APM_ENABLED",
        "value": "true"
      }
    ]
  },
  {
    "cpu": ${var.CPU},
    "image": "${data.aws_ecr_repository.app.repository_url}:${var.APP_IMAGE_TAG}",
    "memory": ${var.MEMORY},
    "name": "${var.APP_NAME}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${var.APP_PORT},
        "hostPort": ${var.APP_PORT}
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.log.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "ecs"
      }
    },    
    "secrets": ${var.SECRETS},
    "environment": ${var.ENVIRONMENT}
  }
]
DEFINITION

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.APP_NAME}"
		)
	)}"
}

resource "aws_ecs_service" "main" {
  name                              = "${var.APP_NAME}"
  cluster                           = "${aws_ecs_cluster.main.id}"
  task_definition                   = "${var.DATADOG_ENABLED == "YES" ? aws_ecs_task_definition.app_with_sidecar.0.arn : aws_ecs_task_definition.app.0.arn}"
  desired_count                     = "${var.APP_COUNT}"
/**
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = "1"
    base = "2"
  }
*/  
  #launch_type                       = "FARGATE"
  health_check_grace_period_seconds = "${var.HEALTHCHECK_GRACE_PERIOD_SEC}"

  network_configuration {
    security_groups = ["${aws_security_group.ecs_tasks.id}"]
    subnets         = "${data.aws_subnet_ids.private.ids}"
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.app.id}"
    container_name   = "${var.APP_NAME}"
    container_port   = "${var.APP_PORT}"
  }

  ## The new ARN and resource ID format must be enabled to add tags to the service
  #enable_ecs_managed_tags          = true
  #propagate_tags                   = "SERVICE"
  #tags = "${merge(
  #var.TAGS,
  #	map(
  #		"Name","${var.APP_NAME}"
  #	)
  #)}"
  depends_on = [
    "aws_ecs_task_definition.app",
    "aws_ecs_task_definition.app_with_sidecar"
  ]
}

# resource "datadog_monitor" "cpumonitor" {
#   name = "${var.APP_NAME} cpu monitor"
#   type = "metric alert"
#   message = "CPU usage alert"
#   query = "avg(last_1m):avg:system.cpu.system{*} by {host} > 60"
# }

# output "dd_monitor_id" {
#   value = "${datadog_monitor.cpumonitor.id}"
# }

output "image_url" {
  value = "${data.aws_ecr_repository.app.repository_url}:${var.APP_IMAGE_TAG}"
}

output "lb_hostname" {
  value = "${data.aws_lb.main.dns_name}"
}

output "listener_https_url" {
  value = "https://${var.DNS_NAME}.${local.DOMAIN}"
}

output "subnets" {
  value = "${join(", ", data.aws_subnet_ids.private.ids)}"
}
output "security_groups" {
  value = "${aws_security_group.ecs_tasks.id}"
}