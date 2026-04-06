#!/bin/bash

set -Eeuo pipefail

# Verificar permissões de root
if [[ "$EUID" -ne 0 ]]; then
  echo "Por favor, execute como root (use sudo)"
  exit 1
fi

echo "🔧 Removendo versões conflitantes do Docker..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  apt-get remove -y $pkg
done

echo "📦 Atualizando pacotes..."
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release git nano

echo "🔐 Adicionando chave GPG oficial do Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "📥 Adicionando repositório oficial do Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

echo "📦 Instalando Docker Engine e plugins..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "✅ Verificando a instalação do Docker..."
docker --version && docker compose version

echo "🔥 Desativando firewall (ufw)..."
ufw disable

echo "📁 Clonando o repositório do ODK Central..."
cd /opt
umask 022
git clone https://github.com/getodk/central

cd central
git submodule update -i

echo "📚 Preparando banco de dados..."
touch ./files/allow-postgres14-upgrade

echo "⚙️ Copiando arquivo de configuração padrão..."
cp .env.template .env


echo "📌 Agora edite o arquivo .env e configure DOMAIN e SYSADMIN_EMAIL"
echo "Exemplo: DOMAIN=odk.seudominio.com  e  SYSADMIN_EMAIL=seu@email.com"
echo "Abrindo o arquivo para edição..."
sleep 2
nano .env


echo "✅ Configuração concluída com sucesso!"
echo "Agora você precisa apenas rodar o comando:"
echo "docker compose up --build -d"


