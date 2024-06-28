#!/bin/bash

IDENTITY_POOL_NAME="github"
IDENTITY_PROVIDER_NAME="demo-repo"

GH_ORG_ID="AdrianoKF"

gcloud iam workload-identity-pools create "$IDENTITY_POOL_NAME" \
  --location="global" \
  --display-name="GitHub Actions Pool"

gcloud iam workload-identity-pools providers create-oidc "$IDENTITY_PROVIDER_NAME" \
  --location="global" \
  --workload-identity-pool="$IDENTITY_POOL_NAME" \
  --display-name="GitHub provider for '$GH_ORG_ID'" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-condition="assertion.repository_owner == '$GH_ORG_ID'" \
  --attribute-mapping="\
      google.subject=assertion.sub,\
      attribute.actor=assertion.actor,\
      attribute.repository=assertion.repository,\
      attribute.repository_owner=assertion.repository_owner"