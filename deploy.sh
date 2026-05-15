#!/bin/bash
# Laravel Deploy Pro v4.0
# Author: Saleh (salehye)
# https://github.com/salehye/laravel-deploy-script
# ============================================

set -e  # Exit on any error

# ============================================
# Colors and Styles
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Icons
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_INFO="ℹ️"
ICON_WARNING="⚠️"
ICON_ROCKET="🚀"
ICON_DB="🗄️"
ICON_GITHUB="🐙"
ICON_DOMAIN="🌐"
ICON_PHP="🐘"
ICON_NGINX="🖥️"
ICON_SSL="🔒"
ICON_WEBHOOK="📡"
ICON_SECURITY="🛡️"
ICON_SHIELD="🔰"

# ============================================
# Global Variables
# ============================================
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="Laravel Deploy Pro"
LOG_FILE="/var/log/laravel-deploy.log"
CONFIG_DIR="/etc/laravel-deploy"
TEMPLATE_DIR="$(dirname "$0")/config"

# ============================================
# Output helpers
# ============================================
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                           ║"
    echo -e "║     ${WHITE}${ICON_ROCKET} LARADEPLOY PRO v${SCRIPT_VERSION} - Professional Laravel Deploy System${CYAN}         ║"
    echo "║                                                                           ║"
    echo -e "║     ${DIM}Zero Downtime | SSL Auto | Advanced Protection${CYAN}                           ║"
    echo "║                                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_title() {
    echo -e "\n${BOLD}${MAGENTA}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${MAGENTA}│${NC} ${BOLD}$1${NC}"
    echo -e "${BOLD}${MAGENTA}└─────────────────────────────────────────────────────────────────────────┘${NC}\n"
}

print_success() { echo -e "  ${GREEN}${ICON_SUCCESS}${NC} $1"; }
print_error()   { echo -e "  ${RED}${ICON_ERROR}${NC} $1"; }
print_info()    { echo -e "  ${BLUE}${ICON_INFO}${NC} $1"; }
print_warning() { echo -e "  ${YELLOW}${ICON_WARNING}${NC} $1"; }

# ============================================
# Input helpers
# ============================================
ask_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    local answer
    while true; do
        echo -ne "  ${YELLOW}❓${NC} $prompt [${default}]: "
        read answer
        answer=${answer:-$default}
        case $answer in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "  ${RED}Please enter Y or N${NC}" ;;
        esac
    done
}

ask_input() {
    local prompt="$1"
    local default="$2"
    local answer
    if [[ -n "$default" ]]; then
        echo -ne "  ${BLUE}📝${NC} $prompt [$default]: " >&2
    else
        echo -ne "  ${BLUE}📝${NC} $prompt: " >&2
    fi
    read -r answer
    answer=$(echo "$answer" | tr -d '\r' | xargs)
    echo "${answer:-$default}"
}

select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    echo -e "  ${BLUE}🔽${NC} $prompt"
    for i in "${!options[@]}"; do
        echo -e "    ${CYAN}$((i+1))${NC}) ${options[$i]}"
    done
    while true; do
        echo -ne "  ${YELLOW}Select a number (1-${#options[@]}): ${NC}"
        read choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#options[@]} )); then
            return $((choice-1))
        fi
        echo -e "  ${RED}Invalid choice${NC}"
    done
}

# ============================================
# Permission check
# ============================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root. Use sudo."
        exit 1
    fi
}

# ============================================
# Dependency checks
# ============================================
check_dependencies() {
    print_title "Checking dependencies"
    local deps=(curl wget git unzip zip nginx jq software-properties-common)
    local missing=()
    for dep in "${deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done
    if (( ${#missing[@]} )); then
        print_warning "Missing dependencies: ${missing[*]}"
        if ask_yes_no "Install missing dependencies?" "Y"; then
            apt update && apt install -y "${missing[@]}"
        else
            print_error "Cannot continue without required dependencies."
            exit 1
        fi
    fi
    print_success "All dependencies are satisfied"
}

# ============================================
# Core installation functions
# ============================================
install_system_packages() {
    print_title "Installing core system packages"
    apt update
    apt install -y curl wget git unzip zip nginx jq software-properties-common
    print_success "Core packages installed"
}

install_php() {
    local version="$1"
    print_title "Installing PHP $version"
    add-apt-repository ppa:ondrej/php -y
    apt update
    local extensions="fpm cli common mysql zip gd mbstring curl xml bcmath tokenizer json redis"
    for ext in $extensions; do
        apt install -y "php${version}-${ext}"
    done
    print_success "PHP $version installed"
}

install_database() {
    local type="$1"
    local db_name="$2"
    local db_user="$3"
    local db_pass="$4"
    if [[ "$type" == "No Database" ]]; then
        return
    fi
    print_title "Installing $type database"
    case "$type" in
        "MySQL")
            apt install -y mysql-server
            systemctl start mysql
            ;;
        "PostgreSQL")
            apt install -y postgresql
            systemctl start postgresql
            ;;
        "MariaDB")
            apt install -y mariadb-server
            systemctl start mariadb
            ;;
    esac
    if [[ "$type" == "PostgreSQL" ]]; then
        sudo -u postgres psql <<EOF
CREATE DATABASE $db_name;
CREATE USER $db_user WITH PASSWORD '$db_pass';
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
EOF
    else
        mysql <<EOF
CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF
    fi
    print_success "Database $db_name created"
}

