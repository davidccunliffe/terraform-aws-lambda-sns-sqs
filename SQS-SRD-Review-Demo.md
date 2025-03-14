# **AWS Security Requirements Document (SRD) for SQS**

This document aligns **Amazon SQS security best practices** with **NIST 800-53** controls to ensure AWS security compliance. Terraform configurations have been integrated to enforce the recommended security policies and controls.

## **SQS Queue Policy Permissions**

### **Description:** 
- Ensure SQS queue policies adhere to the principle of least privilege. 
### **Rationale:**
- Overly permissive queue policies can allow unauthorized access and potential data leakage.  

### **Recommendations:**
- **Use IAM policies** to restrict access to only necessary users and services. *(NIST AC-6: Least Privilege)*
- **Implement condition-based policies** (e.g., IP allow lists, VPC endpoints). *(NIST AC-3: Access Enforcement)*
- **Regularly audit SQS policies** using IAM Access Analyzer. *(NIST CA-7: Continuous Monitoring)*
- **Terraform Implementation:**
  - IAM role policies explicitly define least privilege access.
  - Secure transport enforced via `aws:SecureTransport` condition in IAM.

  Example Below:

  ```json
  # AWS SQS queue (main queue)
  # If queue is FIFO you need to append .fifo to name of resource or will fail
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "sqs.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = local.fifo_queue ? "arn:aws:sqs:<REGION>:<ACCOUNT>:<QUEUE-NAME>.fifo" : "arn:aws:sqs:<REGION>:<ACCOUNT>:<QUEUE-NAME>"
        Condition = {
          "StringEquals" : {
            "aws:SecureTransport" : "true"
          }
        } # (SC-29) Require TLS
      }
    ]
  })
  ```

## **SQS Queue Cost Optimization**

### **Description:** 
- Evaluate the use of SQS for cost optimization.  

### **Rationale:** 
- Efficient use of SQS can reduce costs associated with message processing and storage.  

### **Recommendations:**
- **Enable Dead-Letter Queues (DLQs)** to avoid unnecessary reprocessing. *(NIST SI-4: System Monitoring)*
- **Use long polling** instead of short polling to minimize API calls. *(NIST SC-5: Resource Availability)*
- **Consider using S3 for long-term message storage** instead of keeping messages in SQS. *(NIST MP-6: Media Sanitization for retention control)*
- **Terraform Implementation:**
  - DLQ enabled for failed messages.
  - Long polling configured in `aws_sqs_queue` resource.

  Example Below:

  ```json
  ####################
  # Main & Dead letter queues
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
          Resource  = local.fifo_queue ? "arn:aws:sqs:<REGION>:<ACCOUNT>:<QUEUE-NAME>.fifo" : "arn:aws:sqs:<REGION>:<ACCOUNT>:<QUEUE-NAME>"
          Condition = {
            "StringEquals" : {
              "aws:SecureTransport" : "true"
            }
          } # (SC-29) Require TLS
        }
      ]
    })
  }

  # Retry x number of times before sending to DLQ
  resource "aws_sqs_queue_redrive_policy" "redrive" {
    queue_url = aws_sqs_queue.main_queue.id
    redrive_policy = jsonencode({
      deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
      maxReceiveCount     = 3 # Reduce retries to prevent abuse
    })
  }

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
          Resource  = local.fifo_queue ? "arn:aws:sqs:<REGION>:<ACCOUNT>:<QUEUE-NAME>.fifo" : "arn:aws:sqs:<REGION>:<ACCOUNT>:<QUEUE-NAME>"
          Condition = {
            "StringEquals" : {
              "aws:SecureTransport" : "true"
            }
          } # (SC-29) Require TLS
        }
      ]
    })
  }

  # DLQ poll settings
  resource "aws_lambda_event_source_mapping" "dlq_trigger" {
    event_source_arn = "DLQ ARN"
    function_name    = "Lambda ARN"
    # maximum_batching_window_in_seconds = 300 # Max setting; Not supported with FIFO
    batch_size = 10 # Max setting
    enabled    = true
  }



  ```

## **SQS Queue Monitoring and Alerts**

### **Description:** 
- Set up monitoring and alerts for SQS queue metrics.  

### **Rationale:**
- Monitoring helps detect anomalies, performance issues, and operational problems in queue processing.  

