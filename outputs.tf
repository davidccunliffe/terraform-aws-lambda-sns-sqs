output "sqs_queue_url" {
  value = aws_sqs_queue.main_queue.id
}

output "sqs_aws_cli_command" {
  value = <<EOT
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
for i in {1..X}; do 
  aws sqs send-message \
    --queue-url ${aws_sqs_queue.dead_letter_queue.id} \
    --message-body '{"test": "Retry from DLQ!"}' \
    --message-group-id "dlq-retry-group" > /dev/null 2>&1
done
EOT
}
