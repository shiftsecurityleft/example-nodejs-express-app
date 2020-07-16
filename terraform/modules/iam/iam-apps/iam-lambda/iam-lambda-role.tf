variable "FAMILY" {
  description = "Name of the App Family"
}

variable "APP_PREFIX" {
  description = "Name of the App"
}

variable "TAGS" {
  type = "map"
}

resource "aws_iam_role" "lambda" {
  name        = "${var.APP_PREFIX}"
  description = "Role to be used by Lambda Function"
  path        = "/app/${var.FAMILY}/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
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

resource "aws_iam_role_policy" "default" {
  name = "${var.APP_PREFIX}"
  role = "${aws_iam_role.lambda.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "sns:Publish",
        "ses:SendEmail"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

output "this_lambda_service_role_id" {
  description = "The ID of this Lambda service IAM role"
  value       = "${aws_iam_role.lambda.id}"
}
