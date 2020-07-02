variable "APP_PREFIX" {
  description = "Name of the App"
}

variable "TAGS" {
  type = "map"
}

resource "aws_iam_role" "ecstask" {
  name        = "${var.APP_PREFIX}"
  description = "Role to be used by ECS Task Definition"
  path        = "/app/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.APP_PREFIX}"
		)
	)}"
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy-attach" {
  role       = "${aws_iam_role.ecstask.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMReadOnlyAccess-attach" {
  role       = "${aws_iam_role.ecstask.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "AWSXrayFullAccess-attach" {
  role       = "${aws_iam_role.ecstask.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayFullAccess"
}
