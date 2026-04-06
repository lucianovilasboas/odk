#!/usr/bin/env bash

# install.sh
# Bootstrap para instalação via web (curl | bash).
# Exemplo de uso após publicar este arquivo:
#   curl -fsSL https://SEU_DOMINIO/install.sh | bash
# ou:
#   curl -fsSL https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/install.sh | bash

set -Eeuo pipefail

# Ajuste estes valores para seu repositório final.
REPO_SLUG="${REPO_SLUG:-lucianovilasboas/odk}"
REPO_BRANCH="${REPO_BRANCH:-main}"
PAYLOAD_PATH="${PAYLOAD_PATH:-odk_install.sh}"

PAYLOAD_URL="https://raw.githubusercontent.com/${REPO_SLUG}/${REPO_BRANCH}/${PAYLOAD_PATH}"

log() {
  printf '[install.sh] %s\n' "$*"
}

die() {
  log "ERRO: $*"
  exit 1
}

download_payload() {
  local target_file="$1"

  if command -v curl >/dev/null 2>&1; then
    log "Baixando payload com curl: ${PAYLOAD_URL}"
    curl -fsSL --retry 3 --connect-timeout 10 "${PAYLOAD_URL}" -o "${target_file}"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    log "Baixando payload com wget: ${PAYLOAD_URL}"
    wget -qO "${target_file}" "${PAYLOAD_URL}"
    return 0
  fi

  die "Nem curl nem wget estao disponiveis para baixar ${PAYLOAD_URL}."
}

run_payload() {
  local file="$1"
  shift || true

  chmod +x "${file}"

  if [[ "${EUID}" -eq 0 ]]; then
    log "Executando instalador como root..."
    bash "${file}" "$@"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    log "Permissao root necessaria. Solicitando sudo para executar instalador..."
    sudo bash "${file}" "$@"
    return 0
  fi

  die "Este instalador precisa de root e o comando sudo nao foi encontrado."
}

main() {
  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "${tmp_file}"' EXIT

  log "Iniciando bootstrap do ODK Central..."
  download_payload "${tmp_file}"
  run_payload "${tmp_file}" "$@"
  log "Concluido."
}

main "$@"
