# Guia detalhado do fluxo de instalação (baseado em `install_odk.sh`)

Este documento descreve, passo a passo, o que o script `install_odk.sh` faz para instalar e preparar o ODK Central em um servidor Ubuntu.

## 1. Validação de execução como root

O script começa com:

- `set -Eeuo pipefail`: ativa modo mais seguro para shell script.
	- `-e`: interrompe ao ocorrer erro.
	- `-u`: falha ao usar variável não definida.
	- `-o pipefail`: falha se qualquer comando de um pipe falhar.
	- `-E`: preserva comportamento de traps em funções/subshells.
- Verifica se o usuário atual é root (`EUID != 0`).

Se não for root, o script exibe mensagem e encerra imediatamente.

## 2. Remoção de pacotes potencialmente conflitantes de container

Antes de instalar Docker oficial, o script remove pacotes que podem conflitar:

- `docker.io`
- `docker-doc`
- `docker-compose`
- `docker-compose-v2`
- `podman-docker`
- `containerd`
- `runc`

Objetivo: evitar mistura de versões/pacotes de origens diferentes.

## 3. Atualização de índices e instalação de pré-requisitos

Executa:

- `apt-get update`
- `apt-get install -y ca-certificates curl gnupg lsb-release git nano`

Função de cada pacote principal:

- `ca-certificates`: validação TLS.
- `curl`: download de arquivos (chave GPG).
- `gnupg`: manipulação/verificação de chaves.
- `lsb-release`: informações da distribuição.
- `git`: clonagem do repositório ODK Central.
- `nano`: edição do arquivo `.env`.

## 4. Configuração da chave GPG oficial do Docker

Passos executados:

1. Cria diretório de keyrings: `/etc/apt/keyrings`.
2. Baixa chave GPG da Docker:
	 - URL: `https://download.docker.com/linux/ubuntu/gpg`
	 - Salva em: `/etc/apt/keyrings/docker.asc`
3. Ajusta permissão de leitura global na chave.

Isso garante que o apt confie no repositório oficial da Docker.

## 5. Adição do repositório oficial do Docker

O script grava o arquivo:

- `/etc/apt/sources.list.d/docker.list`

Com uma entrada que usa:

- Arquitetura retornada por `dpkg --print-architecture`
- Distribuição detectada via `/etc/os-release`
- Assinatura pela chave em `/etc/apt/keyrings/docker.asc`

Depois disso, executa `apt-get update` novamente para carregar os pacotes desse novo repositório.

## 6. Instalação do Docker Engine e plugins

Instala os componentes:

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`

Em seguida valida a instalação com:

- `docker --version`
- `docker compose version`

## 7. Desativação do firewall UFW

O script executa:

- `ufw disable`

Efeito: remove bloqueio padrão de portas no host via UFW.

Observação importante:

- Em produção, o ideal é manter firewall ativo e liberar apenas portas necessárias (por exemplo, 80/443 e portas administrativas específicas).

## 8. Clone do ODK Central em `/opt`

Passos:

1. `cd /opt`
2. `umask 022` (arquivos padrão legíveis por outros usuários)
3. `git clone https://github.com/getodk/central`
4. `cd central`
5. `git submodule update -i`

Resultado esperado: código do ODK Central disponível em `/opt/central`.

## 9. Preparação para PostgreSQL 14

O script cria o arquivo:

- `./files/allow-postgres14-upgrade`

Esse marcador é usado pelo projeto para permitir fluxo de upgrade relacionado ao PostgreSQL 14.

## 10. Criação do arquivo de ambiente

O script copia template para arquivo real:

- Origem: `.env.template`
- Destino: `.env`

Depois orienta o operador a editar variáveis essenciais:

- `DOMAIN`
- `SYSADMIN_EMAIL`

E abre o editor interativo:

- `nano .env`

## 11. Etapa manual final para subir os serviços

Após terminar a edição do `.env`, o script orienta executar:

```bash
cd /opt/central
docker compose up --build -d
```

Isso faz build das imagens necessárias e sobe os containers em segundo plano.

## 12. Resumo rápido do que é automático x manual

Automático no script:

- Preparação do sistema e Docker.
- Clone do ODK Central.
- Inicialização de arquivos base (`.env` e marcador de upgrade).

Manual (obrigatório):

- Preencher corretamente o arquivo `.env`.
- Executar `docker compose up --build -d`.

## 13. Comando único para executar o instalador

Se o arquivo já tiver permissão de execução:

```bash
sudo ./install_odk.sh
```

Se ainda não tiver:

```bash
chmod +x install_odk.sh
sudo ./install_odk.sh
```
