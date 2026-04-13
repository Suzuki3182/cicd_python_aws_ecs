# Get the thumbprint of GitHub's OIDC provider
THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com -connect token.actions.githubusercontent.com:443 -prexit 2>/dev/null | openssl x509 -fingerprint -sha256 -noout | cut -d= -f2 | tr -d ':')

# Create the OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $THUMBPRINT
