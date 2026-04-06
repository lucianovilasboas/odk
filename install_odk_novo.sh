#!/usr/bin/env bash

###############################################################################
# install_odk_novo.sh
#
# Objetivo:
#   Automatizar a preparação do servidor para rodar o ODK Central via Docker.
#   Este script:
#     1) Remove pacotes conflitantes (Docker de distro/Podman etc.)
#     2) Instala pré-requisitos (curl, gnupg, git, etc.)
#     3) Adiciona repositório oficial do Docker e instala Docker Engine
#     4) (Opcional) desativa o UFW
#     5) Clona (ou atualiza) o repositório oficial do ODK Central em /opt/central
#     6) Atualiza submódulos do Central
#     7) Cria arquivo de sinalização allow-postgres14-upgrade
#     8) Copia .env.template para .env (sem sobrescrever, por padrão)
#     9) Abre o editor para você ajustar DOMAIN e SYSADMIN_EMAIL
#
# Observações importantes:
#   - O ODK Central é sensível a configuração de domínio, certificados e portas.
#   - Este script NÃO executa "docker compose up"; ele apenas prepara o ambiente.
#   - O script foi escrito para Ubuntu/Debian (usa apt).
#
# Como usar (exemplos):
#   sudo bash install_odk_novo.sh
#
# Variáveis de ambiente (opcionais):
#   DISABLE_UFW=1        -> desativa UFW (padrão: 1, mantendo comportamento antigo)
#   DISABLE_UFW=0        -> NÃO mexe no firewall
#   ODK_DIR=/opt/central -> caminho onde o Central será clonado (padrão: /opt/central)
#   ODK_REPO=...         -> URL do repositório do Central (padrão: oficial)
#   EDITOR=nano|vim      -> editor para abrir o .env (padrão: nano se existir)
#   NO_EDIT=1            -> não abre editor automaticamente; apenas orienta
#   OVERWRITE_ENV=1      -> sobrescreve .env com .env.template (padrão: 0)
#
###############################################################################

set -Eeuo pipefail

# --- Configuráveis via ambiente (com valores padrão) -------------------------
: "${DISABLE_UFW:=1}"
: "${ODK_DIR:=/opt/central}"
: "${ODK_REPO:=https://github.com/getodk/central}"
: "${NO_EDIT:=0}"
: "${OVERWRITE_ENV:=0}"

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

