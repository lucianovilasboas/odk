#!/bin/bash


# Verifica se está na pasta correta
if [ ! -f docker-compose.yml ]; then
  echo "❌ Este script deve ser executado em '/opt/central/' do ODK."
  exit 1
fi

# Solicita o e-mail do usuário a ser criado
read -p "📧 Informe o e-mail do novo usuário: " USER_EMAIL
if [ -z "$USER_EMAIL" ]; then
  echo "❌ E-mail não informado. Abortando..."
  exit 1
fi

# Pergunta se será administrador
read -p "👤 Este usuário será administrador? (s/n): " IS_ADMIN

# Cria o usuário
echo "🔧 Criando usuário: $USER_EMAIL"
docker compose exec service odk-cmd --email "$USER_EMAIL" user-create

# Se for administrador, promove
if [[ "$IS_ADMIN" =~ ^[Ss]$ ]]; then
  echo "🛡️ Promovendo para administrador..."
  docker compose exec service odk-cmd --email "$USER_EMAIL" user-promote
  echo "✅ Usuário '$USER_EMAIL' criado e promovido a administrador com sucesso."
else
  echo "✅ Usuário '$USER_EMAIL' criado como usuário comum com sucesso."
fi

echo ""
echo "🔐 Para redefinir a senha futuramente, use:"
echo "    docker compose exec service odk-cmd --email \"$USER_EMAIL\" user-set-password"
