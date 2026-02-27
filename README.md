# Secure (Ubuntu) Server

Harden an Ubuntu server. 

- 🔒 Disable root login and password authentication for SSH.
- 🔒 Set up a non-root `pcustic` user with sudo privileges.
- 🔒 Install and configure UFW firewall.
- 🔒 Install and configure fail2ban to protect against brute-force attacks.
- 🔒 Set up SSH key authentication using your GitHub SSH keys.

## Usage

#### 1/ SSH into your server as root

```bash
ssh root@your-server-ip
```

#### 2/ Set the `GITHUB_USERNAME` environment variable to your GitHub username.

```bash
export GITHUB_USERNAME=your_username
```

#### 3/ Run the hardening script.

```bash
curl -fsSL https://raw.githubusercontent.com/pcustic/secure-server/main/harden.sh | bash -s -e
```

#### 4/ Use your new `pcustic` user to SSH into your server.

```bash
ssh pcustic@your-server-ip
```