create_system_user() {
    local username="$1"
    print_title "Creating system user $username"
    if id "$username" >/dev/null 2>&1; then
        print_warning "User $username already exists"
    else
        useradd -m -s /bin/bash "$username"
        print_success "User $username created"
    fi
    usermod -a -G www-data "$username"
}

create_directory_structure() {
    local site_path="$1"
    local username="$2"
    print_title "Creating directory structure"
    mkdir -p "$site_path"/{public,storage,logs,bootstrap/cache,releases,shared}
    mkdir -p "$site_path/shared/storage"/{app,framework/{cache,sessions,views,data},logs}
    chown -R "$username":"$username" "$site_path"
    chmod -R 755 "$site_path"
    chmod -R 775 "$site_path/storage"
    chmod -R 775 "$site_path/bootstrap/cache"
    print_success "Directory structure created at $site_path"
}

clone_repository() {
    local repo_url="$1"
    local branch="$2"
    local site_path="$3"
    local username="$4"
    print_title "Cloning repository"
    mkdir -p "/home/$username/.ssh"
    ssh-keygen -t ed25519 -f "/home/$username/.ssh/id_ed25519" -N "" -q
    chown -R "$username":"$username" "/home/$username/.ssh"
    local release_id=$(date +%Y%m%d_%H%M%S)
    local release_dir="$site_path/releases/$release_id"
    sudo -u "$username" git clone "$repo_url" "$release_dir"
    sudo -u "$username" git -C "$release_dir" checkout "$branch"
    ln -sfn "$site_path/shared/storage" "$release_dir/storage"
    ln -sfn "$release_dir" "$site_path/current"
    print_success "Repository cloned"
}

setup_environment() {
    local site_path="$1"
    local username="$2"
    local domain="$3"
    local db_type="$4"
    local db_name="$5"
    local db_user="$6"
    local db_pass="$7"
    print_title "Creating .env file"
    local env_file="$site_path/current/.env"
    if [[ -f "$site_path/current/.env.example" ]]; then
        cp "$site_path/current/.env.example" "$env_file"
    else
        touch "$env_file"
    fi
    cat > "$env_file" <<EOF
APP_NAME="${domain%.*}"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://$domain
LOG_CHANNEL=stack
LOG_LEVEL=debug
EOF
    if [[ "$db_type" != "No Database" ]]; then
        cat >> "$env_file" <<EOF
DB_CONNECTION=$(echo "$db_type" | tr '[:upper:]' '[:lower:]')
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$db_name
DB_USERNAME=$db_user
DB_PASSWORD="$db_pass"
EOF
    fi
    chown "$username":"$username" "$env_file"
    chmod 640 "$env_file"
    print_success ".env created"
}

install_composer_dependencies() {
    local site_path="$1"
    local username="$2"
    print_title "Installing Composer dependencies"
    if ! command -v composer >/dev/null 2>&1; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
    fi
    sudo -u "$username" bash <<'EOF'
cd "$site_path/current"
composer install --no-interaction --optimize-autoloader --no-dev
php artisan key:generate
php artisan storage:link
php artisan config:cache
php artisan route:cache
php artisan view:cache
EOF
    print_success "Composer dependencies installed"
}

run_migrations() {
    local site_path="$1"
    local username="$2"
    print_title "Running migrations"
    sudo -u "$username" php "$site_path/current/artisan" migrate --force
    print_success "Migrations completed"
}

