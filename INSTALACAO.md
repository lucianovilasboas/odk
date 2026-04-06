# Instalação do ODK Central

Tutorial de Instalação do ODK Central 

Baseado em: 

- https://docs.getodk.org/central-install

- https://docs.getodk.org/central-install-digital-ocean/#central-install-digital-ocean


Para este tutorial vamos supor uma VPS configurada com UBUNTU 24.04 LTS na Hostinger (hostinger.com) e um dominio `envelhecer.online` com um subdominio `odk.envelhecer.online` que aponta para a VPS.

## Passo 0 - Configurações DNS do dominio e subdominio 

1. Configure "DNS / Nameservers"
a) Registros de DNS (na imagem abaixo substitua IPv4 e IPv6 pelos respectivos IPs da sua VM)

![Exemplo de configuração DNS](dns_1.png)
![Exemplo de configuração DNS](dns_2.png)
Isso vai linkar o seu dominio ao seu ODK Central inclusive habilitando o envio de email.

b) (Opcional) Child nameservers

![Exemplo de configuração DNS](dns_3.png)
Isso vai criar o seu subdominio e apontar para a sua VPS.


## Passo 1 - Configuração da VPS

> Use permissão de root.

1. Acesse a máquina via ssh ou outro cliente de acesso remoto;
2. suba o script `odk_install.sh`;
3. dê permissão de execução com o comando `chmod +x odk_install.sh`.
4. suba o script `odk_create_user.sh`;
5. dê permissão de execução com o comando `chmod +x odk_create_user.sh`.


## Passo 2 - Instalação
a) Execute o script com `sudo ./odk_install.sh` ou `sudo bash odk_install.sh` e siga as instruções. ([Detalhes](SCRIPT.md))

b) Acesse `/opt/central/` e execute `docker compose up --build -d`

c) (Opcional) Acompanhe os logs: `docker compose logs -f`

> **Dica:** O script aceita variáveis de ambiente para personalizar o comportamento (ex.: `NO_EDIT=1` para não abrir editor, `DISABLE_UFW=0` para manter o firewall). Veja a lista completa no [README.md](README.md#variáveis-de-ambiente-opcionais).


## Passo 3 - Criação do usuário Admin

> O script `odk_install.sh` já copia automaticamente o `odk_create_user.sh` para `/opt/central/`. Caso não tenha sido copiado, faça manualmente:
> `cp ~/odk/odk_create_user.sh /opt/central/`

a) Acesse o diretório: `cd /opt/central`

b) Execute o script com `sudo bash odk_create_user.sh` e siga as instruções.

c) Acesse o endereço criado para seu ODK Central (ex.: `odk.envelhecer.online`) e faça login com o usuário e senha criados.


Bom trabalho e boa jornada!!!

<hr> 

Configurações complementares no link: https://docs.getodk.org/central-install

