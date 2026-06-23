#!/bin/sh
# Coleta somente leitura para validar o ZLAN9809M antes da instalação.

section() {
    printf '\n===== %s =====\n' "$1"
}

show_file() {
    label="$1"
    path="$2"

    printf '\n--- %s (%s) ---\n' "$label" "$path"
    if [ -r "$path" ]; then
        cat "$path"
    else
        echo "indisponível"
    fi
}

show_package() {
    package_name="$1"
    printf '\n--- pacote: %s ---\n' "$package_name"
    opkg status "$package_name" 2>&1 || true
}

echo "ZLAN9809M hardware/firmware probe"
echo "Somente leitura: nenhuma configuração será alterada."
date 2>/dev/null || true

section "IDENTIDADE DO SISTEMA"
id 2>&1 || true
uname -a 2>&1 || true
show_file "OpenWrt release" /etc/openwrt_release
show_file "OS release" /etc/os-release

if command -v ubus >/dev/null 2>&1; then
    printf '\n--- ubus system board ---\n'
    ubus call system board 2>&1 || true
fi

section "CPU E ABI"
show_file "CPU info" /proc/cpuinfo
printf '\n--- executáveis e shell ---\n'
ls -l /bin/sh /bin/busybox 2>&1 || true
busybox 2>&1 | sed -n '1,2p' || true
for command_name in sh ash bash awk sed grep xz upx wget curl; do
    printf '%-8s ' "$command_name"
    command -v "$command_name" 2>/dev/null || echo "ausente"
done

printf '\n--- runtime C ---\n'
ls -l /lib/ld-musl-* /lib/libc.so* /lib/libgcc_s.so* 2>&1 || true

section "KERNEL E TUN"
printf 'kernel: '
uname -r 2>&1 || true
show_package kernel
show_package kmod-tun
printf '\n--- módulo/dispositivo TUN ---\n'
ls -ld /sys/module/tun /dev/net /dev/net/tun 2>&1 || true
lsmod 2>&1 | grep -i tun || true

if [ -r /proc/config.gz ] && command -v zcat >/dev/null 2>&1; then
    zcat /proc/config.gz 2>/dev/null | grep 'CONFIG_TUN' || true
fi

section "MEMÓRIA"
show_file "Meminfo" /proc/meminfo
show_file "Swap" /proc/swaps
free 2>&1 || true

section "FLASH, MTD E MONTAGENS"
show_file "Partições MTD" /proc/mtd
ls -l /dev/mtd* 2>&1 || true
printf '\n--- df -k ---\n'
df -k 2>&1 || true
printf '\n--- mount ---\n'
mount 2>&1 || true

if command -v block >/dev/null 2>&1; then
    printf '\n--- block info ---\n'
    block info 2>&1 || true
fi

printf '\n--- uso persistente relevante ---\n'
du -sk /overlay /etc/tailscale /usr/sbin 2>&1 || true

section "OPKG E FEEDS"
mkdir_error=""
if [ ! -d /var/lock ]; then
    mkdir_error="/var/lock não existe; comandos OPKG podem falhar"
fi
echo "$mkdir_error"
opkg print-architecture 2>&1 || true

for package_name in busybox libc libgcc ca-bundle xz xz-utils luci-base; do
    show_package "$package_name"
done

printf '\n--- feeds ativos (credenciais de URL mascaradas quando presentes) ---\n'
for config_file in /etc/opkg.conf /etc/opkg/*.conf; do
    [ -r "$config_file" ] || continue
    echo "# $config_file"
    grep '^[[:space:]]*src' "$config_file" 2>/dev/null \
        | sed 's#://[^ /]*@#://***@#' || true
done

section "TAILSCALE EXISTENTE"
ls -lh /usr/sbin/tailscale* /tmp/tailscale* /etc/tailscale 2>&1 || true
ps 2>&1 | grep '[t]ailscale' || true

section "LOGS DE DETECÇÃO DE HARDWARE"
dmesg 2>&1 \
    | grep -Ei 'Linux version|CPU|Memory|MTD|SPI|NAND|NOR|JFFS|squash|overlay|mt7628|ramips' \
    | sed -n '1,160p' || true

section "FIM"
echo "Cole todo este relatório na conversa para a validação de compatibilidade."
