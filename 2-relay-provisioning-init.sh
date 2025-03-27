#!/bin/bash

# relay-provisioning-init.sh

# 🚧 Relay Provisioning Script
# This script sets up the Cardano relay node and provisions the 'cardano' user.
# It installs dependencies, downloads precompiled binaries, fetches config files,
# installs systemd services, sets up aliases, and enables 2FA for security.

set -euo pipefail

CARDANO_USER="cardano"
CARDANO_HOME="/home/$CARDANO_USER/cardano"
BIN_DIR="$CARDANO_HOME/bin"
CONFIG_DIR="$CARDANO_HOME/config"
DB_DIR="$CARDANO_HOME/db"
LOG_DIR="$CARDANO_HOME/logs"
SCRIPTS_DIR="$CARDANO_HOME/scripts"
ALIASES_FILE="/home/$CARDANO_USER/.bash_cardano_aliases"
SYSTEMD_SERVICE="/etc/systemd/system/cardano-node.service"
CARDANO_VERSION="10.2.1"
REPO_URL="https://github.com/IntersectMBO/cardano-node/releases/download/$CARDANO_VERSION"

echo "🚀 Starting Cardano relay provisioning..."

# ─── 1. Create Cardano User ──────────────────────────────
if id "$CARDANO_USER" &>/dev/null; then
  echo "✅ User '$CARDANO_USER' already exists."
else
  echo "👤 Creating user '$CARDANO_USER'..."
  sudo adduser --disabled-password --gecos "" $CARDANO_USER
  echo "🔑 Please set a password for the '$CARDANO_USER' user:"
  sudo passwd $CARDANO_USER
fi

# ─── 2. Install Dependencies ────────────────

echo "📦 Installing required packages..."
sudo apt-get update -qq && sudo apt-get install -y curl jq wget git unzip libpq-dev libpam-google-authenticator

# ─── 3. Enable 2FA for Cardano User ──────────────

# (Commented out since 2FA has already been configured)
# echo "🔐 Enabling 2FA for '$CARDANO_USER'..."
# sudo -u $CARDANO_USER bash -c 'google-authenticator -t -d -f -r 3 -R 30 -W'
# if ! grep -q "auth required pam_google_authenticator.so" /etc/pam.d/sshd; then
#   echo "auth required pam_google_authenticator.so nullok" | sudo tee -a /etc/pam.d/sshd
# fi
# sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
# sudo systemctl restart sshd

# ─── 4. Download and Install Cardano Binaries ──────────────────────

echo "🗜️ Downloading and extracting Cardano binaries..."
sudo -u $CARDANO_USER mkdir -p $BIN_DIR
cd $BIN_DIR

BINARY_TAR="cardano-node-$CARDANO_VERSION-linux.tar.gz"
wget -qO $BINARY_TAR $REPO_URL/$BINARY_TAR || {
  echo "❌ Failed to download cardano-node binary."; exit 1;
}

TEMP_DIR=$(mktemp -d)
tar -xzf $BINARY_TAR -C $TEMP_DIR || {
  echo "❌ Failed to extract cardano-node binaries."; exit 1;
}

cp "$TEMP_DIR/bin/cardano-node" "$BIN_DIR"
cp "$TEMP_DIR/bin/cardano-cli" "$BIN_DIR"
chmod +x "$BIN_DIR/cardano-node" "$BIN_DIR/cardano-cli"
rm -rf "$TEMP_DIR" "$BINARY_TAR"

# ─── 5. Fetch Latest Configuration Files ──────────────

echo "📁 Fetching Cardano configuration files..."
sudo -u $CARDANO_USER mkdir -p $CONFIG_DIR
cd $CONFIG_DIR

wget -q https://book.world.dev.cardano.org/environments/mainnet/config.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/topology.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/byron-genesis.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/shelley-genesis.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/alonzo-genesis.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/conway-genesis.json

# ─── 6. Set Up Systemd Service ───────────────────

echo "⚙️  Setting up systemd service for Cardano Node..."
cat <<EOF | sudo tee $SYSTEMD_SERVICE >/dev/null
[Unit]
Description=Cardano Node
After=network.target

[Service]
User=$CARDANO_USER
ExecStart=$BIN_DIR/cardano-node run \
  --topology $CONFIG_DIR/topology.json \
  --database-path $DB_DIR \
  --socket-path $DB_DIR/node.socket \
  --host-addr 0.0.0.0 \
  --port 3001 \
  --config $CONFIG_DIR/config.json
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable cardano-node

# ─── 7. Create Log and Scripts Directories ───────────────

echo "📂 Creating logs and scripts directories..."
sudo -u $CARDANO_USER mkdir -p $LOG_DIR $SCRIPTS_DIR $DB_DIR

# ─── 8. Set Up Bash Aliases ──────────────

echo "📜 Setting up custom bash aliases..."
cat <<EOF | sudo tee -a $ALIASES_FILE >/dev/null
# Custom Cardano Node Commands

# Check node sync progress
alias node-sync='cardano-cli query tip --mainnet'

# Check if systemd service is running
alias node-status='systemctl status cardano-node'

# View live logs of the node
alias node-logs='journalctl -u cardano-node -f'

# View last 100 lines of logs
alias node-logs-recent='journalctl -u cardano-node --no-pager -n 100'

# Restart Cardano node
node-restart() {
    read -p "Are you sure you want to RESTART the Cardano node? (yes/no): " confirm
    if [[ "\$confirm" == "yes" ]]; then
        systemctl restart cardano-node
        echo "🔄 Cardano node is restarting..."
    else
        echo "❌ Operation canceled."
    fi
}

# Stop Cardano node
node-stop() {
    read -p "Are you sure you want to STOP the Cardano node? (yes/no): " confirm
    if [[ "\$confirm" == "yes" ]]; then
        systemctl stop cardano-node
        echo "✅ Cardano node has been stopped."
    else
        echo "❌ Operation canceled."
    fi
}

# Start Cardano node
alias node-start='systemctl start cardano-node'

# Node diagnostic utility
node-diag() {
    echo "🩺 Cardano Relay Diagnostic Script"
    echo "----------------------------------"
    echo ""
    echo "🔍 Checking if cardano-node is running..."
    if pgrep -x "cardano-node" > /dev/null; then
        echo "✅ cardano-node process is running."
    else
        echo "❌ cardano-node process is NOT running."
    fi
    echo ""
    echo "🔍 Checking systemd service: cardano-node"
    systemctl status cardano-node --no-pager | head -20
    echo ""
    echo "🔍 Checking for node socket at:"
    echo "\$CARDANO_HOME/db/node.socket"
    if [ -S "\$CARDANO_HOME/db/node.socket" ]; then
        echo "✅ Socket file exists."
    else
        echo "❌ Socket file not found. Either node hasn't finished booting or path is wrong."
    fi
    echo ""
    echo "🔍 Checking if port 3001 is bound..."
    if sudo ss -tuln | grep -q ':3001'; then
        echo "✅ Port 3001 is open and accepting connections."
    else
        echo "❌ Port 3001 is NOT open. Relay may not be accepting connections."
    fi
    echo ""
    echo "🔍 Checking CARDANO_NODE_SOCKET_PATH environment variable..."
    echo "CARDANO_NODE_SOCKET_PATH=\$CARDANO_NODE_SOCKET_PATH"
    echo ""
    echo "✅ Diagnostic complete."
}

export -f node-restart
export -f node-stop
export -f node-diag
EOF

echo "✅ Relay provisioning complete. Reboot and check node status."

exit 0
