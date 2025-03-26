#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────
# 💡 Cardano Relay Provisioning Script
# ─────────────────────────────────────────────────────────────

CARDANO_USER="cardano"
CARDANO_HOME="/home/$CARDANO_USER/cardano"
BIN_DIR="$CARDANO_HOME/bin"
CONFIG_DIR="$CARDANO_HOME/config"
DB_DIR="$CARDANO_HOME/db"
LOG_DIR="$CARDANO_HOME/logs"
SCRIPTS_DIR="$CARDANO_HOME/scripts"
ALIASES_FILE="/home/$CARDANO_USER/.bash_cardano_aliases"
SYSTEMD_SERVICE="/etc/systemd/system/cardano-node.service"

echo "🔧 Starting Cardano relay provisioning..."

# ─── 1. Create Cardano User ──────────────────────────────────
if ! id "$CARDANO_USER" &>/dev/null; then
  echo "👤 Creating '$CARDANO_USER' user..."
  useradd -m -s /bin/bash -G sudo "$CARDANO_USER"
  passwd -d "$CARDANO_USER"
  echo "$CARDANO_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-cardano
else
  echo "✅ User '$CARDANO_USER' already exists."
fi

# ─── 2. Install 2FA ──────────────────────────────────────────
echo "🔐 Installing 2FA (Google Authenticator)..."
apt-get update -qq && apt-get install -y libpam-google-authenticator

su - "$CARDANO_USER" -c "
  yes y | google-authenticator -t -d -f -r 3 -R 30 -W -Q UTF8 -e 10
"

if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
  echo "auth required pam_google_authenticator.so nullok" >> /etc/pam.d/sshd
fi
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# ─── 3. Create Folder Structure ──────────────────────────────
echo "📁 Creating directory structure..."
runuser -l "$CARDANO_USER" -c "mkdir -p $BIN_DIR $CONFIG_DIR $DB_DIR $LOG_DIR $SCRIPTS_DIR"

# ─── 4. Download Latest Cardano Binaries ─────────────────────
echo "⬇️  Downloading latest Cardano binaries..."
LATEST_URL=$(curl -s https://api.github.com/repos/IntersectMBO/cardano-node/releases/latest \
  | grep browser_download_url \
  | grep 'linux.*64.*tar.gz' \
  | cut -d '"' -f 4)

FILENAME=$(basename "$LATEST_URL")

runuser -l "$CARDANO_USER" -c "
  curl -L $LATEST_URL -o ~/cardano/$FILENAME &&
  tar -xzf ~/cardano/$FILENAME -C $BIN_DIR &&
  rm ~/cardano/$FILENAME
"

# ─── 5. Download Mainnet Config Files ────────────────────────
echo "📦 Fetching mainnet config files..."
CONFIG_BASE="https://book.world.dev.cardano.org/environments/mainnet"
CONFIG_FILES=(config.json topology.json alonzo-genesis.json byron-genesis.json shelley-genesis.json conway-genesis.json)

for file in "${CONFIG_FILES[@]}"; do
  curl -sL "$CONFIG_BASE/$file" -o "$CONFIG_DIR/$file"
done

# ─── 6. Setup Systemd Service ────────────────────────────────
echo "⚙️  Installing systemd service..."
cat <<EOF > "$SYSTEMD_SERVICE"
[Unit]
Description=Cardano Node
After=network.target

[Service]
User=$CARDANO_USER
ExecStart=$BIN_DIR/cardano-node run \\
  --topology $CONFIG_DIR/topology.json \\
  --database-path $DB_DIR \\
  --socket-path $DB_DIR/node.socket \\
  --host-addr 0.0.0.0 \\
  --port 3001 \\
  --config $CONFIG_DIR/config.json
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable cardano-node
systemctl restart cardano-node

# ─── 7. Register Aliases ─────────────────────────────────────
echo "📚 Adding helpful CLI aliases..."
cat <<'EOF' > "$ALIASES_FILE"
# Custom Cardano Node Aliases
alias node-sync='cardano-cli query tip --mainnet'
alias node-status='systemctl status cardano-node'
alias node-logs='journalctl -u cardano-node -f'
alias node-logs-recent='journalctl -u cardano-node --no-pager -n 100'
alias node-start='sudo systemctl start cardano-node'
alias node-stop='sudo systemctl stop cardano-node'
node-restart() {
    read -p "Are you sure you want to RESTART the Cardano node? (yes/no): " confirm
    [[ "$confirm" == "yes" ]] && sudo systemctl restart cardano-node
}
export -f node-restart
EOF

echo "source ~/.bash_cardano_aliases" >> "/home/$CARDANO_USER/.bashrc"
chown "$CARDANO_USER":"$CARDANO_USER" "$ALIASES_FILE"

# ─── 8. Final Message ────────────────────────────────────────
echo "✅ Provisioning complete! Login as '$CARDANO_USER' and run: oobe-init.sh"
