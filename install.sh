#!/bin/sh
# Automatic installer/uninstaller for Tailscale-ZLAN9809M Online Optimized
# Target: ZLAN9809M / OpenWrt / mipsel_24kc

RAW_BASE="https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main"

BINARY_URL="$RAW_BASE/tailscale.combined"
LOADER_URL="$RAW_BASE/tailscale-loader.sh"
INIT_URL="$RAW_BASE/tailscale-loader"
ENV_URL="$RAW_BASE/tailscale.env"
VERSION_URL="$RAW_BASE/version.txt"
LUCI_INSTALLER_URL="$RAW_BASE/install-luci.sh"

CONFIG_DIR="/etc/tailscale"
CONFIG_FILE="$CONFIG_DIR/tailscale.env"
STATE_FILE="$CONFIG_DIR/tailscaled.state"

LOADER_PATH="/usr/bin/tailscale-loader.sh"
INIT_PATH="/etc/init.d/tailscale-loader"

LUCI_CONTROLLER="/usr/lib/lua/luci/controller/tailscale_zlan.lua"
LUCI_VIEW_DIR="/usr/lib/lua/luci/view/tailscale_zlan"
LUCI_VIEW="$LUCI_VIEW_DIR/status.htm"

TMP_BINARY="/tmp/tailscale.combined"
TMP_ENV="/tmp/tailscale.env.repo"
TMP_TAILSCALE="/tmp/tailscale"
TMP_TAILSCALED="/tmp/tailscaled"
TMP_RUNTIME_DIR="/tmp/tailscale-runtime"
TMP_LOG="/tmp/tailscale-loader.log"

PIDFILE="/var/run/tailscale-loader.pid"
WATCHDOG_PIDFILE="/var/run/tailscale-loader-watchdog.pid"

TAILSCALE_BIN="/tmp/tailscale"
TAILSCALED_BIN="/tmp/tailscaled"

echo ""
echo "============================================================"
echo " Tailscale-ZLAN9809M Online Optimized Installer"
echo "============================================================"
echo ""

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: this installer must be run as root."
    exit 1
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "ERROR: wget was not found."
    exit 1
fi

stop_existing_service() {
    echo "Stopping previous Tailscale-ZLAN service if it exists..."

    if [ -x "$INIT_PATH" ]; then
        "$INIT_PATH" stop 2>/dev/null
    fi

    if [ -x "$TMP_TAILSCALE" ]; then
        "$TMP_TAILSCALE" --socket="$TMP_RUNTIME_DIR/tailscaled.sock" down 2>/dev/null
    fi

    killall tailscaled 2>/dev/null
    killall tailscale.combined 2>/dev/null
    killall tailscale-loader.sh 2>/dev/null
}

clean_luci_cache() {
    rm -f /tmp/luci-indexcache 2>/dev/null
    rm -rf /tmp/luci-modulecache 2>/dev/null

    if [ -x /etc/init.d/uhttpd ]; then
        /etc/init.d/uhttpd restart 2>/dev/null
    fi
}

