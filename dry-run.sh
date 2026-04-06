#!/usr/bin/env bash

set -Eeuo pipefail

# dry-run.sh
# Script para simular (sem executar) os passos do install_odk.sh
# Uso:
#   bash dry-run.sh        -> simula todas as ações (não altera o sistema)

DRYRUN=true

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERRO" "$*"; exit 1; }

run() {
  # Apenas imprime a ação simulada (DRY-RUN somente)
  printf 'DRYRUN: %s\n' "$*"
}

info_step() { printf '\n==> %s\n' "$*"; }

main() {
  info_step "Checagens iniciais"
  if ! command -v apt-get >/dev/null 2>&1; then
    log "AVISO" "apt-get não encontrado — este script é para Ubuntu/Debian (somente verificação)."
  else
    run echo "apt-get disponível"
  fi

  info_step "Remover pacotes conflitantes (simulado)"
  local pkgs=(docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc)
  for pkg in "${pkgs[@]}"; do
    run echo apt-get remove -y "$pkg"
  done

  info_step "Atualizar índice e instalar pré-requisitos (simulado)"
  run echo apt-get update
  run echo apt-get install -y ca-certificates curl gnupg lsb-release git nano

  info_step "Adicionar repositório do Docker (simulado)"
  run echo install -m 0755 -d /etc/apt/keyrings
  run echo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  run echo chmod a+r /etc/apt/keyrings/docker.asc
  run echo "Escrever linha no /etc/apt/sources.list.d/docker.list (com codename detectado)"
  run echo apt-get update

  info_step "Instalar Docker Engine e plugins (simulado)"
  run echo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  run echo docker --version
  run echo docker compose version

  info_step "Firewall (ufw) — simulação"
  run echo "ufw disable || true"

  info_step "Clonar/atualizar ODK Central em /opt/central (simulado)"
  run echo mkdir -p /opt
  run echo git clone https://github.com/getodk/central /opt/central
  run echo git -C /opt/central submodule update --init -i

  info_step "Criar flag allow-postgres14-upgrade (simulado)"
  run echo touch /opt/central/files/allow-postgres14-upgrade

  info_step "Preparar arquivo .env (simulado)"
  run echo cp /opt/central/.env.template /opt/central/.env
  run echo "Abrir .env no editor (quando não NO_EDIT) — show user to edit"

  info_step "Próximos passos (informativo)"
  printf '%s\n' "cd /opt/central" "docker compose up --build -d" "docker compose logs -f"

  info_step "Criar usuário admin (simulado)"
  run echo "No diretório com docker-compose.yml: sudo bash create_useradmin_odk.sh"

  printf '\nDRY-RUN concluído. Este script não executa comandos.\n'
}

main "$@"
