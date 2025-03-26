#!/bin/bash

set -e

echo "🔧 Starting relay provisioning..."
LOG_DIR="/home/cardano/cardano/logs"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/provisioning.log") 2>&1

# Step 1: Create cardano user with no password but 2FA enforced
if id "cardano" &>/dev/null; then
    echo "✅ User 'cardano' already exists. Skipping creation."
else
    echo "👤 Creating user 'cardano'..."
    useradd -m -s /bin/bash -G sudo cardano
    passwd -d cardano
    echo "cardano ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-cardano
fi

# Step 2: Install Google Authenticator for 2FA
echo "🔐 Installing 2FA for 'cardano'..."
apt-get update && apt-get install -y libpam-google-authenticator

# Step 3: Run the google-authenticator setup for the cardano user (non-interactive setup)
su - cardano -c "
    yes y | google-authenticator -t -d -f -r 3 -R 30 -W -Q UTF8 -e 10
"

# Step 4: Update PAM to require 2FA for cardano user
echo "📦 Updating PAM config for 2FA..."
PAM_LINE='auth required pam_google_authenticator.so nullok'
if ! grep -Fxq "$PAM_LINE" /etc/pam.d/sshd; then
    echo "$PAM_LINE" >> /etc/pam.d/sshd
fi

# Step 5: Enable ChallengeResponseAuthentication
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config

# Step 6: Restart SSH
echo "🔁 Restarting SSH service..."
systemctl restart ssh

# Step 7: Set up relay folder structure
echo "📁 Preparing Cardano directories..."
su - cardano -c "mkdir -p ~/cardano/{bin,config,db,logs,scripts}"

echo "✅ Relay provisioning complete."
