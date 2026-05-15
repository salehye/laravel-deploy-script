# 🛠️ Customizations Guide

How to modify the script and templates for your specific needs.

## 📄 Modifying Templates

You can find all configuration templates in the `config/` directory:
- `nginx-template.conf`: Change headers, gzip settings, or security rules.
- `php-fpm-template.conf`: Adjust memory limits or execution times.
- `supervisor-template.conf`: Change the number of processes or queue command flags.

## 🎨 Changing UI/Colors

In `deploy.sh`, look for the "Colors and Styles" section to modify the CLI appearance.

## 🧩 Adding New Features

The script is modular. You can add new functions to the core functions section and include them in the `main_menu`.

## 📦 Custom Release Paths

The default path is `/var/www/domain.com/releases`. You can change `SITE_PATH` in the `deploy_new_project` function if you prefer a different location.
