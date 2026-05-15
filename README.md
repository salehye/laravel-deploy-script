# 🚀 Laravel Deploy Pro

[![Version](https://img.shields.io/badge/version-4.0-blue.svg)](https://github.com/salehye/laravel-deploy-script)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.0+-yellow.svg)](https://www.gnu.org/software/bash/)
[![Laravel](https://img.shields.io/badge/Laravel-9.x%2F10.x%2F11.x-red.svg)](https://laravel.com)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2F22.04%2F24.04-orange.svg)](https://ubuntu.com)

A professional deployment script for Laravel applications on Ubuntu VPS with Zero Downtime, automatic SSL, and multi-domain support.

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🚀 | **One-Click Deploy** — Fully automated deployment |
| 🌐 | **Multi-Domain** — Add multiple domains to a single project |
| 🔒 | **Auto SSL** — Free Let's Encrypt certificates |
| 📦 | **Zero Downtime** — Deploy without service interruption |
| 🗄️ | **Multiple Databases** — MySQL, PostgreSQL, MariaDB |
| ⚙️ | **Flexible Options** — Customize PHP, resources, and extensions |
| 🔄 | **Auto Deploy** — Webhook + GitHub Actions integration |
| 📊 | **Performance Monitor** — System and site statistics |
| 💾 | **Automated Backups** — Daily backup with retention policy |
| 🛡️ | **Advanced Security** — Fail2Ban, ModSecurity, UFW |
| ⚙️ | **Full Management** — Edit and delete projects easily |
| 🛠️ | **Extra Tools** — Maintenance mode, log viewer, swap setup |
| 📦 | **Dev Environment** — Auto-install Docker, Node.js, NPM |

## 📋 Requirements

- VPS running **Ubuntu 20.04 / 22.04 / 24.04**
- `root` or a user with `sudo` privileges
- Internet connection

## 🚀 Quick Start

### Direct Download:

```bash
curl -sSL https://raw.githubusercontent.com/salehye/laravel-deploy-script/main/deploy.sh -o deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### Via Git:

```bash
git clone https://github.com/salehye/laravel-deploy-script.git
cd laravel-deploy-script
chmod +x deploy.sh
sudo ./deploy.sh
```

## 📖 Usage

After running the script, follow the interactive prompts:

1. Enter the project name
2. Add domain(s) (you can add multiple)
3. Choose the PHP version
4. Choose the database type
5. Enter the GitHub repository URL (optional)
6. Confirm the information and wait for completion

## 🛠️ Quick Commands

```bash
# Deploy a new project
sudo ./deploy.sh

# Update an existing project
sudo deploy-{PROJECT_NAME}

# Run backup
sudo ./scripts/backup.sh

# Monitor performance
sudo ./scripts/monitor.sh

# Install Docker
sudo ./scripts/install-docker.sh
```

## 📁 Directory Structure After Deployment

```
/var/www/example.com/
├── current/              # Current release (symlink)
├── releases/             # Previous releases
│   ├── 20240101_120000/
│   └── 20240102_120000/
├── shared/               # Shared files
│   ├── .env
│   └── storage/
├── logs/                 # Site logs
│   ├── php-error.log
│   └── nginx-error.log
└── .deploy-info          # Deployment metadata
```

## 🛡️ Security

This script is designed with security in mind:
- **Input Validation:** Project names and domains are validated to prevent command injection.
- **File Permissions:** Strict permissions are set for sensitive files like `.env` (640).
- **Password Management:** Strong random passwords are generated for each project.
- **Process Protection:** Temporary environment variables are used for database passwords to avoid exposure in process logs.
- **Security Headers:** Nginx configuration includes protection against XSS, Clickjacking, and MIME Sniffing.

## 🤝 Contributing

Contributions are welcome! Please read the [Contributing Guide](CONTRIBUTING.md).

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.

## ⭐ Support

If you like this project, don't forget to give it a star ⭐
