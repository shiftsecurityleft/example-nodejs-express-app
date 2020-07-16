variable LAMBDA_NAME {}
variable LAMBDA_HANDLER {}
variable LAMBDA_ZIPFILE {}

variable LAMBDA_ROLE {}

variable LAMBDA_RUNTIME {
  description = "nodejs6.10 | nodejs8.10 | java8 | python2.7 | python3.6 | python3.7 | dotnetcore1.0 | dotnetcore2.0 | dotnetcore2.1 | go1.x | ruby2.5 | provided"
}

variable "TAGS" {
  type = "map"
}

data "aws_iam_role" "lambda" {
  name = "${var.LAMBDA_ROLE}"
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.LAMBDA_NAME}-dlq"
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 10

  # Enable Server Side Encryption
  kms_master_key_id                 = "alias/aws/sqs"
  kms_data_key_reuse_period_seconds = 300

  tags = "${merge(
		"${var.TAGS}",
		map(
			"Name","${var.LAMBDA_NAME}-dlq"
		)
	)}"
}

resource "aws_sqs_queue" "sqs_queue" {
  name                      = "${var.LAMBDA_NAME}-sqs"
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 3600
  receive_wait_time_seconds = 10
  redrive_policy            = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.dlq.arn}\",\"maxReceiveCount\":3}"

  # Enable Server Side Encryption
  kms_master_key_id                 = "alias/aws/sqs"
  kms_data_key_reuse_period_seconds = 300

  tags = "${merge(
		"${var.TAGS}",
		map(
			"Name","${var.LAMBDA_NAME}-sqs"
		)
	)}"

  depends_on = ["aws_sqs_queue.dlq"]
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.LAMBDA_NAME}"
  role             = "${data.aws_iam_role.lambda.arn}"
  handler          = "${var.LAMBDA_HANDLER}"
  filename         = "${path.root}/${var.LAMBDA_ZIPFILE}"
  source_code_hash = "${base64sha256(file("${path.root}/${var.LAMBDA_ZIPFILE}"))}"
  runtime          = "${var.LAMBDA_RUNTIME}"

  environment {
    variables = {
      SQS_URL = "${aws_sqs_queue.sqs_queue.id}"
    }
  }

  tags = "${merge(
		"${var.TAGS}",
		map(
			"Name","${var.LAMBDA_NAME}"
		)
	)}"
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = "${aws_sqs_queue.sqs_queue.arn}"
  function_name    = "${aws_lambda_function.this.arn}"
}

resource "aws_cloudwatch_log_group" "cloudwatch_log_notications" {
  name = "/aws/lambda/${aws_lambda_function.this.function_name}"

  tags = "${merge(
		"${var.TAGS}",
		map(
			"Name","${aws_lambda_function.this.function_name} CloudWatch Logs"
		)
	)}"
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = "${aws_lambda_function.this.arn}"
}

output "lambda_function_invoke_arn" {
  description = "The ARN of the Lambda function"
  value       = "${aws_lambda_function.this.invoke_arn}"
}

output "sqs_queue_arn" {
  description = "The ARN of the SQS"
  value       = "${aws_sqs_queue.sqs_queue.arn}"
}

output "sqs_queue_id" {
  description = "The Id of the SQS"
  value       = "${aws_sqs_queue.sqs_queue.id}"
}

output "role_arn" {
  description = "The ARN of the IAM Role for lambda"
  value       = "${data.aws_iam_role.lambda.arn}"
}

output "dlq_arn" {
  description = "The ARN of the DLQ"
  value       = "${aws_sqs_queue.dlq.arn}"
}

output "dlq_id" {
  description = "The Id of the notifications DLQ"
  value       = "${aws_sqs_queue.dlq.id}"
}
