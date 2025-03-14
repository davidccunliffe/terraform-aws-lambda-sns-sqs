####################
# AWS Encryption
####################
# # Create KMS Key for Encrypting SQS (SC-12, SC-28)
# resource "aws_kms_key" "sqs_kms_key" {
#   description         = "KMS key for SQS encryption"
#   enable_key_rotation = true
# }

# resource "aws_kms_alias" "sqs_kms_alias" {
#   name          = "alias/sqsEncryptionKey"
#   target_key_id = aws_kms_key.sqs_kms_key.id
# }

# # KMS Key Resource Policy (SC-12, SC-28)
# resource "aws_kms_grant" "sqs_kms_grant" {
#   name              = "AllowLambdaToDecrypt"
#   key_id            = aws_kms_key.sqs_kms_key.id
#   grantee_principal = aws_iam_role.lambda_role.arn
#   operations        = ["Decrypt", "GenerateDataKey"]
# }

# # Create KMS VPC Endpoint Policy (SC-7)
# resource "aws_vpc_endpoint" "kms_endpoint" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.us-east-1.kms"
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.inter_vpc_sg.id]
#   private_dns_enabled = true

#   subnet_ids = [aws_subnet.private.id]
# }


####################
# AWS Encryption - KMS for SQS
####################

# Create KMS Key for Encrypting SQS (SC-12, SC-28)
resource "aws_kms_key" "sqs_kms_key" {
  description         = "KMS key for SQS encryption"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "sqs-kms-key-policy"
    Statement = [
      # Allow the AWS account full control over the key
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },

      # Allow Lambda Role and DQL to use the key (for processing messages)
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },

      # # Allow DLQ Lambda Role to use the key (for processing dead-letter messages)
      # {
      #   Effect = "Allow"
      #   Principal = {
      #     AWS = aws_iam_role.dlq_lambda_role.arn
      #   }
      #   Action = [
      #     "kms:Decrypt",
      #     "kms:GenerateDataKey"
      #   ]
      #   Resource = "*"
      # },

      # Allow SQS to use the key for encryption/decryption
      {
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "sqs.us-east-1.amazonaws.com"
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# KMS Alias
resource "aws_kms_alias" "sqs_kms_alias" {
  name          = "alias/sqsEncryptionKey"
  target_key_id = aws_kms_key.sqs_kms_key.id
}

# Create KMS VPC Endpoint Policy (SC-7)
resource "aws_vpc_endpoint" "kms_endpoint" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.kms"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.inter_vpc_sg.id]
  private_dns_enabled = true

  subnet_ids = [aws_subnet.private.id]
}
