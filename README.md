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
* locale
* mdadm
* PAM
* rsyslog
* /etc/reportbug.conf
* MariaDB
* PHP
* Postfix
* Tinyproxy
* FTP :


    pure-pw useradd scanner -u $(id -u farzy) -g $(id -g farzy) -d /data/home/farzy/Dropbox/Scanner -c "FTP Scanner" 
    pure-pw mkdb

* Dolibarr
  * v3.6.1
  * Données : /data/srv/dolibarr/documents
  * Backup MySQL : /data/srv/dolibarr/documents/admin/backup/mysqldump_dolibarr_3.6.1_201610022351.sql.bz2
