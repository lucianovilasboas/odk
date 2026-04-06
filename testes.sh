#!/usr/bin/env bash

set -Eeuo pipefail

# --- Configuráveis via ambiente (com valores padrão) -------------------------
: "${DISABLE_UFW:=1}"
: "${ODK_DIR:=/opt/central}"
: "${ODK_REPO:=https://github.com/getodk/central}"
: "${NO_EDIT:=0}"
: "${OVERWRITE_ENV:=0}"


# --- Checagens iniciais ------------------------------------------------------
require_root() {
  # Instalação de pacotes e escrita em /etc e /opt exigem root.
  if [[ "${EUID}" -ne 0 ]]; then
    die "Execute como root (ex.: sudo bash install_odk_novo.sh)"
  fi
}

# --- Utilitários -------------------------------------------------------------
log() {
  # Prefixo simples; evita emojis para facilitar logs em ambientes sem UTF-8.
  # Uso: log "INFO" "mensagem"
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*"
}

die() {
  log "ERRO" "$*"
  exit 1
}

run() {
  # Centraliza execução para manter logs consistentes.
  # Uso: run comando arg1 arg2 ...
  log "EXEC" "$*"
  "$@"
}


print_next_steps() {
  log "INFO" "Configuração concluída. Próximos passos:"
  log "INFO" "1) Entre no diretório: cd ${ODK_DIR}"
  log "INFO" "2) Suba os serviços: docker compose up --build -d"
  log "INFO" "3) Acompanhe logs (opcional): docker compose logs -f"
}

print_ls_output() {
  run ls -lah .
}

detect_codename() {
  # Determina codinome da distro para o repo do Docker.
  # Preferimos /etc/os-release para suportar Ubuntu e Debian.
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    # UBUNTU_CODENAME pode existir no Ubuntu; VERSION_CODENAME costuma existir em Debian/Ubuntu.
    local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    [[ -n "${codename}" ]] || die "Não foi possível determinar o codinome da distro (UBUNTU_CODENAME/VERSION_CODENAME)."
    printf '%s' "${codename}"
  else
    die "/etc/os-release não encontrado; não sei identificar a versão da distro."
  fi
}

main() {
  require_root
  print_next_steps
  #cd /home/luciano
  print_ls_output
  detect_codename
}

main "$@"