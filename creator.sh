#!/usr/bin/env sh

# /////////////////////////////////////////////////////
# VARIABLES
# /////////////////////////////////////////////////////

[ -z "$DOWNLOAD_DIR" ] && DOWNLOAD_DIR="$HOME/Downloads"
[ -z "$ARCH_LINUX_ISO_MIRROR" ] && ARCH_LINUX_ISO_MIRROR="https://mirrors.xtom.de/archlinux/iso/latest"
ARCH_OS_RELEASES_API="https://api.github.com/repos/murkl/arch-os/releases/latest"

# /////////////////////////////////////////////////////
# FUNCTIONS
# /////////////////////////////////////////////////////

print_white() { printf ':: %s\n' "$1"; }
print_purple() { printf ':: \033[35m%s\033[0m\n' "$1"; }
print_green() { printf ':: \033[32m%s\033[0m\n' "$1"; }
print_yellow() { printf ':: \033[33m%s\033[0m\n' "$1"; }
print_red() { printf ':: \033[31m%s\033[0m\n' "$1"; }
print_title() { printf '\033[34m// %s\033[0m\n' "$1"; }
print_info() { printf '\033[1;37m%s\033[0m\n' "$1"; }
print_mesg() { printf '%s\n' "$1"; }

# /////////////////////////////////////////////////////
# MAIN
# /////////////////////////////////////////////////////

trap '[ -n "$arch_iso_file" ] && rm -f "$DOWNLOAD_DIR/$arch_iso_file.part"; exit 130' INT TERM HUP

clear # Clear the screen & print welcome message
mkdir -p "$DOWNLOAD_DIR" || exit 1
print_title "Welcome to Arch OS Bootable Device Creator"
print_mesg "This Script download & create a bootable Device"
print_mesg "from the latest Arch OS or Arch Linux ISO."
echo && print_mesg "Exit with CTRL + C"

# Choose ISO source
echo && print_title "ISO Source"
printf ":: Use official Arch Linux ISO instead of Arch OS? [y/N]: "
read -r use_archlinux </dev/tty

# Fetch download infos
case "$use_archlinux" in
[Yy]*)
	iso_source="Arch Linux"
	iso_hash=""
	arch_latest_version=$(curl -Lfs "${ARCH_LINUX_ISO_MIRROR}/arch/version") || exit 1
	arch_iso_file="archlinux-${arch_latest_version}-x86_64.iso"
	arch_sha_file="archlinux-${arch_latest_version}-x86_64.sha256"
	iso_url="${ARCH_LINUX_ISO_MIRROR}/${arch_iso_file}"
	sha_url="${ARCH_LINUX_ISO_MIRROR}/sha256sums.txt"
	;;
*)
	iso_source="Arch OS"
	sha_url=""
	release_json=$(curl -Lfs "$ARCH_OS_RELEASES_API") || {
		print_red "ERROR: Fetching Arch OS release"
		exit 1
	}
	iso_url=$(printf '%s' "$release_json" | grep -oE 'https://[^"]+\.iso' | head -n1)
	[ -z "$iso_url" ] && print_red "ERROR: No ISO asset found" && exit 1
	iso_hash=$(printf '%s' "$release_json" | grep -oE 'sha256:[a-f0-9]{64}' | head -n1)
	iso_hash="${iso_hash#sha256:}"
	arch_iso_file="${iso_url##*/}"
	arch_sha_file="${arch_iso_file}.sha256"
	;;
esac

echo # Printing info
print_info "ISO Source:   ${iso_source}"
print_info "ISO File:     ${arch_iso_file}"
print_info "Download Dir: ${DOWNLOAD_DIR}"

