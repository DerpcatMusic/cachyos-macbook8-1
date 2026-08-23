#!/bin/bash
# CachyOS calamares-online.sh plus MacBook8,1 kernel swap.
# Re-applied after pacman refreshes cachyos-calamares-next.

mb81_patch_calamares() {
    local netyaml
    netyaml=$(find /usr/share/calamares /etc/calamares -name netinstall.yaml 2>/dev/null | head -1)
    if [[ -z "$netyaml" ]]; then
        echo "mb81: netinstall.yaml not found" >&2
        return 1
    fi
    # headers first so we do not turn linux-cachyos-headers into linux-cachyos-mb81-headers twice
    sed -i \
        -e 's/- linux-cachyos-headers$/- linux-cachyos-mb81-headers/' \
        -e 's/- linux-cachyos$/- linux-cachyos-mb81/' \
        "$netyaml"
    echo "mb81: Calamares will install linux-cachyos-mb81 from $netyaml"
}

main() {
    sudo rm -rf /etc/pacman.d/gnupg
    sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
    sudo pacman-key --init
    sudo pacman-key --populate archlinux cachyos
    timedatectl set-ntp true

    local progname
    progname="$(basename "$0")"
    local log="/home/liveuser/cachy-install.log"
    local mode="online"

    local SYSTEM=""
    if [ -d /sys/firmware/efi ]; then
        SYSTEM="UEFI SYSTEM"
    else
        SYSTEM="BIOS/MBR SYSTEM"
    fi

    local ISO_VERSION
    ISO_VERSION="$(cat /etc/version-tag)"
    echo "USING ISO VERSION: ${ISO_VERSION}"

    sudo pacman -Sy --noconfirm cachyos-calamares-next
    mb81_patch_calamares

    inxi -F > "$log"

    cat <<EOF >> "$log"
########## $log by $progname
########## Started (UTC): $(date -u "+%x %X")
########## ISO version: $ISO_VERSION
########## System: $SYSTEM
########## Kernel: linux-cachyos-mb81 (MacBook8,1)
EOF

    sudo cp "/usr/share/calamares/settings_${mode}.conf" /etc/calamares/settings.conf
    exec pkexec-wrapper calamares -D6 >> "$log"
}

main "$@"
