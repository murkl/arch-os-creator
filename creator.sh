#!/usr/bin/env sh

# /////////////////////////////////////////////////////
# VARIABLES
# /////////////////////////////////////////////////////

[ -z "$ARCH_ISO_DOWNLOAD_DIR" ] && ARCH_ISO_DOWNLOAD_DIR="$HOME/Downloads"
[ -z "$ARCH_ISO_DOWNLOAD_MIRROR" ] && ARCH_ISO_DOWNLOAD_MIRROR="https://mirrors.xtom.de/archlinux/iso/latest"

# /////////////////////////////////////////////////////
# FUNCTIONS
# /////////////////////////////////////////////////////

print_white() { printf ':: %s\n' "$1"; }
print_purple() { printf ':: \033[35m%s\033[0m\n' "$1"; }
print_green() { printf ':: \033[32m%s\033[0m\n' "$1"; }
print_yellow() { printf ':: \033[33m%s\033[0m\n' "$1"; }
print_red() { printf ':: \033[31m%s\033[0m\n' "$1"; }
print_title() { printf '\033[35m// %s\033[0m\n' "$1"; }
print_info() { printf '\033[1;37m%s\033[0m\n' "$1"; }
print_mesg() { printf '%s\n' "$1"; }

# /////////////////////////////////////////////////////
# MAIN
# /////////////////////////////////////////////////////

clear # Clear the screen & print welcome message
mkdir -p "$ARCH_ISO_DOWNLOAD_DIR" || exit 1
echo && print_title "Welcome to Arch OS Bootable Device Creator"
print_mesg "This script downloads the latest Arch Linux ISO"
print_mesg "and creates a bootable USB device."
echo && print_mesg "Exit with CTRL + C"
echo && print_info "Download Mirror:  ${ARCH_ISO_DOWNLOAD_MIRROR}"
print_info "Download Dir:     ${ARCH_ISO_DOWNLOAD_DIR}"

# Fetch download infos
arch_latest_version="$(curl -Lfs "${ARCH_ISO_DOWNLOAD_MIRROR}"/arch/version)"
arch_iso_file="archlinux-${arch_latest_version}-x86_64.iso"
arch_sha_file="archlinux-${arch_latest_version}-x86_64.sha256"

# Downloading ISO if not exists
echo && print_title "Downloading Arch Linux ISO"
if ! [ -f "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}" ]; then
    if ! curl -Lf --progress-bar "${ARCH_ISO_DOWNLOAD_MIRROR}/${arch_iso_file}" -o "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}.part"; then
        print_red "ERROR: Downloading Arch ISO"
        exit 1
    fi
    if ! mv "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}.part" "${ARCH_ISO_DOWNLOAD_DIR}/${arch_iso_file}"; then
        print_red "ERROR: Moving Arch ISO"
        exit 1
    fi
    print_green "Finished: ${arch_iso_file} successfully downloaded"
else
    print_white "Skipped: ${arch_iso_file} already exists"
fi

# Downloading Checksum if not exists
if ! [ -f "${ARCH_ISO_DOWNLOAD_DIR}/${arch_sha_file}" ]; then
    if ! curl -Lf --progress-bar "${ARCH_ISO_DOWNLOAD_MIRROR}/sha256sums.txt" -o "${ARCH_ISO_DOWNLOAD_DIR}/${arch_sha_file}"; then
        print_red "ERROR: Downloading Checksum"
        exit 1
    else
        print_green "Finished: ${arch_sha_file} successfully downloaded"
    fi
else
    print_white "Skipped: ${arch_sha_file} already exists"
fi

# Check ISO sum
cd "$ARCH_ISO_DOWNLOAD_DIR" || exit 1
print_white "sha256sum: ${arch_iso_file}..."
if grep -qrnw "${arch_sha_file}" -e "$(sha256sum "${arch_iso_file}")"; then
    print_green "Checksum is correct"
else
    print_red "ERROR: Checksum incorrect"
    exit 1
fi

# Choose Disk
echo && print_title "USB Target Device"
print_white "Choose Disk Number:" && echo

# List disks and number them
disk_list=$(lsblk -I 8 -d -o KNAME -n) || exit 1
[ -z "$disk_list" ] && print_red "No disk found" && exit 1
counter=1 && printf '%s\n' "$disk_list" | while read -r disk_line; do
    size=$(lsblk -d -n -o SIZE /dev/"$disk_line")
    printf '%d) /dev/%s (%s)\n' "$counter" "$disk_line" "$size"
    counter=$((counter + 1))
done

# Count total number of disks
total_disks=$(printf '%s\n' "$disk_list" | wc -l)

# User input
printf "\n:: (1 - %d): " "$total_disks"
read -r user_input </dev/tty

# Validate the input
if ! [ "$user_input" -eq "$user_input" ] 2>/dev/null ||
    [ "$user_input" -lt 1 ] ||
    [ "$user_input" -gt "$total_disks" ]; then
    print_red "Invalid input! Please choose a number between 1 and ${total_disks}"
    exit 1
fi

# Select the corresponding disk
unset selected_disk
selected_disk=$(printf '%s\n' "$disk_list" | sed -n "${user_input}p")
selected_disk="/dev/$selected_disk"
print_green "Selected Disk: ${selected_disk}"

# Create USB Device
echo && print_title "Create Bootable USB Device..."
printf "CAUTION: All data on %s will be removed! Really proceed? [y/N]: " "$selected_disk"
read -r confirm </dev/tty
case "$confirm" in
[Yy]*) print_info "Proceeding with ${selected_disk} (${arch_iso_file})" ;;
*) print_red "Operation cancelled" && exit 0 ;;
esac

# Create bootable device
if ! sudo dd bs=4M if="${arch_iso_file}" of="${selected_disk}" status=progress oflag=sync; then
    print_red "ERROR: Creating USB Device"
    exit 1
fi
print_green "Bootable USB Device successfully created"

# Finished
echo && print_title "Finished"
print_yellow "Please remove USB Device ${selected_disk} or reboot System"
