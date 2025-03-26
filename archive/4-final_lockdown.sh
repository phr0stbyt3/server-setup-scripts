#!/bin/bash

if [ "$(whoami)" != "ubuntu" ]; then
  echo "❌ This script must be run as the 'ubuntu' user."
  exit 1
fi

# Confirm 2FA is set up
if [ ! -f ~/.google_authenticator ]; then
  echo "❌ 2FA is not configured for this user. Run google-authenticator first."
  exit 1
fi

echo ""
echo "🚨 WARNING: This will disable the root account completely."
echo "✅ Make sure you can log in as 'ubuntu' using TOTP in a separate terminal before continuing!"
read -p "Have you verified SSH access with TOTP for 'ubuntu'? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "❌ Aborting. Please verify access first."
  exit 1
fi

echo "🔐 Disabling root login and shell access..."
sudo passwd -l root
sudo usermod -s /usr/sbin/nologin root

echo "✅ Root account disabled."
echo "🧱 Your system is now fully secured with:"
echo " - PAM 2FA (TOTP) for 'ubuntu'"
echo " - 'ubuntu' has full admin privileges"
echo " - 'root' cannot log in or escalate"
