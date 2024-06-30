#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Logging functions
log() {
    echo -e "\033[1;32m[INFO] $1\033[0m"
}

log_error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m" >&2
}

log_verbose() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo -e "\033[1;34m[VERBOSE] $1\033[0m"
    fi
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Parse CLI arguments
VERBOSE=0
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=1; shift ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --verbose  Enable verbose output"
            echo "  -h, --help     Display this help message"
            exit 0
            ;;
        *) log_error "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

# Function to copy and set permissions
copy_and_chmod() {
    local src=$1
    local dest=$2
    cp "$src" "$dest"
    chmod +x "$dest"
    log_verbose "Copied $src to $dest and set executable permissions"
}

echo ""
log "Starting installation..."

# Copy the custom kernel script
log "Copying custom-kernel.sh to /usr/bin/custom-kernel"
copy_and_chmod "./custom-kernel.sh" "/usr/bin/custom-kernel"

# Create the kernel post-install hook
log "Creating kernel post-install hook in /etc/kernel/postinst.d/zz-custom-kernel"
copy_and_chmod "./zz-custom-kernel" "/etc/kernel/postinst.d/zz-custom-kernel"

# Create the custom kernel entry
log "Creating custom kernel entry in /boot/efi/loader/entries/Pop_OS-custom.conf"
cp /boot/efi/loader/entries/Pop_OS-current.conf /boot/efi/loader/entries/Pop_OS-custom.conf
sed -i 's/vmlinuz\.efi/vmlinuz-custom\.efi/' /boot/efi/loader/entries/Pop_OS-custom.conf
sed -i 's/initrd\.img/initrd\.img-custom/' /boot/efi/loader/entries/Pop_OS-custom.conf
log_verbose "Modified /boot/efi/loader/entries/Pop_OS-custom.conf"

# Change the default boot entry to the custom kernel entry
log "Setting the default boot entry to Pop_OS-custom"
sed -i 's/default Pop_OS-current/default Pop_OS-custom/' /boot/efi/loader/loader.conf
log_verbose "Modified /boot/efi/loader/loader.conf"

# Initialize the custom kernel configuration file
log "Initializing the custom kernel configuration file"
custom-kernel --init-config
log_verbose "Initialized custom kernel configuration file"

log "Installation complete."
echo -e "\n  1. Run 'custom-kernel --help' for more information."
echo -e   "  2. Run 'custom-kernel' to set your desired custom kernel."
echo -e   "  3. Reboot your system to use the custom kernel.\n"

exit 0
