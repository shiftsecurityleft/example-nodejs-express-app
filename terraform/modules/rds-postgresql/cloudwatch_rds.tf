data "aws_sns_topic" "slack" {
  name = "slack-topic"
}

resource "aws_cloudwatch_metric_alarm" "rds-cpuutil" {
  alarm_name          = "${module.db.this_db_instance_name}-rds-cpuhigh"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "monitors RDS cpu utilization"
  alarm_actions       = ["${data.aws_sns_topic.slack.arn}"]

  dimensions {
    DBInstanceIdentifier = "${module.db.this_db_instance_name}"
  }

  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "rds-freestorage" {
  alarm_name          = "${module.db.this_db_instance_name}-rds-storagelow"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1000000000"
  alarm_description   = "monitors RDS free storage"
  alarm_actions       = ["${data.aws_sns_topic.slack.arn}"]

  dimensions {
    DBInstanceIdentifier = "${module.db.this_db_instance_name}"
  }

  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "rds-connections" {
  alarm_name          = "${module.db.this_db_instance_name}-rds-highconns"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "monitors the number of database connections"
  alarm_actions       = ["${data.aws_sns_topic.slack.arn}"]

  dimensions {
    DBInstanceIdentifier = "${module.db.this_db_instance_name}"
  }

  insufficient_data_actions = []
}
