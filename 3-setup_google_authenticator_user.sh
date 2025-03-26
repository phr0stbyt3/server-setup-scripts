#!/bin/bash

if [ "$(whoami)" != "ubuntu" ]; then
  echo "❌ This script must be run as the 'ubuntu' user."
  exit 1
fi

echo "📱 Starting 2FA setup using google-authenticator..."
echo "Scan the QR code with Google Authenticator, Authy, 1Password, etc."

google-authenticator

if [ -f ~/.google_authenticator ]; then
    echo "✅ 2FA setup complete."
else
    echo "❌ Failed to create ~/.google_authenticator. Try again."
    exit 1
fi

echo "📌 Now open a new terminal and test SSH login as 'ubuntu'."
echo "You should be prompted for password + verification code."
echo "✅ Once verified, it's safe to disable root completely."
