# self-config

Terraform /Ansible configuration for my servers

## GCP configuration

* Create a GCP project
* Create a Service Account and give it **Project Owner** role
* Create JSON Key
* Save key under name `terraform/_auth/gcp-admin.json` and in a safe place (**1Password**)
* Create a GCS bucket:
  * Name: `farzad-infrastructure`
  * Location: `eu`
  * Storage: `standard`
* Delete default VPC network called `default`
* Delete default firewall rules
* Add public SSH key to Compute Engine Metadata


## Terraform

* Configure GCP project name and region in `terraform/gcp/setup.tf`
* `terraform init`
* `terraform plan`
* `terraform apply`


## Ansible

* Install `pipenv`
* Run `pipenv sync` after each `Pipfile.lock` update
* Run `pipenv shell`
* `cd ansible`


### Sample

    ansible-playbook playbooks/site.yml --ask-vault-pass -v --diff
    ansible-playbook playbooks/site.yml --tags=deploy --skip-tags=packages --ask-vault-pass -v --diff
    ansible-playbook playbooks/site.yml -v --diff --check --skip-tags=packages
    ansible-vault decrypt --output - vault.yml
    ansible-playbook playbooks/site.yml --list-tasks --ask-vault-pass
    ansible-playbook playbooks/site.yml -v --list-tags
