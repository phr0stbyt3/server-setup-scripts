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

# ─── 1. Create Cardano User ────────────────────────────────
if id "$CARDANO_USER" &>/dev/null; then
  echo "✅ User '$CARDANO_USER' already exists."
else
  echo "👤 Creating user '$CARDANO_USER'..."
  sudo adduser --disabled-password --gecos "" $CARDANO_USER
  echo "🔑 Please set a password for the '$CARDANO_USER' user:"
  sudo passwd $CARDANO_USER
fi

# ─── 2. Install Dependencies ───────────────────

echo "📦 Installing required packages..."
sudo apt-get update -qq && sudo apt-get install -y curl jq wget git unzip libpq-dev libpam-google-authenticator

# ─── 3. Configure 2FA for Cardano User ──────────────────

echo "🔐 Installing and configuring 2FA for '$CARDANO_USER'..."
echo "📲 Launching Google Authenticator setup for '$CARDANO_USER' (interactive)..."
sudo -u $CARDANO_USER google-authenticator

# Update SSHD for 2FA
echo "⚙️  Updating SSHD configuration for 2FA..."
PAM_LINE='auth required pam_google_authenticator.so'
if ! grep -q "$PAM_LINE" /etc/pam.d/sshd; then
  echo "$PAM_LINE" | sudo tee -a /etc/pam.d/sshd
fi

sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "✅ 2FA for 'cardano' configured."

# ─── 4. Download and Install Cardano Binaries ─────────────────

echo "🔽 Downloading Cardano binaries..."
sudo -u $CARDANO_USER mkdir -p $BIN_DIR
cd $BIN_DIR

wget -q $REPO_URL/cardano-node-$CARDANO_VERSION-linux.tar.gz
wget -q $REPO_URL/cardano-cli-$CARDANO_VERSION-linux.tar.gz

tar -xzf cardano-node-$CARDANO_VERSION-linux.tar.gz
tar -xzf cardano-cli-$CARDANO_VERSION-linux.tar.gz
chmod +x cardano-node cardano-cli

# ─── 5. Fetch Latest Configuration Files ────────────────

echo "📁 Fetching Cardano configuration files..."
sudo -u $CARDANO_USER mkdir -p $CONFIG_DIR
cd $CONFIG_DIR
wget -q https://book.world.dev.cardano.org/environments/mainnet/config.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/topology.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/byron-genesis.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/shelley-genesis.json
wget -q https://book.world.dev.cardano.org/environments/mainnet/alonzo-genesis.json

# ─── 6. Set Up Systemd Service ─────────────────────

echo "⚙️  Setting up systemd service for Cardano Node..."
cat <<EOF | sudo tee $SYSTEMD_SERVICE
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

sudo systemctl daemon-reload
sudo systemctl enable cardano-node

# ─── 7. Create Log and Scripts Directories ────────────────

echo "📂 Creating logs and scripts directories..."
sudo -u $CARDANO_USER mkdir -p $LOG_DIR $SCRIPTS_DIR

# ─── 8. Set Up Bash Aliases ───────────────

echo "📜 Setting up custom bash aliases..."
cat <<EOF | sudo -u $CARDANO_USER tee $ALIASES_FILE
# Custom Cardano Node Commands
alias node-sync='cardano-cli query tip --mainnet'
alias node-status='systemctl status cardano-node'
alias node-logs='journalctl -u cardano-node -f'
alias node-logs-recent='journalctl -u cardano-node --no-pager -n 100'
EOF

echo "✅ Relay provisioning complete. Reboot and check node status."

exit 0
