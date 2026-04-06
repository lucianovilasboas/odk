# Instalação do ODK Central

Tutorial de Instalação do ODK Central

Baseado em: 

- https://docs.getodk.org/central-install

- https://docs.getodk.org/central-install-digital-ocean/#central-install-digital-ocean


Para este tutorial vamos supor uma VPS configurada com UBUNTU 24.04 na Hostinger (hostinger.com) e um dominio `envelhecer.online` com um subdominio `odk.envelhecer.online` que aponta para a VPS.

## Passo 0
Configurações DNS do dominio e subdominio 
1. Configure “DNS / Nameservers”
a) Registros de DNS (na imagem abaixo substitua IPv4 e IPv6 pelos respectivos IPs da sua VM)

![Exemplo de configuração DNS](dns_1.png)
![Exemplo de configuração DNS](dns_2.png)

Isso vai linkar o seu dominio ao seu ODK Central inclusive habilitando o envio de email.

b) Child nameservers

![Exemplo de configuração DNS](dns_3.png)


Isso vai criar o seu subdominio e apontar para a sua VPS.


## Passo 1 
Configuração da VPS
use permissão de root 

1. acesse a maquina via ssh ou outro cliente de acesso remoto;
2. suba o script `install_odk.sh`;
3. dê permissão de execução  com o comando `chmod +x install_odk.sh`.
4. suba o script `create_useradmin_odk.sh`;
5. dê permissão de execução  com o comando `chmod +x create_useradmin_odk.sh`.


## Passo 2
Execute o script com `sudo ./install_odk.sh` ou `sudo sh install_odk.sh` e siga as intruções.

## Passo 3
Execute o script com `./create_useradmin_odk` ou `sudo sh create_useradmin_odk` e siga as intruções.


Acesse o endereço criado para seu ODK Central `odk.envelhecer.online`





Configurações complementares no link: https://docs.getodk.org/central-install

