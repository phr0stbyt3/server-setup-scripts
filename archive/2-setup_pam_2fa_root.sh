#!/bin/bash

USERNAME="ubuntu"
SUDOERS_FILE="/etc/sudoers.d/${USERNAME}-nopass"
SSH_CONFIG="/etc/ssh/sshd_config"
PAM_SSHD_FILE="/etc/pam.d/sshd"

echo "🛠️ Starting PAM 2FA + root handoff prep..."

# 1. Ensure the user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "🚧 User '$USERNAME' does not exist. Creating it..."
    adduser "$USERNAME"
fi

# 2. Add to sudo group
echo "🔧 Adding '$USERNAME' to sudo group..."
usermod -aG sudo "$USERNAME"

# 3. Enable passwordless sudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | tee "$SUDOERS_FILE" > /dev/null
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" || { echo "❌ Invalid sudoers file!"; exit 1; }

# 4. Install PAM module
echo "🔐 Installing Google Authenticator PAM module..."
apt update && apt install libpam-google-authenticator -y

# 5. Configure PAM for SSH
echo "🔧 Enabling PAM in SSH config..."
if ! grep -q "pam_google_authenticator.so" "$PAM_SSHD_FILE"; then
    sed -i '1iauth required pam_google_authenticator.so' "$PAM_SSHD_FILE"
fi

# 6. Harden SSH
cp "$SSH_CONFIG" "$SSH_CONFIG.bak.$(date +%F-%H%M%S)"
sed -i 's/^#\?\s*PermitRootLogin .*/PermitRootLogin no/' "$SSH_CONFIG"
sed -i 's/^#\?\s*PasswordAuthentication .*/PasswordAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^#\?\s*UsePAM .*/UsePAM yes/' "$SSH_CONFIG"

if ! grep -q "^AllowUsers $USERNAME" "$SSH_CONFIG"; then
    echo "AllowUsers $USERNAME" >> "$SSH_CONFIG"
fi

echo "🔄 Reloading SSH..."
systemctl reload sshd

echo ""
echo "✅ PAM 2FA setup complete for SSH."
echo "➡️  Now log in as '$USERNAME' and run:"
echo "     google-authenticator"
echo ""
echo "🚨 Do not lock or disable root until you confirm TOTP login works!"
