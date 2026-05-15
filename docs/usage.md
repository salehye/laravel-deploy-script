# 📖 Usage Guide

How to use the various features of Laravel Deploy Pro.

## 🚀 Deploying a New Project

Simply run `sudo ./deploy.sh` and select option 1.

## 🔄 Updating an Existing Project

Select option 2 from the main menu or use the custom command generated for your project:

```bash
sudo deploy-myproject
```

## 💾 Backups

Backups are stored in `/var/backups/laravel`. You can run a manual backup:

```bash
sudo ./scripts/backup.sh
```

## 📊 Monitoring

View system performance and active sites:

```bash
sudo ./scripts/monitor.sh
```

## 🐳 Docker Support

If you need Docker, you can install it using the helper script:

```bash
sudo ./scripts/install-docker.sh
```
