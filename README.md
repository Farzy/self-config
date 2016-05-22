# self-config
Ansible configuration for my servers

## Sample

    ansible-playbook playbooks/site.yml --tags=deploy --skip-tags=packages --ask-vault-pass -v --diff
    ansible-vault decrypt --output - vault.yml
    ansible-playbook playbooks/site.yml --list-tasks --ask-vault-pass
    ansible-playbook playbooks/site.yml -v --list-tags
