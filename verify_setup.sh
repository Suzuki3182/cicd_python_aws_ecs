# Test role trust policy
aws iam get-role --role-name GitHubActions-Deploy-Role

# Verify OIDC provider exists
aws iam list-open-id-connect-providers