setup_php_fpm() {
    local username="$1"
    local php_version="$2"
    local site_path="$3"
    print_title "Configuring PHP-FPM"
    cat > "/etc/php/$php_version/fpm/pool.d/$username.conf" <<EOF
[$username]
user = $username
group = $username
listen = /run/php/php${php_version}-$username-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 20
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.max_requests = 500
php_admin_value[open_basedir] = $site_path/current:/tmp
php_admin_value[memory_limit] = 256M
php_admin_value[max_execution_time] = 120
php_admin_value[upload_max_filesize] = 50M
php_admin_flag[display_errors] = off
php_admin_value[error_log] = $site_path/logs/php-error.log
php_admin_value[session.save_path] = $site_path/shared/storage/framework/sessions
EOF
    systemctl restart "php${php_version}-fpm"
    print_success "PHP-FPM pool created"
}

setup_nginx() {
    local project_name="$1"
    shift
    local domains=("$@")
    local site_path="${domains[-1]}"   # placeholder, will be overridden later
    local php_version="${domains[-2]}"
    local username="${domains[-1]}"
    # The above is just to keep compatibility with older call signatures; we will recompute properly
    # Re‑extract arguments
    local domain_list=("${@:1:$#-4}")
    local site_path="${@: -3:1}"
    local php_version="${@: -2:1}"
    local username="${@: -1}"
    print_title "Configuring Nginx"
    local server_names=$(printf "%s " "${domain_list[@]}" "www.${domain_list[@]}")
    cat > "/etc/nginx/sites-available/$project_name" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $server_names;
    root $site_path/current/public;
    index index.php index.html;
    client_max_body_size 50M;
    access_log $site_path/logs/nginx-access.log;
    error_log $site_path/logs/nginx-error.log;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${php_version}-$username-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~ /\.env { deny all; return 404; }
    location ~ /\.git { deny all; return 404; }
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF
    ln -sf "/etc/nginx/sites-available/$project_name" "/etc/nginx/sites-enabled/"
    nginx -t && systemctl reload nginx
    print_success "Nginx configuration applied"
}

install_ssl() {
    local domains=("$@")
    print_title "Installing SSL certificates"
    if ! command -v certbot >/dev/null 2>&1; then
        apt install -y certbot python3-certbot-nginx
    fi
    local ssl_domains=""
    for d in "${domains[@]}"; do
        ssl_domains="$ssl_domains -d $d -d www.$d"
    done
    certbot --nginx $ssl_domains --non-interactive --agree-tos --email "admin@${domains[0]}" --redirect
    print_success "SSL certificates installed"
}

setup_webhook() {
    local project_name="$1"
    local domain="$2"
    local branch="$3"
    local php_version="$4"
    print_title "Setting up GitHub webhook for auto‑deploy"
    local webhook_secret=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    local webhook_path="/var/www/webhooks/$project_name"
    mkdir -p "$webhook_path"
    cat > "$webhook_path/index.php" <<'PHPEOF'
<?php
$headers = getallheaders();
$signature = $headers['X-Hub-Signature-256'] ?? '';
$payload = file_get_contents('php://input');
$secret = getenv('WEBHOOK_SECRET');
if ($secret && $signature) {
    $hash = 'sha256=' . hash_hmac('sha256', $payload, $secret);
    if (!hash_equals($hash, $signature)) {
        http_response_code(401);
        echo 'Invalid signature';
        exit;
    }
}
$data = json_decode($payload, true);
$branch = explode('/', $data['ref'] ?? '')[2] ?? '';
$expectedBranch = getenv('BRANCH') ?: 'main';
if ($branch === $expectedBranch && ($data['after'] ?? '')) {
    $project = getenv('PROJECT_NAME');
    exec("sudo /usr/local/bin/deploy-$project > /dev/null 2>&1 &");
    echo "Deployment started for $project\n";
} else {
    echo "No deployment needed\n";
}
PHPEOF
    cat > "$webhook_path/.env" <<EOF
WEBHOOK_SECRET=$webhook_secret
PROJECT_NAME=$project_name
BRANCH=$branch
EOF
    cat > "/etc/nginx/sites-available/webhook-$project_name" <<EOF
server {
    listen 80;
    server_name webhook.$domain;
    root $webhook_path;
    location / {
        try_files \$uri /index.php?\$query_string;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${php_version}-fpm.sock;
        fastcgi_param WEBHOOK_SECRET $webhook_secret;
        fastcgi_param PROJECT_NAME $project_name;
        fastcgi_param BRANCH $branch;
    }
}
EOF
    ln -sf "/etc/nginx/sites-available/webhook-$project_name" "/etc/nginx/sites-enabled/"
    nginx -t && systemctl reload nginx
    print_success "Webhook configured"
    echo -e "  ${CYAN}Webhook URL:${NC} http://webhook.$domain/"
    echo -e "  ${CYAN}Secret:${NC} $webhook_secret"
}

