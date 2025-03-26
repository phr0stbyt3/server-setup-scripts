#!/bin/bash
# oobe-init.sh - First login configuration wizard for Cardano Relay

set -e

OOBE_STATE_FILE="$HOME/.oobe-configured"
LOGO="\n🚀 Cardano Relay OOBE - First Time Setup\n--------------------------------------\n"

if [ -f "$OOBE_STATE_FILE" ]; then
  echo -e "$LOGO"
  echo "🔁 OOBE already completed. You may re-run this wizard manually anytime:"
  echo "  ~/cardano/scripts/oobe-init.sh"
  exit 0
fi

# Step 1 - Greet
clear
echo -e "$LOGO"
echo "Welcome! This script will help configure your relay node."
echo "You can re-run this at any time: ~/cardano/scripts/oobe-init.sh"
echo
read -p "Press Enter to continue..."

# Step 2 - Describe Relay Type
echo -e "\n🔍 Select relay type:"
select RELAY_TYPE in "Private Relay (default)" "Public Relay"; do
  case $REPLY in
    1) RELAY_MODE="private"; break;;
    2) RELAY_MODE="public"; break;;
    *) echo "Defaulting to Private."; RELAY_MODE="private"; break;;
  esac
done

# Step 3 - Ask Block Producer IP
echo -e "\n🧠 Enter your Block Producer's public IP (use 192.0.2.1 as placeholder):"
read -rp "Block Producer IP: " BP_IP
BP_IP=${BP_IP:-192.0.2.1}

# Step 4 - Build topology.json
echo -e "\n📦 Generating new topology.json for P2P..."
TOPOLOGY_PATH="$HOME/cardano/config/topology.json"

cat > "$TOPOLOGY_PATH" <<EOF
{
  "localRoots": [
    {
      "accessPoints": [
        {
          "address": "$BP_IP",
          "port": 6000
        }
      ],
      "advertise": $( [[ "$RELAY_MODE" == "public" ]] && echo true || echo false ),
      "valency": 1,
      "trustable": false
    }
  ],
  "publicRoots": [],
  "useLedgerAfterSlot": 128908821
}
EOF

# Step 5 - Restart node
echo -e "\n🔄 Restarting cardano-node service..."
sudo systemctl restart cardano-node

# Step 6 - Confirm
echo "✅ Updated topology.json and restarted node."
echo "You selected: $RELAY_MODE relay, with BP IP: $BP_IP"

# Save OOBE complete marker
touch "$OOBE_STATE_FILE"
echo "📁 OOBE complete. This wizard won't run again unless manually invoked."
echo "Run: ~/cardano/scripts/oobe-init.sh to reconfigure."
exit 0
