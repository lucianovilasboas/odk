#!/usr/bin/env bash

###############################################################################
# dry-run.sh
#
# Simula (sem executar) todas as etapas do odk_install.sh.
# Útil para validar o fluxo antes de rodar no servidor real.
#
# Uso:
#   bash dry-run.sh
#
# Aceita as mesmas variáveis de ambiente do odk_install.sh para refletir
# o comportamento que seria adotado:
#   DISABLE_UFW, ODK_DIR, ODK_REPO, NO_EDIT, OVERWRITE_ENV, LOG_FILE
#
###############################################################################

set -Eeuo pipefail

# --- Variáveis (mesmas do odk_install.sh) ------------------------------------
: "${DISABLE_UFW:=1}"
: "${ODK_DIR:=/opt/central}"
: "${ODK_REPO:=https://github.com/getodk/central}"
: "${NO_EDIT:=0}"
: "${OVERWRITE_ENV:=0}"
: "${LOG_FILE:=/var/log/odk_install.log}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Utilitários -------------------------------------------------------------

log() {
  local level="$1"; shift
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] [%s] %s\n' "${ts}" "${level}" "$*"
}

dry() {
  # Imprime o comando que SERIA executado.
  log "DRY " "$*"
}

separator() {
  log "----" "-----------------------------------------------"
}

# --- Etapa 1: Checagens iniciais ---------------------------------------------

step_require_root() {
  separator
  log "INFO" "Etapa 1: Verificando permissões de root..."
  if [[ "${EUID}" -ne 0 ]]; then
    log "AVISO" "Não está rodando como root. Em execução real o script abortaria aqui."
  else
    log "INFO" "Executando como root — OK."
  fi

  log "INFO" "Verificando disponibilidade do apt-get e dpkg..."
  if command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
    log "INFO" "apt-get e dpkg disponíveis — OK."
  else
    log "AVISO" "apt-get/dpkg não encontrados. Este script é para Ubuntu/Debian."
  fi
}

# --- Etapa 2: Remoção de pacotes conflitantes --------------------------------

step_remove_conflicting() {
  separator
  log "INFO" "Etapa 2: Removendo pacotes potencialmente conflitantes..."

  local pkgs=(
    docker.io docker-doc docker-compose docker-compose-v2
    podman-docker containerd runc
  )
  for pkg in "${pkgs[@]}"; do
    dry "apt-get remove -y ${pkg} || true"
  done

  log "INFO" "Remoção de conflitantes concluída (simulado)."
}

# --- Etapa 3: Pré-requisitos -------------------------------------------------

step_install_prerequisites() {
  separator
  log "INFO" "Etapa 3: Atualizando índice de pacotes e instalando pré-requisitos..."

  dry "export DEBIAN_FRONTEND=noninteractive"
  dry "apt-get update"
  dry "apt-get install -y ca-certificates curl gnupg lsb-release git nano"

  log "INFO" "Pré-requisitos instalados (simulado)."
}

# --- Etapa 4: Chave GPG e repositório Docker ---------------------------------

step_add_docker_repo() {
  separator
  log "INFO" "Etapa 4: Adicionando chave GPG e repositório oficial do Docker..."

  dry "install -m 0755 -d /etc/apt/keyrings"
  dry "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
  dry "chmod a+r /etc/apt/keyrings/docker.asc"

  local arch="amd64"
  if command -v dpkg >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture)"
  fi
  log "INFO" "Arquitetura detectada: ${arch}"

  local codename="<codename>"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-<desconhecido>}}"
  fi
  log "INFO" "Codinome da distro: ${codename}"

  dry "tee /etc/apt/sources.list.d/docker.list <<< 'deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable'"
  dry "apt-get update"

  log "INFO" "Repositório Docker adicionado (simulado)."
}

# --- Etapa 5–6: Instalação e verificação do Docker ---------------------------

step_install_docker() {
  separator
  log "INFO" "Etapa 5: Instalando Docker Engine e plugins..."

  dry "export DEBIAN_FRONTEND=noninteractive"
  dry "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

  separator
  log "INFO" "Etapa 6: Verificando versões instaladas..."
  dry "docker --version"
  dry "docker compose version"

  log "INFO" "Docker instalado e verificado (simulado)."
}

# --- Etapa 7: Firewall -------------------------------------------------------

step_firewall() {
  separator
  log "INFO" "Etapa 7: Tratamento do firewall (UFW)..."

  if [[ "${DISABLE_UFW}" == "1" ]]; then
    log "AVISO" "UFW seria desativado (DISABLE_UFW=1)."
    dry "ufw disable || true"
  else
    log "INFO" "Firewall seria mantido (DISABLE_UFW=0)."
  fi
}

# --- Etapa 8–9: Clone/atualização do ODK Central -----------------------------

