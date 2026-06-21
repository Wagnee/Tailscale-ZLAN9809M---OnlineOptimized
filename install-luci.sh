#!/bin/sh
# Install LuCI menu for Tailscale-ZLAN9809M Online Optimized

RAW_BASE="https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main"

CONTROLLER_URL="$RAW_BASE/luci/tailscale_zlan.lua"
VIEW_URL="$RAW_BASE/luci/status.htm"

CONTROLLER_PATH="/usr/lib/lua/luci/controller/tailscale_zlan.lua"
VIEW_DIR="/usr/lib/lua/luci/view/tailscale_zlan"
VIEW_PATH="$VIEW_DIR/status.htm"

echo ""
echo "============================================================"
echo " Installing LuCI menu for Tailscale ZLAN9809M"
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

if [ ! -d /usr/lib/lua/luci ]; then
    echo "ERROR: LuCI was not found on this router."
    exit 1
fi

mkdir -p /usr/lib/lua/luci/controller
mkdir -p "$VIEW_DIR"

echo "Downloading LuCI controller..."
wget --no-check-certificate -O "$CONTROLLER_PATH" "$CONTROLLER_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download controller"
    exit 1
fi

echo "Downloading LuCI view..."
wget --no-check-certificate -O "$VIEW_PATH" "$VIEW_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to download view"
    exit 1
fi

sed -i 's/\r$//' "$CONTROLLER_PATH" 2>/dev/null
sed -i 's/\r$//' "$VIEW_PATH" 2>/dev/null

rm -f /tmp/luci-indexcache 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null

/etc/init.d/uhttpd restart 2>/dev/null

rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache
/etc/init.d/uhttpd restart

echo ""
echo "LuCI menu installed."
echo ""
echo "Open:"
echo "  System web interface → Services → Tailscale ZLAN"
echo ""