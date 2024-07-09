---
# Deck options
theme: default
background: /emma-pUsLi19_Czs-unsplash.jpg
title: "GitHub Actions x Workload Identity Federation = ❤️"
highlighter: shiki
transition: slide-up
mdc: true

# Slide options
class: text-center
hideInToc: true
---

# <mdi-github /> x <logos-google-cloud /> = <twemoji-red-heart />

## Using Workload Identity Federation in GitHub Actions

---
hideInToc: true
layout: full
---

# Agenda

<Toc columns="2" maxDepth="2" />

---

<style scoped>
  li {
    line-height: 2.5em !important;
    list-style-type: none;
    margin: 0;    
  }

  li .slidev-icon:first-child {
    margin-right: 12px;
  }
</style>

# Setting the Scene

Can you see yourself doing any of this in a CI pipeline?

- <mdi-ship-wheel /> **Deploy applications** to Cloud Functions, Cloud Run, Kubernetes Engine, App Engine, ...
- <mdi-docker /> **Push container images** to Container Registry (`gcr.io`) or Artifact Registry (`pkg.dev`)
- <mdi-crane /> Deploy **Infrastructure as Code** (Terraform, Pulumi, ...)
- <mdi-cloud /> Use ephemeral cloud infrastructure during **integration testing**
- <mdi-database /> **Access data assets** living in Cloud Storage, BigQuery, Cloud SQL, ...
- <mdi-security /> **Access secrets** in Secret Manager
- <mdi-language-python /> **Publish Python packages** to PyPI (<mdi-arrow-right-thin /> [Trusted Publishing](https://docs.pypi.org/trusted-publishers/))
- ...

---
title: How to not integrate GitHub and GCP
---

# Looks familiar?

<img src="/gh-service-account-key.png" mx-auto h-90 />

Adding JSON credentials for a service account with appropriate permissions (_cough_, `roles/owner`) is probably the easiest way to access GCP from a GitHub Actions pipeline.

---
layout: fact
class: "empty-bg"
---

<img fixed class="-z-10" inset-0 opacity-30 src="https://i.ytimg.com/vi/1uvr7CJazqE/maxresdefault.jpg">

Problem: Long-lived service account credentials are a <span v-mark.red="0">security desaster waiting to happen</span>.

<p>&nbsp;</p>

Don't believe it? [Here's](https://cloud.google.com/iam/docs/service-account-creds#user-managed-keys) what Google has to say on the subject:

<v-click>

> **Caution**: Service account keys are a security risk if not managed correctly.
> You should choose a more secure alternative to service account keys whenever possible.
> If you must authenticate with a service account key, <span text-black v-mark.highlight.red="+1">you are responsible for the security</span> of the private key \[...\].

</v-click>

<p v-after>&nbsp;</p>

<p v-click>
Things only get worse when coupling that with <pre inline-block>roles/owner</pre>, obviously.
</p>

<p v-click absolute bottom-5 class="left-1/2 -translate-x-1/2">
Also: IT forbids service account key creation in new projects through an organization policy constraint by default. <twemoji-winking-face />  
</p>

---
layout: section
---

The solution?

<v-clicks>

# Workload Identity Federation

<p font-thin>
<mdi-information-box /> This talk focuses on identity federation between GitHub and other Google Cloud.<br/>
However, you can use the same principles to perform cross-cloud authentication.
</p>

</v-clicks>

---
level: 2
---

# Overview

Allow external services to securely access Google Cloud resources through OIDC/SAML tokens.

![](https://storage.googleapis.com/gweb-cloudblog-publish/images/2_GitHub_Actions.max-1100x1100.jpg)

<p absolute bottom-5>
<a href="https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions" target="_blank">Source</a>
</p>

<!--
- 1️⃣. OIDC JWT token exchange (GitHub ID token for short-lived Google Cloud access token)
- 2️⃣. Access control and mapping of GitHub token claims
- 3️⃣. GitHub Actions Runner can act as a service account (or IAM principal)
-->

---
layout: two-cols-header
level: 2
---

# OpenID Connect (OIDC) in a Nutshell

(courtesy of Claude)

::left::

<p>

**What is OIDC?**

- An identity layer built on top of OAuth 2.0 (an authorization framework)
- Enables clients to verify user identity
- Obtains basic profile information

</p>

<p>

**Key Components**

1. **ID Token**: JWT containing user info
2. **`UserInfo` Endpoint**: Additional user details
3. **Standard Claims**: Predefined user attributes

</p>

::right::

<p>

**Benefits**

- Single Sign-On (SSO)
- <span v-mark.underline.red>Improved security</span>
- <span v-mark.underline.red.at="1">Standardized protocol</span>
- Widely adopted

</p>

---
level: 3
---

# What's in a [GitHub OIDC token](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token)?

<Transform scale=".6">

```json {|1-6,8,31-34|9-18|19-30}{at: 1}
{
  "typ": "JWT",
  "alg": "RS256",
  "x5t": "example-thumbprint",
  "kid": "example-key-id"
}
{
  "jti": "example-id",
  "sub": "repo:octo-org/octo-repo:environment:prod",
  "environment": "prod",
  "aud": "https://github.com/octo-org",
  "ref": "refs/heads/main",
  "sha": "example-sha",
  "repository": "octo-org/octo-repo",
  "repository_owner": "octo-org",
  "repository_visibility": "private",
  "repository_id": "74",
  "repository_owner_id": "65",
  "run_id": "example-run-id",
  "run_number": "10",
  "run_attempt": "2",
  "runner_environment": "github-hosted",
  "actor_id": "12",
  "actor": "octocat",
  "workflow": "example-workflow",
  "head_ref": "",
  "base_ref": "",
  "event_name": "workflow_dispatch",
  "ref_type": "branch",
  "job_workflow_ref": "octo-org/octo-automation/.github/workflows/oidc.yml@refs/heads/main",
  "iss": "https://token.actions.githubusercontent.com",
  "nbf": 1632492967,
  "exp": 1632493867,
  "iat": 1632493567
}
```

</Transform>

<p absolute bottom-5>
<v-switch>
<template #1>Standard JWT structure & OIDC claims</template>
<template #2>Repository and environment information</template>
<template #3>Actions workflow information & runner environment</template>
</v-switch>
</p>

---
layout: two-cols-header
level: 2
---

# Building Blocks

Google Cloud resources and concepts for Workload Identity Federation

::left::

<v-clicks every="2">

## Identity Pool Provider

An entity that describes a relationship between Google Cloud and another IdP (e.g., GitHub).

## Identity Pool

An entity that lets you manage external identities.

</v-clicks>

::right::

<v-clicks every="2">

## Attribute Mappings

Define how to derive the value of the Google Security Token Service token attribute from an external token.

## Attribute Conditions

Check assertion attributes and target attributes to determine if a credential should be accepted.

</v-clicks>

---
layout: section
---

# Seeing it in Action: GitHub Actions

---
layout: center
title: Example workflow
level: 2
---

````md magic-move
```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
  - name: Build React app
    run: npm run build
  - name: Deploy to Google Cloud
    run: gsutil rsync -dr dist gs://${{ vars.WEBSITE_BUCKET }}/
```

```yaml {3,9-17}
permissions:
  contents: "read" # required for actions/checkout
  id-token: "write" # required for requesting the JWT to pass to Google Cloud

steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4

  - name: Authenticate with Google Cloud
    uses: google-github-actions/auth@v2
    with:
      project_id: ${{ vars.GCP_PROJECT_ID }}
      workload_identity_provider: ${{ vars.GCP_WORKLOAD_IDENTITY_PROVIDER_NAME }}
  - uses: google-github-actions/setup-gcloud@v2
    with:
      skip_install: true

  - name: Build React app
    run: npm run build
  - name: Deploy to Google Cloud
    run: gsutil rsync -dr dist gs://${{ vars.WEBSITE_BUCKET }}/
```
````

---
layout: center
---

## Breaking down `workload_identity_provider`

<p>&nbsp;</p>

<code text-base :class="$clicks === 0 ? 'text-white' : 'text-slate-500'">
  <span :class="{ 'text-white': $clicks === 1 }">projects/790484731908</span>/<span :class="{ 'text-white': $clicks === 2 }">locations/global</span>/<span :class="{ 'text-white': $clicks === 3 }">workloadIdentityPools/github</span>/<span :class="{ 'text-white': $clicks === 4 }">providers/demo-repo</span>
</code>

<p relative>
<v-switch>
<template #1>
<div absolute left-0>
  <p font-semibold>Project number (not ID!)</p>
  <p>Visible in Cloud Console on the project Welcome page and under <mdi-dots-vertical /> <mdi-arrow-right-thin /> <em>Project Settings</em></p>
</div>
</template>
<template #2><div font-semibold absolute left-53>Location (always <code>global</code>)</div></template>
<template #3><div font-semibold absolute left-94>Identity pool ID</div></template>
<template #4><div font-semibold absolute left-158>Identity pool provider ID</div></template>
<template #5>
  <br>
  We can get this string in a single GCloud CLI call:

  <div absolute class="left-1/2 -translate-x-1/2">
```shell
gcloud iam workload-identity-pools providers describe "$IDENTITY_PROVIDER_NAME" \
        --project="${PROJECT_ID}" \
        --location="global" \
        --workload-identity-pool="$IDENTITY_POOL_NAME" \
        --format="value(name)"
```
  </div>
</template>
</v-switch>
</p>

<style scoped>
code span {
  transition: color .25s linear;
}
</style>

---
layout: section
---

# Setting up Google Cloud

---
title: Using the GCloud SDK
level: 2
layout: center
---

<style scoped>
  .annotation {
    font-size: 75%;
  }
</style>

<<< @/snippets/create-gcp-workload-identity-provider.sh shell {|3-6|8-10|12-22|16|17|18-22}

<span v-click="4" class="annotation" absolute right-10 top-337px>Tokens are issued by GitHub</span>
<span v-click="5" class="annotation" absolute right-10 top-359px>Accept single organization only</span>
<span v-click="6" class="annotation" absolute right-10 top-410px>Map [JWT claims](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token) to assertions</span>

<p absolute bottom-5>
<v-switch at="1">
<template #2>Create Identity Pool</template>
<template #3-7>Create Identity Pool Provider</template>
</v-switch>
</p>

---
title: Using Terraform
level: 2
layout: center
---

```terraform
module "gh_oidc" {
  source      = "terraform-google-modules/github-actions-runners/google//modules/gh-oidc"
  project_id  = var.project_id
  pool_id     = "example-pool"
  provider_id = "example-gh-provider"
  sa_mapping = {
    "foo-service-account" = {
      sa_name   = "projects/my-project/serviceAccounts/foo-service-account@my-project.iam.gserviceaccount.com"
      attribute = "attribute.repository/${USER/ORG}/<repo>"
    }
  }
}
```

`gh_oidc` [module](https://github.com/terraform-google-modules/terraform-google-github-actions-runners/tree/master/modules/gh-oidc)

---
level: 2
---

# Setting IAM Permissions

How do I manage the permissions of a federated account?

Permissions for federated identities are managed the same way as for "regular" Google Cloud identities: through **IAM** (both on the project- or resource-level).

You can reference them through `principal://` and `principalSet://` [principal identifiers](https://cloud.google.com/iam/docs/principal-identifiers):

````md magic-move
```shell
gcloud storage buckets add-iam-policy-binding \
  gs://${BUCKET_NAME} \
  --member=PRINCIPAL_IDENTIFIER \
  --role=roles/storage.objectAdmin
```

```shell {3-5}
gcloud storage buckets add-iam-policy-binding \
  gs://${BUCKET_NAME} \
  --member=\
    "principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/" \
    "locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${REPO}" \
  --role=roles/storage.objectAdmin
```
````

---
level: 2
---

# Identity Types

Referencing federated identities based on their attributes

| Identities                                     | Identifier Format                                                                                                                                   |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Single identity                                | `principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/subject/SUBJECT_ATTRIBUTE_VALUE`             |
| All identities in a group                      | `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/group/GROUP_ID`                           |
| All identities with a specific attribute value | `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/attribute.ATTRIBUTE_NAME/ATTRIBUTE_VALUE` |

The GitHub documentation page on [OIDC Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#example-subject-claims) shows examples on how to build claim patterns that match specific events and conditions in GitHub Actions.

---
layout: section
class: "empty-bg"
---

<img fixed class="-z-10" inset-0 opacity-50 src="https://unsplash.com/photos/cFbNlpRZKi0/download?ixid=M3wxMjA3fDB8MXxzZWFyY2h8MTJ8fHdvb2RzfGVufDB8fHx8MTcxOTUwOTM4NXww&force=true&w=1920">

# Demo

[<mdi-github /> AdrianoKF/workload-identity-federation-demo](https://github.com/AdrianoKF/workload-identity-federation-demo)

---

# What about Azure & AWS?

Google Cloud can't be the only one, right?

Azure and AWS both offer similar mechanisms to Workload Identity Federation.

**AWS**

- [GitHub: Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS: Create an OpenID Connect (OIDC) identity provider in IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

**Azure**

- [GitHub: Configuring OpenID Connect in Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure: Workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)

<br/>

You are also not limited to just GitHub Actions:
Another big use case is cloud-based infrastructure management (e.g. Terraform Cloud / HCP Terraform, [Pulumi Cloud](https://www.pulumi.com/docs/pulumi-cloud/oidc/provider/)).

---
layout: two-cols-header
---

<style scoped>
  a {
    font-size: 12px !important;
  }

  a code {
    font-size: 12px !important;
  }

  li {
    line-height: 1.2em !important;
  }
</style>

# Resources

::right::

## Google Cloud

- [Enabling keyless authentication from GitHub Actions](https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Configure Workload Identity Federation with deployment pipelines](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
- [Best practices for using Workload Identity Federation](https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation#use-immutable-attributes)

## Terraform

- [`gh_oidc` module](https://registry.terraform.io/modules/terraform-google-modules/github-actions-runners/google/latest/submodules/gh-oidc)

## PyPI <span text-sm text-gray-500>(not technically Workload Identity Federation)</span>

- [Trusted Publishers](https://docs.pypi.org/trusted-publishers/)
- [Publishing with a Trusted Publisher](https://docs.pypi.org/trusted-publishers/using-a-publisher/)

::left::

## GitHub

Marketplace actions

- [`google-github-actions/auth`](https://github.com/google-github-actions/auth)
- [`google-github-actions/setup-gcloud`](https://github.com/google-github-actions/setup-gcloud/)
- [`github/actions-oidc-debugger`](https://github.com/github/actions-oidc-debugger)

Documentation

- [About security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
  - [OIDC token structure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token)
- [Configuring OpenID Connect in Google Cloud Platform](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform)

---
layout: end
---

`questions || comments || feedback`