step_clone_central() {
  separator
  log "INFO" "Etapa 8: Obtendo repositório do ODK Central em: ${ODK_DIR}"

  dry "umask 022"
  dry "mkdir -p $(dirname "${ODK_DIR}")"

  if [[ -d "${ODK_DIR}/.git" ]]; then
    log "INFO" "Repositório já existe; seria atualizado (fetch + pull)."
    dry "git -C ${ODK_DIR} fetch --all --prune"
    dry "git -C ${ODK_DIR} pull --ff-only"
  elif [[ -e "${ODK_DIR}" ]]; then
    log "AVISO" "${ODK_DIR} existe mas não é repositório git. Em execução real o script abortaria."
  else
    dry "git clone ${ODK_REPO} ${ODK_DIR}"
  fi

  separator
  log "INFO" "Etapa 9: Atualizando submódulos..."
  dry "git -C ${ODK_DIR} submodule update --init"

  log "INFO" "Repositório ODK Central pronto (simulado)."
}

# --- Etapa 10: Flag de upgrade do Postgres ------------------------------------

step_database_flag() {
  separator
  log "INFO" "Etapa 10: Criando flag allow-postgres14-upgrade..."

  dry "mkdir -p ${ODK_DIR}/files"
  dry "touch ${ODK_DIR}/files/allow-postgres14-upgrade"

  log "INFO" "Flag criado (simulado)."
}

# --- Etapa 11: Arquivo .env --------------------------------------------------

step_env_file() {
  separator
  log "INFO" "Etapa 11: Preparando arquivo .env..."

  local template="${ODK_DIR}/.env.template"
  local env_file="${ODK_DIR}/.env"

  if [[ -f "${env_file}" && "${OVERWRITE_ENV}" != "1" ]]; then
    log "INFO" ".env já existe; não seria sobrescrito (OVERWRITE_ENV=0)."
  elif [[ -f "${env_file}" && "${OVERWRITE_ENV}" == "1" ]]; then
    log "AVISO" ".env existente seria sobrescrito (OVERWRITE_ENV=1)."
    dry "cp ${template} ${env_file}"
  else
    dry "cp ${template} ${env_file}"
  fi

  log "INFO" "Arquivo .env preparado (simulado)."
}

# --- Etapa 12: Copiar script auxiliar -----------------------------------------

step_copy_admin_script() {
  separator
  log "INFO" "Etapa 12: Copiando script auxiliar odk_create_user.sh..."

  local src="${SCRIPT_DIR}/odk_create_user.sh"
  local dst="${ODK_DIR}/odk_create_user.sh"

  if [[ -f "${src}" ]]; then
    dry "cp ${src} ${dst}"
    dry "chmod +x ${dst}"
    log "INFO" "Script seria copiado para ${dst}."
  else
    log "AVISO" "Arquivo ${src} não encontrado; cópia seria ignorada."
  fi
}

# --- Etapa 13: Edição do .env -------------------------------------------------

step_edit_env() {
  separator
  log "INFO" "Etapa 13: Configuração do arquivo .env"
  log "INFO" "Variáveis obrigatórias: DOMAIN e SYSADMIN_EMAIL"

  if [[ "${NO_EDIT}" == "1" ]]; then
    log "INFO" "NO_EDIT=1: editor não seria aberto."
  else
    local editor_cmd="${EDITOR:-nano}"
    log "INFO" "Editor que seria utilizado: ${editor_cmd}"
    dry "${editor_cmd} ${ODK_DIR}/.env"
  fi
}

# --- Etapa 14: Próximos passos ------------------------------------------------

step_next_steps() {
  separator
  log "INFO" "Etapa 14: Instalação concluída (simulado)."
  log "INFO" ""
  log "INFO" "Próximos passos reais após executar odk_install.sh:"
  log "INFO" "  1) cd ${ODK_DIR}"
  log "INFO" "  2) docker compose up --build -d"
  log "INFO" "  3) docker compose logs -f"
  log "INFO" ""
  log "INFO" "Log seria gravado em: ${LOG_FILE}"
  separator
}

# --- Main ---------------------------------------------------------------------

main() {
  log "INFO" "=== DRY-RUN do odk_install.sh (nenhum comando será executado) ==="
  log "INFO" "Variáveis ativas:"
  log "INFO" "  DISABLE_UFW=${DISABLE_UFW}  ODK_DIR=${ODK_DIR}  NO_EDIT=${NO_EDIT}  OVERWRITE_ENV=${OVERWRITE_ENV}"
  log "INFO" ""

  step_require_root
  step_remove_conflicting
  step_install_prerequisites
  step_add_docker_repo
  step_install_docker
  step_firewall
  step_clone_central
  step_database_flag
  step_env_file
  step_copy_admin_script
  step_edit_env
  step_next_steps

  log "INFO" "=== DRY-RUN concluído. Nenhuma alteração foi feita no sistema. ==="
}

main "$@"
