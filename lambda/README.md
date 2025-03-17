Here’s the updated markdown file with **Windows PowerShell** equivalent instructions added for each relevant step:

---

# **Lambda Function Documentation**

## **Overview**
This document describes the functionality and deployment process of the AWS Lambda function (`vpc_lambda`). The function is responsible for processing messages from an **AWS SQS Queue**, handling failures with a **Dead Letter Queue (DLQ)**, and notifying via **AWS SNS**.

## **Lambda Function Actions**

### **1️⃣ Event Trigger**
- The function is triggered by **SQS messages** arriving in the **main-queue**.
- It receives event payloads containing JSON messages.

### **2️⃣ Message Processing**
- Extracts **message body** from the SQS event.
- Logs **message ID** and **payload content**.
- If processing fails, the message remains in SQS until the retry limit is exceeded.

### **3️⃣ Sending Notifications via SNS**
- On successful processing, an **SNS notification** is published.
- The notification contains the original message details.

### **4️⃣ Handling Processing Failures**
- If Lambda **fails multiple times**, the message is sent to the **Dead Letter Queue (DLQ)**.
- The **DLQ Processor Lambda** retrieves failed messages for retry.

### **5️⃣ Deleting Processed Messages**
- Once successfully processed, the function **deletes the message** from the SQS queue to prevent reprocessing.

---
## **Lambda Deployment Instructions**

### **1️⃣ Move to Lambda Directory**
**Linux/macOS:**
```sh
cd lambda
```
**Windows PowerShell:**
```powershell
Set-Location -Path lambda
```

### **2️⃣ Initialize the Python Virtual Environment**
**Linux/macOS:**
```sh
python3 -m venv venv
source venv/bin/activate
```
**Windows PowerShell:**
```powershell
python -m venv venv
.\venv\Scripts\Activate
```

### **3️⃣ Install Dependencies in a Package Folder**
**Linux/macOS:**
```sh
pip install --no-cache-dir -r requirements.txt -t .
```
**Windows PowerShell:**
```powershell
pip install --no-cache-dir -r requirements.txt -t .
```

### **4️⃣ Zip the Package**
**Linux/macOS:**
```sh
zip -r ../lambda.zip .
```
**Windows PowerShell:**
```powershell
Compress-Archive -Path * -DestinationPath ..\lambda.zip
```

### **5️⃣ Deploy the Lambda Function Using Terraform**
Navigate back to the Terraform directory and run:

**Linux/macOS:**
```sh
cd ..
terraform apply -auto-approve
```
**Windows PowerShell:**
```powershell
Set-Location -Path ..
terraform apply -auto-approve
```

### **6️⃣ Update the Lambda Function (Without Rebuilding)**
**Linux/macOS:**
```sh
cd lambda
rm -f ../lambda.zip
zip -r ../lambda.zip .
aws lambda update-function-code --function-name vpc_lambda --zip-file fileb://../lambda.zip
cd ..
```
**Windows PowerShell:**
```powershell
Set-Location -Path lambda
Remove-Item ..\lambda.zip -Force
Compress-Archive -Path * -DestinationPath ..\lambda.zip
aws lambda update-function-code --function-name vpc_lambda --zip-file fileb://../lambda.zip
Set-Location -Path ..
```

### **7️⃣ Move Back to Terraform Directory**
**Linux/macOS:**
```sh
cd ..
```
**Windows PowerShell:**
```powershell
Set-Location -Path ..
```

---
## **Testing the Lambda Function**

### **Send a Test Message to SQS**
**Linux/macOS:**
```sh
aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/main-queue" \
    --message-body '{ "test": "Hello Lambda!" }'
```
**Windows PowerShell:**
```powershell
aws sqs send-message `
    --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/main-queue" `
    --message-body '{ "test": "Hello Lambda!" }'
```

### **Monitor Lambda Execution Logs**
**Linux/macOS:**
```sh
aws logs tail /aws/lambda/vpc_lambda --follow
```
**Windows PowerShell:**
```powershell
aws logs tail /aws/lambda/vpc_lambda --follow
```

### **Verify SNS Notifications**
**Linux/macOS:**
```sh
aws sns list-subscriptions-by-topic --topic-arn "arn:aws:sns:us-east-1:12345678901:alerts-topic"
```
**Windows PowerShell:**
```powershell
aws sns list-subscriptions-by-topic --topic-arn "arn:aws:sns:us-east-1:12345678901:alerts-topic"
```

### **Check Dead Letter Queue Messages (If Processing Fails)**
**Linux/macOS:**
```sh
aws sqs receive-message --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/dlq"
```
**Windows PowerShell:**
```powershell
aws sqs receive-message --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/dlq"
```