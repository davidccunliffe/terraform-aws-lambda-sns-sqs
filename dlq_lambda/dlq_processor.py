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

# Environment Variables
DLQ_URL = os.environ["DLQ_URL"]
MAIN_QUEUE_URL = os.environ["MAIN_QUEUE_URL"]

def lambda_handler(event, context):
    """
    Process messages from the DLQ and re-send them to the main queue.
    """
    logger.info(f"🚀 DLQ Processor invoked with event: {json.dumps(event, indent=4)}")

    # ✅ Check if the event contains 'Records'
    if "Records" not in event:
        logger.error("❌ Event does not contain SQS records. Check the trigger source.")
        return {"statusCode": 400, "body": "No SQS records found"}

    for record in event["Records"]:
        logger.info(f"📩 Processing DLQ message ID: {record.get('messageId')}")

        try:
            # Get message body
            message_body = record["body"]
            logger.info(f"📜 DLQ Message body: {message_body}")

            # Re-send the message to the main queue
            response = sqs.send_message(
                QueueUrl=MAIN_QUEUE_URL,
                MessageBody=message_body
            )
            logger.info(f"✅ Re-sent to Main Queue: {response}")

            # Delete the message from DLQ after successful processing
            logger.info("🗑 Deleting message from DLQ...")
            sqs.delete_message(
                QueueUrl=DLQ_URL,
                ReceiptHandle=record["receiptHandle"]
            )
            logger.info(f"✅ Deleted message: {record['messageId']}")

        except Exception as e:
            logger.error(f"❌ Error processing DLQ message: {e}", exc_info=True)

    return {"statusCode": 200, "body": "DLQ processing complete."}