setup_supervisor() {
    local project_name="$1"
    local site_path="$2"
    local username="$3"
    print_title "Configuring Supervisor for queue workers"
    apt install -y supervisor
    cat > "/etc/supervisor/conf.d/${project_name}_worker.conf" <<EOF
[program:${project_name}_worker]
process_name=%(program_name)s_%(process_num)02d
command=php $site_path/current/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=$username
numprocs=2
redirect_stderr=true
stdout_logfile=$site_path/logs/worker.log
stopwaitsecs=3600
EOF
    supervisorctl reread && supervisorctl update && supervisorctl start "${project_name}_worker:*"
    print_success "Supervisor configuration applied"
}

setup_cron_jobs() {
    local project_name="$1"
    local site_path="$2"
    local username="$3"
    print_title "Setting up cron jobs"
    cat > "/etc/cron.d/$project_name" <<EOF
* * * * * $username php $site_path/current/artisan schedule:run >> $site_path/logs/cron.log 2>&1
0 2 * * * $username php $site_path/current/artisan backup:run >> $site_path/logs/backup.log 2>&1
EOF
    chmod 644 "/etc/cron.d/$project_name"
    print_success "Cron jobs created"
}

create_deploy_script() {
    local project_name="$1"
    local site_path="$2"
    print_title "Creating fast‑deploy helper script"
    cat > "/usr/local/bin/deploy-$project_name" <<'DEPLOYSCRIPT'
#!/bin/bash
PROJECT_NAME="$1"
SITE_PATH="/var/www/$PROJECT_NAME"
PROJECT_USER=$(stat -c '%U' "$SITE_PATH/current" 2>/dev/null || echo "www-data")
RELEASE_ID=$(date +%Y%m%d_%H%M%S)
RELEASE_PATH="$SITE_PATH/releases/$RELEASE_ID"

if [ ! -d "$SITE_PATH/current/.git" ]; then
    echo "❌ Project is not a git repository"
    exit 1
fi

sudo -u "$PROJECT_USER" git clone "$(sudo -u "$PROJECT_USER" git -C "$SITE_PATH/current" config --get remote.origin.url)" "$RELEASE_PATH"
sudo -u "$PROJECT_USER" git -C "$RELEASE_PATH" checkout "$(sudo -u "$PROJECT_USER" git -C "$SITE_PATH/current" rev-parse --abbrev-ref HEAD)"
ln -sfn "$SITE_PATH/shared/storage" "$RELEASE_PATH/storage"
ln -sfn "$SITE_PATH/shared/.env" "$RELEASE_PATH/.env"
cd "$RELEASE_PATH"
sudo -u "$PROJECT_USER" composer install --no-interaction --optimize-autoloader --no-dev
sudo -u "$PROJECT_USER" php artisan migrate --force
sudo -u "$PROJECT_USER" php artisan config:cache
sudo -u "$PROJECT_USER" php artisan route:cache
sudo -u "$PROJECT_USER" php artisan view:cache
ln -sfn "$RELEASE_PATH" "$SITE_PATH/current.next"
mv -T "$SITE_PATH/current.next" "$SITE_PATH/current"
PHP_VERSION=$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)
sudo systemctl reload "php${PHP_VERSION}-fpm"
cd "$SITE_PATH/releases" && ls -t | tail -n +6 | xargs -r rm -rf
echo "✅ Deployment of $PROJECT_NAME completed"
DEPLOYSCRIPT
    chmod +x "/usr/local/bin/deploy-$project_name"
    print_success "Deploy helper script created: deploy-$project_name"
}

# ============================================
# Additional tools
# ============================================
extra_tools() {
    print_title "🛠️ Additional Tools"
    local options=(
        "Toggle Maintenance Mode"
        "Log Viewer"
        "Setup Swap Memory"
        "Setup UFW Firewall"
        "Install Node.js & NPM"
        "Back"
    )
    select_option "Choose a tool" "${options[@]}"
    local choice=$?
    case $choice in
        0) toggle_maintenance ;;
        1) log_viewer ;;
        2) setup_swap ;;
        3) setup_firewall ;;
        4) install_nodejs ;;
        5) return ;;
    esac
}

