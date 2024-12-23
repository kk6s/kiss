#!/bin/bash

# Variables
ver=2021.7-9
url=https://github.com/kisslinux/repo/releases/download/$ver
file=kiss-chroot-$ver.tar.xz
target_dir="/mnt/kiss"
repo_dir="$target_dir/kiss-repo"

# Functions
error_exit() {
    echo "Error: $1"
    exit 1
}

pause() {
    read -p "$1 (Press Enter to continue)"
}

echo "KISS Linux Installation Script"

# Step 1: Disk Partitioning
echo "Starting disk partitioning with cfdisk..."
pause "Ensure that your root partition (e.g., /dev/sda1) is ready."
cfdisk || error_exit "Failed to run cfdisk."

# Step 2: Format and Mount the Partition
echo "Formatting the root partition as ext4..."
read -p "Enter the root partition (e.g., /dev/sda1): " root_partition

if [ ! -b "$root_partition" ]; then
    error_exit "Partition $root_partition does not exist."
fi

mkfs.ext4 "$root_partition" || error_exit "Failed to format $root_partition."
echo "Mounting $root_partition to /mnt..."
mount "$root_partition" /mnt || error_exit "Failed to mount $root_partition."

# Step 3: Download Installation Tarball
echo "Downloading the KISS Linux tarball..."
curl -fLO "$url/$file" || error_exit "Failed to download tarball."
curl -fLO "$url/$file.sha256" || error_exit "Failed to download checksum."
sha256sum -c < "$file.sha256" || error_exit "Checksum verification failed."

# Step 4: Extract Tarball
echo "Extracting tarball to $target_dir..."
mkdir -p "$target_dir" || error_exit "Failed to create target directory."
tar -C "$target_dir" -xvf "$file" || error_exit "Failed to extract tarball."

# Step 5: Enter Chroot
echo "Entering chroot environment..."
"$target_dir/bin/kiss-chroot" "$target_dir" << "EOF"
    echo "Welcome to KISS Linux Chroot."

    # Step 6: Clone Official Repositories
    echo "Cloning official repositories..."
    git clone https://github.com/kisslinux/repo "$repo_dir" || exit 1
    export KISS_PATH="$repo_dir/core:$repo_dir/extra"

    # Step 7: Update and Build GPG
    echo "Building GPG for repository signing..."
    kiss build gnupg1 || exit 1
    gpg --keyserver keyserver.ubuntu.com --recv-key 13295DAC2CF13B5C || exit 1
    echo trusted-key 0x13295DAC2CF13B5C >> /root/.gnupg/gpg.conf

    # Enable signature verification
    cd "$repo_dir" || exit 1
    git config merge.verifySignatures true

    # Step 8: Build and Install Packages
    echo "Rebuilding all base packages..."
    cd /var/db/kiss/installed && kiss build * || exit 1

    # Step 9: Kernel Setup
    echo "Downloading and configuring the Linux kernel..."
    curl -fLO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.tar.xz || exit 1
    tar xvf linux-6.1.tar.xz || exit 1
    cd linux-6.1 || exit 1
    make defconfig || exit 1
    make menuconfig || exit 1
    make || exit 1
    make modules_install || exit 1
    make install || exit 1
    mv /boot/vmlinuz /boot/vmlinuz-6.1 || exit 1
    mv /boot/System.map /boot/System.map-6.1 || exit 1

    # Step 10: Install Init System and Bootloader
    echo "Installing init system and bootloader..."
    kiss build baseinit || exit 1
    kiss build grub || exit 1
    grub-install --target=i386-pc /dev/sda || exit 1
    grub-mkconfig -o /boot/grub/grub.cfg || exit 1

    # Step 11: Create Users and Set Passwords
    echo "Creating user accounts..."
    passwd root || exit 1
    adduser user || exit 1
    passwd user || exit 1

    # Exit chroot
    exit 0
EOF

# Step 12: Cleanup
echo "Cleaning up installation files..."
rm -f "$file" "$file.sha256"

echo "KISS Linux installation is complete! Reboot into your new system."
