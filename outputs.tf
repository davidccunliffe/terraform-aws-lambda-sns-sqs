output "sqs_queue_url" {
  value = aws_sqs_queue.main_queue.id
}

output "sqs_aws_cli_command" {
  value = " date; aws sqs send-message --queue-url ${aws_sqs_queue.main_queue.id} --message-body '{ \"test\": \"Hello Lambda from SQS!\" }' "
}

output "sqs_deadletter_aws_cli_command" {
  value = " date; aws sqs send-message --queue-url ${aws_sqs_queue.dead_letter_queue.id} --message-body '{ \"test\": \"Retry from DLQ!\" }' "
}
