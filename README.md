# Air-Gapped Encrypted Vault

This repository contains the architecture and installation script for an industrial-grade, air-gapped LUKS2 encryption setup suitable for CasaOS, Docker, or any Linux server.

## How It Works (The 9.5 Paranoid Level)

The security architecture splits the encryption into two separate physical locations:

1. **The Lock (Server):** The LUKS header is detached from the drive and stored on the OS (default: `/etc/vault-headers/vault.header`). The data drive contains zero cryptographic signatures — it looks like dead noise to forensic tools.
2. **The Key (CD-ROM/USB):** A 512-byte raw decryption key is stored on external media.
3. **The Math:** The Argon2id hashing algorithm is configured to require 2GB of active RAM per guess, making brute-force attacks impractical.

Without the key drive inserted, the data drive cannot be mounted, and anything depending on it (e.g. Docker volumes) will see an empty mount point.

## Installation

Run:

```bash
sudo ./install.sh
```

The script will prompt for:
- The target data drive to encrypt (e.g. `/dev/sdb`)
- The key drive (e.g. `/dev/sr0` or a USB device)
- Where to store the detached header (default `/etc/vault-headers/vault.header`)
- Where to mount the vault once unlocked (default `/mnt/vault`)

**WARNING:** This script wipes the target data drive completely. Double-check the device path before confirming.

## Unlocking the Vault

After a reboot, the vault won't be mounted automatically. To unlock and mount it:

```bash
sudo cryptsetup luksOpen --header /etc/vault-headers/vault.header --key-file /path/to/vault.key /dev/sdX vault
sudo mount /dev/mapper/vault /mnt/vault
```

To lock it back up:

```bash
sudo umount /mnt/vault
sudo cryptsetup luksClose vault
```

## Migration: Moving to a New Server

If your hardware dies and you need to access your data on a different machine, you need **three** things:

1. The physical encrypted data drive.
2. The physical key drive containing `vault.key`.
3. A backup of the detached header file (`vault.header`).

To unlock on the new machine:

```bash
sudo cryptsetup luksOpen --header /path/to/vault.header --key-file /path/to/vault.key /dev/sdX vault
```

Then mount `/dev/mapper/vault` as usual.

## Backups

Without **both** the header file and the key file, the encrypted data is permanently unrecoverable — there is no password fallback. Keep copies of both in a separate, secure location from the server and the key drive.
