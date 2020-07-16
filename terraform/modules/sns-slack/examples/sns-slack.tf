variable SLACK_WEBHOOK {
  default = "https://hooks.slack.com/services/XXXX/YYYYYYYYYYYYYYYYY"
}

module "notify_slack" {
  source = "terraform-aws-modules/terraform-aws-notify-slack"

  sns_topic_name = "slack-topic"

  slack_webhook_url = "${var.SLACK_WEBHOOK}"
  slack_channel     = "aws-notification"
  slack_username    = "aws-ops"

  lambda_function_name = "notify-slack"
}

output "this_vpc_notify_slack_arn" {
  description = "The ARN of the Slack Notification SNS Topic"
  value       = "${module.notify_slack.this_slack_topic_arn}"
}
