# **DLQ Processor Lambda Documentation**

## **Overview**
This document describes the functionality and deployment process of the AWS Lambda function (`dlq_processor`). The function is responsible for retrieving messages from the **Dead Letter Queue (DLQ)**, reprocessing them, and reinjecting them into the **Main SQS Queue** for another attempt at processing.

## **DLQ Processor Actions**

### **1️⃣ Event Trigger**
- The function is triggered by **SQS messages** arriving in the **Dead Letter Queue (DLQ)**.
- It receives event payloads containing failed messages.

### **2️⃣ Message Processing**
- Extracts **message body** from the DLQ event.
- Logs **message ID** and **payload content**.
- Attempts to **re-send the message** to the **Main SQS Queue**.

### **3️⃣ Handling Processing Failures**
- If reprocessing fails, the message remains in DLQ for manual intervention.
- If successful, the function **deletes the message** from DLQ after reinjection.

---
## **DLQ Processor Deployment Instructions**

### **1️⃣ Move to DLQ Lambda Directory**
```sh
cd dlq_lambda
```

### **2️⃣ Initialize the Python Virtual Environment**
```sh
python3 -m venv venv
source venv/bin/activate
```

### **3️⃣ Install Dependencies in a Package Folder**
```sh
pip install --no-cache-dir -r requirements.txt -t .
```

### **4️⃣ Zip the Package**
```sh
zip -r ../dlq_processor.zip .
```

### **5️⃣ Deploy the DLQ Processor Lambda Using Terraform**
Navigate back to the Terraform directory and run:
```sh
terraform apply -auto-approve
```

### **6️⃣ Update the DLQ Processor Lambda (Without Rebuilding)**
```sh
cd dlq_lambda
rm -f ../dlq_processor.zip
zip -r ../dlq_processor.zip .
aws lambda update-function-code --function-name dlq_processor --zip-file fileb://../dlq_processor.zip
cd ..
```

### **7️⃣ Move Back to Terraform Directory**
```sh
cd ..
```

---
## **Testing the DLQ Processor**

### **Send a Test Message to DLQ**
```sh
aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/dlq" \
    --message-body '{ "test": "Retry from DLQ" }'
```

### **Monitor DLQ Processor Execution Logs**
```sh
aws logs tail /aws/lambda/dlq_processor --follow
```

### **Verify Message Was Reprocessed**
Check if the message was reinjected into the **Main SQS Queue**:
```sh
aws sqs receive-message --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/main-queue"
```

---
## **Security Measures**
- **IAM Least Privilege**: Lambda only has permissions for `sqs:ReceiveMessage`, `sqs:DeleteMessage`, and `sqs:SendMessage`.
- **KMS Encryption**: Messages in **SQS are encrypted** at rest.
- **TLS for Secure Transport**: All communications use HTTPS.
- **CloudTrail Logging**: Logs all API requests for auditing.