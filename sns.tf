# Create SNS Topic
resource "aws_sns_topic" "alerts" {
  name = "alerts-topic"
}

# Create SNS Subscription
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "davidccunliffe@gmail.com"
}

# Create VPC Endpoint for SNS (SC-7)
resource "aws_vpc_endpoint" "sns_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sns"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private.id]
}
