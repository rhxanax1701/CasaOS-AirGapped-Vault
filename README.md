# Air-Gapped CasaOS Vault 

This repository contains the architecture and installation script for an industrial-grade, air-gapped LUKS2 encryption setup designed for CasaOS and Docker environments.

## How It Works (The 9.5 Paranoid Level)
The security architecture splits the encryption into two separate physical locations:
1. **The Lock (Server):** The LUKS header is detached from the drive and stored on the OS at `/etc/vault-headers/vault.header`. The data drive (`/dev/sdb`) contains zero cryptographic signatures. It looks like dead cosmic noise to forensic tools.
2. **The Key (CD-ROM/USB):** The 512-byte raw decryption key is stored on external media. 
3. **The Math:** The Argon2id hashing algorithm is configured to require 2GB of active RAM per guess, rendering brute-force attacks mathematically bankrupt.

Without the CD inserted into the server, the drive cannot be mounted, and linked Docker containers (like Gitea) will read an empty folder.

## Migration: Moving to a New Server
If your server hardware dies and you need to access your data on a completely different Linux machine, you need **three** things:
1. The physical encrypted hard drive (`/dev/sdb`).
2. The physical CD/USB containing `vault.key`.
3. A backup of the `/etc/vault-headers/vault.header` file from your old server.

**To unlock on the new machine:**
Copy the header to the new server, insert the key drive, plug in the hard drive, and run:
`cryptsetup luksOpen --header /path/to/vault.header --key-file /path/to/vault.key /dev/sdX vault`

## Installation
Run `sudo ./install.sh`. 
**WARNING:** This script wipes the target data drive completely. Use with extreme caution.
