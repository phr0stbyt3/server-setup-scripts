#!/bin/bash
# secure-server-init.sh
# Combines initial server hardening tasks into one streamlined script

set -e

echo "🔒 Beginning secure server initialization..."

# ─── 1. Create hardened user ─────────────────────────────────────
NEW_USER="ubuntu"

if id "$NEW_USER" &>/dev/null; then
  echo "✅ User '$NEW_USER' already exists."
else
  echo "👤 Creating hardened user '$NEW_USER'..."
  useradd -m -s /bin/bash -G sudo "$NEW_USER"
  passwd -d "$NEW_USER"
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$NEW_USER
fi

# ─── 2. Setup Google Authenticator for root and new user ────────
echo "🔐 Installing 2FA dependencies..."
apt-get update -qq && apt-get install -y libpam-google-authenticator ufw fail2ban

for user in root "$NEW_USER"; do
  echo "🔐 Enabling 2FA for $user..."
  su - "$user" -c "yes y | google-authenticator -t -d -f -r 3 -R 30 -W -Q UTF8 -e 10"
done

# ─── 3. Configure PAM + SSH ─────────────────────────────────────
echo "⚙️  Configuring PAM and SSHD..."
PAM_LINE='auth required pam_google_authenticator.so nullok'
if ! grep -q "$PAM_LINE" /etc/pam.d/sshd; then
  echo "$PAM_LINE" >> /etc/pam.d/sshd
fi

sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

systemctl restart ssh

# ─── 4. Configure Firewall ──────────────────────────────────────
echo "🛡️  Configuring UFW firewall..."
ufw allow OpenSSH
ufw --force enable

# ─── 5. Configure Fail2Ban ──────────────────────────────────────
echo "🔒 Enabling fail2ban..."
systemctl enable --now fail2ban

# ─── 6. Disable root password ───────────────────────────────────
echo "🔒 Disabling root password..."
passwd -l root

# ─── 7. Final Status ────────────────────────────────────────────
echo "✅ Server hardening complete. You can now SSH as '$NEW_USER' with 2FA enabled."
