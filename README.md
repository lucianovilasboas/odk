# ODK Central — Instalação automatizada

Scripts para preparar e instalar o [ODK Central](https://docs.getodk.org/central-install/) em uma VPS Ubuntu 24.04 LTS.

## Pré-requisitos

- VPS com **Ubuntu 24.04 LTS** (ex.: Hostinger, DigitalOcean, etc.)
- Domínio/subdomínio apontando para o IP da VPS (ex.: `odk.seudominio.com`)
- Acesso **root** (ou `sudo`)

## Configuração DNS

Antes de instalar, configure os registros DNS do seu domínio/subdomínio para apontar para a VPS. Detalhes e exemplos com imagens em [INSTALACAO.md](INSTALACAO.md#passo-0---configurações-dns-do-dominio-e-subdominio).

## Instalação rápida

```bash
# 1. Copie os scripts para a VPS e dê permissão de execução
chmod +x odk_install.sh odk_create_user.sh

# 2. Execute o instalador (prepara Docker + ODK Central)
sudo bash odk_install.sh

# 3. Acesse /opt/central e suba os serviços
cd /opt/central
docker compose up --build -d

# 4. Crie o usuário admin
sudo bash odk_create_user.sh
```

> Para detalhes de cada etapa do instalador, consulte [SCRIPT.md](SCRIPT.md).

## Arquivos do repositório

| Arquivo | Descrição |
|---|---|
| `odk_install.sh` | **Script recomendado** — prepara o servidor, instala Docker e clona o ODK Central |
| `odk_create_user.sh` | Cria usuário administrador no ODK Central |
| `install_odk.sh` | Versão anterior/simplificada do instalador |
| `install_odk_novo.sh` | Versão intermediária usada como base para `odk_install.sh` |
| `dry-run.sh` | Script de teste (dry-run) |


## Documentação

- [INSTALACAO.md](INSTALACAO.md) — Tutorial completo passo a passo (DNS, VPS, instalação e criação de usuário)
- [SCRIPT.md](SCRIPT.md) — Explicação detalhada de cada etapa executada pelo instalador

## Variáveis de ambiente (opcionais)

O `odk_install.sh` aceita variáveis para personalizar o comportamento:

| Variável | Padrão | Descrição |
|---|---|---|
| `DISABLE_UFW` | `1` | `0` para manter o firewall ativo |
| `ODK_DIR` | `/opt/central` | Caminho de instalação do Central |
| `NO_EDIT` | `0` | `1` para não abrir editor automaticamente |
| `OVERWRITE_ENV` | `0` | `1` para sobrescrever `.env` existente |
| `LOG_FILE` | `/var/log/odk_install.log` | Caminho do arquivo de log |

## Referências

- [Documentação oficial do ODK Central](https://docs.getodk.org/central-install/)
- [Guia de instalação DigitalOcean](https://docs.getodk.org/central-install-digital-ocean/)
