# Tailscale-ZLAN9809M Online Optimized

[Português](#português) | [English](#english)

---

# Português

## Tailscale para ZLAN9809M com carregamento otimizado em `/tmp`

Este repositório facilita o uso do **Tailscale** no roteador industrial **ZLAN9809M**, baseado em **OpenWrt 21.02 / ramips / mipsel_24kc**.

O objetivo é permitir que o ZLAN9809M funcione como um **Tailscale Subnet Router**, oferecendo acesso remoto aos dispositivos conectados à LAN do roteador, mesmo quando a conexão 4G está atrás de **CGNAT**.

Como o ZLAN9809M possui pouco espaço persistente disponível no overlay, esta solução não instala o binário completo do Tailscale permanentemente na flash. Em vez disso:

- o binário `tailscale.combined` é baixado automaticamente para `/tmp`;
- o binário é recriado a cada boot, sem ocupar espaço permanente;
- o estado/autenticação do Tailscale fica salvo em `/etc/tailscale`;
- o serviço inicia automaticamente com o OpenWrt;
- quando o roteador encontra internet, ele baixa o binário e inicia o Tailscale.

---

## Arquivos do repositório

| Arquivo | Função |
|---|---|
| `tailscale.combined` | Binário otimizado do Tailscale para OpenWrt `mipsel_24kc`. |
| `tailscale-loader.sh` | Script principal. Aguarda internet, baixa o binário para `/tmp`, cria os atalhos `tailscale` e `tailscaled`, inicia o daemon e executa `tailscale up`. |
| `tailscale-loader` | Serviço init.d/procd do OpenWrt para iniciar o loader automaticamente no boot. |
| `tailscale.env` | Arquivo de configuração persistente com URL do binário, hostname, rota anunciada e auth key opcional. |
| `install.sh` | Instalador automático recomendado. Baixa os arquivos do GitHub e pergunta apenas as configurações básicas. |

---

## Arquitetura da solução

```text
Internet / 4G / CGNAT
        │
        ▼
ZLAN9809M
OpenWrt + Tailscale carregado em /tmp
        │
        ▼
LAN local
192.168.9.0/24 ou 10.10.1.0/24
        │
        ▼
CLP / IHM / Gateway / sensores / dispositivos industriais
```

O ZLAN9809M anuncia a rede local para a sua tailnet usando:

```text
--advertise-routes
```

Depois que a rota é aprovada no painel do Tailscale, dispositivos autorizados na sua tailnet conseguem acessar os equipamentos conectados à LAN do roteador.

---

## Requisitos

Antes de instalar, confirme que o roteador possui:

- acesso SSH como `root`;
- internet funcionando;
- `/dev/net/tun` disponível;
- `wget` instalado;
- espaço livre em `/tmp`;
- uma conta Tailscale.

No ZLAN9809M:

```sh
ls -l /dev/net/tun
which wget
df -h
free -h
```

---

## Instalação rápida recomendada

Acesse o roteador via SSH:

```sh
ssh root@192.168.9.1
```

Baixe e execute o instalador:

```sh
wget --no-check-certificate -O /tmp/install-tailscale-zlan.sh \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/install.sh

chmod +x /tmp/install-tailscale-zlan.sh
sh /tmp/install-tailscale-zlan.sh
```

O instalador perguntará:

- hostname do dispositivo no Tailscale;
- rede LAN que será anunciada, por exemplo `192.168.9.0/24` ou `10.10.1.0/24`;
- auth key opcional do Tailscale;
- se o serviço deve ser iniciado imediatamente.

> **Importante:** se você não informar `TS_AUTHKEY`, será necessário autenticar manualmente usando a URL exibida nos logs.

---

## Instalação manual

Use esta opção se quiser instalar os arquivos manualmente ou entender cada etapa.

### 1. Criar diretório persistente

```sh
mkdir -p /etc/tailscale
```

### 2. Criar configuração persistente

```sh
vi /etc/tailscale/tailscale.env
```

Conteúdo recomendado:

```sh
TS_BINARY_URL="https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined"

# Nome do equipamento no painel do Tailscale
TS_HOSTNAME="zlan9809m-sr2"

# Rede LAN que será anunciada no Tailscale
# Altere conforme a rede usada no seu roteador
TS_ROUTES="192.168.9.0/24"

# Opcional: auth key do Tailscale para login automático
# Nunca publique sua auth key em repositórios públicos
TS_AUTHKEY=""

# Diretórios e arquivos usados pelo serviço
TS_STATE_DIR="/etc/tailscale"
TS_RUNTIME_DIR="/tmp/tailscale-runtime"
TS_BIN="/tmp/tailscale.combined"
TS_SOCKET="/tmp/tailscale-runtime/tailscaled.sock"
```

Se o seu roteador usar uma rede em faixa 10, por exemplo:

```sh
TS_ROUTES="10.10.1.0/24"
```

### 3. Instalar o loader

```sh
wget --no-check-certificate -O /usr/bin/tailscale-loader.sh \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale-loader.sh

chmod +x /usr/bin/tailscale-loader.sh
```

### 4. Instalar o serviço de boot

```sh
wget --no-check-certificate -O /etc/init.d/tailscale-loader \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale-loader

chmod +x /etc/init.d/tailscale-loader
/etc/init.d/tailscale-loader enable
```

### 5. Iniciar

```sh
/etc/init.d/tailscale-loader start
```

---

## Primeiro login no Tailscale

Se `TS_AUTHKEY` estiver vazio, o serviço deve gerar uma URL de autenticação nos logs.

Verifique com:

```sh
logread | grep -i "https"
```

Ou acompanhe em tempo real:

```sh
logread -f | grep tailscale
```

Abra a URL exibida, autentique na sua conta Tailscale e aprove o dispositivo.

---

## Aprovar a subnet route

Depois que o dispositivo aparecer online no painel do Tailscale, aprove a rota anunciada.

Exemplos:

```text
192.168.9.0/24
```

ou:

```text
10.10.1.0/24
```

Sem essa aprovação, o roteador pode aparecer online, mas a rede local atrás dele não ficará acessível.

---

## Comandos úteis

Ver logs:

```sh
logread -f | grep tailscale
```

Ver status:

```sh
/tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock status
```

Ver IP Tailscale:

```sh
/tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock ip
```

Ver processos:

```sh
ps | grep tailscale
```

Ver memória:

```sh
free -h
```

Ver espaço em disco:

```sh
df -h
```

Reiniciar o serviço:

```sh
/etc/init.d/tailscale-loader restart
```

Parar o serviço:

```sh
/etc/init.d/tailscale-loader stop
```

---

## Alterar a rede anunciada

Edite:

```sh
vi /etc/tailscale/tailscale.env
```

Altere:

```sh
TS_ROUTES="192.168.9.0/24"
```

Para, por exemplo:

```sh
TS_ROUTES="10.10.1.0/24"
```

Reinicie:

```sh
/etc/init.d/tailscale-loader restart
```

Depois aprove a nova rota no painel do Tailscale.

---

## Testar de outro dispositivo

De outro dispositivo conectado à mesma tailnet:

```sh
ping 192.168.9.1
```

ou:

```sh
ping 10.10.1.1
```

Também é possível acessar a interface web do roteador:

```text
http://192.168.9.1
```

ou:

```text
http://10.10.1.1
```

---

## Segurança

Este repositório é público. Portanto:

- nunca publique sua `TS_AUTHKEY`;
- nunca publique o arquivo `tailscaled.state`;
- nunca publique configurações reais de clientes;
- use um hostname diferente para cada roteador;
- use uma sub-rede diferente para cada instalação;
- aprove apenas as rotas necessárias no painel do Tailscale.

Arquivo sensível:

```text
/etc/tailscale/tailscaled.state
```

Esse arquivo identifica o dispositivo dentro da sua tailnet. Não compartilhe.

---

## Troubleshooting

### O serviço não inicia

```sh
logread | grep tailscale
/usr/bin/tailscale-loader.sh
```

### O binário não baixa

Teste internet:

```sh
ping -c 3 1.1.1.1
ping -c 3 8.8.8.8
```

Teste o download:

```sh
wget --no-check-certificate -O /tmp/tailscale.combined \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined
```

### O Tailscale sobe, mas a LAN não responde

Verifique o IP forwarding:

```sh
cat /proc/sys/net/ipv4/ip_forward
```

Deve retornar:

```text
1
```

Confirme se a rota foi aprovada no painel Tailscale e se `TS_ROUTES` está correto:

```sh
cat /etc/tailscale/tailscale.env
```

### Verificar interface e rotas

```sh
ip addr
ip route
```

---

## Como o binário foi gerado

Exemplo de build usado para gerar um binário otimizado para OpenWrt MIPS little-endian:

```sh
git clean -xfd
git checkout v1.60.1

GOOS=linux GOARCH=mipsle GOMIPS=softfloat \
go build -trimpath \
  -o tailscale.combined \
  -tags ts_include_cli \
  -ldflags="-s -w -buildid=" \
  ./cmd/tailscaled

upx --lzma --best tailscale.combined
du -h tailscale.combined
```

---

## Aviso

Este projeto é experimental e foi criado para ajudar usuários que precisam rodar Tailscale em roteadores industriais com poucos recursos.

Use por sua conta e risco. Teste bem antes de aplicar em produção.

---

# English

## Tailscale for ZLAN9809M with optimized `/tmp` runtime loading

This repository makes it easier to run **Tailscale** on the **ZLAN9809M** industrial router, based on **OpenWrt 21.02 / ramips / mipsel_24kc**.

The goal is to allow the ZLAN9809M to work as a **Tailscale Subnet Router**, providing remote access to devices connected to the router LAN, even when the 4G connection is behind **CGNAT**.

Because the ZLAN9809M has very limited persistent overlay storage, this solution does not permanently install the full Tailscale binary into flash. Instead:

- the `tailscale.combined` binary is automatically downloaded to `/tmp`;
- the binary is recreated at each boot without permanently consuming flash storage;
- Tailscale state/authentication is stored in `/etc/tailscale`;
- the service starts automatically with OpenWrt;
- once the router has internet access, it downloads the binary and starts Tailscale.

---

## Repository files

| File | Purpose |
|---|---|
| `tailscale.combined` | Optimized Tailscale binary for OpenWrt `mipsel_24kc`. |
| `tailscale-loader.sh` | Main loader script. Waits for internet, downloads the binary to `/tmp`, creates the `tailscale` and `tailscaled` symlinks, starts the daemon, and runs `tailscale up`. |
| `tailscale-loader` | OpenWrt init.d/procd service that starts the loader on boot. |
| `tailscale.env` | Persistent configuration file with binary URL, hostname, advertised route, and optional auth key. |
| `install.sh` | Recommended automatic installer. Downloads the repository files and asks only for the basic configuration. |

---

## Solution architecture

```text
Internet / 4G / CGNAT
        │
        ▼
ZLAN9809M
OpenWrt + Tailscale loaded in /tmp
        │
        ▼
Local LAN
192.168.9.0/24 or 10.10.1.0/24
        │
        ▼
PLC / HMI / Gateway / sensors / industrial devices
```

The ZLAN9809M advertises the local network to your tailnet using:

```text
--advertise-routes
```

After the route is approved in the Tailscale admin panel, authorized devices in your tailnet can access the devices connected to the router LAN.

---

## Requirements

Before installing, make sure the router has:

- SSH access as `root`;
- working internet access;
- `/dev/net/tun` available;
- `wget` installed;
- free space in `/tmp`;
- a Tailscale account.

On the ZLAN9809M:

```sh
ls -l /dev/net/tun
which wget
df -h
free -h
```

---

## Recommended quick installation

Access the router through SSH:

```sh
ssh root@192.168.9.1
```

Download and run the installer:

```sh
wget --no-check-certificate -O /tmp/install-tailscale-zlan.sh \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/install.sh

chmod +x /tmp/install-tailscale-zlan.sh
sh /tmp/install-tailscale-zlan.sh
```

The installer will ask for:

- Tailscale device hostname;
- LAN subnet to advertise, for example `192.168.9.0/24` or `10.10.1.0/24`;
- optional Tailscale auth key;
- whether the service should be started immediately.

> **Important:** if you do not provide `TS_AUTHKEY`, you must authenticate manually using the URL shown in the logs.

---

## Manual installation

Use this option if you want to install the files manually or understand each step.

### 1. Create the persistent directory

```sh
mkdir -p /etc/tailscale
```

### 2. Create the persistent configuration

```sh
vi /etc/tailscale/tailscale.env
```

Recommended content:

```sh
TS_BINARY_URL="https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined"

# Device name shown in the Tailscale admin panel
TS_HOSTNAME="zlan9809m-sr2"

# LAN subnet to advertise through Tailscale
# Change this according to your router LAN network
TS_ROUTES="192.168.9.0/24"

# Optional: Tailscale auth key for automatic login
# Never publish your auth key in a public repository
TS_AUTHKEY=""

# Service paths
TS_STATE_DIR="/etc/tailscale"
TS_RUNTIME_DIR="/tmp/tailscale-runtime"
TS_BIN="/tmp/tailscale.combined"
TS_SOCKET="/tmp/tailscale-runtime/tailscaled.sock"
```

For a 10.x subnet, for example:

```sh
TS_ROUTES="10.10.1.0/24"
```

### 3. Install the loader

```sh
wget --no-check-certificate -O /usr/bin/tailscale-loader.sh \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale-loader.sh

chmod +x /usr/bin/tailscale-loader.sh
```

### 4. Install the boot service

```sh
wget --no-check-certificate -O /etc/init.d/tailscale-loader \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale-loader

chmod +x /etc/init.d/tailscale-loader
/etc/init.d/tailscale-loader enable
```

### 5. Start

```sh
/etc/init.d/tailscale-loader start
```

---

## First Tailscale login

If `TS_AUTHKEY` is empty, the service should generate an authentication URL in the logs.

Check with:

```sh
logread | grep -i "https"
```

Or watch in real time:

```sh
logread -f | grep tailscale
```

Open the displayed URL, authenticate with your Tailscale account, and approve the device.

---

## Approve the subnet route

After the device appears online in the Tailscale admin panel, approve the advertised route.

Examples:

```text
192.168.9.0/24
```

or:

```text
10.10.1.0/24
```

Without this approval, the router may appear online, but the LAN behind it will not be reachable.

---

## Useful commands

View logs:

```sh
logread -f | grep tailscale
```

View status:

```sh
/tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock status
```

View Tailscale IP:

```sh
/tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock ip
```

View processes:

```sh
ps | grep tailscale
```

View memory:

```sh
free -h
```

View disk usage:

```sh
df -h
```

Restart the service:

```sh
/etc/init.d/tailscale-loader restart
```

Stop the service:

```sh
/etc/init.d/tailscale-loader stop
```

---

## Change the advertised network

Edit:

```sh
vi /etc/tailscale/tailscale.env
```

Change:

```sh
TS_ROUTES="192.168.9.0/24"
```

To, for example:

```sh
TS_ROUTES="10.10.1.0/24"
```

Restart:

```sh
/etc/init.d/tailscale-loader restart
```

Then approve the new route in the Tailscale admin panel.

---

## Test from another device

From another device connected to the same tailnet:

```sh
ping 192.168.9.1
```

or:

```sh
ping 10.10.1.1
```

You can also access the router web interface:

```text
http://192.168.9.1
```

or:

```text
http://10.10.1.1
```

---

## Security

This repository is public. Therefore:

- never publish your `TS_AUTHKEY`;
- never publish the `tailscaled.state` file;
- never publish real customer configuration;
- use a different hostname for each router;
- use a different subnet for each installation;
- approve only the required routes in the Tailscale admin panel.

Sensitive file:

```text
/etc/tailscale/tailscaled.state
```

This file identifies the device inside your tailnet. Do not share it.

---

## Troubleshooting

### Service does not start

```sh
logread | grep tailscale
/usr/bin/tailscale-loader.sh
```

### Binary does not download

Test internet:

```sh
ping -c 3 1.1.1.1
ping -c 3 8.8.8.8
```

Test the download:

```sh
wget --no-check-certificate -O /tmp/tailscale.combined \
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined
```

### Tailscale starts, but LAN access does not work

Check IP forwarding:

```sh
cat /proc/sys/net/ipv4/ip_forward
```

It should return:

```text
1
```

Make sure the route was approved in the Tailscale admin panel and `TS_ROUTES` is correct:

```sh
cat /etc/tailscale/tailscale.env
```

### Check interface and routes

```sh
ip addr
ip route
```

---

## How the binary was built

Example build used to generate an optimized binary for OpenWrt MIPS little-endian:

```sh
git clean -xfd
git checkout v1.60.1

GOOS=linux GOARCH=mipsle GOMIPS=softfloat \
go build -trimpath \
  -o tailscale.combined \
  -tags ts_include_cli \
  -ldflags="-s -w -buildid=" \
  ./cmd/tailscaled

upx --lzma --best tailscale.combined
du -h tailscale.combined
```

---

## Disclaimer

This project is experimental and was created to help users who need to run Tailscale on resource-constrained industrial routers.

Use it at your own risk. Test carefully before using it in production.