# Downloading ISO if not exists
echo && print_title "Downloading ISO"
if ! [ -f "${DOWNLOAD_DIR}/${arch_iso_file}" ]; then
	if ! curl -Lf --progress-bar "${iso_url}" -o "${DOWNLOAD_DIR}/${arch_iso_file}.part"; then
		print_red "ERROR: Downloading ISO"
		exit 1
	fi
	if ! mv "${DOWNLOAD_DIR}/${arch_iso_file}.part" "${DOWNLOAD_DIR}/${arch_iso_file}"; then
		print_red "ERROR: Moving ISO"
		exit 1
	fi
	print_green "Finished: ${arch_iso_file} successfully downloaded"
else
	print_white "Skipped: ${arch_iso_file} already exists"
fi

# Provide Checksum (from API digest or remote sha file)
if ! [ -f "${DOWNLOAD_DIR}/${arch_sha_file}" ]; then
	if [ -n "$iso_hash" ]; then
		printf '%s  %s\n' "$iso_hash" "$arch_iso_file" >"${DOWNLOAD_DIR}/${arch_sha_file}"
		print_green "Stored: ${arch_sha_file} from release digest"
	elif [ -n "$sha_url" ]; then
		if ! curl -Lf --progress-bar "${sha_url}" -o "${DOWNLOAD_DIR}/${arch_sha_file}"; then
			print_red "ERROR: Downloading Checksum"
			exit 1
		fi
		print_green "Finished: ${arch_sha_file} successfully downloaded"
	else
		print_yellow "Skipped: No checksum available"
	fi
else
	print_white "Skipped: ${arch_sha_file} already exists"
fi

# Check ISO sum
cd "$DOWNLOAD_DIR" || exit 1
if [ -n "$arch_sha_file" ] && [ -f "$arch_sha_file" ]; then
	print_white "sha256sum: ${arch_iso_file}..."
	if grep -qFw -e "$(sha256sum "$arch_iso_file")" "$arch_sha_file"; then
		print_green "Checksum is correct"
	else
		print_red "ERROR: Checksum incorrect"
		exit 1
	fi
else
	print_yellow "Skipped: Checksum verification (no checksum available)"
fi

# Choose Disk
echo && print_title "USB Target Device"

# List USB devices and number them
disk_list=$(lsblk -d -n -r -o NAME,TRAN | grep ' usb$' | cut -d' ' -f1) || exit 1
[ -z "$disk_list" ] && print_red "No USB device found" && exit 1
print_white "Choose Disk Number:" && echo
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
selected_disk="/dev/$(printf '%s\n' "$disk_list" | sed -n "${user_input}p")"
[ -b "$selected_disk" ] || {
	print_red "ERROR: ${selected_disk} is not a block device"
	exit 1
}
print_green "Selected Disk: ${selected_disk}"

# Create USB Device
echo && print_title "Create Bootable USB Device..."
printf ":: CAUTION: All data on %s will be removed! Really proceed? [y/N]: " "$selected_disk"
read -r confirm </dev/tty
case "$confirm" in
[Yy]*) print_info "Proceeding with ${selected_disk} (${arch_iso_file})" ;;
*) print_red "Operation cancelled" && exit 0 ;;
esac

# Unmount partitions if necessary (lazy as fallback for busy mounts)
if lsblk -nro MOUNTPOINT "$selected_disk" | grep -q .; then
	lsblk -nro MOUNTPOINT "$selected_disk" | while read -r mp; do
		[ -n "$mp" ] && { sudo umount "$mp" 2>/dev/null || sudo umount -l "$mp"; }
	done
	lsblk -nro MOUNTPOINT "$selected_disk" | grep -q . && {
		print_red "ERROR: Failed to unmount some partitions"
		exit 1
	}
	print_green "Unmounted partitions"
fi

# Create bootable device
if ! sudo dd bs=4M if="${arch_iso_file}" of="${selected_disk}" status=progress oflag=sync; then
	print_red "ERROR: Creating USB Device"
	exit 1
fi
print_green "Bootable USB Device successfully created"

# Finished
echo && print_title "Finished"
print_yellow "Please remove USB Device ${selected_disk} or reboot System"
