variable DOMAIN {}

variable VPC_NAME {}

variable INTERNAL {
  default = true
}

variable PROXYED {
  description = "True if using an external DNS service like CloudFlare to proxy this, the resulting NDS name will be <Account alias>-wildcard"
  default = false
}

variable SOURCE_CIDRS {
  type = "list"
}

variable LB_NAME {}

variable LB_DNS_NAME {
  default = "wildcard"
}

variable "TAGS" {
  type = "map"
}

data "aws_iam_account_alias" "current" {}

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.VPC_NAME}"]
  }
}

data "aws_subnet_ids" "selected" {
  vpc_id = "${data.aws_vpc.main.id}"

  tags = {
    Tier = "${var.INTERNAL ? "private":"public"}"
  }
}

locals {
  alias     = "${lower(data.aws_iam_account_alias.current.account_alias)}"
  subdomain = "${lower(data.aws_iam_account_alias.current.account_alias)}.${var.DOMAIN}"
}

data "aws_route53_zone" "selected" {
  name = "${local.subdomain}"
}

data "aws_acm_certificate" "wildcard" {
  domain      = "*.${local.subdomain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

# lb Security group
# This is the group you need to edit if you want to restrict access to your application
resource "aws_security_group" "lb" {
  name        = "${var.LB_NAME}"
  description = "controls access to the lb"
  vpc_id      = "${data.aws_vpc.main.id}"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.LB_NAME}"
		)
	)}"
}

/**
resource "aws_security_group_rule" "allow_http" {
  type      = "ingress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  cidr_blocks = ["173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22", "141.101.64.0/18", "108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22", "198.41.128.0/17", "162.158.0.0/15", "104.16.0.0/12", "172.64.0.0/13", "131.0.72.0/22", "12.171.137.115/32", "199.120.242.115/32"]

  security_group_id = "${aws_security_group.lb.id}"
}
*/

resource "aws_security_group_rule" "allow_https" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  #cidr_blocks = ["173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22", "141.101.64.0/18", "108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22", "198.41.128.0/17", "162.158.0.0/15", "104.16.0.0/12", "172.64.0.0/13", "131.0.72.0/22", "12.171.137.115/32", "199.120.242.115/32"]
  cidr_blocks = "${var.SOURCE_CIDRS}"

  security_group_id = "${aws_security_group.lb.id}"
}

resource "aws_security_group_rule" "nonrestricted_egress" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.lb.id}"
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "s3_lb_write" {
  policy_id = "s3_lb_write"

  statement = {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_logs.arn}/${var.LB_NAME}-lb/*"]

    principals = {
      identifiers = ["${data.aws_elb_service_account.main.arn}"]
      type        = "AWS"
    }
  }
}

module "s3_logs" {
  source             = "../modules/s3"
  S3_BUCKET          = "${var.LB_NAME}-logs-${data.aws_iam_account_alias.current.account_alias}"
  VERSIONING_ENABLED = false

  TAGS = "${var.TAGS}"
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = "${module.s3_logs.id}"
  policy = "${data.aws_iam_policy_document.s3_lb_write.json}"
}

resource "aws_lb" "this" {
  name               = "${var.LB_NAME}"
  load_balancer_type = "application"
  internal           = "${var.INTERNAL ? true:false}"

  subnets         = ["${data.aws_subnet_ids.selected.ids}"]
  security_groups = ["${aws_security_group.lb.id}"]

  access_logs {
    bucket  = "${module.s3_logs.id}"
    prefix  = "${var.LB_NAME}-lb"
    enabled = true
  }

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.LB_NAME}"
		)
	)}"

  depends_on = ["module.s3_logs"]
}

resource "aws_route53_record" "wild" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${var.PROXYED ? "wildcard-${local.alias}" : "*"}"
  type    = "CNAME"
  ttl     = "30"

  records = ["${aws_lb.this.dns_name}"]
}

/**
resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = "${aws_lb_listener.http.arn}"

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    field  = "host-header"
    values = ["*${var.DOMAIN}"]
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.int.arn}"
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
*/

resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.this.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.wildcard.arn}"

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
  value = "${aws_lb.this.dns_name}"
}
