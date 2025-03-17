output "sqs_queue_url" {
  value = aws_sqs_queue.main_queue.id
}

output "sqs_aws_cli_command" {
  value = <<EOT
date -u;
for i in {1..X}; do 
  aws sqs send-message \
    --queue-url ${aws_sqs_queue.main_queue.id} \
    --message-body '{"test": "Hello World!"}' \
    --message-group-id "main-group" > /dev/null 2>&1
done
EOT
}

output "sqs_deadletter_aws_cli_command" {
  value = <<EOT
date -u;
for i in {1..X}; do 
  aws sqs send-message \
    --queue-url ${aws_sqs_queue.dead_letter_queue.id} \
    --message-body '{"test": "Retry from DLQ!"}' \
    --message-group-id "dlq-retry-group" > /dev/null 2>&1
done
EOT
}

output "sqs_aws_cli_powershell_command" {
  value = <<EOT
Get-Date -Format "u"
for ($i = 1; $i -le X; $i++) {
  $body = '{\"test\": \"Hello World!\"}'
  aws sqs send-message `
    --queue-url ${aws_sqs_queue.main_queue.id} `
    --message-body $body `
    --message-group-id "main-group" | Out-Null
}
EOT
}

output "sqs_deadletter_aws_cli_powershell_command" {
  value = <<EOT
Get-Date -Format "u"
for ($i = 1; $i -le X; $i++) {
  $body = '{\"test\": \"Retry from DLQ!\"}'
  aws sqs send-message `
    --queue-url ${aws_sqs_queue.dead_letter_queue.id} `
    --message-body $body `
    --message-group-id "dlq-retry-group" | Out-Null
}
EOT
}

