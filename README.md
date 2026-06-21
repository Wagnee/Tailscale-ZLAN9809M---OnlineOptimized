# Tailscale-ZLAN9809M Online Optimized

[Português](#português) | [English](#english)

---

# Português

## Tailscale para ZLAN9809M com carregamento otimizado em `/tmp`

Este repositório contém uma versão otimizada do **Tailscale** preparada para uso no roteador industrial **ZLAN9809M**, baseado em **OpenWrt 21.02 / ramips / mipsel_24kc**.

O objetivo é permitir que o ZLAN9809M funcione como um **Tailscale Subnet Router**, permitindo acesso remoto aos dispositivos conectados à LAN do roteador, mesmo em redes 4G/CGNAT.

Como o ZLAN9809M possui pouco espaço persistente disponível no overlay, este projeto utiliza uma abordagem otimizada:

* O binário `tailscale.combined` é baixado automaticamente para `/tmp`;
* O binário não ocupa espaço permanente na flash;
* O estado/autenticação do Tailscale fica salvo em `/etc/tailscale`;
* O serviço inicia automaticamente no boot;
* Quando houver internet, o roteador baixa o binário e inicia o Tailscale.

---

## Por que este projeto existe?

Em muitos projetos industriais, gateways 4G como o **ZLAN9809M** são usados para conectar CLPs, sensores, IHMs, medidores e outros equipamentos remotos.

O problema é que, em redes 4G, normalmente existe **CGNAT**, o que impede acesso remoto direto por redirecionamento de portas.

O Tailscale resolve muito bem esse problema, mas o ZLAN9809M possui recursos limitados, especialmente em armazenamento persistente.

Exemplo real do equipamento testado:

```text
OpenWrt: 21.02.0
Arquitetura: mipsel_24kc
RAM total: ~120 MB
Overlay livre: ~5.5 MB
/tmp livre: ~60 MB
```

Por isso, este projeto usa `/tmp` para armazenar o binário em tempo de execução e mantém apenas as configurações persistentes na flash.

---

## Arquitetura da solução

```text
Internet / 4G / CGNAT
        │
        ▼
ZLAN9809M
OpenWrt + Tailscale em /tmp
        │
        ▼
LAN local
192.168.9.0/24 ou 10.10.1.0/24
        │
        ▼
CLP / IHM / Gateway / Dispositivos industriais
```

O ZLAN9809M anuncia a rede local para a sua tailnet usando:

```text
--advertise-routes
```

Assim, qualquer dispositivo autorizado na sua conta Tailscale pode acessar os equipamentos conectados à LAN do roteador.

---

## Requisitos

Antes de iniciar, confirme que o roteador possui:

* Acesso SSH como `root`;
* Internet funcionando;
* `/dev/net/tun` disponível;
* `wget` instalado;
* Espaço suficiente em `/tmp`;
* Uma conta Tailscale.

No ZLAN9809M, você pode verificar com:

```sh
ls -l /dev/net/tun
which wget
df -h
free -h
```

---

## Binário usado

O binário otimizado está neste repositório:

```text
tailscale.combined
```

URL direta usada pelo roteador:

```text
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined
```

Este arquivo foi pensado para ser baixado para `/tmp` durante a inicialização do dispositivo.

---

## Instalação

Acesse o roteador via SSH:

```sh
ssh root@192.168.9.1
```

Substitua o IP conforme a configuração atual do seu ZLAN9809M.

---

## 1. Criar arquivo persistente de configuração

Crie o diretório persistente:

```sh
mkdir -p /etc/tailscale
```

Crie o arquivo de configuração:

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

Se o seu roteador usar outra rede, altere `TS_ROUTES`.

Exemplo para rede em faixa 10:

```sh
TS_ROUTES="10.10.1.0/24"
```

---

## 2. Criar script de download e inicialização

Crie o script:

```sh
vi /usr/bin/tailscale-loader.sh
```

Cole o conteúdo abaixo:

```sh
#!/bin/sh

CONFIG="/etc/tailscale/tailscale.env"

[ -f "$CONFIG" ] && . "$CONFIG"

TS_BINARY_URL="${TS_BINARY_URL:-}"
TS_HOSTNAME="${TS_HOSTNAME:-zlan9809m}"
TS_ROUTES="${TS_ROUTES:-}"
TS_AUTHKEY="${TS_AUTHKEY:-}"

TS_STATE_DIR="${TS_STATE_DIR:-/etc/tailscale}"
TS_RUNTIME_DIR="${TS_RUNTIME_DIR:-/tmp/tailscale-runtime}"
TS_BIN="${TS_BIN:-/tmp/tailscale.combined}"
TS_SOCKET="${TS_SOCKET:-/tmp/tailscale-runtime/tailscaled.sock}"

TAILSCALE="/tmp/tailscale"
TAILSCALED="/tmp/tailscaled"

log() {
    logger -t tailscale-loader "$*"
    echo "[tailscale-loader] $*"
}

wait_for_internet() {
    log "Waiting for internet connection..."

    while true; do
        ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && return 0
        ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 && return 0
        sleep 10
    done
}

download_binary() {
    if [ -z "$TS_BINARY_URL" ]; then
        log "Error: TS_BINARY_URL is not configured"
        return 1
    fi

    log "Downloading Tailscale binary..."

    rm -f "$TS_BIN" "$TAILSCALE" "$TAILSCALED"

    wget --no-check-certificate -O "$TS_BIN" "$TS_BINARY_URL"
    if [ $? -ne 0 ]; then
        log "Error downloading binary"
        return 1
    fi

    chmod +x "$TS_BIN"

    ln -sf "$TS_BIN" "$TAILSCALE"
    ln -sf "$TS_BIN" "$TAILSCALED"

    "$TAILSCALE" --help >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: binary did not run as tailscale"
        return 1
    fi

    "$TAILSCALED" --help >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: binary did not run as tailscaled"
        return 1
    fi

    log "Tailscale binary is ready in /tmp"
    return 0
}

enable_forwarding() {
    echo 1 > /proc/sys/net/ipv4/ip_forward
}

start_tailscaled() {
    mkdir -p "$TS_STATE_DIR"
    mkdir -p "$TS_RUNTIME_DIR"

    rm -f "$TS_SOCKET"

    log "Starting tailscaled..."

    "$TAILSCALED" \
        --state="$TS_STATE_DIR/tailscaled.state" \
        --socket="$TS_SOCKET" &

    TS_PID="$!"

    i=0
    while [ $i -lt 30 ]; do
        [ -S "$TS_SOCKET" ] && return 0
        sleep 1
        i=$((i + 1))
    done

    log "Error: tailscaled socket was not created"
    kill "$TS_PID" 2>/dev/null
    return 1
}

tailscale_up() {
    enable_forwarding

    CMD="$TAILSCALE --socket=$TS_SOCKET up --hostname=$TS_HOSTNAME"

    if [ -n "$TS_ROUTES" ]; then
        CMD="$CMD --advertise-routes=$TS_ROUTES"
    fi

    if [ -n "$TS_AUTHKEY" ]; then
        CMD="$CMD --auth-key=$TS_AUTHKEY"
    fi

    log "Running tailscale up..."

    $CMD
    RET="$?"

    if [ "$RET" -ne 0 ]; then
        log "tailscale up returned error: $RET"
    else
        log "tailscale up completed"
    fi

    return "$RET"
}

main() {
    wait_for_internet

    while true; do
        download_binary && break
        log "Trying again in 30 seconds..."
        sleep 30
    done

    start_tailscaled || exit 1

    tailscale_up

    log "tailscaled running with PID $TS_PID"
    wait "$TS_PID"
}

main
```

Dê permissão de execução:

```sh
chmod +x /usr/bin/tailscale-loader.sh
```

---

## 3. Criar serviço para iniciar no boot

Crie o serviço:

```sh
vi /etc/init.d/tailscale-loader
```

Cole o conteúdo abaixo:

```sh
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/tailscale-loader.sh
    procd_set_param respawn 30 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    /tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock down 2>/dev/null
    killall tailscaled 2>/dev/null
    killall tailscale.combined 2>/dev/null
}
```

Dê permissão:

```sh
chmod +x /etc/init.d/tailscale-loader
```

Habilite no boot:

```sh
/etc/init.d/tailscale-loader enable
```

Inicie o serviço:

```sh
/etc/init.d/tailscale-loader start
```

---

## 4. Verificar funcionamento

Ver logs em tempo real:

```sh
logread -f | grep tailscale
```

Ver status do Tailscale:

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

Ver uso de memória:

```sh
free -h
```

Ver espaço em disco:

```sh
df -h
```

---

## 5. Primeiro login no Tailscale

Se `TS_AUTHKEY=""`, o serviço deve gerar uma URL de autenticação nos logs.

Você pode procurar a URL com:

```sh
logread | grep -i "https"
```

Também é possível rodar manualmente:

```sh
/tmp/tailscale \
  --socket=/tmp/tailscale-runtime/tailscaled.sock \
  up \
  --hostname=zlan9809m-sr2 \
  --advertise-routes=192.168.9.0/24
```

Abra a URL exibida, autentique na sua conta Tailscale e aprove o dispositivo.

---

## 6. Aprovar a subnet route

Após autenticar o dispositivo, acesse o painel administrativo do Tailscale e aprove a rota anunciada.

Exemplo:

```text
192.168.9.0/24
```

ou, se você configurou o roteador para faixa 10:

```text
10.10.1.0/24
```

Sem aprovar a rota, o roteador aparecerá online, mas a rede local atrás dele não ficará acessível.

---

## 7. Alterar a rede anunciada

Para mudar a rede anunciada, edite:

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

Reinicie o serviço:

```sh
/etc/init.d/tailscale-loader restart
```

Depois aprove a nova rota no painel do Tailscale.

---

## 8. Testar de outro dispositivo

De outro dispositivo conectado à mesma tailnet, teste:

```sh
ping 192.168.9.1
```

ou:

```sh
ping 10.10.1.1
```

Também tente acessar a interface web do roteador:

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

* Nunca publique sua `TS_AUTHKEY`;
* Nunca publique o arquivo `tailscaled.state`;
* Nunca publique arquivos reais de configuração do seu cliente;
* Use nomes de host diferentes para cada roteador;
* Use uma subnet diferente para cada instalação;
* Aprove apenas as rotas necessárias no painel Tailscale.

O arquivo sensível é:

```text
/etc/tailscale/tailscaled.state
```

Ele identifica o dispositivo dentro da sua tailnet. Não compartilhe esse arquivo.

---

## Troubleshooting

### O serviço não inicia

Verifique logs:

```sh
logread | grep tailscale
```

Teste o script manualmente:

```sh
/usr/bin/tailscale-loader.sh
```

---

### O binário não baixa

Teste internet:

```sh
ping -c 3 1.1.1.1
ping -c 3 8.8.8.8
```

Teste o download:

```sh
wget --no-check-certificate -O /tmp/tailscale.combined https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined
```

---

### O Tailscale sobe, mas não acesso a LAN

Confirme o IP forward:

```sh
cat /proc/sys/net/ipv4/ip_forward
```

Deve retornar:

```text
1
```

Confirme se a rota foi aprovada no painel Tailscale.

Confirme se `TS_ROUTES` está correto:

```sh
cat /etc/tailscale/tailscale.env
```

---

### Verificar interface Tailscale

```sh
ip addr
ip route
```

---

### Reiniciar serviço

```sh
/etc/init.d/tailscale-loader restart
```

---

## Como este binário foi gerado

O binário usado neste projeto foi otimizado para dispositivos OpenWrt com arquitetura MIPS little-endian.

Exemplo de build:

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

Este projeto é experimental e foi criado para ajudar usuários que precisam rodar Tailscale em roteadores industriais com recursos limitados.

Use por sua conta e risco. Teste bem antes de aplicar em produção.

---

# English

## Tailscale for ZLAN9809M with optimized `/tmp` runtime loading

This repository provides an optimized **Tailscale** binary and startup method for the **ZLAN9809M** industrial router, based on **OpenWrt 21.02 / ramips / mipsel_24kc**.

The goal is to allow the ZLAN9809M to work as a **Tailscale Subnet Router**, providing remote access to devices connected to the router LAN, even behind 4G/CGNAT networks.

Because the ZLAN9809M has very limited persistent overlay storage, this project uses an optimized approach:

* The `tailscale.combined` binary is automatically downloaded to `/tmp`;
* The binary does not permanently consume flash storage;
* Tailscale state/authentication is stored persistently in `/etc/tailscale`;
* The service starts automatically on boot;
* Once internet is available, the router downloads the binary and starts Tailscale.

---

## Why this project exists

In many industrial projects, 4G gateways such as the **ZLAN9809M** are used to connect PLCs, sensors, HMIs, meters, and other remote devices.

The problem is that 4G networks often use **CGNAT**, which prevents direct inbound access using port forwarding.

Tailscale solves this very well, but the ZLAN9809M has limited resources, especially persistent flash storage.

Example from a tested device:

```text
OpenWrt: 21.02.0
Architecture: mipsel_24kc
Total RAM: ~120 MB
Free overlay: ~5.5 MB
Free /tmp: ~60 MB
```

For this reason, this project stores the binary in `/tmp` at runtime and keeps only the persistent configuration and state in flash.

---

## Solution architecture

```text
Internet / 4G / CGNAT
        │
        ▼
ZLAN9809M
OpenWrt + Tailscale in /tmp
        │
        ▼
Local LAN
192.168.9.0/24 or 10.10.1.0/24
        │
        ▼
PLC / HMI / Gateway / Industrial devices
```

The ZLAN9809M advertises the local network to your tailnet using:

```text
--advertise-routes
```

This allows any authorized device in your Tailscale account to access devices connected to the router LAN.

---

## Requirements

Before starting, make sure the router has:

* SSH access as `root`;
* Working internet access;
* `/dev/net/tun` available;
* `wget` installed;
* Enough free space in `/tmp`;
* A Tailscale account.

On the ZLAN9809M, you can check with:

```sh
ls -l /dev/net/tun
which wget
df -h
free -h
```

---

## Binary used

The optimized binary is available in this repository:

```text
tailscale.combined
```

Direct download URL used by the router:

```text
https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined
```

This file is intended to be downloaded to `/tmp` during device startup.

---

## Installation

Access the router via SSH:

```sh
ssh root@192.168.9.1
```

Replace the IP address according to your current ZLAN9809M configuration.

---

## 1. Create the persistent configuration file

Create the persistent directory:

```sh
mkdir -p /etc/tailscale
```

Create the configuration file:

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

If your router uses a different LAN subnet, change `TS_ROUTES`.

Example for a 10.x subnet:

```sh
TS_ROUTES="10.10.1.0/24"
```

---

## 2. Create the download and startup script

Create the script:

```sh
vi /usr/bin/tailscale-loader.sh
```

Paste the content below:

```sh
#!/bin/sh

CONFIG="/etc/tailscale/tailscale.env"

[ -f "$CONFIG" ] && . "$CONFIG"

TS_BINARY_URL="${TS_BINARY_URL:-}"
TS_HOSTNAME="${TS_HOSTNAME:-zlan9809m}"
TS_ROUTES="${TS_ROUTES:-}"
TS_AUTHKEY="${TS_AUTHKEY:-}"

TS_STATE_DIR="${TS_STATE_DIR:-/etc/tailscale}"
TS_RUNTIME_DIR="${TS_RUNTIME_DIR:-/tmp/tailscale-runtime}"
TS_BIN="${TS_BIN:-/tmp/tailscale.combined}"
TS_SOCKET="${TS_SOCKET:-/tmp/tailscale-runtime/tailscaled.sock}"

TAILSCALE="/tmp/tailscale"
TAILSCALED="/tmp/tailscaled"

log() {
    logger -t tailscale-loader "$*"
    echo "[tailscale-loader] $*"
}

wait_for_internet() {
    log "Waiting for internet connection..."

    while true; do
        ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && return 0
        ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 && return 0
        sleep 10
    done
}

download_binary() {
    if [ -z "$TS_BINARY_URL" ]; then
        log "Error: TS_BINARY_URL is not configured"
        return 1
    fi

    log "Downloading Tailscale binary..."

    rm -f "$TS_BIN" "$TAILSCALE" "$TAILSCALED"

    wget --no-check-certificate -O "$TS_BIN" "$TS_BINARY_URL"
    if [ $? -ne 0 ]; then
        log "Error downloading binary"
        return 1
    fi

    chmod +x "$TS_BIN"

    ln -sf "$TS_BIN" "$TAILSCALE"
    ln -sf "$TS_BIN" "$TAILSCALED"

    "$TAILSCALE" --help >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: binary did not run as tailscale"
        return 1
    fi

    "$TAILSCALED" --help >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: binary did not run as tailscaled"
        return 1
    fi

    log "Tailscale binary is ready in /tmp"
    return 0
}

enable_forwarding() {
    echo 1 > /proc/sys/net/ipv4/ip_forward
}

start_tailscaled() {
    mkdir -p "$TS_STATE_DIR"
    mkdir -p "$TS_RUNTIME_DIR"

    rm -f "$TS_SOCKET"

    log "Starting tailscaled..."

    "$TAILSCALED" \
        --state="$TS_STATE_DIR/tailscaled.state" \
        --socket="$TS_SOCKET" &

    TS_PID="$!"

    i=0
    while [ $i -lt 30 ]; do
        [ -S "$TS_SOCKET" ] && return 0
        sleep 1
        i=$((i + 1))
    done

    log "Error: tailscaled socket was not created"
    kill "$TS_PID" 2>/dev/null
    return 1
}

tailscale_up() {
    enable_forwarding

    CMD="$TAILSCALE --socket=$TS_SOCKET up --hostname=$TS_HOSTNAME"

    if [ -n "$TS_ROUTES" ]; then
        CMD="$CMD --advertise-routes=$TS_ROUTES"
    fi

    if [ -n "$TS_AUTHKEY" ]; then
        CMD="$CMD --auth-key=$TS_AUTHKEY"
    fi

    log "Running tailscale up..."

    $CMD
    RET="$?"

    if [ "$RET" -ne 0 ]; then
        log "tailscale up returned error: $RET"
    else
        log "tailscale up completed"
    fi

    return "$RET"
}

main() {
    wait_for_internet

    while true; do
        download_binary && break
        log "Trying again in 30 seconds..."
        sleep 30
    done

    start_tailscaled || exit 1

    tailscale_up

    log "tailscaled running with PID $TS_PID"
    wait "$TS_PID"
}

main
```

Make it executable:

```sh
chmod +x /usr/bin/tailscale-loader.sh
```

---

## 3. Create the boot service

Create the service:

```sh
vi /etc/init.d/tailscale-loader
```

Paste the content below:

```sh
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/tailscale-loader.sh
    procd_set_param respawn 30 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    /tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock down 2>/dev/null
    killall tailscaled 2>/dev/null
    killall tailscale.combined 2>/dev/null
}
```

Make it executable:

```sh
chmod +x /etc/init.d/tailscale-loader
```

Enable it on boot:

```sh
/etc/init.d/tailscale-loader enable
```

Start the service:

```sh
/etc/init.d/tailscale-loader start
```

---

## 4. Verify that it is working

Watch logs in real time:

```sh
logread -f | grep tailscale
```

Check Tailscale status:

```sh
/tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock status
```

Check Tailscale IP:

```sh
/tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock ip
```

Check processes:

```sh
ps | grep tailscale
```

Check memory usage:

```sh
free -h
```

Check disk usage:

```sh
df -h
```

---

## 5. First Tailscale login

If `TS_AUTHKEY=""`, the service should generate an authentication URL in the logs.

You can find it with:

```sh
logread | grep -i "https"
```

You can also run it manually:

```sh
/tmp/tailscale \
  --socket=/tmp/tailscale-runtime/tailscaled.sock \
  up \
  --hostname=zlan9809m-sr2 \
  --advertise-routes=192.168.9.0/24
```

Open the displayed URL, authenticate with your Tailscale account, and approve the device.

---

## 6. Approve the subnet route

After authenticating the device, open the Tailscale admin panel and approve the advertised route.

Example:

```text
192.168.9.0/24
```

or, if you configured the router to use a 10.x subnet:

```text
10.10.1.0/24
```

Without approving the route, the router will appear online, but the LAN behind it will not be reachable.

---

## 7. Change the advertised network

To change the advertised subnet, edit:

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

Restart the service:

```sh
/etc/init.d/tailscale-loader restart
```

Then approve the new route in the Tailscale admin panel.

---

## 8. Test from another device

From another device connected to the same tailnet, test:

```sh
ping 192.168.9.1
```

or:

```sh
ping 10.10.1.1
```

You can also try accessing the router web interface:

```text
http://192.168.9.1
```

or:

```text
http://10.10.1.1
```

---

## Security notes

This repository is public. Therefore:

* Never publish your `TS_AUTHKEY`;
* Never publish your `tailscaled.state` file;
* Never publish real customer configuration files;
* Use a unique hostname for each router;
* Use a different subnet for each installation;
* Approve only the required routes in the Tailscale admin panel.

The sensitive file is:

```text
/etc/tailscale/tailscaled.state
```

It identifies the device in your tailnet. Do not share it.

---

## Troubleshooting

### Service does not start

Check logs:

```sh
logread | grep tailscale
```

Run the script manually:

```sh
/usr/bin/tailscale-loader.sh
```

---

### Binary does not download

Test internet access:

```sh
ping -c 3 1.1.1.1
ping -c 3 8.8.8.8
```

Test the download:

```sh
wget --no-check-certificate -O /tmp/tailscale.combined https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined
```

---

### Tailscale starts, but LAN access does not work

Check IP forwarding:

```sh
cat /proc/sys/net/ipv4/ip_forward
```

It should return:

```text
1
```

Make sure the subnet route was approved in the Tailscale admin panel.

Check if `TS_ROUTES` is correct:

```sh
cat /etc/tailscale/tailscale.env
```

---

### Check Tailscale interface

```sh
ip addr
ip route
```

---

### Restart the service

```sh
/etc/init.d/tailscale-loader restart
```

---

## How this binary was built

The binary used in this project was optimized for OpenWrt devices using MIPS little-endian architecture.

Example build:

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
