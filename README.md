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

  * If the GCS already exists but no `terraform.state` is present, import it instead of
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

* Install XCode command line tools
  
        xcode-select --install
  
* Install Ansible personal key

        echo "THIS PASSWORD" > ~/.ansible-personal-key

* Install `pipenv`
* Run `pipenv sync` after each `Pipfile.lock` update
* If `pipenv` fails when install `cryptography`, run the following commands then `pipenv sync` again:
  
        pipenv shell
        pip install -U pip

* Configure Git subtrees

        git remote add -f ansible-role-nginx https://github.com/nginxinc/ansible-role-nginx.git
        git subtree add --prefix ansible/roles/nginxinc.nginx ansible-role-nginx master --squash

### Using

    pipenv shell
    cd ansible

Here are some sample ansible commands:

    ansible-playbook playbooks/web.yml -v --diff
    ansible-playbook playbooks/web.yml --tags=nginx --skip-tags=deploy -v --diff
    ansible-playbook playbooks/web.yml --tags=nginx_template_config -v --diff
    ansible-playbook playbooks/web.yml -v --diff --check
    ansible-playbook playbooks/web.yml --list-tasks
    ansible-playbook playbooks/web.yml --list-tags
    ansible-playbook -v --diff --vault-id personal@~/.ansible-personal-key playbooks/mac.yml
    ansible-vault decrypt --output - vars/vault.yml
    ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --encrypt-vault-id personal 'XXXX' --name github_token

### Updating

* Update Python modules:

        pipenv sync

* Update Git subtrees:

        git fetch --all -v
        git subtree pull --prefix ansible/roles/nginxinc.nginx ansible-role-nginx master --squash

## References

* Git Subtree: https://www.atlassian.com/git/tutorials/git-subtree
