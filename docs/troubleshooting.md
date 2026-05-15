# 🔍 Troubleshooting Guide

Solutions to common issues.

## ❌ Nginx 502 Bad Gateway

This usually means the PHP-FPM pool is not running.
- Check PHP-FPM status: `sudo systemctl status php8.3-fpm` (replace with your version).
- Check the pool config: `/etc/php/8.3/fpm/pool.d/youruser.conf`.

## ❌ Permissions Issues

If you get 403 Forbidden or "Permission denied" in Laravel logs:
- Ensure the storage directory is writable: `sudo chmod -R 775 storage bootstrap/cache`.
- Ensure the user belongs to `www-data`: `sudo usermod -aG www-data username`.

## ❌ SSL Certificate Failure

If Certbot fails:
- Ensure your domain is correctly pointing to the server's IP.
- Ensure port 80 is open in your firewall (UFW/Security Groups).
- Check Certbot logs: `sudo cat /var/log/letsencrypt/letsencrypt.log`.

## ❌ Database Connection Refused

- Ensure the database service is running: `sudo systemctl status mysql`.
- Verify credentials in `.env`.
