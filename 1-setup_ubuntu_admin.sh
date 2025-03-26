#!/bin/bash

USERNAME="ubuntu"
SUDOERS_FILE="/etc/sudoers.d/${USERNAME}-nopass"

echo "👤 Creating and configuring admin user '$USERNAME'..."

# Create user if it doesn't exist
if ! id "$USERNAME" &>/dev/null; then
    adduser "$USERNAME"
fi

# Add to sudo group
usermod -aG sudo "$USERNAME"

# Grant passwordless sudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | tee "$SUDOERS_FILE" > /dev/null
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" || { echo "❌ Invalid sudoers file!"; exit 1; }

echo "✅ '$USERNAME' is now a root-equivalent user with no-password sudo."
