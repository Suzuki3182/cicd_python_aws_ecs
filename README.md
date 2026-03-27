# cicd_python_aws_ecs

# 🐍 Python App on AWS ECS Fargate (IaC)

Infrastructure as Code (IaC) repository for deploying a containerized Python application on AWS ECS Fargate with a managed PostgreSQL database (RDS). This project uses **Terraform** for infrastructure provisioning and **GitHub Actions** for CI/CD pipelines with OIDC authentication.

## 🏗 Architecture Overview

*   **Compute:** AWS ECS Fargate (Serverless Containers)
*   **Database:** Amazon RDS for PostgreSQL (Private Subnet)
*   **Container Registry:** Amazon ECR
*   **Infrastructure:** Terraform
*   **CI/CD:** GitHub Actions (OIDC Authentication)
*   **Secrets:** AWS Secrets Manager
*   **Networking:** VPC with Public/Private Subnets, NAT Gateway, Security Groups

## 📁 Project Structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD Pipeline
├── infra/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── ecs/
│   │   └── rds/
│   ├── main.tf                 # Root Terraform configuration
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf              # S3 Backend configuration
├── app/
│   ├── src/
│   ├── Dockerfile
│   └── requirements.txt
└── README.md
```

## 🚀 Prerequisites

Before deploying, ensure you have the following installed and configured:

*   **AWS CLI** configured (`aws configure`)
*   **Terraform** >= 1.5.0
*   **Docker** (for local testing)
*   **GitHub Account** with repository access
*   **AWS Account** with administrative permissions (for initial setup)

## 🛠 Setup Instructions

### 1. AWS Backend Configuration
Create an S3 bucket and DynamoDB table for Terraform state locking:

```bash
aws s3 mb s3://my-terraform-state-bucket-<unique-id>
aws dynamodb create-table --table-name terraform-locks --attribute-definitions AttributeName=LockId,AttributeType=S --key-schema AttributeName=LockId,KeyType=HASH --billing-mode PAY_PER_REQUEST
```

Update `infra/backend.tf` with your bucket name and region.

### 2. GitHub OIDC Configuration
To allow GitHub Actions to deploy to AWS without static credentials:

1.  **Create IAM OIDC Provider** in AWS (can be done via Terraform or CLI).
2.  **Create IAM Role** with trust policy allowing `token.actions.githubusercontent.com`.
3.  **Add Secrets to GitHub Repository**:
    *   `AWS_ACCOUNT_ID`: Your 12-digit AWS Account ID.
    *   `AWS_REGION`: e.g., `us-east-1`.

### 3. Terraform Deployment

Initialize and apply the infrastructure:

```bash
cd infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Important Outputs:**
After applying, note the outputs provided by Terraform, such as:
*   `ecs_cluster_name`
*   `ecs_service_name`
*   `rds_endpoint`

### 4. Configure Secrets Manager
Ensure database credentials are stored in AWS Secrets Manager. The Terraform code provided creates a secret, but you should rotate passwords securely in production.

## 🔄 CI/CD Pipeline

The pipeline triggers on every push to the `main` branch.

1.  **Build:** Builds the Docker image from `app/Dockerfile`.
2.  **Authenticate:** Uses OIDC to assume the AWS IAM Role.
3.  **Push:** Pushes the image to Amazon ECR.
4.  **Deploy:** Updates the ECS Task Definition and forces a new deployment of the service.

## 🔒 Security Best Practices

*   **No Static Credentials:** Uses GitHub OIDC for AWS authentication.
*   **Private Database:** RDS instance is placed in private subnets with no public access.
*   **Least Privilege:** IAM roles for ECS tasks and GitHub Actions are scoped to specific resources.
*   **Secrets Management:** Database credentials are injected at runtime via AWS Secrets Manager, not stored in environment variables or code.
*   **Security Groups:** Strict ingress/egress rules (only ECS tasks can access RDS on port 5432).

## 🧹 Cleanup

To avoid unnecessary costs, destroy the infrastructure when not in use:

```bash
cd infra
terraform destroy
```

**Warning:** This will delete the RDS instance and all data within it. Ensure you have backups before destroying.

## 📝 Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `aws_region` | AWS Region for deployment | `us-east-1` |
| `app_name` | Name prefix for resources | `python-app` |
| `db_instance_class` | RDS Instance Type | `db.t3.micro` |
| `environment` | Environment name (dev/prod) | `dev` |

## 🤝 Contributing

1.  Create a feature branch (`git checkout -b feature/NewFeature`).
2.  Commit your changes (`git commit -am 'Add NewFeature'`).
3.  Push to the branch (`git push origin feature/NewFeature`).
4.  Open a Pull Request.

## 📄 License

This project is licensed under the MIT License.

---

### 💡 Dicas Adicionais para o seu Repositório

1.  **Arquivo `.gitignore`:** Certifique-se de criar um `.gitignore` na raiz para evitar subir arquivos sensíveis:
    ```gitignore
    .terraform/
    *.tfstate
    *.tfstate.lock.info
    .env
    __pycache__/
    *.pyc
    ```
