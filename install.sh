#!/bin/bash
GREEN='\033[1;32m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW="\033[1;33m"
banner() {
  printf " ${YELLOW}"
  printf "\n"
  printf " ${WHITE}+-+-+-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+ \n"
  printf " |${YELLOW} Instalador n8n    ${WHITE}-    ${GREEN}Por Joseph${WHITE} | \n"
  printf " +-+-+-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+ \n"
  printf "\n"
}

instalacao_n8n() {
  banner
  printf "${WHITE} >> Digite o dominio para instalação... Ex: ${RED}n8n.dominio.com.br${WHITE}\n"
  echo
  read -p " > " n8n_url
  sleep 2

  banner
  printf "${WHITE} >> Digite o email para gerar os certificados SSL:${WHITE}\n"
  echo
  read -p " > " certbot_email
  sleep 2

  banner
  UBUNTU_VERSION=$(lsb_release -sr)
  if [ "$UBUNTU_VERSION" = "22.04" ]; then
    printf "${WHITE} >> Ubuntu 22.04 detectado, aplicando configuracoes...${WHITE}\n"
    sleep 2
    if grep -q "NEEDRESTART_MODE" /etc/needrestart/needrestart.conf; then
      sed -i 's/^NEEDRESTART_MODE=.*/NEEDRESTART_MODE=a/' /etc/needrestart/needrestart.conf
    else
      echo 'NEEDRESTART_MODE=a' >>/etc/needrestart/needrestart.conf
    fi
  else
    printf "${WHITE} >> Versao do Ubuntu é $UBUNTU_VERSION. Proseguindo com a instalacao...${WHITE}\n"
    sleep 2
  fi

  banner
  printf "${WHITE} >> Atualizando o SO...\n"
  echo
  sudo DEBIAN_FRONTEND=noninteractive apt update -y && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && sudo DEBIAN_FRONTEND=noninteractive apt-get install build-essential -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apparmor-utils
  sleep 2

  banner
  printf "${WHITE} >> Configurando Timezone...\n"
  echo
  sudo timedatectl set-timezone America/Sao_Paulo
  sleep 2

  banner
  printf "${WHITE} >> Configurando o firewall Portas 80 e 443...\n"
  echo
  sudo ufw allow 80/tcp && ufw allow 22/tcp && ufw allow 443/tcp
  sleep 2

  banner
  printf "${WHITE} >> Instalando nodejs 18...\n"
  echo
  sudo apt-get install gnupg -y
  curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
  sudo sh -c "echo deb https://deb.nodesource.com/node_18.x focal main \
  > /etc/apt/sources.list.d/nodesource.list"
  sudo apt-get update && apt-get install nodejs -y
  npm install -g npm@10.2.3
  sleep 2

  banner
  printf "${WHITE} >> Instalando pm2...\n"
  echo
  npm install pm2 -g
  export PATH=$PATH:/usr/local/bin
  echo "export PATH=\$PATH:/usr/local/bin" >>~/.bashrc
  source ~/.bashrc
  pm2 startup ubuntu -u root
  env PATH=\$PATH:/usr/bin pm2 startup ubuntu -u root --hp /root
  pm2 save --force
  sleep 2

  banner
  printf "${WHITE} >> Instalando n8n...\n"
  echo
  npm install n8n -g
  pm2 start n8n
  sudo su - root <<EOF
cat > /root/ecosystem.config.js << 'END'
module.exports = {
  apps : [{
      name   : "n8n",
      env: {
          N8N_PROTOCOL: "https",
          WEBHOOK_TUNNEL_URL: "https://${n8n_url}/",
          N8N_HOST: "${n8n_url}"
      }
  }]
}
END
EOF
  cd /root
  pm2 start ecosystem.config.js
  pm2 save --force
  sleep 2

  banner
  printf "${WHITE} >> Instalando snapd...\n"
  echo
  sudo apt install -y snapd
  snap install core
  snap refresh core
  sleep 2

  banner
  printf "${WHITE} >> Instalando nginx...\n"
  echo
  sudo apt install -y nginx
  rm /etc/nginx/sites-enabled/default
  rm /etc/nginx/sites-available/default
  sudo systemctl start nginx
  sudo systemctl enable nginx
  sleep 2

  banner
  printf "${WHITE} >> Instalando certbot...\n"
  echo
  sudo apt-get remove certbot
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot
  sleep 2

  banner
  printf "${WHITE} >> Configurando proxy-reverso do n8n...\n"
  echo
  sudo su - root <<EOF
cat > /etc/nginx/sites-available/n8n << 'END'
server {
  server_name $n8n_url;
  location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Host \$host;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
    }
}
END
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled
  sleep 2
EOF

  banner
  printf "${WHITE} >> reiniciando nginx...\n"
  echo
  sudo service nginx restart
  sleep 2

  banner
  printf "${WHITE} >> Gerando certificado SSL...\n"
  echo
  sudo certbot --nginx -d $n8n_url --non-interactive --agree-tos -m $certbot_email
  sleep 2

  banner
  printf "${BLUE} >> Dados da Instalação <<\n"

}

atualizacao_n8n() {
  pm2 stop n8n
  sleep 2
  npm install -g n8n@latest
  sleep 2
  pm2 restart n8n
  printf " >> ${GREEN}Atualização concluida...${WHITE}\n"
  echo
  exit 0
}

sair() {
  printf " >> ${RED}Instalador Finalizado...${WHITE}\n"
  echo
  exit 0
}

menu() {
  while true; do
    banner
    printf "${WHITE} Bem vindo ao Instalador n8n, Selecione abaixo a próxima ação!\n"
    echo
    printf "   [${BLUE}1${WHITE}] Instalar n8n\n"
    printf "   [${BLUE}2${WHITE}] Atualizar n8n\n"
    printf "   [${BLUE}0${WHITE}] Sair\n"
    echo
    read -p "> " option
    case "${option}" in
    1)
      instalacao_n8n
      ;;
    2)
      atualizacao_n8n
      ;;
    0)
      sair
      ;;
    *)
      printf "${RED}Opção inválida. Tente novamente.${WHITE}"
      sleep 2
      ;;
    esac
  done
}
menu
