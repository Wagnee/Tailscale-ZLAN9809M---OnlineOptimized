#!/bin/sh
# Automatic installer for Tailscale-ZLAN9809M Online Optimized
# Target: ZLAN9809M / OpenWrt / mipsel_24kc

RAW_BASE="https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main"

BINARY_URL="$RAW_BASE/tailscale.combined"
LOADER_URL="$RAW_BASE/tailscale-loader.sh"
INIT_URL="$RAW_BASE/tailscale-loader"
ENV_URL="$RAW_BASE/tailscale.env"

CONFIG_DIR="/etc/tailscale"
CONFIG_FILE="$CONFIG_DIR/tailscale.env"

LOADER_PATH="/usr/bin/tailscale-loader.sh"
INIT_PATH="/etc/init.d/tailscale-loader"

TMP_BINARY="/tmp/tailscale.combined"
TMP_ENV="/tmp/tailscale.env.repo"

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
    echo ""
fi

echo "Current disk usage:"
df -h
echo ""

echo "Downloading repository files from:"
echo "$RAW_BASE"
echo ""

mkdir -p "$CONFIG_DIR"

echo "Downloading tailscale.env template..."
wget --no-check-certificate -O "$TMP_ENV" "$ENV_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download tailscale.env"
    exit 1
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

if [ -f "$CONFIG_FILE" ]; then
    BACKUP_FILE="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
    echo "Existing config found. Backup: $BACKUP_FILE"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

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

echo ""
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
echo "Configuration file:"
echo "  $CONFIG_FILE"
echo ""
echo "Downloaded runtime binary:"
echo "  $TMP_BINARY"
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