### **Recommendations:**
- **Enable Amazon CloudWatch metrics for SQS.** *(NIST AU-12: Audit Generation)*
- **Set up CloudWatch alarms** for high queue depth, age of oldest message, and API throttling. *(NIST SI-4: System Monitoring)*
- **Enable AWS Config rules** to monitor policy compliance and encryption settings. *(NIST CA-7: Continuous Monitoring)*
- **Terraform Implementation:**
  - CloudWatch alarms configured for queue monitoring.
  - AWS Config enabled for security compliance tracking.

Example Below:

```json
####################
# Cloudwatch metrics to Distribution group
####################
resource "aws_cloudwatch_metric_alarm" "sqs_message_delay_alarm" {
  alarm_name          = "sqs-message-delay-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = 300  # If a message is 5 minutes old, trigger the alarm
  alarm_description   = "Triggers when messages have been waiting for over 5 minutes."
  alarm_actions       = [aws_sns_topic.sqs_alerts.arn]
  dimensions = {
    QueueName = aws_sqs_queue.example_queue.name
  }
}

resource "aws_sns_topic" "sqs_alerts" {
  name = "sqs-alerts-topic"
}

resource "aws_sns_topic_subscription" "sqs_alerts_email" {
  topic_arn = aws_sns_topic.sqs_alerts.arn
  protocol  = "email"
  endpoint  = "distribution-group@example.com"  # Change to your email
}
```

## **SQS Queue Data Transfer Monitoring**

### **Description:**
- Monitor data transfer costs associated with SQS queues.  

### **Rationale:**
- Understanding data transfer patterns helps manage costs and optimize network usage.  

### **Recommendations:**
- **Use VPC endpoints for SQS** to avoid unnecessary public data transfer costs. *(NIST SC-7: Boundary Protection)*
- **Analyze data transfer logs** to identify patterns and optimize usage. *(NIST AU-6: Audit Review, Analysis, and Reporting)*
- **Consider message batching** to reduce API call frequency and associated costs. *(NIST SC-5: Resource Availability)*
- **Terraform Implementation:**
  - VPC endpoints configured for private SQS communication.
  - AWS CloudTrail logs enabled for audit tracking.

Example Below:

```json
####################
# Cloudwatch
####################
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
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
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

####################
# VPC Endpoints
####################

# Create Security Group for VPC
resource "aws_security_group" "inter_vpc_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "inter-vpc-sg"
  }
}

resource "aws_vpc_endpoint" "sqs_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.<region>.sqs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private.id]
}

resource "aws_vpc_endpoint" "sns_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.<region>.sns"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private.id]
}

resource "aws_vpc_endpoint" "kms_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.<region>.kms"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private.id]
}

```

## **SQS Queue Policy Compliance**

### **Description:**
- Validate that SQS queue policies comply with security best practices.  

### **Rationale:**
- Ensuring policy compliance helps maintain security and operational integrity of SQS queues.  

### **Recommendations:**
- **Enforce encryption using AWS Key Management Service (KMS).** *(NIST SC-12: Cryptographic Key Establishment & Management)*
- **Require message signing** for sensitive workloads. *(NIST SC-13: Cryptographic Protection)*
- **Implement AWS Security Hub and AWS Config** to ensure continuous compliance. *(NIST CA-7: Continuous Monitoring)*
- **Terraform Implementation:**
  - KMS encryption enforced for all SQS messages.
  - Security Hub integration for real-time compliance monitoring.

  Example Below:

```json


```

## **Compliance Framework Alignment**
| NIST Control | Description | Implementation in AWS SQS |
|-------------|------------|---------------------------|
| AC-2 | Account Management | IAM policies for SQS queue access |
| AC-3 | Access Enforcement | Restrict permissions using IAM roles |
| AC-6 | Least Privilege | Define least privilege access for SQS queues |
| AU-2 | Audit Events | Enable AWS CloudTrail for SQS events |
| AU-6 | Audit Review & Analysis | Use CloudWatch Logs and AWS Config |
| AU-12 | Audit Generation | CloudTrail logs all API calls |
| CA-7 | Continuous Monitoring | Enable AWS Security Hub & Config rules |
| IR-4 | Incident Handling | Set up event-driven alerts for unauthorized access |
| MP-6 | Media Sanitization | Use S3 lifecycle policies instead of SQS for long-term storage |
| SC-5 | Resource Availability | Optimize polling and data transfer costs |
| SC-7 | Boundary Protection | Use VPC endpoints to secure SQS connections |
| SC-12 | Cryptographic Key Management | Encrypt messages using KMS |
| SC-13 | Cryptographic Protection | Sign messages for data integrity |
| SC-28 | Protection of Information at Rest | Enforce KMS encryption on all messages |
| SC-29 | Protection of Information in Transit | Use TLS for secure communication |