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
