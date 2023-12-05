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

## Scaleway configuration

* Create a Scaleway account
* Create a project, or use Default project
* Create an API key on https://console.scaleway.com/iam/api-keys using the [documentation](https://github.com/scaleway/scaleway-sdk-go/blob/master/scw/README.md#scaleway-config)
* Put the key in `$HOME/.config/scw/config.yaml` along with organization id, project id, default region, default zone

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


* Install `poetry`

        brew install poetry

* Run `poetry install` after each `pyproject.toml` update
* Configure Git subtrees

        git remote add -f ansible-role-nginx https://github.com/nginxinc/ansible-role-nginx.git
        git subtree add --prefix ansible/roles/nginxinc.nginx ansible-role-nginx master --squash

### Using Ansible

    poetry shell
    cd ansible

Install Galaxy modules:

    ansible-galaxy collection install -r requirements.yml

Here are some sample ansible commands:

    ansible-playbook playbooks/web.yml -v --diff
    ansible-playbook playbooks/web.yml --tags=nginx --skip-tags=deploy -v --diff
    ansible-playbook playbooks/web.yml --tags=nginx_template_config -v --diff
    ansible-playbook playbooks/web.yml -v --diff --check
    ansible-playbook playbooks/web.yml --list-tasks
    ansible-playbook playbooks/web.yml --list-tags
    ansible-playbook -v --diff playbooks/mac.yml
    ansible-playbook -v --diff --vault-id personal@~/.ansible-personal-key playbooks/mac.yml
    ansible-vault decrypt --output - vars/vault.yml
    ansible-vault encrypt_string 'XXXX' --name github_token
    ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --encrypt-vault-id personal 'XXXX' --name github_token

**Note**: If [vault_identity_list](https://docs.ansible.com/ansible/latest/user_guide/vault.html#setting-a-default-vault-id) 
is set in `ansible.cfg`, there is no need to use `--vault-id` or `--encrypt-vault-id` 
on the command line.

### Updating

* Update Python modules:

        poetry update

* Update Git subtrees:

        git fetch --all -v
        git subtree pull --prefix ansible/roles/nginxinc.nginx ansible-role-nginx master --squash

## Configuring Powerline fonts for Powerlevel10k

* Run `p10k configure` to at least download and install the fonts.
* When instructed, quit and relaunch iTerm2.

You should not need to further configure P10K because Ansible already did so.

## KinD (Kubernetes in Docker)

KinD is installed on a Scaleway server.

### SSH Setup

Sign the server host key using our SSH CA.
- Copy the CA key and certificate to `/root.ssh`
- Sign the host certificates:
```shell
cd /etc/ssh
for cert in ssh_host_*_key.pub ; do ssh-keygen -s ~/.ssh/ca_host_key -h -I k8s.farzad.tech $cert ; done
rm -f /root/.ssh/ca_host_key*
```
- Add the following lines to `/etc/ssh/sshd_config`:
```text
HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub
HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
```
- Restart SSH server
```shell
service sshd restart
```

### Setup

Set KinD configuration in [ansible/playbooks/kind-server.yml](ansible/playbooks/k8s-server.yml):
- `kind_cluster_name`
- `kind_config`: Check https://kind.sigs.k8s.io/docs/user/configuration/

Run Ansible:

```shell
ansible-playbook --diff playbooks/kind-server.yml
```

The Kubeconfig file is now available at `/tmp/kubeconfig-multi.yaml`.

### Merging the remote Kubeconfig with the local one

This can be done using the trick from the website in the references. You have to be careful when the keys already 
exist in the local Kubeconfig. It will be so if you recreate the KinD cluster multiple times with the same name.

I found that inputting the configuration files in the following order works:

```shell
KUBECONFIG=/tmp/kubeconfig-multi.yaml:~/.kube/config kubectl config view --flatten > ~/.kube/config-new
# Compare config and config-new to make sure that everything is OK
mv ~/.kube/config-new ~/.kube/config
chmod 600 ~/.kube/config
```

### Accessing the KinD cluster

You need to open an SSH tunnel, for example like this:

```shell
ssh -L 46419:localhost:46419 -T root@kind.farzad.tech
```

And access the cluster with its context name which is `kind-<CLUSTER-NAME>`.

**Limitations**: 

- The Kube API server cannot be directly exposed on the Internet because the domain name is not part of the X509
  certificate and `kubectl` will refuse the connection.
- My goal is to be able to shut down the server in order to save money. But KinD in HA mode (multiple control planes) does
not support restarts ! This is because Docker changes the nodes' IPs, and the control plane components cannot find
each other anymore. You must therefore avoid creating HA clusters, unless you are sure to keep the server up and running.

## References

* Git Subtree: https://www.atlassian.com/git/tutorials/git-subtree
* How to merge Kubernetes config files: https://medium.com/@jacobtomlinson/how-to-merge-kubernetes-kubectl-config-files-737b61bd517d
* Fix multi-node cluster not working after restarting docker: https://github.com/kubernetes-sigs/kind/pull/2775
* HA clusters don't reboot properly: https://github.com/kubernetes-sigs/kind/issues/1689
