# GitLab for Embrapa I/O

Configuração de _deploy_ do **GitLab** no ecossistema do **Embrapa I/O**.

## Ambiente de Desenvolvimento

1. Faça o _backup_ no servidor remoto (de produção) utilizando os [scripts oficiais](https://github.com/embrapa-io/backup/).
2. Crie uma VM local em **Ubuntu Server 20.04 LTS**:
   
   ```bash
   sudo su -
   apt update && apt upgrade -y && apt dist-upgrade -y && apt autoremove -y && apt autoclean
   ```
   
4. Siga o passo-a-passo da [documentação oficial para instalação no Ubuntu](https://docs.gitlab.com/install/package/ubuntu/) (via _package_/_ominibus_, como está em produção).

   > **Atenção!** Ao seguir o tutorial, atente-se para selecionar sempre as abas "**Community Edition**". No momento da instalação, verifique a versão do _backup_ e instale a <u>mesma versão</u>. Por exemplo:

   ```bash
   apt install -y curl vim
   curl "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh" | bash
   apt-cache madison gitlab-ce
   EXTERNAL_URL="https://gitlab.orb.local" apt install gitlab-ce=17.11.4-ce.0
   ```

5. Para restaurar o backup, copie o arquivo `.tar.gz` para a nova VM e faça:

   ```bash
   # Descompacte o arquivo e moda o arquivo apropriado para o recovery do GitLab:
   tar -xvf io_gitlab_2025-10-15_11-15-16.tar.gz
   mv io_gitlab_2025-10-15_11-15-16/gitlab/1760526957_2025_10_15_17.11.4_gitlab_backup.tar /var/opt/gitlab/backups/
   chmod +r /var/opt/gitlab/backups/*

   # Pare o GitLab:
   gitlab-ctl stop

   # Execute o restore:
   gitlab-backup restore BACKUP=1760526957_2025_10_15_17.11.4
   ```

6. Em ambiente de desenvolvimento é recomendado **NÃO** recuperar os arquivos de configuração (aqueles em `/etc/gitlab/`). Em resumo, o `gitlab.rb` da plataforma altera apenas configurações de URL, SMTP e LDAP:

   ```ruby
   #
   # embrapa.io
   #
   
   # URL and SSL
   
   external_url "https://git.embrapa.io"
   
   letsencrypt['enable'] = true
   letsencrypt['contact_emails'] = ['camilo.carromeu@embrapa.br']
   letsencrypt['auto_renew'] = true
   
   # Prevent users to create groups (DEPRECATED)
   
   # gitlab_rails['gitlab_default_can_create_group'] = false
   
   # SMTP
   
   gitlab_rails['smtp_enable'] = true
   gitlab_rails['smtp_address'] = "smtp-relay.nuvem.ti.embrapa.br"
   gitlab_rails['smtp_port'] = 25
   
   gitlab_rails['gitlab_email_from'] = 'no-reply@embrapa.br'
   gitlab_rails['gitlab_email_reply_to'] = 'no-reply@embrapa.br'
   
   # LDAP/ADDS config
   
   gitlab_rails['ldap_enabled'] = true
   
   gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
     main:
       label: 'Embrapa'
       ...
   EOS
   ```
