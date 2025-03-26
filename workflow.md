[ Cloud-Init ]
      |
      v
[ 1. General Server Hardening ]
   └─ Creates hardened 'ubuntu' user
   └─ Locks down root
   └─ Enables basic 2FA for 'ubuntu'
      |
      v
[ 2. Relay Provisioning ]
   └─ Creates 'cardano' user
   └─ Enables 2FA (not SSH keys)
   └─ Creates folder structure
   └─ Downloads binaries
   └─ Installs systemd service
   └─ Adds CLI aliases
   └─ Fetches mainnet configs
      |
      v
[ 3. OOBE Wizard ]
   └─ Runs on first login by cardano user
   └─ Asks questions: hostname, BP IP, public/private
   └─ Generates `topology.json`
   └─ Restarts node cleanly
