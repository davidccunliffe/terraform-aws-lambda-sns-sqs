####################
# AWS Encryption
####################
# Create KMS Key for Encrypting SQS (SC-12, SC-28)
resource "aws_kms_key" "sqs_kms_key" {
  description         = "KMS key for SQS encryption"
  enable_key_rotation = true
}

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
