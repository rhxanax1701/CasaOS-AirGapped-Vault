#!/bin/bash
# Air-Gapped Vault Installer (LUKS2 + Argon2id, detached header)
# WARNING: This will destroy all data on the target data drive.

set -e

echo -e "\e[1;36m[+] Initializing Air-Gapped Vault Setup...\e[0m"

read -p "Enter target DATA drive to encrypt (e.g., /dev/sdb): " TARGET_DRIVE
read -p "Enter target KEY drive (CD/USB) (e.g., /dev/sr0 or /dev/sdc1): " KEY_DRIVE
read -p "Enter path for the detached LUKS header [/etc/vault-headers/vault.header]: " HEADER_PATH
HEADER_PATH=${HEADER_PATH:-/etc/vault-headers/vault.header}
read -p "Enter mount point for the unlocked vault [/mnt/vault]: " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-/mnt/vault}
read -p "Enter temporary mount point for the key drive [/media/vault-key-drive]: " KEY_MOUNT
KEY_MOUNT=${KEY_MOUNT:-/media/vault-key-drive}

if [ ! -b "$TARGET_DRIVE" ]; then
    echo -e "\e[1;31m[!] $TARGET_DRIVE is not a valid block device.\e[0m"
    exit 1
fi

if [ ! -b "$KEY_DRIVE" ]; then
    echo -e "\e[1;31m[!] $KEY_DRIVE is not a valid block device.\e[0m"
    exit 1
fi

echo -e "\e[1;33m[!] WARNING: ALL DATA ON $TARGET_DRIVE WILL BE DESTROYED.\e[0m"
read -p "Type 'I UNDERSTAND' to continue: " CONFIRM
if [ "$CONFIRM" != "I UNDERSTAND" ]; then
    echo "Aborting."
    exit 1
fi

HEADER_DIR=$(dirname "$HEADER_PATH")

# 1. Create the server-side header directory
echo "[+] Creating detached header directory at $HEADER_DIR..."
sudo mkdir -p "$HEADER_DIR"
sudo chmod 700 "$HEADER_DIR"

# 2. Mount the key drive and generate the 512-byte raw key
echo "[+] Mounting $KEY_DRIVE and generating raw cryptographic key..."
sudo mkdir -p "$KEY_MOUNT"
sudo mount "$KEY_DRIVE" "$KEY_MOUNT"

KEY_FILE="$KEY_MOUNT/vault.key"
if [ -f "$KEY_FILE" ]; then
    echo -e "\e[1;33m[!] $KEY_FILE already exists.\e[0m"
    read -p "Overwrite with a new random key? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo "[+] Using existing key file."
    else
        sudo dd if=/dev/urandom of="$KEY_FILE" bs=512 count=1
    fi
else
    sudo dd if=/dev/urandom of="$KEY_FILE" bs=512 count=1
fi
sudo chmod 400 "$KEY_FILE"

# 3. Format the drive with detached header and Argon2id (paranoid settings)
echo "[+] Formatting $TARGET_DRIVE with LUKS2 (detached header + 2GB RAM cost)..."
sudo cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha512 \
    --pbkdf argon2id \
    --pbkdf-memory 2097152 \
    --header "$HEADER_PATH" \
    "$TARGET_DRIVE" "$KEY_FILE"

# 4. Open and build the filesystem
echo "[+] Building Ext4 filesystem..."
sudo cryptsetup luksOpen --header "$HEADER_PATH" --key-file "$KEY_FILE" "$TARGET_DRIVE" vault
sudo mkfs.ext4 /dev/mapper/vault
sudo mkdir -p "$MOUNT_POINT"
sudo mount /dev/mapper/vault "$MOUNT_POINT"
sudo chmod 777 "$MOUNT_POINT"

# 5. Lock it down
sudo umount "$MOUNT_POINT"
sudo cryptsetup luksClose vault
sudo umount "$KEY_MOUNT"

echo -e "\e[1;32m[✓] Vault created successfully.\e[0m"
echo -e "\e[1;32m    Header: $HEADER_PATH\e[0m"
echo -e "\e[1;32m    Key:    $KEY_FILE\e[0m"
echo -e "\e[1;32m    Back up both the header file and the key drive — without BOTH, the data is unrecoverable.\e[0m"
