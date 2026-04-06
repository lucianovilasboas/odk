#!/usr/bin/env bash

###############################################################################
# odk_install.sh
#
# Objetivo:
#   Automatizar a preparação completa do servidor para rodar o ODK Central
#   via Docker em Ubuntu/Debian.
#
# Etapas executadas:
#   1)  Validação de root e dependências do sistema (apt/dpkg)
#   2)  Remoção de pacotes conflitantes (Docker de distro, Podman, etc.)
#   3)  Atualização de índices e instalação de pré-requisitos
#   4)  Adição da chave GPG e repositório oficial do Docker
#   5)  Instalação do Docker Engine, CLI, containerd, Buildx e Compose
#   6)  Verificação das versões instaladas do Docker
#   7)  (Opcional) Desativação do firewall UFW
#   8)  Clone ou atualização do repositório oficial do ODK Central
#   9)  Atualização de submódulos do Central
#   10) Criação do flag allow-postgres14-upgrade
#   11) Cópia de .env.template para .env (sem sobrescrever por padrão)
#   12) Cópia do script auxiliar create_useradmin_odk.sh para /opt/central
#   13) Abertura do editor para configurar DOMAIN e SYSADMIN_EMAIL
#   14) Orientação dos próximos passos (docker compose up)
#
# O script NÃO executa "docker compose up"; ele apenas prepara o ambiente.
#
# Como usar:
#   sudo bash odk_install.sh
#
# Variáveis de ambiente (opcionais):
#   DISABLE_UFW=1        -> desativa UFW (padrão: 1)
#   DISABLE_UFW=0        -> NÃO mexe no firewall
#   ODK_DIR=/opt/central -> caminho onde o Central será clonado (padrão)
#   ODK_REPO=<url>       -> URL do repositório (padrão: oficial do GitHub)
#   EDITOR=nano|vim      -> editor para abrir o .env (padrão: nano)
#   NO_EDIT=1            -> não abre editor automaticamente
#   OVERWRITE_ENV=1      -> sobrescreve .env existente (padrão: 0)
#   LOG_FILE=<caminho>   -> arquivo de log (padrão: /var/log/odk_install.log)
#
###############################################################################

set -Eeuo pipefail

# --- Configuráveis via ambiente (com valores padrão) -------------------------
: "${DISABLE_UFW:=1}"
: "${ODK_DIR:=/opt/central}"
: "${ODK_REPO:=https://github.com/getodk/central}"
: "${NO_EDIT:=0}"
: "${OVERWRITE_ENV:=0}"
: "${LOG_FILE:=/var/log/odk_install.log}"

# Diretório de onde o script foi chamado (para localizar arquivos auxiliares)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Utilitários de log ------------------------------------------------------

# Cria/abre arquivo de log desde o início
touch "${LOG_FILE}" 2>/dev/null || true

log() {
  # Uso: log "INFO" "mensagem"
  # Grava em tela e no arquivo de log com timestamp.
  local level="$1"; shift
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  local msg="[${ts}] [${level}] $*"
  printf '%s\n' "${msg}"
  printf '%s\n' "${msg}" >> "${LOG_FILE}" 2>/dev/null || true
}

die() {
  log "ERRO" "$*"
  exit 1
}

run() {
  # Executa comando com log prévio do que será rodado.
  log "EXEC" "$*"
  "$@"
}

separator() {
  log "----" "-----------------------------------------------"
}

# --- Trap de erro com número de linha ----------------------------------------
on_error() {
  local exit_code=$?
  local line_no=$1
  log "ERRO" "Falha na linha ${line_no} (exit=${exit_code})."
  log "ERRO" "Verifique o log completo em: ${LOG_FILE}"
  exit "${exit_code}"
}
trap 'on_error $LINENO' ERR

# --- Etapa 1: Checagens iniciais ---------------------------------------------

require_root() {
  separator
  log "INFO" "Etapa 1: Verificando permissões de root..."
  if [[ "${EUID}" -ne 0 ]]; then
    die "Execute como root (ex.: sudo bash odk_install.sh)"
  fi
  log "INFO" "Executando como root — OK."
}

