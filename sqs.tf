####################
# AWS SQS
####################

locals {
  fifo_queue = true
}

# Create Encrypted SQS Queue (SC-12, SC-28)
resource "aws_sqs_queue" "main_queue" {
  name                              = local.fifo_queue ? "main-queue.fifo" : "main-queue"
  message_retention_seconds         = 1209600                     # Retain messages for 5 minutes (300 seconds) but can go up to 14 days (1209600 seconds) default is 4 days for terraform
  visibility_timeout_seconds        = 30                          # Hide message for 30 seconds
  kms_master_key_id                 = aws_kms_key.sqs_kms_key.arn # Encrypt SQS messages
  kms_data_key_reuse_period_seconds = 300                         # Reuse data keys for 5 minutes
  fifo_queue                        = local.fifo_queue
  content_based_deduplication       = local.fifo_queue

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "sqs.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = local.fifo_queue ? "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:main-queue.fifo" : "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:main-queue"
        Condition = {
          "StringEquals" : {
            "aws:SecureTransport" : "true"
          }
        } # (SC-29) Require TLS
      }
    ]
  })
}

# Dead Letter Queue (DLQ) for Failure Handling
resource "aws_sqs_queue" "dead_letter_queue" {
  name                        = local.fifo_queue ? "dlq.fifo" : "dlq"
  message_retention_seconds   = 1209600 # Retain messages for 14 days MAX SETTING
  kms_master_key_id           = aws_kms_key.sqs_kms_key.arn
  visibility_timeout_seconds  = 60 # Hide message for 60 seconds
  fifo_queue                  = local.fifo_queue
  content_based_deduplication = local.fifo_queue

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "sqs.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = local.fifo_queue ? "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:dlq.fifo" : "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:dlq"
        Condition = {
          "StringEquals" : {
            "aws:SecureTransport" : "true"
          }
        } # (SC-29) Require TLS
      }
    ]
  })
}

resource "aws_sqs_queue_redrive_policy" "redrive" {
  queue_url = aws_sqs_queue.main_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = 3 # Reduce retries to prevent abuse
  })
}

# Create VPC Endpoint for SQS (SC-7)
resource "aws_vpc_endpoint" "sqs_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sqs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private.id]
}


# Enable AWS CloudTrail for SQS Logging (AU-2, AU-12)
resource "aws_cloudtrail" "sqs_audit_trail" {
  name                          = "sqs-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  enable_log_file_validation    = true
}

# Create S3 Bucket for CloudTrail Logs (AU-2, AU-6, AU-12)
resource "aws_s3_bucket" "audit_logs" {
  bucket = "sqs-audit-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "audit_logs_versioning" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "audit_logs_policy" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck20150319"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite20150319"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
