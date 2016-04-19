# self-config
Ansible configuration for my servers

## Sample

    ansible-playbook site.yml --tags=deploy --skip-tags=packages --ask-vault-pass -v --diff
    ansible-vault decrypt --output - vault.yml
    ansible-playbook site.yml --list-tasks --ask-vault-pass