uninstall_solution() {
    echo ""
    echo "============================================================"
    echo " Tailscale-ZLAN9809M Online Optimized Uninstaller"
    echo "============================================================"
    echo ""

    echo "This will remove the Tailscale-ZLAN9809M loader, service and LuCI menu."
    echo ""
    echo "Choose what to do with Tailscale configuration/state:"
    echo "  1) Keep /etc/tailscale files"
    echo "  2) Backup and remove /etc/tailscale files"
    echo "  3) Remove /etc/tailscale files without backup"
    echo "  4) Cancel uninstall"
    echo ""
    printf "Option [1]: "
    read REMOVE_CONFIG_OPTION
    REMOVE_CONFIG_OPTION="${REMOVE_CONFIG_OPTION:-1}"

    case "$REMOVE_CONFIG_OPTION" in
        1)
            REMOVE_CONFIG="keep"
            ;;
        2)
            REMOVE_CONFIG="backup_remove"
            ;;
        3)
            REMOVE_CONFIG="remove"
            ;;
        4)
            echo "Uninstall cancelled."
            return 1
            ;;
        *)
            echo "Invalid option."
            return 1
            ;;
    esac

    stop_existing_service

    if [ -x "$INIT_PATH" ]; then
        "$INIT_PATH" disable 2>/dev/null
    fi

    echo "Removing init service and loader script..."
    rm -f "$INIT_PATH"
    rm -f "$LOADER_PATH"

    echo "Removing temporary runtime files..."
    rm -f "$TMP_BINARY"
    rm -f "$TMP_TAILSCALE"
    rm -f "$TMP_TAILSCALED"
    rm -f "$PIDFILE"
    rm -f "$WATCHDOG_PIDFILE"
    rm -f "$TMP_LOG"
    rm -rf "$TMP_RUNTIME_DIR"

    echo "Removing LuCI menu files..."
    rm -f "$LUCI_CONTROLLER"
    rm -f "$LUCI_VIEW"
    rmdir "$LUCI_VIEW_DIR" 2>/dev/null

    echo "Cleaning LuCI cache..."
    clean_luci_cache

    case "$REMOVE_CONFIG" in
        keep)
            echo ""
            echo "Keeping Tailscale configuration/state:"
            [ -f "$CONFIG_FILE" ] && echo "  - $CONFIG_FILE"
            [ -f "$STATE_FILE" ] && echo "  - $STATE_FILE"
            ;;
        backup_remove)
            BACKUP_DIR="/etc/tailscale.removed.$(date +%Y%m%d%H%M%S)"
            echo ""
            echo "Backing up Tailscale configuration/state to:"
            echo "  $BACKUP_DIR"

            mkdir -p "$BACKUP_DIR"

            [ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "$BACKUP_DIR/tailscale.env"
            [ -f "$STATE_FILE" ] && cp "$STATE_FILE" "$BACKUP_DIR/tailscaled.state"

            echo "Removing /etc/tailscale..."
            rm -rf "$CONFIG_DIR"
            ;;
        remove)
            echo ""
            echo "Removing /etc/tailscale without backup..."
            rm -rf "$CONFIG_DIR"
            ;;
    esac

    sync

    echo ""
    echo "Uninstall finished."
    echo ""
    echo "Recommended final check:"
    echo "  ps | grep tailscale"
    echo "  ls -lh /etc/init.d/tailscale-loader /usr/bin/tailscale-loader.sh 2>/dev/null"
    echo ""

    return 0
}

install_luci_menu() {
    echo ""
    printf "Install LuCI web menu? [Y/n]: "
    read INSTALL_LUCI
    INSTALL_LUCI="${INSTALL_LUCI:-Y}"

    case "$INSTALL_LUCI" in
        y|Y|yes|YES)
            echo "Downloading LuCI menu installer..."

            wget --no-check-certificate -O /tmp/install-luci-tailscale.sh "$LUCI_INSTALLER_URL"
            if [ $? -ne 0 ]; then
                echo "WARNING: failed to download LuCI installer."
                echo "You can install it later using the install-luci.sh file from this repository."
                return 1
            fi

            sed -i 's/\r$//' /tmp/install-luci-tailscale.sh 2>/dev/null
            chmod +x /tmp/install-luci-tailscale.sh

            echo "Running LuCI menu installer..."
            sh /tmp/install-luci-tailscale.sh
            ;;
        *)
            echo "LuCI menu installation skipped."
            ;;
    esac
}

echo "Current disk usage:"
df -h
echo ""

if [ ! -e /dev/net/tun ]; then
    echo "WARNING: /dev/net/tun was not found."
    echo "Tailscale may not work unless kmod-tun is available."
    echo ""
fi

INSTALLATION_FOUND="0"
[ -f "$CONFIG_FILE" ] && INSTALLATION_FOUND="1"
[ -f "$STATE_FILE" ] && INSTALLATION_FOUND="1"
[ -f "$LOADER_PATH" ] && INSTALLATION_FOUND="1"
[ -f "$INIT_PATH" ] && INSTALLATION_FOUND="1"
[ -f "$LUCI_CONTROLLER" ] && INSTALLATION_FOUND="1"
[ -f "$LUCI_VIEW" ] && INSTALLATION_FOUND="1"