toggle_maintenance() {
    local projects=()
    local paths=()
    for d in /var/www/*/; do
        [[ -f "$d/.deploy-info" ]] && { source "$d/.deploy-info"; projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)"); paths+=("$d"); }
    done
    [[ ${#projects[@]} -eq 0 ]] && { print_error "No deployed projects found"; return; }
    select_option "Select project" "${projects[@]}"
    local idx=$?
    source "${paths[$idx]}/.deploy-info"
    if sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" down --help >/dev/null 2>&1; then
        if ask_yes_no "Enable maintenance mode?" "Y"; then
            sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" down
            print_success "Maintenance mode enabled"
        else
            sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" up
            print_success "Maintenance mode disabled"
        fi
    else
        print_error "Artisan not available"
    fi
}

log_viewer() {
    local options=("Nginx Access" "Nginx Error" "PHP-FPM Error" "Laravel Logs")
    select_option "Select log to view" "${options[@]}"
    local choice=$?
    case $choice in
        0) tail -n 50 /var/log/nginx/access.log ;;
        1) tail -n 50 /var/log/nginx/error.log ;;
        2) tail -n 50 /var/log/php*-fpm.log ;;
        3)
            local projects=()
            for d in /var/www/*/; do [[ -f "$d/.deploy-info" ]] && projects+=("$(basename "$d")"); done
            select_option "Select project" "${projects[@]}"
            local idx=$?
            tail -n 50 "/var/www/${projects[$idx]}/logs/php-error.log"
            ;;
    esac
}

setup_swap() {
    local size=$(ask_input "Swap size (e.g., 2G)" "2G")
    print_info "Creating $size swap file"
    fallocate -l "$size" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    print_success "Swap created"
}

setup_firewall() {
    print_info "Installing UFW firewall"
    apt install -y ufw
    ufw allow OpenSSH
    ufw allow 'Nginx Full'
    ufw --force enable
    print_success "UFW enabled with SSH and HTTP/HTTPS allowed"
}

install_nodejs() {
    print_info "Installing Node.js LTS"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt install -y nodejs
    print_success "Node.js $(node -v) installed"
}

# ============================================
# Security settings
# ============================================
security_settings() {
    print_title "🛡️ Security Settings"
    local options=(
        "Install Fail2Ban"
        "Install ModSecurity"
        "Harden SSH"
        "Vulnerability Scan"
        "Back"
    )
    select_option "Choose a security option" "${options[@]}"
    local choice=$?
    case $choice in
        0) setup_fail2ban ;;
        1) setup_modsecurity ;;
        2) harden_ssh ;;
        3) scan_vulnerabilities ;;
        4) return ;;
    esac
}

