#!/bin/bash
# ============================================
# Automated Backup Script
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }

# Variables
BACKUP_ROOT="/var/backups/laravel"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_ROOT"

print_info "Starting backup process..."

# Find all deployed projects
for site_path in /var/www/*/; do
    if [[ -f "$site_path/.deploy-info" ]]; then
        source "$site_path/.deploy-info"
        site_name=$(basename "$site_path")
        
        print_info "Backing up site: $site_name"
        
        backup_file="$BACKUP_ROOT/${site_name}_${DATE}.tar.gz"
        
        # Create file backup
        tar -czf "$backup_file" \
            --exclude="$site_path/releases/*/node_modules" \
            --exclude="$site_path/releases/*/vendor" \
            --exclude="$site_path/releases/*/.git" \
            --exclude="$site_path/shared/storage/framework/cache/*" \
            --exclude="$site_path/shared/storage/framework/sessions/*" \
            --exclude="$site_path/shared/storage/logs/*.log" \
            "$site_path" 2>/dev/null || true
        
        if [[ -f "$backup_file" ]]; then
            size=$(du -h "$backup_file" | cut -f1)
            print_success "Created $backup_file ($size)"
        fi
        
        # Backup database
        if [[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASS" ]]; then
            db_backup="$BACKUP_ROOT/${site_name}_db_${DATE}.sql"
            
            if command -v mysqldump &> /dev/null; then
                export MYSQL_PWD="$DB_PASS"
                mysqldump -u "$DB_USER" "$DB_NAME" > "$db_backup" 2>/dev/null
                unset MYSQL_PWD
                gzip "$db_backup"
                print_success "Database backed up: ${site_name}_db_${DATE}.sql.gz"
            fi
        fi
    fi
done

# Clean old backups
print_info "Cleaning backups older than $RETENTION_DAYS days"
find "$BACKUP_ROOT" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
find "$BACKUP_ROOT" -name "*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete

# Upload to S3 (optional)
if command -v aws &> /dev/null && [[ -n "$AWS_BACKUP_BUCKET" ]]; then
    print_info "Uploading backups to S3..."
    aws s3 sync "$BACKUP_ROOT" "s3://$AWS_BACKUP_BUCKET/backups/" --delete
    print_success "Backups uploaded to S3"
fi

print_success "Backup process completed"