KEEP_EXISTING="0"

if [ "$INSTALLATION_FOUND" = "1" ]; then
    echo ""
    echo "Existing Tailscale-ZLAN installation/configuration was found:"
    [ -f "$CONFIG_FILE" ] && echo "  - $CONFIG_FILE"
    [ -f "$STATE_FILE" ] && echo "  - $STATE_FILE"
    [ -f "$LOADER_PATH" ] && echo "  - $LOADER_PATH"
    [ -f "$INIT_PATH" ] && echo "  - $INIT_PATH"
    [ -f "$LUCI_CONTROLLER" ] && echo "  - $LUCI_CONTROLLER"
    [ -f "$LUCI_VIEW" ] && echo "  - $LUCI_VIEW"
    echo ""
    echo "Choose what to do:"
    echo "  1) Keep existing Tailscale state/configuration and update files"
    echo "  2) Backup and reset Tailscale configuration/state, then install"
    echo "  3) Uninstall Tailscale-ZLAN from this router"
    echo "  4) Cancel"
    echo ""
    printf "Option [1]: "
    read EXISTING_OPTION
    EXISTING_OPTION="${EXISTING_OPTION:-1}"

    case "$EXISTING_OPTION" in
        1)
            echo "Keeping existing configuration/state."
            KEEP_EXISTING="1"
            ;;
        2)
            BACKUP_DIR="/etc/tailscale.backup.$(date +%Y%m%d%H%M%S)"
            echo "Creating backup at: $BACKUP_DIR"
            mkdir -p "$BACKUP_DIR"

            [ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "$BACKUP_DIR/tailscale.env"
            [ -f "$STATE_FILE" ] && cp "$STATE_FILE" "$BACKUP_DIR/tailscaled.state"

            echo "Removing previous configuration/state..."
            rm -f "$CONFIG_FILE"
            rm -f "$STATE_FILE"

            KEEP_EXISTING="0"
            ;;
        3)
            uninstall_solution
            exit $?
            ;;
        4)
            echo "Installation cancelled."
            exit 0
            ;;
        *)
            echo "Invalid option."
            exit 1
            ;;
    esac
fi

stop_existing_service

mkdir -p "$CONFIG_DIR"

echo ""
echo "Downloading repository files from:"
echo "$RAW_BASE"
echo ""

echo "Downloading tailscale.env template..."
wget --no-check-certificate -O "$TMP_ENV" "$ENV_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download tailscale.env"
    exit 1
fi

echo "Downloading version.txt..."
wget --no-check-certificate -O "$CONFIG_DIR/version.txt" "$VERSION_URL"
if [ $? -ne 0 ]; then
    echo "WARNING: failed to download version.txt, auto-update may not work"
fi

echo "Downloading tailscale-loader.sh..."
wget --no-check-certificate -O "$LOADER_PATH" "$LOADER_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download tailscale-loader.sh"
    exit 1
fi

echo "Downloading init service..."
wget --no-check-certificate -O "$INIT_PATH" "$INIT_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download tailscale-loader init service"
    exit 1
fi

echo "Downloading tailscale.combined to /tmp..."
wget --no-check-certificate -O "$TMP_BINARY" "$BINARY_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download tailscale.combined"
    exit 1
fi

# Fix Windows CRLF line endings if files were edited on Windows before upload.
sed -i 's/\r$//' "$TMP_ENV" 2>/dev/null
sed -i 's/\r$//' "$LOADER_PATH" 2>/dev/null
sed -i 's/\r$//' "$INIT_PATH" 2>/dev/null

chmod +x "$LOADER_PATH"
chmod +x "$INIT_PATH"
chmod +x "$TMP_BINARY"

