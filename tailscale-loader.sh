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
LOGFILE="/tmp/tailscale-loader.log"
MAX_LOG_SIZE=51200  # 50KB

# Connection history (lightweight, max 10 entries)
HISTORY_FILE="$TS_STATE_DIR/connection_history.txt"
MAX_HISTORY=10

log() {
    logger -t tailscale-loader "$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [tailscale-loader] $*" >> "$LOGFILE"
    echo "[tailscale-loader] $*"
    
    # Trim log if it exceeds MAX_LOG_SIZE
    if [ -f "$LOGFILE" ]; then
        LOG_SIZE=$(wc -c < "$LOGFILE" 2>/dev/null)
        if [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ]; then
            # Keep only last 100 lines
            tail -n 100 "$LOGFILE" > "$LOGFILE.tmp" 2>/dev/null
            mv "$LOGFILE.tmp" "$LOGFILE" 2>/dev/null
        fi
    fi
}

add_history_entry() {
    local event="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$TS_STATE_DIR"
    
    # Add new entry at the beginning
    echo "$timestamp - $event" > "$HISTORY_FILE.tmp"
    
    # Append existing entries (up to MAX_HISTORY-1)
    if [ -f "$HISTORY_FILE" ]; then
        head -n $((MAX_HISTORY - 1)) "$HISTORY_FILE" >> "$HISTORY_FILE.tmp" 2>/dev/null
    fi
    
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE" 2>/dev/null
}

get_local_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE" 2>/dev/null
    else
        echo "0.0.0"
    fi
}

get_remote_version() {
    wget --no-check-certificate -qO- "$REMOTE_VERSION_URL" 2>/dev/null
}

wait_for_internet() {
    log "Waiting for internet connection..."

    TIMEOUT=300
    ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        # First check if gateway is reachable
        GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
        if [ -n "$GATEWAY" ]; then
            if ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
                log "Gateway $GATEWAY is reachable"
                
                # Then check internet connectivity
                if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
                    log "Internet connection established (1.1.1.1)"
                    return 0
                fi
                
                if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
                    log "Internet connection established (8.8.8.8)"
                    return 0
                fi
            fi
        fi
        
        ELAPSED=$((ELAPSED + 10))
        log "Waiting for internet... (${ELAPSED}s/${TIMEOUT}s)"
        sleep 10
    done
    
    log "ERROR: Timeout waiting for internet connection"
    return 1
}

download_binary() {
    if [ -z "$TS_BINARY_URL" ]; then
        log "Error: TS_BINARY_URL is not configured"
        return 1
    fi

    log "Downloading Tailscale binary..."

    # Download to temporary file first
    TMP_DOWNLOAD="$TS_BIN.tmp"
    rm -f "$TMP_DOWNLOAD"

    wget --no-check-certificate -O "$TMP_DOWNLOAD" "$TS_BINARY_URL"
    if [ $? -ne 0 ]; then
        log "Error downloading binary"
        rm -f "$TMP_DOWNLOAD"
        return 1
    fi

    chmod +x "$TMP_DOWNLOAD"

    # Validate downloaded binary before replacing
    "$TMP_DOWNLOAD" --help >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: downloaded binary did not run as tailscale"
        rm -f "$TMP_DOWNLOAD"
        return 1
    fi

    # Replace old binary
    mv -f "$TMP_DOWNLOAD" "$TS_BIN"
    rm -f "$TAILSCALE" "$TAILSCALED"

    ln -sf "$TS_BIN" "$TAILSCALE"
    ln -sf "$TS_BIN" "$TAILSCALED"

    # Verify symlinks work
    "$TAILSCALE" --help >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: binary did not run as tailscale via symlink"
        return 1
    fi

    "$TAILSCALED" --help >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: binary did not run as tailscaled via symlink"
        return 1
    fi

    log "Tailscale binary is ready in /tmp"
    return 0
}

enable_forwarding() {
    # Enable IP forwarding immediately
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Persist IP forwarding across reboots
    if [ -f /etc/sysctl.conf ]; then
        grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
            log "Persisted ip_forward in sysctl.conf"
        fi
    fi
    
    # Also try OpenWrt-specific method
    if [ -f /etc/config/network ]; then
        uci set network.lan.ipaddr=192.168.9.1 2>/dev/null
        uci commit network 2>/dev/null
    fi
    
    log "IP forwarding enabled"
}

