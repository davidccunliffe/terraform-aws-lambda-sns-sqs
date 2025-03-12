# **Terraform Codebase Documentation**

## **Overview**
This Terraform-based AWS deployment integrates security best practices and NIST 800-53 controls while ensuring efficient message processing through SQS, Lambda, and SNS. The infrastructure is designed to be **secure, scalable, and auditable** with logging and monitoring enabled for operational insights.

This Terraform codebase provisions an AWS infrastructure consisting of:
- A **VPC** with a Lambda function inside it.
- An **SQS Queue** (main queue) for processing messages.
- A **Dead Letter Queue (DLQ)** for failed messages.
- An **SNS Topic** for notifications.
- IAM policies ensuring **least privilege access**.
- Security enhancements aligned with **NIST 800-53 controls**.

## **NIST 800-53 Controls Implemented**

| **NIST Control** | **Description** | **Implementation in AWS SQS** |
|-------------|------------|---------------------------|
| **AC-2** | Account Management | IAM policies restrict access to SQS & SNS |
| **AC-3** | Access Enforcement | IAM Roles enforce access restrictions |
| **AC-6** | Least Privilege | Lambda has only `sqs:ReceiveMessage`, `sns:Publish` as needed |
| **AU-2** | Audit Events | CloudTrail enabled for SQS events |
| **AU-6** | Audit Review & Analysis | CloudWatch Logs capture Lambda execution details |
| **AU-12** | Audit Generation | CloudTrail logs all API calls |
| **CA-7** | Continuous Monitoring | Security Hub & AWS Config enabled |
| **IR-4** | Incident Handling | SNS sends alerts on processing failures |
| **MP-6** | Media Sanitization | S3 lifecycle policies for long-term storage |
| **SC-5** | Resource Availability | Optimized SQS visibility timeout & Lambda execution time |
| **SC-7** | Boundary Protection | VPC endpoints secure communication to LOGS, SQS, SNS and Lambda |
| **SC-12** | Cryptographic Key Management | SQS messages encrypted with AWS KMS |
| **SC-13** | Cryptographic Protection | Message integrity verified via KMS encryption |
| **SC-28** | Protection of Information at Rest | KMS encryption enforced on all SQS messages |
| **SC-29** | Protection of Information in Transit | TLS used for secure message transmission |

## **Architecture**
### **Components & Responsibilities**
1. **VPC-Connected Lambda (`lambda` and `dlq_processor`)**
   - Processes messages from **SQS Main Queue**.
   - Publishes notifications to **SNS Topic**.
   - Logs execution in **CloudWatch Logs**.
   - DLQ processor attempts to push old logs back into main queue

2. **SQS Queues**
   - **Main Queue**: Receives messages and triggers `lambda`.
   - **DLQ (Dead Letter Queue)**: Stores failed messages for further processing and ships back to **Main Queue**.

3. **SNS Topic**
   - Receives notifications from `lambda`.
   - Ensures alerts for failed message processing.

4. **IAM Policies**
   - Grants **least privilege** access to AWS resources.
   - Implements **encryption & security restrictions**.



## **Mermaid Diagram: Communication & Encryption Flow**
```mermaid
graph TD;
    A[Producer] -->|SendMessage| B[Main SQS Queue]
    B -->|Trigger| C[Lambda Function (vpc_lambda)]
    C -->|Process| D[SNS Topic (alerts-topic)]
    C -->|Process Failure| E[Dead Letter Queue (DLQ)]
    E -->|Reprocess| F[DLQ Processor Lambda]
    F -->|Retry Send| B
    
    subgraph Security & Encryption
        B -.-|KMS Encrypt| G[KMS Key for SQS]
        E -.-|KMS Encrypt| G
        D -.-|TLS Encryption| H[SNS Secure Transport]
    end
```

## **Security Enhancements**
- **KMS Encryption**: Messages are encrypted at rest in **SQS and DLQ**.
- **TLS for SNS & SQS**: Ensures secure transport for all messages.
- **IAM Least Privilege**: Lambda has the minimal permissions required.
- **CloudTrail Logging**: Enables auditing for security events.
- **AWS Config & Security Hub**: Monitors misconfigurations & security risks.

## **Deployment Instructions**
1. **Initialize Terraform**:
   ```sh
   terraform init
   ```
2. **Validate Configuration**:
   ```sh
   terraform validate
   ```
3. **Deploy Infrastructure**:
   ```sh
   terraform apply -auto-approve
   ```
4. **Verify Resources**:
   ```sh
   aws sqs list-queues
   aws sns list-topics
   aws lambda list-functions
   ```

## **Testing & Monitoring**
### **1. Send a Test Message to SQS**
```sh
aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/main-queue" \
    --message-body '{ "test": "Hello Lambda!" }'
```
### **2. Monitor Lambda Execution Logs**
```sh
aws logs tail /aws/lambda/vpc_lambda --follow
```
### **3. Check Dead Letter Queue Messages**
```sh
aws sqs receive-message --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/dlq"
```
### **4. Reprocess Failed Messages**
```sh
aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/12345678901/main-queue" \
    --message-body '{ "test": "Retry from DLQ" }'
```

# Lambda deployment information
Information is included in repositories for [lambda](./lambda/README.md) and [dlq_processing](./dlq_lambda/README.md)