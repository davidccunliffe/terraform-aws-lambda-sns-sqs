# Create SNS FIFO Topic
resource "aws_sns_topic" "main_queue" {
  name                        = "main-queue-topic.fifo"
  fifo_topic                  = true
  content_based_deduplication = false # We control deduplication manually using MessageDeduplicationId
}

# Create SNS Subscription (Note: Email protocol is **not supported** for FIFO topics)
# FIFO topics only support SQS, Lambda, HTTPS, or application endpoints (not email or SMS).
# So we'll remove this or update it to an SQS FIFO queue subscription.

# Example: Subscribe to an SQS FIFO Queue
resource "aws_sns_topic_subscription" "sqs_sub" {
  topic_arn            = aws_sns_topic.main_queue.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.main_queue.arn # You need to define this FIFO SQS Queue
  raw_message_delivery = true
}

# # Example FIFO SQS Queue
# resource "aws_sqs_queue" "alerts_queue" {
#   name                        = "alerts-queue.fifo"
#   fifo_queue                  = true
#   content_based_deduplication = false
# }

# Create VPC Endpoint for SNS (SC-7)
resource "aws_vpc_endpoint" "sns_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sns"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private.id]
}

