# Cardano Relay Node Provisioning Runbook (Precompiled Binaries Method)

# 1. Introduction

## 1.1 Installation Flow Overview

This guide follows a structured user flow to ensure **security and best practices** for provisioning a Cardano relay node. The process is divided into three user roles:

1. **Root User (Cloud Install Only – optional if your environment already has a default non-root user)**

   - Used **only** to create the `ubuntu` user and set its password.
   - Disables root login for security.
   - Transfers control to the `ubuntu` user.

2. **Ubuntu User (Installer)**

   - Used to create the `cardano` service account.
   - Performs **all remaining installation steps** under the `cardano` user.

3. **Cardano User (Service Account)**

   - Runs the Cardano node and executes management commands.
   - Has **restricted sudo privileges**, limited only to post-installation node management.
   - Uses **predefined aliases** to check and control node status without requiring `sudo`.

This structure ensures that **no unnecessary privileges** are granted, reducing security risks while maintaining full control over the relay node.

This document provides a step-by-step guide to provisioning a secure, pre-built Cardano relay node using **precompiled binaries** instead of compiling from source. This method enables faster setup and ensures stability by using official release builds.

---

## 2. System Preparation

This guide applies to both **cloud** and **on-prem** installations. Follow the appropriate steps based on your environment.

### 2.1 Set Hostname for Relay Node

To properly identify the relay node, set a meaningful hostname that follows a structured naming convention, ensuring differentiation for multiple relays or blockchain networks.

#### Strict Naming Convention

All relay nodes must follow the format `<blockchain>-relay-<number>` to ensure consistency across different blockchains and multiple nodes within the same network.

**Examples:**

- `cardano-relay-01`, `cardano-relay-02` (for redundancy within Cardano)
- `solana-relay-01`, `solana-relay-02`
- `polkadot-relay-01`, `polkadot-relay-02`

This ensures a standardized naming approach across various networks.

1. **Check the current hostname:**
   ```bash
   hostnamectl
   ```
2. **Set a new hostname**
   - **For cloud (as root):**
     ```bash
     hostnamectl set-hostname cardano-relay-01
     ```
   - **For on-prem (non-root):**
     ```bash
     sudo hostnamectl set-hostname cardano-relay-01
     ```
