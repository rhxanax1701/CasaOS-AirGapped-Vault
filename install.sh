#!/bin/bash
# CasaOS Air-Gapped Vault Installer
# WARNING: This will destroy all data on the target data drive.

echo -e "\e[1;36m[+] Initializing CasaOS Paranoid Vault Setup...\e[0m"

read -p "Enter target DATA drive to encrypt (e.g., /dev/sdb): " TARGET_DRIVE
read -p "Enter target KEY drive (CD/USB) (e.g., /dev/sr0): " KEY_DRIVE

echo -e "\e[1;33m[!] WARNING: ALL DATA ON $TARGET_DRIVE WILL BE DESTROYED.\e[0m"
read -p "Type 'I UNDERSTAND' to continue: " CONFIRM
if [ "$CONFIRM" != "I UNDERSTAND" ]; then
    echo "Aborting."
    exit 1
fi

# 1. Create the server-side header directory
echo "[+] Creating detached header directory..."
sudo mkdir -p /etc/vault-headers
sudo chmod 700 /etc/vault-headers

# 2. Mount the CD/USB and generate the 512-byte raw key
echo "[+] Mounting $KEY_DRIVE and generating raw cryptographic key..."
sudo mkdir -p /media/vault-key-drive
sudo mount $KEY_DRIVE /media/vault-key-drive
sudo dd if=/dev/urandom of=/media/vault-key-drive/vault.key bs=512 count=1
sudo chmod 400 /media/vault-key-drive/vault.key

# 3. Format the drive with detached header and Argon2id (Paranoid Settings)
echo "[+] Formatting $TARGET_DRIVE with LUKS2 (Detached Header + 2GB RAM cost)..."
sudo cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha512 \
    --pbkdf argon2id \
    --pbkdf-memory 2097152 \
    --header /etc/vault-headers/vault.header \
    $TARGET_DRIVE /media/vault-key-drive/vault.key

# 4. Open and build the filesystem
echo "[+] Building Ext4 Filesystem..."
sudo cryptsetup luksOpen --header /etc/vault-headers/vault.header --key-file /media/vault-key-drive/vault.key $TARGET_DRIVE vault
sudo mkfs.ext4 /dev/mapper/vault
sudo mkdir -p /mnt/vault
sudo mount /dev/mapper/vault /mnt/vault
sudo chmod 777 /mnt/vault

# 5. Lock it down
sudo umount /mnt/vault
sudo cryptsetup luksClose vault
sudo umount /media/vault-key-drive
echo -e "\e[1;32m[✓] Vault Created Successfully. Remember to backup /etc/vault-headers/vault.header!\e[0m"
