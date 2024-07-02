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
---

# Agenda

<Toc />

---

<style scoped>
  li {
    line-height: 2.2em !important;
  }
</style>

# Setting the Scene

Can you see yourself doing any of this in GitHub Actions CI pipeline?

<v-clicks>

- **Deploy applications** to Cloud Functions, Cloud Run, Kubernetes Engine, App Engine, ...
- **Push container images** to Container Registry (`gcr.io`) or Artifact Registry (`pkg.dev`)
- Deploy **Infrastructure as Code** (Terraform, Pulumi, ...)
- Use cloud infrastructure for **integration testing**
- **Access data assets** living in Cloud Storage, BigQuery, Cloud SQL, ...
- **Access secrets** in Secret Manager
- ...

</v-clicks>

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

# Workload Identity Federation

---

## Overview

Allow external services to securely access Google Cloud resources through OIDC/SAML tokens.

![](https://storage.googleapis.com/gweb-cloudblog-publish/images/2_GitHub_Actions.max-1100x1100.jpg)

<p absolute bottom-5>
<a href="https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions" target="_blank">Source</a>
</p>

---
layout: two-cols-header
---

## Building Blocks

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

```yaml {3,6-14}
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

<<< @/snippets/create-gcp-workload-identity-provider.sh shell {3-6|8-10|12-22|16|17|18-22}

<span v-click="3" class="annotation" absolute right-10 top-337px>Tokens are issued by GitHub</span>
<span v-click="4" class="annotation" absolute right-10 top-359px>Accept single organization only</span>
<span v-click="5" class="annotation" absolute right-10 top-410px>Map [JWT claims](https://token.actions.githubusercontent.com/.well-known/openid-configuration) to assertions</span>

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

## Setting IAM Permissions

How do I manage the permissions of a federated account?

Simple enough - they are referenced through `principalSet://` [principal identifiers](https://cloud.google.com/iam/docs/principal-identifiers):

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

## Identity Types

| Identities                                     | Identifier Format                                                                                                                                   |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Single identity                                | `principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/subject/SUBJECT_ATTRIBUTE_VALUE`             |
| All identities in a group                      | `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/group/GROUP_ID`                           |
| All identities with a specific attribute value | `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/attribute.ATTRIBUTE_NAME/ATTRIBUTE_VALUE` |

---
layout: section
class: "empty-bg"
---

<img fixed class="-z-10" inset-0 opacity-50 src="https://unsplash.com/photos/cFbNlpRZKi0/download?ixid=M3wxMjA3fDB8MXxzZWFyY2h8MTJ8fHdvb2RzfGVufDB8fHx8MTcxOTUwOTM4NXww&force=true&w=1920">

# Demo

[<mdi-github /> AdrianoKF/workload-identity-federation-demo](https://github.com/AdrianoKF/workload-identity-federation-demo)

---
layout: full
---

<style scoped>
  a {
    font-size: 65% !important;
  }

  li {
    line-height: 1.2em !important;
  }
</style>

# Resources

## Google Cloud

- https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions
- https://cloud.google.com/iam/docs/workload-identity-federation
- https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines

## GitHub

Marketplace actions

- https://github.com/google-github-actions/auth
- https://github.com/google-github-actions/setup-gcloud/

Documentation

- https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform

---
layout: end
---

Questions & comments?
