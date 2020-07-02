variable DOMAIN {}

variable "TAGS" {
  type = "map"
}

/*
variable "LB" {
  type = "string"
}
*/

data "aws_iam_account_alias" "current" {}

/*
data "aws_lb" "defaultlb" {
  name = "${var.LB}"
}
*/

locals {
  alias     = "${lower(data.aws_iam_account_alias.current.account_alias)}"
  subdomain = "${lower(data.aws_iam_account_alias.current.account_alias)}.${var.DOMAIN}"
}

data "aws_route53_zone" "main" {
  name = "${local.subdomain}"
}

/*
resource "aws_route53_zone" "main" {
  name = "${local.subdomain}"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${local.subdomain}"
		)
	)}"
}
*/

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.${local.subdomain}"
  validation_method = "DNS"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${local.subdomain}"
		)
	)}"

  lifecycle {
    create_before_destroy = true
  }
}

/*
resource "aws_route53_record" "wild" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "*"
  type    = "CNAME"
  ttl     = "30"

  records = ["${data.aws_lb.defaultlb.dns_name}"]
}
*/

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.main.id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60

  #  depends_on = ["aws_acm_certificate.cert"]
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]

  #  depends_on = ["aws_acm_certificate.cert"]
}

output "fqdn" {
  value = "${aws_acm_certificate.cert.domain_name}"
}

output "subdomain" {
  value = "${data.aws_route53_zone.main.name}"
}
