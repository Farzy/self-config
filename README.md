# self-config
Ansible configuration for my servers

## Sample

    ansible-playbook playbooks/site.yml --ask-vault-pass -v --diff
    ansible-playbook playbooks/site.yml --tags=deploy --skip-tags=packages --ask-vault-pass -v --diff
    ansible-playbook playbooks/site.yml -v --diff --check --skip-tags=packages
    ansible-vault decrypt --output - vault.yml
    ansible-playbook playbooks/site.yml --list-tasks --ask-vault-pass
    ansible-playbook playbooks/site.yml -v --list-tags

## TODO

* Config shell
* compte farzy
* config ssh
* config vim, screen, etc
* config tmux
* config mail
* Configuration Dropbox
* locale
* mdadm
* PAM
* rsyslog
* /etc/reportbug.conf
