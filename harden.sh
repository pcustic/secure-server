#!/usr/bin/env bash

#
# Applies common security measures for Ubuntu servers. 
#
# Afterwards, you'll only be able to SSH into the server as 'app', eg. app@1.2.3.4
#

set -e

# ---------------------------------------------------------
# Step 1: Update and upgrade system packages
# ---------------------------------------------------------

apt update -y
apt upgrade -y
apt install -y vim curl htop

# Configure 'needrestart' for auto-restart of services after upgrades
sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf

# ---------------------------------------------------------
# Step 2: Install Docker and Docker Compose
# ---------------------------------------------------------

# Update package list and install prerequisites
apt update -y
apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key and set up repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker and Docker Compose plugins
apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---------------------------------------------------------
# Step 3: Configure Virtual Memory Overcommit
# ---------------------------------------------------------

sysctl vm.overcommit_memory=1
echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf

# ---------------------------------------------------------
# Step 4: Configure UFW Firewall
# ---------------------------------------------------------

ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# ---------------------------------------------------------
# Step 5: Secure SSH Configuration
# ---------------------------------------------------------

# 1/ Enable public key authentication
# 2/ disable password-based login
# 3/ and enforce other security settings

sed -i -e '/^\(#\|\)PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)PubkeyAuthentication/s/^.*$/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)PermitEmptyPasswords/s/^.*$/PermitEmptyPasswords no/' /etc/ssh/sshd_config

if ! grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config; then
    echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config
else
    sed -i -e '/^\(#\|\)ChallengeResponseAuthentication/s/^.*$/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
fi

echo 'Reloading ssh agent'
systemctl reload ssh

# ---------------------------------------------------------
# Step 6: Create Non-Root User with Sudo and Docker Access
# ---------------------------------------------------------

echo "Setup app user"
adduser --disabled-password --gecos "" app
echo "app ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

sudo -H -u app bash -c 'mkdir ~/.ssh'
sudo -H -u app bash -c 'chmod 700 ~/.ssh'
sudo -H -u app bash -c 'touch ~/.ssh/authorized_keys'
sudo -H -u app bash -c 'chmod 600 ~/.ssh/authorized_keys'
sudo -H -u app bash -c "echo '$AUTHORIZED_KEYS' >> ~/.ssh/authorized_keys"

# Add new user to Docker group
usermod -aG docker nonroot

# ---------------------------------------------------------
# Step 7: Install and Configure fail2ban
# ---------------------------------------------------------

echo "Setup fail2ban"
apt install -y fail2ban

cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 5
findtime = 600
bantime = 600
ignoreip = 127.0.0.1/8
logpath = /var/log/auth.log
EOF

systemctl restart fail2ban

# ---------------------------------------------------------
# Step 8: Secure Shared Memory
# ---------------------------------------------------------

echo "Secure shared memory"
echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab

# ---------------------------------------------------------
# Step 9: Disable Root User Login
# ---------------------------------------------------------

echo "Disable root user login"
sed -i -e '/^\(#\|\)PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload ssh

# ---------------------------------------------------------
# Step 10: Reboot to Apply Changes
# ---------------------------------------------------------

echo "Rebooting so changes can take effect"
reboot
