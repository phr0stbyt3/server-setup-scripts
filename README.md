# secure-server-init.sh

This script is the **first step** in preparing a secure Ubuntu server for hosting Cardano relay nodes. It consolidates multiple hardening actions into one automated run.

---

## 🔐 What It Does

1. Creates a non-root `ubuntu` user with passwordless sudo
2. Prompts for a secure password during user creation
3. Installs and configures Google Authenticator 2FA for both `root` and `ubuntu`
4. Hardens SSH and PAM authentication
5. Enables UFW firewall and Fail2Ban
6. Locks out password login for root

---

## 🧰 Requirements
- A clean Ubuntu server
- Root access via SSH
- Internet connection for installing packages

---

## 🚀 Initial Setup

After provisioning your VPS, SSH in as `root` and run:

```bash
apt update && apt upgrade
apt install git
git clone https://github.com/phr0stbyt3/server-setup-scripts.git
cd server-setup-scripts
chmod +x secure-server-init.sh
sudo ./secure-server-init.sh
```

> ⚠️ You will be prompted to enter a secure password for the `ubuntu` user.
> Once the script completes, reconnect via SSH as `ubuntu` (2FA enabled).

---

## 🛡️ Why This Script?

Before configuring the Cardano node, we must:
- Remove root SSH access
- Require 2FA login to prevent brute-force attacks
- Prepare a hardened, sudo-enabled user for provisioning the relay

This is step **1 of 2**.

- ✅ Step 1: `secure-server-init.sh` (security hardening)
- 🧱 Step 2: `relay-provisioning-init.sh` (Cardano node setup)

---

## 🔄 Next Steps

Once this script completes:

1. Log in as the `ubuntu` user
2. Clone the repo again if needed:
   ```bash
   git clone https://github.com/phr0stbyt3/server-setup-scripts.git
   ```
3. Run the second script:
   ```bash
   chmod +x relay-provisioning-init.sh
   sudo ./relay-provisioning-init.sh
   ```

---

## ✍️ Notes
- 2FA is enabled with default settings
- UFW allows only OpenSSH by default
- You can further customize PAM or SSHD options after setup

---

## 📂 File Structure

```
server-setup-scripts/
├── secure-server-init.sh       # This script (run first)
├── relay-provisioning-init.sh  # Run second as ubuntu
```

---

## ✅ Success Message

You’ll see:
```
✅ Server hardening complete. You can now SSH as 'ubuntu' with 2FA enabled.
```

When that shows up — you're ready to provision your Cardano node.
