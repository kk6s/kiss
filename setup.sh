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

# Step 0: Run cfdisk for Partitioning
echo "Starting disk partitioning with cfdisk..."
echo "Please create and format your partitions. The root partition should be mounted at /mnt."
cfdisk || error_exit "Failed to run cfdisk."

# Prompt user to mount partitions
echo "Ensure that your root partition is mounted at /mnt before proceeding."
read -p "Press Enter to confirm that your partitions are mounted correctly..."

# Step 1: Create Target Directory
echo "Creating target directory: $target_dir"
mkdir -p "$target_dir" || error_exit "Failed to create target directory."

# Step 2: Download Installation Tarball
echo "Downloading tarball from $url"
curl -fLO "$url/$file" || error_exit "Failed to download tarball."
curl -fLO "$url/$file.sha256" || error_exit "Failed to download checksum."

# Step 3: Verify Tarball
echo "Verifying tarball checksum..."
sha256sum -c < "$file.sha256" || error_exit "Checksum verification failed."

# Step 4: Extract Tarball
echo "Extracting tarball to $target_dir"
tar -C "$target_dir" -xvf "$file" || error_exit "Failed to extract tarball."

# Step 5: Enter Chroot
echo "Entering chroot environment..."
if [ ! -x "$target_dir/bin/kiss-chroot" ]; then
    error_exit "KISS chroot script not found. Extraction may have failed."
fi
"$target_dir/bin/kiss-chroot" "$target_dir" << "EOF"
    echo "Welcome to KISS Linux Chroot."

    # Clone Official Repositories
    echo "Cloning official repositories..."
    git clone https://github.com/kisslinux/repo "$repo_dir" || exit 1

    # Set KISS_PATH
    export KISS_PATH="$repo_dir/core:$repo_dir/extra"

    # Optionally, configure the repositories for Wayland support
    echo "KISS_PATH set to: $KISS_PATH"

    # Exit chroot environment
    exit 0
EOF

# Post-chroot Actions
echo "KISS Linux setup completed. You can now proceed with kernel installation and configuration."
echo "Use the chroot environment to further set up KISS Linux as needed."

# Cleanup (optional)
rm -f "$file" "$file.sha256"

echo "Installation script completed successfully."