start_tailscaled() {
    mkdir -p "$TS_STATE_DIR"
    mkdir -p "$TS_RUNTIME_DIR"

    # Check if tailscaled is already running
    EXISTING_PID=$(pidof tailscaled 2>/dev/null)
    if [ -n "$EXISTING_PID" ]; then
        log "tailscaled already running with PID $EXISTING_PID, checking socket..."
        
        # Check if socket exists and works
        if [ -S "$TS_SOCKET" ]; then
            if [ -x "$TAILSCALE" ]; then
                "$TAILSCALE" --socket="$TS_SOCKET" status >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    log "tailscaled is already healthy, reusing"
                    TS_PID="$EXISTING_PID"
                    return 0
                fi
            fi
        fi
        
        # If we get here, existing process is not healthy, kill it
        log "Killing unhealthy existing tailscaled process"
        killall tailscaled 2>/dev/null
        sleep 2
        killall -9 tailscaled 2>/dev/null
    fi

    rm -f "$TS_SOCKET"

    log "Starting tailscaled..."

    "$TAILSCALED" \
        --state="$TS_STATE_DIR/tailscaled.state" \
        --socket="$TS_SOCKET" \
        --port=41641  &

    TS_PID="$!"

    i=0
    while [ $i -lt 180 ]; do
        if [ -S "$TS_SOCKET" ]; then
            # Verify socket is actually working
            if [ -x "$TAILSCALE" ]; then
                "$TAILSCALE" --socket="$TS_SOCKET" status >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    log "tailscaled socket is healthy"
                    return 0
                fi
            fi
        fi
        sleep 1
        i=$((i + 1))
    done

    log "Error: tailscaled socket was not created or not functional"
    kill "$TS_PID" 2>/dev/null
    sleep 1
    kill -9 "$TS_PID" 2>/dev/null
    return 1
}

tailscale_up() {
    enable_forwarding

    CMD="$TAILSCALE --socket=$TS_SOCKET up --hostname=$TS_HOSTNAME --accept-dns=false --reset"

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
        add_history_entry "Connection failed (error $RET)"
    else
        log "tailscale up completed"
        add_history_entry "VPN connected successfully"
    fi

    return "$RET"
}

check_vpn_status() {
    if [ ! -x "$TAILSCALE" ] || [ ! -S "$TS_SOCKET" ]; then
        return 1
    fi
    
    "$TAILSCALE" --socket="$TS_SOCKET" status >/dev/null 2>&1
    return $?
}

monitor_vpn() {
    log "Starting VPN monitoring loop"
    
    CHECK_INTERVAL=30
    FAILURE_COUNT=0
    MAX_FAILURES=3
    
    while true; do
        sleep $CHECK_INTERVAL
        
        if ! check_vpn_status; then
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            log "VPN status check failed (attempt $FAILURE_COUNT/$MAX_FAILURES)"
            
            if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
                log "VPN failed $MAX_FAILURES consecutive checks, attempting reconnection"
                add_history_entry "VPN disconnected, attempting reconnection"
                FAILURE_COUNT=0
                
                # Try to bring down and up again
                "$TAILSCALE" --socket="$TS_SOCKET" down 2>/dev/null
                sleep 5
                
                if tailscale_up; then
                    log "VPN reconnection successful"
                    add_history_entry "VPN reconnected successfully"
                else
                    log "VPN reconnection failed, will retry on next cycle"
                    add_history_entry "VPN reconnection failed"
                fi
            fi
        else
            FAILURE_COUNT=0
        fi
    done
}

main() {
    wait_for_internet || {
        log "Failed to establish internet connection, exiting"
        exit 1
    }

    # Check for updates first
    if ! check_for_updates; then
        # Update available, perform it
        if perform_update; then
            # If update succeeds, this process will be replaced by exec
            log "Update triggered, process will be replaced"
            exit 0
        else
            log "Update failed, continuing with current version"
        fi
    fi

    while true; do
        download_binary && break
        log "Trying again in 120 seconds..."
        sleep 120
    done

    start_tailscaled || {
        log "Failed to start tailscaled, exiting"
        exit 1
    }

    # Initial connection attempt with retries
    UP_RETRY=0
    MAX_UP_RETRIES=3
    while [ $UP_RETRY -lt $MAX_UP_RETRIES ]; do
        if tailscale_up; then
            log "Initial VPN connection successful"
            break
        else
            UP_RETRY=$((UP_RETRY + 1))
            log "Initial VPN connection failed (attempt $UP_RETRY/$MAX_UP_RETRIES)"
            if [ $UP_RETRY -lt $MAX_UP_RETRIES ]; then
                sleep 10
            fi
        fi
    done

    if [ $UP_RETRY -ge $MAX_UP_RETRIES ]; then
        log "Failed to establish VPN connection after $MAX_UP_RETRIES attempts"
        log "Will continue with monitoring in case connection recovers"
    fi

    log "tailscaled running with PID $TS_PID"
    
    # Start VPN monitoring in background
    monitor_vpn &
    MONITOR_PID="$!"
    log "VPN monitoring started with PID $MONITOR_PID"
    
    # Wait for tailscaled process
    wait "$TS_PID"
    
    # If tailscaled exits, kill monitor and exit
    log "tailscaled exited, stopping monitor and exiting"
    kill "$MONITOR_PID" 2>/dev/null
}

main
