#!/usr/bin/env sh

# /////////////////////////////////////////////////////
# VARIABLES
# /////////////////////////////////////////////////////

[ -z "$ARCH_ISO_DOWNLOAD_DIR" ] && ARCH_ISO_DOWNLOAD_DIR="$HOME/Downloads"
[ -z "$ARCH_ISO_DOWNLOAD_URL" ] && ARCH_ISO_DOWNLOAD_URL="https://mirrors.xtom.de/archlinux/iso/latest"

# /////////////////////////////////////////////////////
# FUNCTIONS
# /////////////////////////////////////////////////////

print_white() { printf '%s\n' "$1"; }
print_green() { printf '\033[32m%s\033[0m\n' "$1"; }
print_red() { printf '\033[31m%s\033[0m\n' "$1"; }
print_purple() { printf '\033[35m%s\033[0m\n' "$1"; }
print_yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
print_info() { printf '\033[1;37m%s\033[0m\n' "$1"; }
print_title() { print_purple "// ${1}"; }

# /////////////////////////////////////////////////////
# MAIN
# /////////////////////////////////////////////////////

clear # Clear the screen & print welcome message
echo && print_title "Welcome to Arch OS Bootable Device Creator"
print_white "This script downloads the latest Arch Linux ISO"
print_white "and creates a bootable USB device."
echo && print_info "Download Dir: ${ARCH_ISO_DOWNLOAD_DIR}"

# Fetch download infos
arch_latest_version="$(curl -Lfs "${ARCH_ISO_DOWNLOAD_URL}"/arch/version)"
arch_iso_file="archlinux-${arch_latest_version}-x86_64.iso"
arch_sha_file="archlinux-${arch_latest_version}-x86_64.sha256"

mkdir -p "$ARCH_ISO_DOWNLOAD_DIR" || exit 1

# Downloading ISO if not exists
echo && print_title "Downloading Arch Linux ISO"
if ! [ -f "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}" ]; then
    if ! curl -Lf --progress-bar "${ARCH_ISO_DOWNLOAD_URL}/${arch_iso_file}" -o "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}.part"; then
        print_red "ERROR: Downloading Arch ISO"
        exit 1
    fi
    if ! mv "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}.part" "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}"; then
        print_red "ERROR: Moving Arch ISO"
        exit 1
    fi
    print_green "Finished: ${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file} successfuly downloaded"
else
    print_white "Skipped: ${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file} already exists"
fi

# Downloading Checksum if not exists
if ! [ -f "${ARCH_ISO_DOWNLOAD_DIR}/${arch_sha_file}" ]; then
    if ! curl -Lf --progress-bar "${ARCH_ISO_DOWNLOAD_URL}/sha256sums.txt" -o "${ARCH_ISO_DOWNLOAD_DIR}/${arch_sha_file}"; then
        print_red "ERROR: Downloading Checksum"
        exit 1
    else
        print_green "Finished: ${ARCH_ISO_DOWNLOAD_DIR}/${arch_sha_file} successfuly downloaded"
    fi
else
    print_white "Skipped: ${ARCH_ISO_DOWNLOAD_DIR}/${arch_sha_file} already exists"
fi

# Change to download dir
cd "$ARCH_ISO_DOWNLOAD_DIR" || exit 1

# Check ISO sum
print_white "sha256sum ${ARCH_ISO_DOWNLOAD_URL}/${arch_iso_file}..."
if grep -qrnw "${arch_sha_file}" -e "$(sha256sum "${arch_iso_file}")"; then
    print_green "Checksum is correct"
else
    print_red "ERROR: Checksum incorrect"
    exit 1
fi

# Choose Disk
echo && print_title "USB Target Device"

# List disks and number them
disk_list=$(lsblk -I 8 -d -o KNAME -n)
counter=1
printf '%s\n' "$disk_list" | while read -r disk_line; do
    size=$(lsblk -d -n -o SIZE /dev/"$disk_line")
    printf '%d) /dev/%s (%s)\n' "$counter" "$disk_line" "$size"
    counter=$((counter + 1))
done

# Count total number of disks
total_disks=$(printf '%s\n' "$disk_list" | wc -l)

# User input
printf "\nChoose Disk (1-%d): " "$total_disks"
read -r user_input

# Validate the input
if ! [ "$user_input" -eq "$user_input" ] 2>/dev/null ||
    [ "$user_input" -lt 1 ] ||
    [ "$user_input" -gt "$total_disks" ]; then
    print_red "Invalid input! Please choose a number between 1 and ${total_disks}"
    exit 1
fi

# Select the corresponding disk
selected_disk=$(printf '%s\n' "$disk_list" | sed -n "${user_input}p")
selected_disk="/dev/$selected_disk"
print_green "Selected Disk: ${selected_disk}"

# Create USB Device
echo && print_title "Create Bootable USB Device..."
printf "CAUTION: All data on %s will be removed! Really proceed? [y/N]: " "$selected_disk"
read -r confirm
case "$confirm" in
[Yy]*) print_info "Proceeding with $selected_disk" ;;
*) print_red "Operation cancelled" && exit 0 ;;
esac

# Create bootable device
print_white "Arch Linux ISO: ${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}"
if ! sudo dd bs=4M if="${arch_iso_file}" of="$selected_disk" status=progress oflag=sync; then
    print_red "ERROR: Creating USB Device"
    exit 1
fi
print_green "Bootable USB Device succefully created"

# Finished
echo && print_title "Finished"
print_yellow "Please remove USB Device or reboot System: $selected_disk"
