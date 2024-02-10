---
layout: post
title: Create your own certificate authority (CA) using Vault in a docker container
date: 2023-10-19
categories:
  - hashicorp
---

<!-- # Project: vault-docker-pki -->

Create your own certificate authority (CA) using Vault.
In this project, the Vault server runs in a docker container.

## Repository structure

```sh
$ tree --dirsfirst -F
.
├── 00-hosts-FQDN.sh  # If you do not currently have access to the name server (DNS), then first of all run the 00-hosts-FQDN.sh script
├── 01-install-vault-in-container.sh
├── 02-vault-withoutTLS-unseal.sh     
├── 03-vault-withoutTLS-autounseal.sh
├── 04-creating-PKI.sh
├── 05-generate-cert-vault.sh
├── 06-vault-withTLS-autounseal.sh   
├── config-docker.env
└── README.md

0 directories, 9 files
```

Change the variables in file config-docker.env

## Sensitive environment variables are used

```sh
pki_access_user_name=CHANGE
pki_access_user_name_password=CHANGE
```

## To create your own certificate, change the variables

```sh
vault_server_fqdn=CHANGE
pki_allowed_domains=CHANGE
pki_role_intermediate=CHANGE
ca_country=CHANGE
ca_locality=CHANGE
ca_organization=CHANGE
ca_ou=CHANGE
ca_common_name=CHANGE
```
