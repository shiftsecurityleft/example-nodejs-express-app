variable VPC_NAME {}

variable SOURCE_CIDRS {
  type = list
}

variable LB_NAME {}

variable LB_DNS_NAME {
  default = "wildcard"
}

variable "TAGS" {
  type = map(string)
}

data "aws_iam_account_alias" "current" {}

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [var.VPC_NAME]
  }
}

data "aws_subnet_ids" "selected" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Tier = "public"
  }
}

# lb Security group
# This is the group you need to edit if you want to restrict access to your application
resource "aws_security_group" "lb" {
  name        = var.LB_NAME
  description = "controls access to the lb"
  vpc_id      = data.aws_vpc.main.id

  tags = merge(
		var.TAGS,
		{
			Name = var.LB_NAME
    }
	)
}

resource "aws_security_group_rule" "allow_http" {
  type      = "ingress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  cidr_blocks = var.SOURCE_CIDRS

  security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "nonrestricted_egress" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.lb.id
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "s3_lb_write" {
  policy_id = "s3_lb_write"

  statement = {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_logs.arn}/${var.LB_NAME}-lb/*"]

    principals = {
      identifiers = [data.aws_elb_service_account.main.arn]
      type        = "AWS"
    }
  }
}

module "s3_logs" {
  source             = "../modules/s3"

  S3_BUCKET          = "${var.LB_NAME}-logs-${data.aws_iam_account_alias.current.account_alias}"
  VERSIONING_ENABLED = false

  TAGS = var.TAGS
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = module.s3_logs.id
  policy = data.aws_iam_policy_document.s3_lb_write.json
}

resource "aws_lb" "this" {
  name               = var.LB_NAME
  load_balancer_type = "application"
  internal           = false

  subnets         = [data.aws_subnet_ids.selected.ids]
  security_groups = [aws_security_group.lb.id]

  access_logs {
    bucket  = module.s3_logs.id
    prefix  = "${var.LB_NAME}-lb"
    enabled = true
  }

  tags = merge(
		var.TAGS,
		{
			Name = var.LB_NAME
    }
	)
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Origin DNS Error: the requested host name could not be resolved on the network to an origin server."
      status_code  = "530"
    }
  }
}

output "lb_dns_name" {
  value = aws_lb.this.dns_name
}
