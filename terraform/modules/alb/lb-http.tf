resource "aws_security_group_rule" "allow_http" {
  type      = "ingress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
  cidr_blocks = "${var.SOURCE_CIDRS}"

  security_group_id = "${aws_security_group.lb.id}"
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.this.arn}"
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
    field  = "path-pattern"
    values = ["*"]
  }
}
