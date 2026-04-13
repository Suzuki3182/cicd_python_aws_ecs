# Replace these variables first
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export GITHUB_USERNAME="YOUR_GITHUB_USERNAME"
export REPO_NAME="YOUR_REPO_NAME"

# Create trust policy
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_USERNAME}/${REPO_NAME}:*"
        }
      }
    }
  ]
}
EOF
