module("luci.controller.tailscale_zlan", package.seeall)

function index()
    entry(
        {"admin", "services", "tailscale_zlan"},
        template("tailscale_zlan/status"),
        _("Tailscale ZLAN"),
        60
    ).dependent = false

    entry(
        {"admin", "services", "tailscale_zlan", "action"},
        call("action")
    ).leaf = true

    entry(
        {"admin", "services", "tailscale_zlan", "save"},
        call("save")
    ).leaf = true

    entry(
        {"admin", "services", "tailscale_zlan", "ping"},
        call("ping_peer")
    ).leaf = true
end

function action()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local dispatcher = require "luci.dispatcher"

    local cmd = http.formvalue("cmd")

    if cmd == "start" then
        sys.call("/etc/init.d/tailscale-loader start >/dev/null 2>&1")
    elseif cmd == "stop" then
        sys.call("/etc/init.d/tailscale-loader stop >/dev/null 2>&1")
    elseif cmd == "restart" then
        sys.call("/etc/init.d/tailscale-loader restart >/dev/null 2>&1")
    end

    http.redirect(dispatcher.build_url("admin", "services", "tailscale_zlan"))
end

local function clean_value(v)
    v = v or ""
    v = v:gsub("\r", "")
    v = v:gsub("\n", "")
    v = v:gsub('"', '\\"')
    return v
end

local function read_env()
    local env = {}
    local f = io.open("/etc/tailscale/tailscale.env", "r")

    if not f then
        return env
    end

    for line in f:lines() do
        local k, v = line:match('^([A-Z0-9_]+)="(.*)"')
        if k and v then
            env[k] = v
        end
    end

    f:close()
    return env
end

function save()
    local http = require "luci.http"
    local dispatcher = require "luci.dispatcher"

    local old = read_env()

    local binary_url = clean_value(http.formvalue("ts_binary_url"))
    local hostname = clean_value(http.formvalue("ts_hostname"))
    local routes = clean_value(http.formvalue("ts_routes"))
    local authkey = clean_value(http.formvalue("ts_authkey"))
    local clear_authkey = http.formvalue("clear_authkey")

    if binary_url == "" then
        binary_url = old["TS_BINARY_URL"] or "https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/tailscale.combined"
    end

    if hostname == "" then
        hostname = old["TS_HOSTNAME"] or "zlan9809m"
    end

    if routes == "" then
        routes = old["TS_ROUTES"] or ""
    end

    if clear_authkey == "1" then
        authkey = ""
    elseif authkey == "" then
        authkey = old["TS_AUTHKEY"] or ""
    end

    os.execute("mkdir -p /etc/tailscale")

    local f = io.open("/etc/tailscale/tailscale.env", "w")

    if f then
        f:write('TS_BINARY_URL="' .. binary_url .. '"\n')
        f:write('\n')
        f:write('# Device name shown in the Tailscale admin panel\n')
        f:write('TS_HOSTNAME="' .. hostname .. '"\n')
        f:write('\n')
        f:write('# LAN subnet to advertise through Tailscale\n')
        f:write('TS_ROUTES="' .. routes .. '"\n')
        f:write('\n')
        f:write('# Optional: Tailscale auth key for automatic login\n')
        f:write('# Never publish your auth key in a public repository\n')
        f:write('TS_AUTHKEY="' .. authkey .. '"\n')
        f:write('\n')
        f:write('# Service paths\n')
        f:write('TS_STATE_DIR="/etc/tailscale"\n')
        f:write('TS_RUNTIME_DIR="/tmp/tailscale-runtime"\n')
        f:write('TS_BIN="/tmp/tailscale.combined"\n')
        f:write('TS_SOCKET="/tmp/tailscale-runtime/tailscaled.sock"\n')
        f:close()
    end

    http.redirect(dispatcher.build_url("admin", "services", "tailscale_zlan"))
end

function ping_peer()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local dispatcher = require "luci.dispatcher"

    local peer_ip = http.formvalue("peer_ip")
    
    if not peer_ip or peer_ip == "" then
        http.write_json({success = false, error = "No peer IP provided"})
        return
    end

    -- Execute ping command (3 packets, 1 second timeout each)
    local ping_output = sys.exec("ping -c 3 -W 1 " .. peer_ip .. " 2>&1")
    
    -- Parse ping output for statistics
    local success = false
    local avg_time = "N/A"
    local packet_loss = "N/A"
    
    if ping_output then
        -- Check if ping was successful
        if ping_output:match("3 received") or ping_output:match("2 received") or ping_output:match("1 received") then
            success = true
        end
        
        -- Extract average time
        local avg_match = ping_output:match("avg[= ]([%d%.]+)")
        if avg_match then
            avg_time = avg_match .. " ms"
        end
        
        -- Extract packet loss
        local loss_match = ping_output:match("(%d+)%% packet loss")
        if loss_match then
            packet_loss = loss_match .. "%"
        end
    end

    http.write_json({
        success = success,
        peer_ip = peer_ip,
        avg_time = avg_time,
        packet_loss = packet_loss,
        output = ping_output or ""
    })
end