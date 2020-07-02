resource "aws_security_group" "allow_rds" {
  name        = "${local.tag_name}-allow-rds"
  description = "Allow all RDS inbound traffic"
  vpc_id      = "${data.aws_vpc.default.id}"

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = "${merge(
		var.TAGS,
		map(
      "Name", "${local.tag_name}-allow-rds"
		)
	)}"
}