on_error() {
  local exit_code=$?
  local line_no=$1
  log "ERRO" "Falha na linha ${line_no} (exit=${exit_code})."
  log "ERRO" "Interrompendo para evitar estado parcial."
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

# --- Checagens iniciais ------------------------------------------------------
require_root() {
  # Instalação de pacotes e escrita em /etc e /opt exigem root.
  if [[ "${EUID}" -ne 0 ]]; then
    die "Execute como root (ex.: sudo bash install_odk_novo.sh)"
  fi
}

require_apt() {
  command -v apt-get >/dev/null 2>&1 || die "apt-get não encontrado. Este script é para Ubuntu/Debian."
  command -v dpkg >/dev/null 2>&1 || die "dpkg não encontrado. Este script é para Ubuntu/Debian."
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

# --- Etapa 1: remover conflitos ---------------------------------------------
remove_conflicting_packages() {
  log "INFO" "Removendo possíveis pacotes conflitantes (se existirem)..."

  # Lista baseada na recomendação do próprio Docker + itens do script antigo.
  # Não falha se algum pacote não estiver instalado.
  local pkgs=(
    docker.io
    docker-doc
    docker-compose
    docker-compose-v2
    podman-docker
    containerd
    runc
  )

  # Importante: removemos um a um para manter comportamento previsível.
  for pkg in "${pkgs[@]}"; do
    # apt-get remove retorna 0 mesmo se o pacote não existe em muitos casos,
    # mas em algumas versões pode retornar não-zero. Por isso usamos "|| true".
    run apt-get remove -y "${pkg}" || true
  done
}

# --- Etapa 2: pré-requisitos -------------------------------------------------
install_prerequisites() {
  log "INFO" "Atualizando índice de pacotes e instalando pré-requisitos..."

  # DEBIAN_FRONTEND evita prompts em instalações automatizadas.
  export DEBIAN_FRONTEND=noninteractive

  run apt-get update

  # Pacotes mínimos:
  # - ca-certificates/curl/gnupg: para baixar e validar chave/repo
  # - lsb-release: útil para info de distro (embora usemos os-release)
  # - git: clonar o Central
  # - nano: editor padrão (opcional, mas mantém UX do script antigo)
  run apt-get install -y ca-certificates curl gnupg lsb-release git nano
}

# --- Etapa 3: repo do Docker -------------------------------------------------
add_docker_repository() {
  log "INFO" "Adicionando chave GPG e repositório oficial do Docker..."

  # Diretório recomendado para keyrings no Ubuntu moderno.
  run install -m 0755 -d /etc/apt/keyrings

  # Baixa chave em formato .asc conforme documentação do Docker.
  run curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  run chmod a+r /etc/apt/keyrings/docker.asc

  local arch
  arch="$(dpkg --print-architecture)"

  local codename
  codename="$(detect_codename)"

  # Observação: o script original fixa "linux/ubuntu". Mantemos isso para não alterar
  # comportamento, mas em Debian o correto seria "linux/debian". Se você estiver
  # em Debian e tiver erro de repo, ajuste aqui.
  local repo_line
  repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable"

  # Escreve arquivo de lista do apt de forma determinística.
  printf '%s\n' "${repo_line}" | run tee /etc/apt/sources.list.d/docker.list >/dev/null

  run apt-get update
}

# --- Etapa 4: instalar Docker ------------------------------------------------
install_docker() {
  log "INFO" "Instalando Docker Engine e plugins (Compose/Buildx)..."

  export DEBIAN_FRONTEND=noninteractive

  run apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  log "INFO" "Verificando versões instaladas..."
  run docker --version
  run docker compose version
}

# --- Etapa 5: firewall -------------------------------------------------------
maybe_disable_ufw() {
  # O script antigo sempre desativava o UFW.
  # Isso pode ser perigoso em produção; por isso deixamos controlável via variável.
  if [[ "${DISABLE_UFW}" == "1" ]]; then
    if command -v ufw >/dev/null 2>&1; then
      log "AVISO" "Desativando UFW (DISABLE_UFW=1)."
      run ufw disable || true
    else
      log "INFO" "ufw não está instalado; nada a desativar."
    fi
  else
    log "INFO" "Mantendo firewall como está (DISABLE_UFW=0)."
  fi
}

# --- Etapa 6: Central --------------------------------------------------------
clone_or_update_central() {
  log "INFO" "Obtendo o repositório do ODK Central em: ${ODK_DIR}"

  # Garante permissões consistentes nos arquivos criados.
  umask 022

  # /opt costuma existir; mas criamos se necessário.
  run mkdir -p "$(dirname "${ODK_DIR}")"

  if [[ -d "${ODK_DIR}/.git" ]]; then
    log "INFO" "Repositório já existe; atualizando (git fetch/pull)..."
    run git -C "${ODK_DIR}" fetch --all --prune
    run git -C "${ODK_DIR}" pull --ff-only
  elif [[ -e "${ODK_DIR}" ]]; then
    die "${ODK_DIR} já existe mas não parece ser um repositório git. Renomeie/remova e rode novamente."
  else
    run git clone "${ODK_REPO}" "${ODK_DIR}"
  fi

  log "INFO" "Atualizando submódulos (init + update)..."
  run git -C "${ODK_DIR}" submodule update --init -i
}

prepare_database_flag() {
  # ODK Central usa Postgres dentro do stack. Em certas migrações/atualizações,
  # existe uma proteção para upgrade de versão maior do Postgres.
  # Criar este arquivo libera o upgrade para Postgres 14 quando aplicável.
  log "INFO" "Criando flag allow-postgres14-upgrade (conforme repositório Central)..."
  run touch "${ODK_DIR}/files/allow-postgres14-upgrade"
}

setup_env_file() {
  log "INFO" "Preparando arquivo .env..."

  local template="${ODK_DIR}/.env.template"
  local env_file="${ODK_DIR}/.env"

  [[ -f "${template}" ]] || die "Arquivo ${template} não encontrado. Clone do repositório pode ter falhado."

  if [[ -f "${env_file}" && "${OVERWRITE_ENV}" != "1" ]]; then
    log "INFO" ".env já existe; não vou sobrescrever (use OVERWRITE_ENV=1 para forçar)."
    return 0
  fi

  if [[ -f "${env_file}" && "${OVERWRITE_ENV}" == "1" ]]; then
    log "AVISO" "Sobrescrevendo .env existente (OVERWRITE_ENV=1)."
  fi

  run cp "${template}" "${env_file}"
}

edit_env_file() {
  local env_file="${ODK_DIR}/.env"

  log "INFO" "Você precisa configurar ao menos DOMAIN e SYSADMIN_EMAIL no .env."
  log "INFO" "Exemplo: DOMAIN=odk.seudominio.com  e  SYSADMIN_EMAIL=seu@email.com"

  if [[ "${NO_EDIT}" == "1" ]]; then
    log "INFO" "NO_EDIT=1: não abrindo editor automaticamente."
    log "INFO" "Edite manualmente: ${env_file}"
    return 0
  fi

  # Escolhe editor: respeita $EDITOR; se vazio, tenta nano; senão tenta vi.
  local editor_cmd="${EDITOR:-}"
  if [[ -z "${editor_cmd}" ]]; then
    if command -v nano >/dev/null 2>&1; then
      editor_cmd="nano"
    else
      editor_cmd="vi"
    fi
  fi

  log "INFO" "Abrindo ${env_file} com o editor: ${editor_cmd}"
  run "${editor_cmd}" "${env_file}"
}

print_next_steps() {
  log "INFO" "Configuração concluída. Próximos passos:"
  log "INFO" "1) Entre no diretório: cd ${ODK_DIR}"
  log "INFO" "2) Suba os serviços: docker compose up --build -d"
  log "INFO" "3) Acompanhe logs (opcional): docker compose logs -f"
}

main() {
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
  edit_env_file

  print_next_steps
}

main "$@"
