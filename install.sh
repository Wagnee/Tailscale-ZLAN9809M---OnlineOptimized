#!/bin/sh
# Automatic installer for Tailscale-ZLAN9809M Online Optimized
# Target: OpenWrt / ZLAN9809M / mipsel_24kc

RAW_BASE="https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main"
BINARY_URL="$RAW_BASE/tailscale.combined"
LOADER_URL="$RAW_BASE/tailscale-loader.sh"
INIT_URL="$RAW_BASE/tailscale-loader"

CONFIG_DIR="/etc/tailscale"
CONFIG_FILE="$CONFIG_DIR/tailscale.env"
LOADER_PATH="/usr/bin/tailscale-loader.sh"
INIT_PATH="/etc/init.d/tailscale-loader"

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

if [ ! -e /dev/net/tun ]; then
    echo "WARNING: /dev/net/tun was not found."
    echo "Tailscale may not work unless kmod-tun is available."
fi

echo "Current disk usage:"
df -h
echo ""

echo "Default values are shown in brackets."
echo ""

printf "Tailscale hostname [zlan9809m-sr2]: "
read TS_HOSTNAME
TS_HOSTNAME="${TS_HOSTNAME:-zlan9809m-sr2}"

printf "LAN subnet to advertise [192.168.9.0/24]: "
read TS_ROUTES
TS_ROUTES="${TS_ROUTES:-192.168.9.0/24}"

echo ""
echo "Optional: paste a Tailscale auth key for automatic login."
echo "Leave empty to authenticate manually using the URL shown in logs."
printf "Tailscale auth key []: "
read TS_AUTHKEY

echo ""
echo "Installing files..."

mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi

cat > "$CONFIG_FILE" <<EOF
TS_BINARY_URL="$BINARY_URL"

# Device name shown in the Tailscale admin panel
TS_HOSTNAME="$TS_HOSTNAME"

# LAN subnet to advertise through Tailscale
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

echo "Downloading loader script..."
wget --no-check-certificate -O "$LOADER_PATH" "$LOADER_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download tailscale-loader.sh"
    exit 1
fi
chmod +x "$LOADER_PATH"

echo "Downloading init service..."
wget --no-check-certificate -O "$INIT_PATH" "$INIT_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download init service"
    exit 1
fi
chmod +x "$INIT_PATH"

echo "Enabling service on boot..."
"$INIT_PATH" enable

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

echo ""
echo "Installation finished."
echo ""
echo "Useful commands:"
echo "  logread -f | grep tailscale"
echo "  /tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock status"
echo "  /tmp/tailscale --socket=/tmp/tailscale-runtime/tailscaled.sock ip"
echo "  /etc/init.d/tailscale-loader restart"
echo ""
echo "If no auth key was provided, check the logs for the login URL:"
echo "  logread | grep -i https"
echo ""
echo "Do not forget to approve the advertised subnet route in the Tailscale admin panel:"
echo "  $TS_ROUTES"
echo ""
