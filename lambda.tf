# Create Lambda Function
resource "aws_lambda_function" "lambda" {
  filename      = "${path.module}/lambda/lambda.zip"
  function_name = "vpc_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.main_queue.id
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


# Create IAM Policy for Least Privilege SQS Access (AC-2, AC-3, AC-6)
resource "aws_iam_policy" "sqs_policy" {
  name        = "SQSLeastPrivilegePolicy"
  description = "IAM policy for Lambda to access SQS with least privilege"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = [
          aws_sqs_queue.main_queue.arn,       # Allow main queue access
          aws_sqs_queue.dead_letter_queue.arn # Allow DLQ access
        ]
      },
      {
        Effect = "Deny" # Prevent non-secure access (SC-29)
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage"
        ]
        Resource = [
          aws_sqs_queue.main_queue.arn,
          aws_sqs_queue.dead_letter_queue.arn
        ]
        Condition = {
          "Bool" : {
            "aws:SecureTransport" : "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  policy_arn = aws_iam_policy.sqs_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# Attach IAM Policies to Lambda Role
resource "aws_iam_policy_attachment" "lambda_basic_exec" {
  name       = "lambda-basic-exec"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy_attachment" "lambda_vpc_exec" {
  name       = "lambda-vpc-exec"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Give Lambda Permission to Send Messages to send messages to cloudwatch
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_lambda_permission" "cloudwatch_logs" {
  statement_id  = "AllowExecutionToCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = aws_cloudwatch_log_group.lambda_logs.arn
}

resource "aws_security_group" "lambda_sg" {
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
    Name = "lambda-sg"
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main_queue.arn
  function_name    = aws_lambda_function.lambda.arn
  batch_size       = 5
  enabled          = true
}

# Create VPCE for logs that Lambda can use
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private.id]
}


resource "aws_iam_policy" "lambda_kms_policy" {
  name        = "LambdaKMSDecryptPolicy"
  description = "IAM policy for Lambda to decrypt SQS messages using KMS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey" # Required for decrypting messages in the DLQ
        ]
        Resource = aws_kms_key.sqs_kms_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_kms_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_kms_policy.arn
  role       = aws_iam_role.lambda_role.name
}


resource "aws_iam_policy" "lambda_sns_publish" {
  name        = "LambdaSNSPublishPolicy"
  description = "IAM policy for Lambda to publish messages to SNS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sns_publish_attachment" {
  policy_arn = aws_iam_policy.lambda_sns_publish.arn
  role       = aws_iam_role.lambda_role.name
}



#####################
# DLQ Lambda Function
#####################

resource "aws_lambda_function" "dlq_processor" {
  filename      = "dlq_processor.zip"
  function_name = "dlq_processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "dlq_processor.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  environment {
    variables = {
      DLQ_URL        = aws_sqs_queue.dead_letter_queue.id
      MAIN_QUEUE_URL = aws_sqs_queue.main_queue.id
    }
  }
}

resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  event_source_arn = aws_sqs_queue.dead_letter_queue.arn
  function_name    = aws_lambda_function.dlq_processor.arn
  batch_size       = 5
  enabled          = true
}

