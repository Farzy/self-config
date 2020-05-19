# self-config

Terraform / Ansible configuration for my servers

## GCP configuration

* Create a GCP project
* Create a Service Account and give it **Project Owner** role
* Create JSON Key
* Save key under name `terraform/_auth/gcp-admin.json` and in a safe place (**1Password**)
* Create a GCS bucket:
  * This first step uses a local `terraform.state` to create the Terraform backend
    for the rest of terraform playbooks.


    cd terraform/gcp-management
    terraform init
    terraform plan
    terraform apply

  * If the GCS already exists but not `terraform.state` is present, import it instead of
    running `terraform apply`:


    terraform import google_storage_bucket.farzad-infrastructure farzad-infrastructure

* Delete default VPC network called `default`
* Delete default firewall rules
* Add public SSH key to Compute Engine Metadata with the login `farzad_farid`


## Terraform

* Configure GCP project name and region in `terraform/gcp/setup.tf`


    cd terraform/gcp
    terraform init
    terraform plan
    terraform apply


## Ansible

### Initial configuration
* Install `pipenv`
* Run `pipenv sync` after each `Pipfile.lock` update

### Git subtrees


    git remote add -f ansible-role-nginx https://github.com/nginxinc/ansible-role-nginx.git
    git subtree add --prefix ansible/roles/nginxinc.nginx ansible-role-nginx master --squash

### Using


    pipenv shell
    cd ansible


### Sample

    ansible-playbook playbooks/site.yml --ask-vault-pass -v --diff
    ansible-playbook playbooks/site.yml --tags=deploy --skip-tags=packages --ask-vault-pass -v --diff
    ansible-playbook playbooks/site.yml -v --diff --check --skip-tags=packages
    ansible-vault decrypt --output - vault.yml
    ansible-playbook playbooks/site.yml --list-tasks --ask-vault-pass
    ansible-playbook playbooks/site.yml -v --list-tags
