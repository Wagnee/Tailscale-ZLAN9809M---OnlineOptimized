#!/bin/sh
# Uninstaller for Tailscale-ZLAN9809M Online Optimized
# Target: ZLAN9809M / OpenWrt / mipsel_24kc

CONFIG_DIR="/etc/tailscale"
CONFIG_FILE="$CONFIG_DIR/tailscale.env"
STATE_FILE="$CONFIG_DIR/tailscaled.state"

LOADER_PATH="/usr/bin/tailscale-loader.sh"
INIT_PATH="/etc/init.d/tailscale-loader"

LUCI_CONTROLLER="/usr/lib/lua/luci/controller/tailscale_zlan.lua"
LUCI_VIEW_DIR="/usr/lib/lua/luci/view/tailscale_zlan"
LUCI_VIEW="$LUCI_VIEW_DIR/status.htm"

TMP_BINARY="/tmp/tailscale.combined"
TMP_TAILSCALE="/tmp/tailscale"
TMP_TAILSCALED="/tmp/tailscaled"
TMP_RUNTIME_DIR="/tmp/tailscale-runtime"
TMP_LOG="/tmp/tailscale-loader.log"

PIDFILE="/var/run/tailscale-loader.pid"
WATCHDOG_PIDFILE="/var/run/tailscale-loader-watchdog.pid"

echo ""
echo "============================================================"
echo " Tailscale-ZLAN9809M Online Optimized Uninstaller"
echo "============================================================"
echo ""

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: this uninstaller must be run as root."
    exit 1
fi

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
        exit 0
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

echo ""
echo "Stopping Tailscale-ZLAN service..."

if [ -x "$INIT_PATH" ]; then
    "$INIT_PATH" stop 2>/dev/null
    "$INIT_PATH" disable 2>/dev/null
fi

echo "Stopping remaining processes..."

if [ -x "$TMP_TAILSCALE" ]; then
    "$TMP_TAILSCALE" --socket="$TMP_RUNTIME_DIR/tailscaled.sock" down 2>/dev/null
fi

killall tailscaled 2>/dev/null
killall tailscale.combined 2>/dev/null
killall tailscale-loader.sh 2>/dev/null

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

rm -f /tmp/luci-indexcache 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null

if [ -x /etc/init.d/uhttpd ]; then
    /etc/init.d/uhttpd restart 2>/dev/null
fi

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
echo "Removed:"
echo "  - $INIT_PATH"
echo "  - $LOADER_PATH"
echo "  - $TMP_BINARY"
echo "  - $TMP_TAILSCALE"
echo "  - $TMP_TAILSCALED"
echo "  - $TMP_RUNTIME_DIR"
echo "  - LuCI menu files"
echo ""
echo "Recommended final check:"
echo "  ps | grep tailscale"
echo "  ls -lh /etc/init.d/tailscale-loader /usr/bin/tailscale-loader.sh 2>/dev/null"
echo ""
