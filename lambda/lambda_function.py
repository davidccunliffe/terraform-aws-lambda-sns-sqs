# Copyright (c) 2010-2025 David Cunliffe
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import os
import json
import boto3
import logging

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients
sqs = boto3.client("sqs", region_name="us-east-1")
sns = boto3.client("sns", region_name="us-east-1")

# Environment Variables
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL", "")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")

def lambda_handler(event, context):
    """
    AWS Lambda entry point.
    """
    logger.info(f"🚀 Lambda function invoked with event: {json.dumps(event, indent=4)}")

    if "Records" not in event:
        logger.error("❌ Event does not contain SQS records.")
        return {"statusCode": 400, "body": "No SQS records found"}

    for record in event["Records"]:
        logger.info(f"📩 Received SQS message ID: {record.get('messageId')}")

        try:
            logger.info("📜 Raw message body: " + record["body"])  # Debugging log

            # Fix: Remove double encoding
            message_body = record["body"].replace("\\\"", "\"")  # Fix incorrectly escaped quotes

            # Parse JSON properly
            body = json.loads(message_body)
            logger.info(f"✅ Successfully parsed message: {body}")

            # Send SNS Notification
            logger.info("📡 Sending SNS notification...")
            response = sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=json.dumps({"status": "processed", "message": body}),
                Subject="Lambda Processing Success"
            )
            logger.info(f"✅ SNS Publish Response: {response}")

            # Delete the message from SQS
            logger.info("🗑 Deleting message from SQS...")
            sqs.delete_message(
                QueueUrl=SQS_QUEUE_URL,
                ReceiptHandle=record["receiptHandle"]
            )
            logger.info(f"✅ Deleted message: {record['messageId']}")

        except json.JSONDecodeError as e:
            logger.error(f"❌ JSONDecodeError: Unable to parse message body: {e}", exc_info=True)
        except Exception as e:
            logger.error(f"❌ Error processing message: {e}", exc_info=True)

    return {"statusCode": 200, "body": "Processing complete."}