require_apt() {
  log "INFO" "Verificando disponibilidade do apt-get e dpkg..."
  command -v apt-get >/dev/null 2>&1 || die "apt-get não encontrado. Este script é para Ubuntu/Debian."
  command -v dpkg    >/dev/null 2>&1 || die "dpkg não encontrado. Este script é para Ubuntu/Debian."
  log "INFO" "apt-get e dpkg disponíveis — OK."
}

# --- Etapa 2: Remoção de pacotes conflitantes --------------------------------

remove_conflicting_packages() {
  separator
  log "INFO" "Etapa 2: Removendo pacotes potencialmente conflitantes..."

  local pkgs=(
    docker.io
    docker-doc
    docker-compose
    docker-compose-v2
    podman-docker
    containerd
    runc
  )

  for pkg in "${pkgs[@]}"; do
    # || true evita falha se o pacote não estiver instalado
    run apt-get remove -y "${pkg}" 2>/dev/null || true
  done

  log "INFO" "Remoção de conflitantes concluída."
}

# --- Etapa 3: Pré-requisitos -------------------------------------------------

install_prerequisites() {
  separator
  log "INFO" "Etapa 3: Atualizando índice de pacotes e instalando pré-requisitos..."

  export DEBIAN_FRONTEND=noninteractive

  run apt-get update

  run apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    nano

  log "INFO" "Pré-requisitos instalados com sucesso."
}

# --- Etapa 4: Chave GPG e repositório Docker ---------------------------------

detect_codename() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    [[ -n "${codename}" ]] || die "Não foi possível determinar o codinome da distro."
    printf '%s' "${codename}"
  else
    die "/etc/os-release não encontrado."
  fi
}

add_docker_repository() {
  separator
  log "INFO" "Etapa 4: Adicionando chave GPG e repositório oficial do Docker..."

  run install -m 0755 -d /etc/apt/keyrings

  run curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  run chmod a+r /etc/apt/keyrings/docker.asc

  local arch
  arch="$(dpkg --print-architecture)"
  log "INFO" "Arquitetura detectada: ${arch}"

  local codename
  codename="$(detect_codename)"
  log "INFO" "Codinome da distro: ${codename}"

  local repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable"

  printf '%s\n' "${repo_line}" | run tee /etc/apt/sources.list.d/docker.list >/dev/null

  run apt-get update

  log "INFO" "Repositório Docker adicionado com sucesso."
}

# --- Etapa 5–6: Instalação e verificação do Docker ---------------------------

install_docker() {
  separator
  log "INFO" "Etapa 5: Instalando Docker Engine e plugins..."

  export DEBIAN_FRONTEND=noninteractive

  run apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  separator
  log "INFO" "Etapa 6: Verificando versões instaladas..."
  run docker --version
  run docker compose version

  log "INFO" "Docker instalado e verificado com sucesso."
}

# --- Etapa 7: Firewall -------------------------------------------------------

maybe_disable_ufw() {
  separator
  log "INFO" "Etapa 7: Tratamento do firewall (UFW)..."

  if [[ "${DISABLE_UFW}" == "1" ]]; then
    if command -v ufw >/dev/null 2>&1; then
      log "AVISO" "Desativando UFW (DISABLE_UFW=1). Em produção, considere manter ativo com regras específicas."
      run ufw disable || true
    else
      log "INFO" "ufw não está instalado; nada a fazer."
    fi
  else
    log "INFO" "Mantendo firewall como está (DISABLE_UFW=0)."
  fi
}

# --- Etapa 8–9: Clone/atualização do ODK Central -----------------------------

clone_or_update_central() {
  separator
  log "INFO" "Etapa 8: Obtendo repositório do ODK Central em: ${ODK_DIR}"

  umask 022
  run mkdir -p "$(dirname "${ODK_DIR}")"

  if [[ -d "${ODK_DIR}/.git" ]]; then
    log "INFO" "Repositório já existe; atualizando (fetch + pull)..."
    run git -C "${ODK_DIR}" fetch --all --prune
    run git -C "${ODK_DIR}" pull --ff-only
  elif [[ -e "${ODK_DIR}" ]]; then
    die "${ODK_DIR} já existe mas não é um repositório git. Renomeie/remova e rode novamente."
  else
    run git clone "${ODK_REPO}" "${ODK_DIR}"
  fi

  separator
  log "INFO" "Etapa 9: Atualizando submódulos..."
  run git -C "${ODK_DIR}" submodule update --init

  log "INFO" "Repositório ODK Central pronto."
}

