# Guia detalhado do fluxo de instalação (baseado em `odk_install.sh`)

Este documento descreve, passo a passo, o que o script **`odk_install.sh`** faz para instalar e preparar o ODK Central em um servidor Ubuntu/Debian.

> O script antigo `install_odk.sh` ainda existe no repositório como referência, mas o recomendado é usar `odk_install.sh`.

## Visão geral

O script é dividido em **14 etapas** executadas sequencialmente. Todas as ações são registradas em tela e no arquivo de log (padrão: `/var/log/odk_install.log`). Um trap de erro captura falhas com o número da linha, facilitando diagnóstico.

## Variáveis de ambiente

Antes de executar, você pode personalizar o comportamento exportando variáveis:

| Variável | Padrão | Descrição |
|---|---|---|
| `DISABLE_UFW` | `1` | `0` para manter o firewall ativo |
| `ODK_DIR` | `/opt/central` | Caminho de instalação do Central |
| `ODK_REPO` | `https://github.com/getodk/central` | URL do repositório |
| `NO_EDIT` | `0` | `1` para não abrir editor automaticamente |
| `OVERWRITE_ENV` | `0` | `1` para sobrescrever `.env` existente |
| `LOG_FILE` | `/var/log/odk_install.log` | Caminho do arquivo de log |
| `EDITOR` | `nano` | Editor usado para abrir o `.env` |

## Etapa 1 — Validação de root e dependências

- `set -Eeuo pipefail`: ativa modo seguro do bash.
  - `-e`: interrompe ao ocorrer erro.
  - `-u`: falha ao usar variável não definida.
  - `-o pipefail`: falha se qualquer comando de um pipe falhar.
  - `-E`: preserva comportamento de traps em funções/subshells.
- Verifica se o usuário atual é root (`EUID != 0`). Se não for, encerra imediatamente.
- Verifica se `apt-get` e `dpkg` estão disponíveis (garante que é Ubuntu/Debian).
- Um **trap de erro** (`on_error`) captura qualquer falha e exibe a linha onde ocorreu.

## Etapa 2 — Remoção de pacotes conflitantes

Remove pacotes que podem conflitar com o Docker oficial:

- `docker.io`, `docker-doc`, `docker-compose`, `docker-compose-v2`
- `podman-docker`, `containerd`, `runc`

Cada remoção usa `|| true` para não falhar se o pacote não estiver instalado.

## Etapa 3 — Atualização de índices e pré-requisitos

Executa:

- `export DEBIAN_FRONTEND=noninteractive` (evita prompts interativos)
- `apt-get update`
- `apt-get install -y ca-certificates curl gnupg lsb-release git nano`

Função dos pacotes:

- `ca-certificates`: validação TLS.
- `curl`: download da chave GPG.
- `gnupg`: verificação de chaves.
- `lsb-release`: informações da distribuição.
- `git`: clonagem do repositório ODK Central.
- `nano`: editor padrão para `.env`.

## Etapa 4 — Chave GPG e repositório oficial do Docker

1. Cria diretório de keyrings: `/etc/apt/keyrings`.
2. Baixa chave GPG: `https://download.docker.com/linux/ubuntu/gpg` → `/etc/apt/keyrings/docker.asc`.
3. Ajusta permissão de leitura.
4. Detecta **arquitetura** (`dpkg --print-architecture`) e **codinome** da distro (`/etc/os-release`).
5. Grava `/etc/apt/sources.list.d/docker.list` com a linha do repositório.
6. Executa `apt-get update` para indexar o novo repositório.

## Etapa 5 — Instalação do Docker Engine e plugins

Instala:

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`

## Etapa 6 — Verificação das versões

Valida a instalação com:

- `docker --version`
- `docker compose version`

## Etapa 7 — Desativação do firewall UFW (opcional)

- Se `DISABLE_UFW=1` (padrão): desativa UFW (apenas se `ufw` estiver instalado).
- Se `DISABLE_UFW=0`: mantém firewall intacto.

> **Nota de segurança:** em produção, o ideal é manter o firewall ativo e liberar apenas portas necessárias (80, 443, SSH).

## Etapa 8 — Clone ou atualização do ODK Central

O script é **idempotente**:

- Se `/opt/central/.git` já existe → faz `git fetch --all --prune` + `git pull --ff-only`.
- Se `/opt/central` existe mas não é repositório git → aborta com erro.
- Caso contrário → faz `git clone` do repositório configurado.

Permissões: `umask 022` garante arquivos legíveis por todos.

## Etapa 9 — Atualização de submódulos

Executa:

```bash
git -C /opt/central submodule update --init
```

Inicializa e atualiza todos os submódulos do projeto.

## Etapa 10 — Flag de upgrade do PostgreSQL

Cria o diretório `files/` (se não existir) e o arquivo marcador:

- `${ODK_DIR}/files/allow-postgres14-upgrade`

Esse flag é usado pelo ODK Central para permitir migrações de versão do PostgreSQL.

## Etapa 11 — Criação do arquivo `.env`

- Verifica se `.env.template` existe (falha se não existir).
- Se `.env` já existe e `OVERWRITE_ENV=0` (padrão): **não sobrescreve**.
- Se `.env` já existe e `OVERWRITE_ENV=1`: sobrescreve com aviso.
- Caso contrário: copia `.env.template` → `.env`.

## Etapa 12 — Cópia do script auxiliar `odk_create_user.sh`

- Procura `odk_create_user.sh` no diretório de onde o instalador foi chamado (`SCRIPT_DIR`).
- Se encontrado: copia para `${ODK_DIR}/odk_create_user.sh` e dá permissão de execução.
- Se não encontrado: exibe aviso e continua.

## Etapa 13 — Edição do `.env`

Informa que é necessário configurar `DOMAIN` e `SYSADMIN_EMAIL`.

- Se `NO_EDIT=0` (padrão): abre o editor (`$EDITOR` → `nano` → `vi`).
- Se `NO_EDIT=1`: apenas orienta o operador a editar manualmente.

## Etapa 14 — Próximos passos

Exibe os comandos que devem ser executados manualmente após o script:

```bash
cd /opt/central
docker compose up --build -d
docker compose logs -f     # opcional
```

## Resumo: automático vs. manual

**Automático:**

- Preparação do sistema e Docker.
- Clone/atualização do ODK Central e submódulos.
- Criação de `.env` e flag de upgrade.
- Cópia do script de criação de usuário.

**Manual (obrigatório):**

- Configurar `DOMAIN` e `SYSADMIN_EMAIL` no `.env`.
- Executar `docker compose up --build -d`.
- Criar o usuário admin com `odk_create_user.sh`.

## Como executar

```bash
# Com permissão de execução:
sudo ./odk_install.sh

# Ou diretamente:
sudo bash odk_install.sh

# Exemplo com variáveis personalizadas:
sudo NO_EDIT=1 DISABLE_UFW=0 bash odk_install.sh
```

## Simulação (dry-run)

Para visualizar todas as etapas sem executar nenhum comando no sistema:

```bash
bash dry-run.sh
```
