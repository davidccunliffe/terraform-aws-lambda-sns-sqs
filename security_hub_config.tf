#  Enable AWS Security Hub & Config for Continuous Monitoring (CA-7)
# resource "aws_securityhub_account" "security_hub" {}

# resource "aws_config_configuration_recorder" "config_recorder" {
#   name     = "default"
#   role_arn = aws_iam_role.config_role.arn
# }

resource "aws_iam_role" "config_role" {
  name = "AWSConfigRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}


# Create SNS Topic for Security Alerts (IR-4)
resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
}

# Create Cloudwatch Log Group for CloudTrail sqs (IR-4)
resource "aws_cloudwatch_log_group" "sqs_log_group" {
  name = "/aws/cloudtrail/sqs"
}

# CloudWatch Alarm for Unauthorized SQS Access (IR-4)
resource "aws_cloudwatch_log_metric_filter" "unauthorized_sqs_access" {
  name           = "UnauthorizedSQSAccess"
  log_group_name = aws_cloudwatch_log_group.sqs_log_group.name
  pattern        = "{ ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedSQSActions"
    namespace = "Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_security_alert" {
  alarm_name          = "UnauthorizedSQSAccess"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedSQSActions"
  namespace           = "Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
