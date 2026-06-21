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