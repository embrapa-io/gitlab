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

   # Pare os processos que se conectam ao DB:
   gitlab-ctl stop puma && gitlab-ctl stop sidekiq

   # Verifique:
   gitlab-ctl status

   # Garanta que o usuário do PostgreSQl tenha todas as permissões necessárias:
   sudo gitlab-psql -c "GRANT \"gitlab-psql\" TO gitlab; ALTER USER gitlab WITH SUPERUSER;"

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

   > **Atenção!** Configure o arquivo acima conforme suas especificidades. Por exemplo, você pode querer utilizar o _mail catcher_ da plataforma nas configurações de SMTP.
   
7. Reinicie o GitLab:

   ```bash
   gitlab-ctl reconfigure && gitlab-rake gitlab:check SANITIZE=true && gitlab-ctl restart
   ```

8. Verifique a instalação:

   ```bash
   gitlab-ctl status
   ```

9. Se tiver optado por não copiar os arquivos de configuração, será necessário alterar a senha de `root` e desabilitar o 2FA:

   ```bash
   gitlab-rails runner 'u = User.find_by(username: "root"); u.password = "secret"; u.password_confirmation = "secret"; u.save!(validate: false); puts "Senha alterada\!"' && \
   gitlab-rails runner 'u = User.find_by(username: "root"); u.write_attribute(:otp_required_for_login, false); u.write_attribute(:encrypted_otp_secret, nil); u.write_attribute(:encrypted_otp_secret_iv, nil); u.write_attribute(:encrypted_otp_secret_salt, nil); u.write_attribute(:otp_backup_codes, nil); u.save(validate: false); puts "2FA desabilitado!"' && \
   gitlab-ctl restart
   ```

   Se tiver problemas, veja se o usuário está ativo:

   ```bash
   gitlab-rails runner 'u = User.find_by(username: "root"); puts [u&.id, u&.email, u&.username, u&.state]'
   ```
   