3. **Update the \`\` file (Same for cloud & on-prem):**
   ```bash
   sudo nano /etc/hosts
   ```
   Locate the line with your old hostname and update it to match the new hostname.
4. **Reboot the system to apply changes**
   - **For cloud (as root):**
     ```bash
     reboot
     ```
   - **For on-prem (non-root):**
     ```bash
     sudo reboot
     ```

### 2.2 Set Up Installer Account Password

If you’re using a cloud environment (like AWS, GCP, or Azure), the image often comes with an `ubuntu` user (or a similarly named user) already created. If so, set a strong password for that user to proceed with the initial setup. If you do **not** have an `ubuntu` user, create one with:

```
sudo useradd -m -s /bin/bash ubuntu
sudo passwd ubuntu
```

Or substitute your preferred username in all steps.  The `-m` flag creates a home directory, and `-s /bin/bash` sets the default shell to Bash.

- **For cloud (as root)**:
  ```bash
  passwd ubuntu
  ```

If your on-prem server doesn’t already have an `ubuntu` user, you can either create one or simply adapt these steps to your existing non-root account. For instance:

- **On-prem (non-root)**:
  ```bash
  sudo passwd ubuntu
  ```

### 2.3 Create a Dedicated Service Account

Create a non-root service account for running the Cardano node. By default, we’ll create this user with a home directory, a Bash shell, and **no local password** (which you can optionally set). This approach is similar to creating the `ubuntu` user, but with the username `cardano`.

- **For cloud (as root):**
  ```bash
  useradd -m -s /bin/bash cardano
  usermod -aG sudo cardano
  # Remove any local password if you want no login prompt:
  passwd -d cardano
  ```
- **For on-prem (non-root):**
  ```bash
  sudo useradd -m -s /bin/bash cardano
  sudo usermod -aG sudo cardano
  # Remove any local password if you want no login prompt:
  sudo passwd -d cardano
  ```

If you prefer a password-protected account, simply omit the `passwd -d` step and run `sudo passwd cardano` instead.

Switch to the `cardano` user:

```bash
su - cardano
```

**(Optional) Grant Temporary Passwordless Sudo for Installation**

If you need to run setup commands that require `sudo` while logged in as `cardano`, you can grant temporary NOPASSWD privileges:

```bash
sudo visudo
```

Add a line like at the end of the file:

```
cardano ALL=(ALL) NOPASSWD:ALL
```

Save and exit. Now `cardano` can run any sudo command without a password. **Use with caution**, and remove or restrict it after finishing installation, to the minimal privileges described in [Section 7.5](#75-restrict-sudo-access-for-node-operations).

---

## 3. Download and Install Precompiled Binaries

### 3.1 Download Release

```bash
cd ~
wget https://github.com/IntersectMBO/cardano-node/releases/download/10.1.4/cardano-node-10.1.4-linux.tar.gz
```

### 3.2 Extract and Install

```bash
tar -xvf cardano-node-10.1.4-linux.tar.gz
mv cardano-node-10.1.4-linux/bin/* ~/.local/bin/
chmod +x ~/.local/bin/cardano-node ~/.local/bin/cardano-cli
```

---

## 4. Configuring the Node

### 4.1 Create the Configuration Directory

```bash
mkdir -p ~/cardano-config && cd ~/cardano-config
```

### 4.2 Download Required Configuration Files

```bash
wget -N https://book.world.dev.cardano.org/environments/mainnet/config.json
wget -N https://book.world.dev.cardano.org/environments/mainnet/topology.json
wget -N https://book.world.dev.cardano.org/environments/mainnet/byron-genesis.json
wget -N https://book.world.dev.cardano.org/environments/mainnet/shelley-genesis.json
wget -N https://book.world.dev.cardano.org/environments/mainnet/alonzo-genesis.json
wget -N https://book.world.dev.cardano.org/environments/mainnet/conway-genesis.json
```

Ensure all files are present before proceeding:

```bash
ls -l ~/cardano-config/
```

### 4.3 Set Environment Variables

```bash
echo 'export CARDANO_NODE_SOCKET_PATH="$HOME/cardano-db/node.socket"' >> ~/.bashrc
source ~/.bashrc
```

---

## 5. Automating Startup with systemd

Create a service file:

```bash
sudo nano /etc/systemd/system/cardano-node.service
```

**Note**: If you’d like to keep logs in a dedicated directory, you can add flags (e.g., `--log-file /var/log/cardano/node.log`) if supported by the cardano-node version. You might also reference a version variable or environment variable for the node path to simplify upgrades.

Paste the following:

```ini
[Unit]
Description=Cardano Node
After=network.target

[Service]
User=cardano
# If you wish to define the node path or version as an environment variable, uncomment the next line
# Environment="NODE_PATH=/home/cardano/.local/bin"
ExecStart=/home/cardano/.local/bin/cardano-node run \
  --topology /home/cardano/cardano-config/topology.json \
  --database-path /home/cardano/cardano-db \
  --socket-path /home/cardano/cardano-db/node.socket \
  --host-addr 0.0.0.0 \
  --port 3001 \
  --config /home/cardano/cardano-config/config.json
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable cardano-node
sudo systemctl start cardano-node
```

---

## 6. Custom Aliases for Node Management

To streamline command execution, **create a file named** `~/.bash_cardano_aliases` **and add the following aliases**:

```bash
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
    if [[ "$confirm" == "yes" ]]; then
        systemctl restart cardano-node
        echo "🔄 Cardano node is restarting..."
    else
        echo "❌ Operation canceled."
    fi
}

# Stop Cardano node
node-stop() {
    read -p "Are you sure you want to STOP the Cardano node? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        systemctl stop cardano-node
        echo "✅ Cardano node has been stopped."
    else
        echo "❌ Operation canceled."
    fi
}

# Start Cardano node
alias node-start='systemctl start cardano-node'

# Reload functions immediately
export -f node-stop
export -f node-restart
```

To load these aliases, **add the following** to `~/.bashrc`:

```bash
if [ -f ~/.bash_cardano_aliases ]; then
    . ~/.bash_cardano_aliases
fi
```

Then apply changes:

```bash
source ~/.bashrc
```

---

## 7. Security Best Practices

Before proceeding with additional security steps, ensure that the basic node installation is finished. **We also recommend locking down SSH and configuring your firewall** at this stage.

### 7.1 Secure SSH Access & Firewall Configuration

**Initial SSH Access**

If you used password authentication for `ubuntu` or `cardano` during installation, you should now disable it and switch to key-based authentication only.

1. **Disable root login via SSH (if still enabled):**

   ```bash
   sudo nano /etc/ssh/sshd_config
   ```

   Find the line:

   ```bash
   PermitRootLogin yes
   ```

   Change it to:

   ```bash
   PermitRootLogin no
   ```

2. **Disable password auth for ubuntu (post-install):**

   ```bash
   sudo nano /etc/ssh/sshd_config
   ```

   Locate:

   ```bash
   PasswordAuthentication yes
   ```

   Change it to:

   ```bash
   PasswordAuthentication no
   ```

   Save and exit, then:

   ```bash
   sudo systemctl restart ssh
   ```

3. **Ensure Only ****\`\`**** can use SSH with password** if desired:

   - The `cardano` user remains available for limited node management.
   - The `ubuntu` user can only be accessed via SSH keys for higher security.

4. **Firewall Configuration**

   - **Allow SSH and Cardano Node traffic:**
     ```bash
     sudo ufw allow 22/tcp
     sudo ufw allow 3001/tcp
     ```
   - **Enable UFW:**
     ```bash
     sudo ufw enable
     ```
   - **Verify firewall status:**
     ```bash
     sudo ufw status verbose
     ```

### 7.2 Enable Automatic Security Updates

1. **Install unattended-upgrades:**
   ```bash
   sudo apt install unattended-upgrades
   ```
2. **Enable auto-updates:**
   ```bash
   sudo dpkg-reconfigure --priority=low unattended-upgrades
   ```

### 7.3 Monitor Logs for Security Issues

1. **Check SSH login attempts:**
   ```bash
   sudo journalctl -u ssh --no-pager | tail -20
   ```
2. **Monitor firewall logs:**
   ```bash
   sudo journalctl -u ufw --no-pager | tail -20
   ```
3. **Watch for unauthorized access attempts:**
   ```bash
   sudo cat /var/log/auth.log | grep "Failed password"
   ```

### 7.4 Restrict sudo Access for Node Operations

The `cardano` user will be granted **limited** `sudo` access **only** for managing the node after installation. To prevent unauthorized system modifications, restrict `sudo` access to **only** necessary commands.

1. **Edit sudoers file:**
   ```bash
   sudo visudo
   ```
2. **Add the following line:**
   ```bash
   cardano ALL=(ALL) NOPASSWD: /bin/systemctl start cardano-node, /bin/systemctl stop cardano-node, /bin/systemctl restart cardano-node
   ```
   Save and exit.

This ensures the `cardano` user can manage the node service but **cannot** perform system-wide `sudo` actions.

### 7.5 Locking Down Cardano Binaries & Directories While Allowing Ubuntu Admin Access

If you want the `cardano` user to be the **only** one who can actually run or read node files **but still let the** `ubuntu` **admin account** handle pool operations (e.g., using `cardano-cli` for stake pool tasks), follow these steps:

1. **Create a special group** (e.g., `cardanogroup`) for Cardano admin tasks:

   ```bash
   sudo groupadd cardanogroup
   ```

   Add **both** `cardano` and `ubuntu` to this group:

   ```bash
   sudo usermod -aG cardanogroup cardano
   sudo usermod -aG cardanogroup ubuntu
   ```

2. **Set group ownership** on the relevant binaries and config directories:

   ```bash
   sudo chown -R cardano:cardanogroup /home/cardano/.local/bin
   sudo chown -R cardanogroup /home/cardano/cardano-config
   sudo chown -R cardanogroup /home/cardano/cardano-db
   ```

3. **Restrict other permissions** while allowing group read/execute:

   ```bash
   # Binaries: read+execute for group, no access for others
   sudo chmod 750 /home/cardano/.local/bin/cardano-node
   sudo chmod 750 /home/cardano/.local/bin/cardano-cli

   # Directories: read+execute for group, no access for others
   sudo chmod 750 /home/cardano/.local/bin
   sudo chmod 750 /home/cardano/cardano-config
   sudo chmod 750 /home/cardano/cardano-db
   ```

   This way, **only** the owner (`cardano`) and the group (`cardanogroup`) can access or run the node files. `ubuntu` is in that group, so it can run `cardano-cli` for pool ops if desired.

4. **Testing**

   - Switch to `ubuntu` and run `cardano-cli version` or other pool-ops commands. It should succeed.
   - Attempt to run `cardano-cli` as another user **not** in `cardanogroup`; it should fail with “Permission denied.”

5. **Confirm the node runs** under systemd with `User=cardano`:

   - This remains unchanged. The node will run because the `cardano` user is the owner.

By adopting this group-based approach, you secure the Cardano node files from all users except `cardano` (the node runner) and `ubuntu` (the admin). You can rename `cardanogroup` or add more members as needed for future pool operators.

### 7.6 Remove Temporary Passwordless Sudo (If Applied)

If you granted `cardano` full NOPASSWD privileges during setup (see [Section 2.3](#23-create-a-dedicated-service-account)), you should **remove** or restrict them now that the node is configured and your security steps are complete.

1. **Edit sudoers**:
   ```bash
   sudo visudo
   ```
2. **Remove or comment out** the line:
   ```bash
   cardano ALL=(ALL) NOPASSWD:ALL
   ```
   Or replace it with the minimal privileges described in [Section 7.4](#74-restrict-sudo-access-for-node-operations). For example:
   ```
   cardano ALL=(ALL) NOPASSWD: /bin/systemctl start cardano-node, /bin/systemctl stop cardano-node, /bin/systemctl restart cardano-node
   ```
   Save and exit.

Now the `cardano` user only has the specific node management privileges necessary and cannot perform other administrative actions without a password.

---

## 8. Out-of-Box Experience (OOBE) & Final Validation

### 8.1 Verify Node Synchronization

```bash
node-sync
```

Ensure `syncProgress` reaches **100%** before considering the relay functional.

### 8.2 Perform a Reboot Test

```bash
sudo reboot
```

After reboot, confirm that the node starts automatically:

```bash
node-status
```

### 8.3 Verify Custom Aliases

Run the following commands to ensure all custom aliases work correctly:

```bash
node-status
node-sync
node-logs
node-logs-recent
node-start
node-stop
node-restart
```

If any of the commands do not work, reload the alias file:

```bash
source ~/.bashrc
```

## 9. Conclusion

This guide ensures quick and secure deployment of Cardano relay nodes using precompiled binaries.