setup_fail2ban() {
    print_info "Installing Fail2Ban"
    apt install -y fail2ban
    cat > /etc/fail2ban/jail.d/laravel.conf <<EOF
[nginx-laravel]
enabled = true
port = http,https
filter = nginx-laravel
logpath = /var/log/nginx/*access.log
maxretry = 10
bantime = 3600
EOF
    systemctl restart fail2ban
    print_success "Fail2Ban installed"
}

setup_modsecurity() {
    print_info "Installing ModSecurity for Nginx"
    apt install -y libnginx-mod-http-modsecurity
    mkdir -p /etc/nginx/modsec
    wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/owasp-modsecurity-crs/v3.2/master/crs-setup.conf.example
    print_success "ModSecurity installed"
}

harden_ssh() {
    print_info "Hardening SSH configuration"
    sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    print_warning "Password authentication disabled. Ensure you have SSH keys configured."
    systemctl restart ssh
    print_success "SSH hardened"
}

scan_vulnerabilities() {
    print_title "🔍 Vulnerability Scan"
    print_info "Open ports:"
    netstat -tulpn | grep LISTEN
    print_info "Pending system upgrades:"
    apt list --upgradable
    print_success "Scan completed"
}

# ============================================
# Backup manager
# ============================================
backup_manager() {
    print_title "💾 Backup Manager"
    if [[ -f "$(dirname "$0")/scripts/backup.sh" ]]; then
        bash "$(dirname "$0")/scripts/backup.sh"
    else
        print_error "Backup script not found"
    fi
}

# ============================================
# Performance monitor
# ============================================
performance_monitor() {
    print_title "📊 Performance Monitor"
    if [[ -f "$(dirname "$0")/scripts/monitor.sh" ]]; then
        bash "$(dirname "$0")/scripts/monitor.sh"
    else
        print_error "Monitor script not found"
    fi
}

# ============================================
# Edit existing project
# ============================================
edit_existing_project() {
    print_title "⚙️ Edit Project Settings"
    local projects=() paths=()
    for d in /var/www/*/; do
        [[ -f "$d/.deploy-info" ]] && { source "$d/.deploy-info"; projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)"); paths+=("$d"); }
    done
    [[ ${#projects[@]} -eq 0 ]] && { print_error "No projects found"; return; }
    select_option "Select project" "${projects[@]}"
    local idx=$?
    source "${paths[$idx]}/.deploy-info"
    local edit_opts=("Change PHP version" "Edit domains" "Edit .env file" "Back")
    select_option "What would you like to edit?" "${edit_opts[@]}"
    local choice=$?
    case $choice in
        0) # Change PHP
            local php_versions=("8.3" "8.2" "8.1" "8.0")
            select_option "Select new PHP version" "${php_versions[@]}"
            local new_php=${php_versions[$?]}
            install_php "$new_php"
            setup_php_fpm "$PROJECT_USER" "$new_php" "$SITE_PATH"
            setup_nginx "$PROJECT_NAME" "${DOMAINS[@]}" "$SITE_PATH" "$new_php" "$PROJECT_USER"
            sed -i "s/PHP_VERSION=.*/PHP_VERSION=\"$new_php\"/" "$SITE_PATH/.deploy-info"
            print_success "PHP version updated to $new_php"
            ;;
        1) # Edit domains
            local new_domains=()
            while true; do
                local d=$(ask_input "Enter new domain (blank to finish)" "")
                [[ -z "$d" ]] && break
                if [[ "$d" =~ ^([a-zA-Z0-9](-*[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
                    new_domains+=("$d")
                else
                    print_error "Invalid domain format"
                fi
            done
            if (( ${#new_domains[@]} )); then
                setup_nginx "$PROJECT_NAME" "${new_domains[@]}" "$SITE_PATH" "$PHP_VERSION" "$PROJECT_USER"
                if ask_yes_no "Install SSL for new domains?" "Y"; then
                    install_ssl "${new_domains[@]}"
                fi
                sed -i "s/DOMAINS=.*/DOMAINS=(${new_domains[*]})/" "$SITE_PATH/.deploy-info"
                sed -i "s/PRIMARY_DOMAIN=.*/PRIMARY_DOMAIN=\"${new_domains[0]}\"/" "$SITE_PATH/.deploy-info"
                print_success "Domains updated"
            fi
            ;;
        2) # Edit .env
            if [[ -f "$SITE_PATH/current/.env" ]]; then
                nano "$SITE_PATH/current/.env"
                if ask_yes_no "Restart services to apply .env changes?" "Y"; then
                    sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" config:cache
                    systemctl reload "php$PHP_VERSION-fpm"
                fi
            else
                print_error ".env file not found"
            fi
            ;;
        *) return ;;
    esac
}

# ============================================
# Delete project
# ============================================
delete_project() {
    print_title "🗑️ Delete Project"
    local projects=() paths=()
    for d in /var/www/*/; do
        [[ -f "$d/.deploy-info" ]] && { source "$d/.deploy-info"; projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)"); paths+=("$d"); }
    done
    [[ ${#projects[@]} -eq 0 ]] && { print_error "No projects installed"; return; }
    select_option "Select project to delete" "${projects[@]}"
    local idx=$?
    source "${paths[$idx]}/.deploy-info"
    echo -e "${RED}${BOLD}⚠️ WARNING: This will permanently delete the project and its database!${NC}"
    if ask_yes_no "Are you absolutely sure you want to delete $PROJECT_NAME?" "N"; then
        rm -rf "$SITE_PATH"
        rm -f "/etc/nginx/sites-enabled/$PROJECT_NAME" "/etc/nginx/sites-available/$PROJECT_NAME"
        rm -f "/etc/php/$PHP_VERSION/fpm/pool.d/$PROJECT_USER.conf"
        rm -f "/usr/local/bin/deploy-$PROJECT_NAME"
        rm -f "/etc/cron.d/$PROJECT_NAME"
        if ask_yes_no "Delete system user $PROJECT_USER?" "N"; then
            userdel -r "$PROJECT_USER" 2>/dev/null || true
        fi
        if [[ -n "$DB_NAME" ]]; then
            if ask_yes_no "Delete database $DB_NAME?" "N"; then
                mysql -e "DROP DATABASE IF EXISTS $DB_NAME;"
                mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
                print_success "Database deleted"
            fi
        fi
        systemctl reload nginx
        systemctl reload "php$PHP_VERSION-fpm"
        print_success "Project $PROJECT_NAME deleted"
    else
        print_info "Deletion cancelled"
    fi
}

# ============================================
# Main menu driver
# ============================================
main_menu() {
    print_banner
    local options=(
        "Deploy New Laravel Project"
        "Update Existing Project"
        "Edit Project Settings"
        "Delete Project"
        "Database Management"
        "Security Settings"
        "Additional Tools"
        "Backup Manager"
        "Performance Monitor"
        "Exit"
    )
    select_option "MAIN MENU" "${options[@]}"
    local choice=$?
    case $choice in
        0) deploy_new_project ;;
        1) update_existing_project ;;
        2) edit_existing_project ;;
        3) delete_project ;;
        4) manage_databases ;;
        5) security_settings ;;
        6) extra_tools ;;
        7) backup_manager ;;
        8) performance_monitor ;;
        9) exit 0 ;;
    esac
}

# ============================================
# Deploy New Project
# ============================================
deploy_new_project() {
    print_title "🚀 Deploy New Laravel Project"
    
    # Information Gathering
    while true; do
        PROJECT_NAME=$(ask_input "Project Name (letters, numbers, dots, hyphens only)" "")
        PROJECT_NAME=$(echo "$PROJECT_NAME" | tr -d '\r' | xargs)
        if [[ -z "$PROJECT_NAME" ]]; then
            print_error "Project Name is required"
        else
            case "$PROJECT_NAME" in
                *[!a-zA-Z0-9.-]*)
                    print_error "Project Name contains unauthorized symbols"
                    ;;
                *)
                    break
                    ;;
            esac
        fi
    done
    
    # Add Domains
    DOMAINS=()
    while true; do
        domain=$(ask_input "Enter domain name (e.g., example.com) - leave empty to finish" "")
        [[ -z "$domain" ]] && break
        domain=$(echo "$domain" | tr -d '\r' | xargs)
        if [[ "$domain" =~ ^([a-zA-Z0-9](-*[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
            DOMAINS+=("$domain")
            print_success "Added $domain"
        else
            print_error "Invalid domain format"
        fi
    done
    
    if [[ ${#DOMAINS[@]} -eq 0 ]]; then
        print_error "At least one domain must be added"
        return 1
    fi
    
    PRIMARY_DOMAIN="${DOMAINS[0]}"
    PROJECT_USER="${PROJECT_NAME//[.-]/_}"
    SITE_PATH="/var/www/$PRIMARY_DOMAIN"
    
    # Choose Settings
    PHP_VERSIONS=("8.3" "8.2" "8.1" "8.0")
    select_option "Choose PHP Version" "${PHP_VERSIONS[@]}"
    PHP_VERSION="${PHP_VERSIONS[$?]}"
    
    DB_TYPES=("MySQL" "PostgreSQL" "MariaDB" "No Database")
    select_option "Choose Database Type" "${DB_TYPES[@]}"
    DB_TYPE_INDEX=$?
    DB_TYPE="${DB_TYPES[$DB_TYPE_INDEX]}"
    
    if [[ "$DB_TYPE" != "No Database" ]]; then
        DB_NAME=$(ask_input "Database Name" "${PROJECT_USER}_db")
        DB_USER=$(ask_input "Database User" "${PROJECT_USER}")
        DB_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    fi
    
    GITHUB_URL=$(ask_input "GitHub URL (SSH) - leave empty for manual upload" "")
    BRANCH=$(ask_input "Branch" "main")
    
    # Confirmation
    print_title "📋 Confirm Information"
    echo -e "  • Project: ${GREEN}$PROJECT_NAME${NC}"
    echo -e "  • Domains: ${GREEN}${DOMAINS[*]}${NC}"
    echo -e "  • PHP: ${GREEN}$PHP_VERSION${NC}"
    echo -e "  • Database: ${GREEN}$DB_TYPE${NC}"
    [[ -n "$GITHUB_URL" ]] && echo -e "  • GitHub: ${GREEN}$GITHUB_URL${NC}"
    
    if ! ask_yes_no "Is all information correct?" "Y"; then
        print_error "Installation cancelled"
        return 1
    fi
    
    # Start Installation
    install_system_packages
    install_php "$PHP_VERSION"
    install_database "$DB_TYPE" "$DB_NAME" "$DB_USER" "$DB_PASS"
    create_system_user "$PROJECT_USER"
    create_directory_structure "$SITE_PATH" "$PROJECT_USER"
    
    if [[ -n "$GITHUB_URL" ]]; then
        clone_repository "$GITHUB_URL" "$BRANCH" "$SITE_PATH" "$PROJECT_USER"
        setup_environment "$SITE_PATH" "$PROJECT_USER" "$PRIMARY_DOMAIN" "$DB_TYPE" "$DB_NAME" "$DB_USER" "$DB_PASS"
        install_composer_dependencies "$SITE_PATH" "$PROJECT_USER"
        run_migrations "$SITE_PATH" "$PROJECT_USER"
    fi
    
    setup_php_fpm "$PROJECT_USER" "$PHP_VERSION" "$SITE_PATH"
    setup_nginx "$PROJECT_NAME" "${DOMAINS[@]}" "$SITE_PATH" "$PHP_VERSION" "$PROJECT_USER"
    
    if ask_yes_no "Do you want to install SSL?" "Y"; then
        install_ssl "${DOMAINS[@]}"
    fi
    
    if ask_yes_no "Do you want to enable Auto-Deploy?" "Y"; then
        setup_webhook "$PROJECT_NAME" "$PRIMARY_DOMAIN" "$BRANCH" "$PHP_VERSION"
    fi
    
    if ask_yes_no "Do you want to enable Queue Worker (Supervisor)?" "Y"; then
        setup_supervisor "$PROJECT_NAME" "$SITE_PATH" "$PROJECT_USER"
    fi
    
    setup_cron_jobs "$PROJECT_NAME" "$SITE_PATH" "$PROJECT_USER"
    create_deploy_script "$PROJECT_NAME" "$SITE_PATH"
    
    # Save project info
    cat > "$SITE_PATH/.deploy-info" << EOF
PROJECT_NAME="$PROJECT_NAME"
PRIMARY_DOMAIN="$PRIMARY_DOMAIN"
DOMAINS=(${DOMAINS[*]})
PHP_VERSION="$PHP_VERSION"
PROJECT_USER="$PROJECT_USER"
SITE_PATH="$SITE_PATH"
GITHUB_URL="$GITHUB_URL"
BRANCH="$BRANCH"
EOF
    
    print_success "🎉 Project deployed successfully!"
    echo ""
    echo -e "${CYAN}🔗 Site URL:${NC} https://$PRIMARY_DOMAIN"
    echo -e "${CYAN}📁 Project Path:${NC} $SITE_PATH"
    echo -e "${CYAN}👤 System User:${NC} $PROJECT_USER"
    
    if [[ -n "$GITHUB_URL" ]]; then
        echo ""
        echo -e "${YELLOW}🔑 SSH Public Key (Add to GitHub Deploy Keys):${NC}"
        cat "/home/$PROJECT_USER/.ssh/id_ed25519.pub"
    fi
}

# ============================================
# Update Existing Project
# ============================================
update_existing_project() {
    print_title "🔄 Update Existing Project"
    
    local projects=()
    for dir in /var/www/*/; do
        if [[ -f "$dir/.deploy-info" ]]; then
            source "$dir/.deploy-info"
            projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)")
        fi
    done
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        print_error "No deployed projects found"
        return 1
    fi
    
    select_option "Select project to update" "${projects[@]}"
    local project_index=$?
    local selected_project="${projects[$project_index]}"
    local project_name=$(echo "$selected_project" | cut -d' ' -f1)
    
    if [[ -f "/usr/local/bin/deploy-$project_name" ]]; then
        bash "/usr/local/bin/deploy-$project_name"
    else
        print_error "Deploy script not found for $project_name"
    fi
}

# ============================================
# Database Management
# ============================================
manage_databases() {
    print_title "🗄️ Database Management"
    
    local options=(
        "Create New Database"
        "Delete Database"
        "Export Database"
        "Import Database"
        "Back"
    )
    
    select_option "Choose operation" "${options[@]}"
    local choice=$?
    
    case $choice in
        0) create_database ;;
        1) delete_database ;;
        2) export_database ;;
        3) import_database ;;
        4) return ;;
    esac
}

create_database() {
    local db_name=$(ask_input "Database Name" "")
    local db_user=$(ask_input "Database User" "")
    local db_pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    
    mysql <<EOF
CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    print_success "Database $db_name created"
    echo -e "  ${CYAN}User:${NC} $db_user"
    echo -e "  ${CYAN}Password:${NC} $db_pass"
}

delete_database() {
    local db_name=$(ask_input "Database name to delete" "")
    if ask_yes_no "Are you sure you want to delete database $db_name?" "N"; then
        mysql -e "DROP DATABASE IF EXISTS $db_name;"
        print_success "Database $db_name deleted"
    fi
}

export_database() {
    local db_name=$(ask_input "Database name to export" "")
    local output_file="/root/${db_name}_$(date +%Y%m%d).sql"
    print_info "Exporting to $output_file..."
    mysqldump "$db_name" > "$output_file"
    print_success "Export completed"
}

import_database() {
    local db_name=$(ask_input "Database name to import into" "")
    local input_file=$(ask_input "Path to SQL file" "")
    if [[ -f "$input_file" ]]; then
        mysql "$db_name" < "$input_file"
        print_success "Import completed"
    else
        print_error "File not found"
    fi
}

# ============================================
# Entry point
# ============================================
check_root
main_menu