# Create runtime symlinks immediately.
rm -f "$TAILSCALE_BIN" "$TAILSCALED_BIN"
ln -sf "$TMP_BINARY" "$TAILSCALE_BIN"
ln -sf "$TMP_BINARY" "$TAILSCALED_BIN"

if [ "$KEEP_EXISTING" = "0" ]; then
    echo ""
    echo "Default values are shown in brackets."
    echo ""

    printf "Tailscale hostname [zlan9809m-sr2]: "
    read TS_HOSTNAME
    TS_HOSTNAME="${TS_HOSTNAME:-zlan9809m-sr2}"

    while true; do
        printf "LAN subnet to advertise [192.168.9.0/24]: "
        read TS_ROUTES
        TS_ROUTES="${TS_ROUTES:-192.168.9.0/24}"

        case "$TS_ROUTES" in
            */*)
                break
                ;;
            *)
                echo "Invalid subnet: $TS_ROUTES"
                echo "Use CIDR format, for example: 192.168.9.0/24 or 10.10.1.0/24"
                ;;
        esac
    done

    echo ""
    echo "Optional: paste a Tailscale auth key for automatic login."
    echo "Leave empty to authenticate manually using the URL shown in logs."
    echo "WARNING: do not publish your auth key in GitHub or documentation."
    printf "Tailscale auth key []: "
    read TS_AUTHKEY

    cat > "$CONFIG_FILE" <<EOF
TS_BINARY_URL="$BINARY_URL"

# Device name shown in the Tailscale admin panel
TS_HOSTNAME="$TS_HOSTNAME"

# LAN subnet to advertise through Tailscale
# Change this according to your router LAN network
TS_ROUTES="$TS_ROUTES"

# Optional: Tailscale auth key for automatic login
# Never publish your auth key in a public repository
TS_AUTHKEY="$TS_AUTHKEY"

# Service paths
TS_STATE_DIR="/etc/tailscale"
TS_RUNTIME_DIR="/tmp/tailscale-runtime"
TS_BIN="/tmp/tailscale.combined"
TS_SOCKET="/tmp/tailscale-runtime/tailscaled.sock"
EOF

    sed -i 's/\r$//' "$CONFIG_FILE" 2>/dev/null
else
    echo ""
    echo "Keeping current configuration:"
    cat "$CONFIG_FILE" 2>/dev/null
fi

echo ""
echo "Enabling service on boot..."
"$INIT_PATH" enable

# Install LuCI before starting Tailscale.
# This avoids issues if Tailscale changes DNS/routes during first startup.
install_luci_menu

echo ""
printf "Start Tailscale service now? [Y/n]: "
read START_NOW
START_NOW="${START_NOW:-Y}"

case "$START_NOW" in
    y|Y|yes|YES)
        "$INIT_PATH" restart
        ;;
    *)
        echo "Service was enabled but not started."
        ;;
esac

sync

echo ""
echo "Installation finished."
echo ""
echo "Configuration file:"
echo "  $CONFIG_FILE"
echo ""
echo "Runtime binary:"
echo "  $TMP_BINARY"
echo ""
echo "Useful commands:"
echo "  logread -f | grep tailscale"
echo "  /tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock status"
echo "  /tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock ip"
echo "  /etc/init.d/tailscale-loader status"
echo "  /etc/init.d/tailscale-loader restart"
echo "  /etc/init.d/tailscale-loader stop"
echo ""
echo "If no auth key was provided, check the logs for the login URL:"
echo "  logread | grep -i https"
echo ""
echo "Do not forget to approve the advertised subnet route in the Tailscale admin panel."
echo ""

if [ -f "$CONFIG_FILE" ]; then
    echo "Current advertised route:"
    grep '^TS_ROUTES=' "$CONFIG_FILE" 2>/dev/null
fi

echo ""
printf "Reboot now? [y/N]: "
read REBOOT_NOW
REBOOT_NOW="${REBOOT_NOW:-N}"

case "$REBOOT_NOW" in
    y|Y|yes|YES)
        echo "Rebooting..."
        reboot
        ;;
    *)
        echo "Reboot skipped."
        ;;
esac

echo ""
