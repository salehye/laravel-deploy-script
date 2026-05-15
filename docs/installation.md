# 📥 Installation Guide

This guide will help you install and set up Laravel Deploy Pro on your VPS.

## Prerequisites

- A VPS running Ubuntu 20.04 or newer.
- SSH access with `sudo` privileges.
- A domain name pointing to your server's IP address.

## Step 1: Download the Script

You can download the script directly using `curl`:

```bash
curl -sSL https://raw.githubusercontent.com/salehye/laravel-deploy-script/main/deploy.sh -o deploy.sh
chmod +x deploy.sh
```

## Step 2: Run the Deployment

Execute the script with `sudo`:

```bash
sudo ./deploy.sh
```

## Step 3: Follow the Prompts

The interactive script will ask for:
1. Project Name
2. Domain(s)
3. PHP Version (8.0 - 8.3)
4. Database Type (MySQL, PostgreSQL, MariaDB)
5. GitHub Repository URL (Optional)

## Post-Installation

Once the script finishes, your site will be live at `https://your-domain.com`.
The script handles SSL, Nginx, PHP-FPM, and directory structure automatically.