# --- Etapa 10: Flag de upgrade do Postgres ------------------------------------

prepare_database_flag() {
  separator
  log "INFO" "Etapa 10: Criando flag allow-postgres14-upgrade..."

  run mkdir -p "${ODK_DIR}/files"
  run touch "${ODK_DIR}/files/allow-postgres14-upgrade"

  log "INFO" "Flag criado em ${ODK_DIR}/files/allow-postgres14-upgrade."
}

# --- Etapa 11: Arquivo .env --------------------------------------------------

setup_env_file() {
  separator
  log "INFO" "Etapa 11: Preparando arquivo .env..."

  local template="${ODK_DIR}/.env.template"
  local env_file="${ODK_DIR}/.env"

  [[ -f "${template}" ]] || die "Arquivo ${template} não encontrado. O clone pode ter falhado."

  if [[ -f "${env_file}" && "${OVERWRITE_ENV}" != "1" ]]; then
    log "INFO" ".env já existe; mantendo o atual (use OVERWRITE_ENV=1 para forçar)."
    return 0
  fi

  if [[ -f "${env_file}" && "${OVERWRITE_ENV}" == "1" ]]; then
    log "AVISO" "Sobrescrevendo .env existente (OVERWRITE_ENV=1)."
  fi

  run cp "${template}" "${env_file}"
  log "INFO" "Arquivo .env criado a partir de .env.template."
}

# --- Etapa 12: Copiar script auxiliar -----------------------------------------

copy_admin_script() {
  separator
  log "INFO" "Etapa 12: Copiando script auxiliar odk_create_user.sh..."

  local src="${SCRIPT_DIR}/odk_create_user.sh"
  local dst="${ODK_DIR}/odk_create_user.sh"

  if [[ -f "${src}" ]]; then
    run cp "${src}" "${dst}"
    run chmod +x "${dst}"
    log "INFO" "Script copiado para ${dst}."
  else
    log "AVISO" "Arquivo ${src} não encontrado; pulando cópia. Copie manualmente se necessário."
  fi
}

# --- Etapa 13: Edição do .env -------------------------------------------------

edit_env_file() {
  separator
  log "INFO" "Etapa 13: Configuração do arquivo .env"

  local env_file="${ODK_DIR}/.env"

  log "INFO" "Você precisa configurar ao menos DOMAIN e SYSADMIN_EMAIL."
  log "INFO" "Exemplo: DOMAIN=odk.seudominio.com  SYSADMIN_EMAIL=seu@email.com"

  if [[ "${NO_EDIT}" == "1" ]]; then
    log "INFO" "NO_EDIT=1: editor não será aberto automaticamente."
    log "INFO" "Edite manualmente: ${env_file}"
    return 0
  fi

  # Respeita $EDITOR; se vazio, tenta nano; senão vi
  local editor_cmd="${EDITOR:-}"
  if [[ -z "${editor_cmd}" ]]; then
    if command -v nano >/dev/null 2>&1; then
      editor_cmd="nano"
    else
      editor_cmd="vi"
    fi
  fi

  log "INFO" "Abrindo ${env_file} com: ${editor_cmd}"
  run "${editor_cmd}" "${env_file}"
}

# --- Etapa 14: Próximos passos ------------------------------------------------

print_next_steps() {
  separator
  log "INFO" "Etapa 14: Instalação concluída com sucesso!"
  log "INFO" ""
  log "INFO" "Próximos passos:"
  log "INFO" "  1) Acesse o diretório:  cd ${ODK_DIR}"
  log "INFO" "  2) Suba os serviços:    docker compose up --build -d"
  log "INFO" "  3) Acompanhe os logs:   docker compose logs -f"
  log "INFO" ""
  log "INFO" "Log completo desta instalação: ${LOG_FILE}"
  separator
}

# --- Função principal ---------------------------------------------------------

main() {
  log "INFO" "Iniciando instalação do ODK Central..."
  log "INFO" "Log sendo gravado em: ${LOG_FILE}"

  require_root
  require_apt

  remove_conflicting_packages
  install_prerequisites
  add_docker_repository
  install_docker
  maybe_disable_ufw

  clone_or_update_central
  prepare_database_flag
  setup_env_file
  copy_admin_script
  edit_env_file

  print_next_steps
}

main "$@"
