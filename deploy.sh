#!/bin/bash
# Laravel Deploy Pro v4.0
# سكربت نشر Laravel الاحترافي
# المطور: صالح (salehye)
# https://github.com/salehye/
# ============================================

set -e  # إيقاف التنفيذ عند أي خطأ

# ============================================
# الألوان والأنماط
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

# أيقونات
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
# المتغيرات العامة
# ============================================
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="Laravel Deploy Pro"
LOG_FILE="/var/log/laravel-deploy.log"
CONFIG_DIR="/etc/laravel-deploy"
TEMPLATE_DIR="$(dirname "$0")/config"

# ============================================
# دوال العرض
# ============================================
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                           ║"
    echo -e "║     ${WHITE}${ICON_ROCKET} LARADEPLOY PRO v${SCRIPT_VERSION} - نظام نشر Laravel الاحترافي${CYAN}                    ║"
    echo "║                                                                           ║"
    echo -e "║     ${DIM}نشر احترافي | Zero Downtime | SSL تلقائي | حماية متقدمة${CYAN}                          ║"
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
print_error() { echo -e "  ${RED}${ICON_ERROR}${NC} $1"; }
print_info() { echo -e "  ${BLUE}${ICON_INFO}${NC} $1"; }
print_warning() { echo -e "  ${YELLOW}${ICON_WARNING}${NC} $1"; }

# ============================================
# دوال الإدخال
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
            *) echo "  ${RED}الرجاء إدخال Y أو N${NC}" ;;
        esac
    done
}

ask_input() {
    local prompt="$1"
    local default="$2"
    local answer
    
    if [[ -n "$default" ]]; then
        echo -ne "  ${BLUE}📝${NC} $prompt [$default]: "
    else
        echo -ne "  ${BLUE}📝${NC} $prompt: "
    fi
    read answer
    echo "${answer:-$default}"
}

select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local choice
    
    echo -e "  ${BLUE}🔽${NC} $prompt"
    for i in "${!options[@]}"; do
        echo -e "    ${CYAN}$((i+1))${NC}) ${options[$i]}"
    done
    
    while true; do
        echo -ne "  ${YELLOW}اختر رقماً (1-${#options[@]}): ${NC}"
        read choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $((choice-1))
        fi
        echo -e "  ${RED}اختيار غير صحيح${NC}"
    done
}

# ============================================
# التحقق من الصلاحيات
# ============================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "هذا السكربت يحتاج صلاحيات root"
        echo "قم بتشغيل: sudo bash $0"
        exit 1
    fi
}

# ============================================
# الدوال الأساسية
# ============================================
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_dependencies() {
    print_title "التحقق من التبعيات"
    
    local deps=("curl" "wget" "git" "nginx" "php" "composer" "mysql")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "التبعيات المفقودة: ${missing[*]}"
        if ask_yes_no "هل تريد تثبيت التبعيات المفقودة؟" "Y"; then
            apt update
            for dep in "${missing[@]}"; do
                apt install -y "$dep"
            done
        else
            print_error "لا يمكن المتابعة بدون التبعيات المطلوبة"
            exit 1
        fi
    fi
    
    print_success "جميع التبعيات متوفرة"
}

# ============================================
# تثبيت Docker (اختياري)
# ============================================
install_docker() {
    if [[ -f "$(dirname "$0")/scripts/install-docker.sh" ]]; then
        bash "$(dirname "$0")/scripts/install-docker.sh"
    else
        print_info "تثبيت Docker..."
        curl -fsSL https://get.docker.com | bash
        systemctl enable docker
        systemctl start docker
        print_success "تم تثبيت Docker"
    fi
}

# ============================================
# القائمة الرئيسية
# ============================================
main_menu() {
    print_banner
    
    local options=(
        "نشر مشروع Laravel جديد"
        "تحديث مشروع موجود"
        "تعديل إعدادات مشروع"
        "حذف مشروع"
        "إدارة قواعد البيانات"
        "إعدادات الأمان"
        "أدوات إضافية"
        "النسخ الاحتياطي"
        "مراقبة الأداء"
        "الخروج"
    )
    
    select_option "القائمة الرئيسية" "${options[@]}"
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
# نشر مشروع جديد
# ============================================
deploy_new_project() {
    print_title "🚀 نشر مشروع Laravel جديد"
    
    # جمع المعلومات
    while true; do
        PROJECT_NAME=$(ask_input "اسم المشروع (أحرف، أرقام، نقاط، شرطات فقط)" "")
        # تنظيف أي مسافات زائدة
        PROJECT_NAME=$(echo "$PROJECT_NAME" | xargs)
        
        if [[ -z "$PROJECT_NAME" ]]; then
            print_error "اسم المشروع مطلوب"
        elif [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            print_error "اسم المشروع يحتوي على رموز غير مسموح بها"
        else
            break
        fi
    done
    
    # إضافة الدومينات
    DOMAINS=()
    while true; do
        domain=$(ask_input "أدخل اسم النطاق (مثال: example.com) - اتركه فارغاً للإنهاء" "")
        [[ -z "$domain" ]] && break
        domain=$(echo "$domain" | xargs)
        
        if [[ "$domain" =~ ^([a-zA-Z0-9](-*[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
            DOMAINS+=("$domain")
            print_success "تم إضافة $domain"
        else
            print_error "تنسيق اسم النطاق غير صحيح"
        fi
    done
    
    if [[ ${#DOMAINS[@]} -eq 0 ]]; then
        print_error "يجب إضافة دومين واحد على الأقل"
        return 1
    fi
    
    PRIMARY_DOMAIN="${DOMAINS[0]}"
    PROJECT_USER="${PROJECT_NAME//[.-]/_}"
    SITE_PATH="/var/www/$PRIMARY_DOMAIN"
    
    # اختيار الإعدادات
    PHP_VERSIONS=("8.3" "8.2" "8.1" "8.0")
    select_option "اختر إصدار PHP" "${PHP_VERSIONS[@]}"
    PHP_VERSION="${PHP_VERSIONS[$?]}"
    
    DB_TYPES=("MySQL" "PostgreSQL" "MariaDB" "لا تثبيت")
    select_option "اختر نوع قاعدة البيانات" "${DB_TYPES[@]}"
    DB_TYPE_INDEX=$?
    DB_TYPE="${DB_TYPES[$DB_TYPE_INDEX]}"
    
    if [[ "$DB_TYPE" != "لا تثبيت" ]]; then
        DB_NAME=$(ask_input "اسم قاعدة البيانات" "${PROJECT_USER}_db")
        DB_USER=$(ask_input "مستخدم قاعدة البيانات" "${PROJECT_USER}")
        DB_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    fi
    
    GITHUB_URL=$(ask_input "رابط GitHub (SSH) - اتركه فارغاً للرفع اليدوي" "")
    BRANCH=$(ask_input "الفرع (branch)" "main")
    
    # تأكيد المعلومات
    print_title "📋 تأكيد المعلومات"
    echo -e "  • المشروع: ${GREEN}$PROJECT_NAME${NC}"
    echo -e "  • الدومينات: ${GREEN}${DOMAINS[*]}${NC}"
    echo -e "  • PHP: ${GREEN}$PHP_VERSION${NC}"
    echo -e "  • قاعدة البيانات: ${GREEN}$DB_TYPE${NC}"
    [[ -n "$GITHUB_URL" ]] && echo -e "  • GitHub: ${GREEN}$GITHUB_URL${NC}"
    
    if ! ask_yes_no "هل جميع المعلومات صحيحة؟" "Y"; then
        print_error "تم إلغاء التثبيت"
        return 1
    fi
    
    # بدء التثبيت
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
    
    if ask_yes_no "هل تريد تثبيت SSL؟" "Y"; then
        install_ssl "${DOMAINS[@]}"
    fi
    
    if ask_yes_no "هل تريد تفعيل النشر التلقائي؟" "Y"; then
        setup_webhook "$PROJECT_NAME" "$PRIMARY_DOMAIN" "$BRANCH" "$PHP_VERSION"
    fi
    
    if ask_yes_no "هل تريد تفعيل Queue Worker؟" "Y"; then
        setup_supervisor "$PROJECT_NAME" "$SITE_PATH" "$PROJECT_USER"
    fi
    
    setup_cron_jobs "$PROJECT_NAME" "$SITE_PATH" "$PROJECT_USER"
    create_deploy_script "$PROJECT_NAME" "$SITE_PATH"
    
    # حفظ معلومات المشروع للتعديل مستقبلاً
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
    
    print_success "🎉 تم نشر المشروع بنجاح!"
    echo ""
    echo -e "${CYAN}🔗 رابط الموقع:${NC} https://$PRIMARY_DOMAIN"
    echo -e "${CYAN}📁 مسار المشروع:${NC} $SITE_PATH"
    echo -e "${CYAN}👤 مستخدم النظام:${NC} $PROJECT_USER"
    
    if [[ -n "$GITHUB_URL" ]]; then
        echo ""
        echo -e "${YELLOW}🔑 مفتاح SSH العام (أضفه في GitHub Deploy Keys):${NC}"
        cat "/home/$PROJECT_USER/.ssh/id_ed25519.pub"
    fi
}

# ============================================
# تعديل إعدادات مشروع
# ============================================
edit_existing_project() {
    print_title "⚙️ تعديل إعدادات مشروع"
    
    local projects=()
    local project_paths=()
    for dir in /var/www/*/; do
        if [[ -f "$dir/.deploy-info" ]]; then
            source "$dir/.deploy-info"
            projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)")
            project_paths+=("$dir")
        fi
    done
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        print_error "لا توجد مشاريع مثبتة"
        return 1
    fi
    
    select_option "اختر المشروع للتعديل" "${projects[@]}"
    local project_index=$?
    source "${project_paths[$project_index]}/.deploy-info"
    
    local edit_options=(
        "تغيير إصدار PHP"
        "تعديل الدومينات"
        "تعديل ملف .env"
        "الرجوع"
    )
    
    select_option "ماذا تريد أن تعدل؟" "${edit_options[@]}"
    local edit_choice=$?
    
    case $edit_choice in
        0) # تغيير PHP
            PHP_VERSIONS=("8.3" "8.2" "8.1" "8.0")
            select_option "اختر إصدار PHP الجديد" "${PHP_VERSIONS[@]}"
            NEW_PHP_VERSION="${PHP_VERSIONS[$?]}"
            
            install_php "$NEW_PHP_VERSION"
            setup_php_fpm "$PROJECT_USER" "$NEW_PHP_VERSION" "$SITE_PATH"
            setup_nginx "$PROJECT_NAME" "${DOMAINS[@]}" "$SITE_PATH" "$NEW_PHP_VERSION" "$PROJECT_USER"
            
            # تحديث .deploy-info
            sed -i "s/PHP_VERSION=.*/PHP_VERSION=\"$NEW_PHP_VERSION\"/" "$SITE_PATH/.deploy-info"
            print_success "تم تغيير إصدار PHP إلى $NEW_PHP_VERSION"
            ;;
            
        1) # تعديل الدومينات
            NEW_DOMAINS=()
            while true; do
                domain=$(ask_input "أدخل اسم النطاق الجديد (أو اتركه فارغاً للإنهاء)" "")
                [[ -z "$domain" ]] && break
                if [[ "$domain" =~ ^([a-zA-Z0-9](-*[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
                    NEW_DOMAINS+=("$domain")
                else
                    print_error "تنسيق غير صحيح"
                fi
            done
            
            if [[ ${#NEW_DOMAINS[@]} -gt 0 ]]; then
                setup_nginx "$PROJECT_NAME" "${NEW_DOMAINS[@]}" "$SITE_PATH" "$PHP_VERSION" "$PROJECT_USER"
                if ask_yes_no "هل تريد تحديث SSL للدومينات الجديدة؟" "Y"; then
                    install_ssl "${NEW_DOMAINS[@]}"
                fi
                # تحديث .deploy-info
                sed -i "s/DOMAINS=.*/DOMAINS=(${NEW_DOMAINS[*]})/" "$SITE_PATH/.deploy-info"
                sed -i "s/PRIMARY_DOMAIN=.*/PRIMARY_DOMAIN=\"${NEW_DOMAINS[0]}\"/" "$SITE_PATH/.deploy-info"
                print_success "تم تحديث الدومينات"
            fi
            ;;
            
        2) # تعديل .env
            if [[ -f "$SITE_PATH/current/.env" ]]; then
                nano "$SITE_PATH/current/.env"
                if ask_yes_no "هل تريد إعادة تشغيل الخدمات لتفعيل التغييرات؟" "Y"; then
                    sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" config:cache
                    systemctl reload "php$PHP_VERSION-fpm"
                fi
            else
                print_error "ملف .env غير موجود"
            fi
            ;;
    esac
}

# ============================================
# تحديث مشروع موجود
# ============================================
update_existing_project() {
    print_title "🔄 تحديث مشروع موجود"
    
    # البحث عن المشاريع المثبتة
    local projects=()
    for dir in /var/www/*/; do
        if [[ -f "$dir/.deploy-info" ]]; then
            source "$dir/.deploy-info"
            projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)")
        fi
    done
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        print_error "لا توجد مشاريع مثبتة"
        return 1
    fi
    
    select_option "اختر المشروع للتحديث" "${projects[@]}"
    local project_index=$?
    local selected_project="${projects[$project_index]}"
    local project_name=$(echo "$selected_project" | cut -d' ' -f1)
    
    # تنفيذ النشر
    if [[ -f "/usr/local/bin/deploy-$project_name" ]]; then
        bash "/usr/local/bin/deploy-$project_name"
    else
        print_error "لم يتم العثور على سكربت النشر للمشروع $project_name"
    fi
}

# ============================================
# حذف مشروع
# ============================================
delete_project() {
    print_title "🗑️ حذف مشروع بالكامل"
    
    local projects=()
    local project_paths=()
    for dir in /var/www/*/; do
        if [[ -f "$dir/.deploy-info" ]]; then
            source "$dir/.deploy-info"
            projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)")
            project_paths+=("$dir")
        fi
    done
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        print_error "لا توجد مشاريع مثبتة"
        return 1
    fi
    
    select_option "اختر المشروع للحذف" "${projects[@]}"
    local project_index=$?
    source "${project_paths[$project_index]}/.deploy-info"
    
    echo -e "${RED}${BOLD}⚠️ تحذير: سيتم حذف كافة ملفات المشروع وقواعد البيانات الخاصة به!${NC}"
    if ask_yes_no "هل أنت متأكد تماماً من حذف $PROJECT_NAME؟" "N"; then
        # حذف ملفات الموقع
        rm -rf "$SITE_PATH"
        rm -f "/etc/nginx/sites-enabled/$PROJECT_NAME"
        rm -f "/etc/nginx/sites-available/$PROJECT_NAME"
        rm -f "/etc/php/$PHP_VERSION/fpm/pool.d/$PROJECT_USER.conf"
        rm -f "/usr/local/bin/deploy-$PROJECT_NAME"
        rm -f "/etc/cron.d/$PROJECT_NAME"
        
        # حذف مستخدم النظام إذا طلب ذلك
        if ask_yes_no "هل تريد حذف مستخدم النظام $PROJECT_USER؟" "N"; then
            userdel -r "$PROJECT_USER" 2>/dev/null || true
        fi
        
        # حذف قاعدة البيانات إذا وجدت في المعلومات
        if [[ -n "$DB_NAME" ]]; then
            if ask_yes_no "هل تريد حذف قاعدة البيانات $DB_NAME؟" "N"; then
                mysql -e "DROP DATABASE IF EXISTS $DB_NAME;"
                mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
                print_success "تم حذف قاعدة البيانات"
            fi
        fi
        
        systemctl reload nginx
        systemctl reload "php$PHP_VERSION-fpm"
        
        print_success "تم حذف المشروع $PROJECT_NAME بنجاح"
    else
        print_info "تم إلغاء عملية الحذف"
    fi
}

# ============================================
# إدارة قواعد البيانات
# ============================================
manage_databases() {
    print_title "🗄️ إدارة قواعد البيانات"
    
    local options=(
        "إنشاء قاعدة بيانات جديدة"
        "حذف قاعدة بيانات"
        "تصدير قاعدة بيانات"
        "استيراد قاعدة بيانات"
        "الرجوع"
    )
    
    select_option "اختر عملية" "${options[@]}"
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
    local db_name=$(ask_input "اسم قاعدة البيانات" "")
    local db_user=$(ask_input "اسم المستخدم" "")
    local db_pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    
    mysql <<EOF
CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    print_success "تم إنشاء قاعدة البيانات $db_name"
    echo -e "  ${CYAN}المستخدم:${NC} $db_user"
    echo -e "  ${CYAN}كلمة المرور:${NC} $db_pass"
}

delete_database() {
    local db_name=$(ask_input "اسم قاعدة البيانات للحذف" "")
    if ask_yes_no "هل أنت متأكد من حذف قاعدة البيانات $db_name؟" "N"; then
        mysql -e "DROP DATABASE IF EXISTS $db_name;"
        print_success "تم حذف قاعدة البيانات $db_name"
    fi
}

export_database() {
    local db_name=$(ask_input "اسم قاعدة البيانات للتصدير" "")
    local output_file="/root/${db_name}_$(date +%Y%m%d).sql"
    print_info "جاري التصدير إلى $output_file..."
    mysqldump "$db_name" > "$output_file"
    print_success "تم التصدير بنجاح"
}

import_database() {
    local db_name=$(ask_input "اسم قاعدة البيانات للاستيراد إليها" "")
    local input_file=$(ask_input "مسار ملف SQL" "")
    if [[ -f "$input_file" ]]; then
        mysql "$db_name" < "$input_file"
        print_success "تم الاستيراد بنجاح"
    else
        print_error "الملف غير موجود"
    fi
}

# ============================================
# إعدادات الأمان
# ============================================
security_settings() {
    print_title "🛡️ إعدادات الأمان"
    
    local options=(
        "تثبيت Fail2Ban (حماية هجمات القوة الغاشمة)"
        "تثبيت ModSecurity (جدار حماية التطبيقات)"
        "تأمين SSH"
        "فحص الثغرات"
        "الرجوع"
    )
    
    select_option "اختر الإعداد" "${options[@]}"
    local choice=$?
    
    case $choice in
        0) setup_fail2ban ;;
        1) setup_modsecurity ;;
        2) harden_ssh ;;
        3) scan_vulnerabilities ;;
        4) return ;;
    esac
}

setup_modsecurity() {
    print_info "تثبيت ModSecurity لـ Nginx..."
    apt install -y libnginx-mod-http-modsecurity
    mkdir -p /etc/nginx/modsec
    wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/owasp-modsecurity-crs/v3.2/master/crs-setup.conf.example
    print_success "تم تثبيت ModSecurity الأساسي"
}

harden_ssh() {
    print_info "تأمين SSH..."
    sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    print_warning "تنبيه: تم تعطيل تسجيل الدخول بكلمة المرور. تأكد من وجود مفتاح SSH الخاص بك!"
    systemctl restart ssh
    print_success "تم تأمين SSH"
}

scan_vulnerabilities() {
    print_title "🔍 فحص الثغرات الأساسي"
    print_info "فحص المنافذ المفتوحة..."
    netstat -tulpn | grep LISTEN
    print_info "فحص تحديثات النظام..."
    apt list --upgradable
    print_success "اكتمل الفحص"
}

# ============================================
# أدوات إضافية
# ============================================
extra_tools() {
    print_title "🛠️ أدوات إضافية"
    
    local options=(
        "تبديل وضع الصيانة (Maintenance Mode)"
        "مستعرض السجلات (Log Viewer)"
        "إعداد مساحة التبادل (Swap Memory)"
        "إعداد الجدار الناري (UFW Firewall)"
        "تثبيت Node.js & NPM"
        "الرجوع"
    )
    
    select_option "اختر أداة" "${options[@]}"
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
    local project_paths=()
    for dir in /var/www/*/; do
        if [[ -f "$dir/.deploy-info" ]]; then
            source "$dir/.deploy-info"
            projects+=("$PROJECT_NAME ($PRIMARY_DOMAIN)")
            project_paths+=("$dir")
        fi
    done
    
    select_option "اختر المشروع" "${projects[@]}"
    local idx=$?
    source "${project_paths[$idx]}/.deploy-info"
    
    if sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" down --help &>/dev/null; then
        if ask_yes_no "هل تريد تفعيل وضع الصيانة؟ (Down)" "Y"; then
            sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" down
            print_success "الموقع الآن في وضع الصيانة"
        else
            sudo -u "$PROJECT_USER" php "$SITE_PATH/current/artisan" up
            print_success "الموقع الآن متاح للجميع"
        fi
    else
        print_error "لا يمكن تنفيذ الأمر، تأكد من وجود ملف artisan"
    fi
}

log_viewer() {
    local options=("Nginx Access" "Nginx Error" "PHP-FPM Error" "Laravel Logs")
    select_option "أي سجل تريد قراءته؟" "${options[@]}"
    local choice=$?
    
    case $choice in
        0) tail -n 50 /var/log/nginx/access.log ;;
        1) tail -n 50 /var/log/nginx/error.log ;;
        2) tail -n 50 /var/log/php*-fpm.log ;;
        3) 
            local projects=()
            for dir in /var/www/*/; do [ -f "$dir/.deploy-info" ] && projects+=("$(basename "$dir")"); done
            select_option "اختر المشروع" "${projects[@]}"
            local idx=$?
            tail -n 50 "/var/www/${projects[$idx]}/logs/php-error.log"
            ;;
    esac
}

setup_swap() {
    local size=$(ask_input "حجم الـ Swap (مثال: 2G)" "2G")
    print_info "جاري إعداد Swap بحجم $size..."
    fallocate -l "$size" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    print_success "تم إعداد Swap بنجاح"
}

setup_firewall() {
    print_info "إعداد UFW Firewall..."
    apt install -y ufw
    ufw allow OpenSSH
    ufw allow 'Nginx Full'
    ufw --force enable
    print_success "تم تفعيل الجدار الناري وفتح منافذ HTTP/HTTPS/SSH"
}

install_nodejs() {
    print_info "تثبيت Node.js & NPM..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt install -y nodejs
    print_success "تم تثبيت $(node -v)"
}

setup_fail2ban() {
    print_info "تثبيت Fail2Ban..."
    apt install -y fail2ban
    
    cat > /etc/fail2ban/jail.d/laravel.conf << 'EOF'
[nginx-laravel]
enabled = true
port = http,https
filter = nginx-laravel
logpath = /var/log/nginx/*access.log
maxretry = 10
bantime = 3600

[php-url-fopen]
enabled = true
filter = php-url-fopen
logpath = /var/log/php*.log
maxretry = 3
bantime = 3600
EOF

    systemctl restart fail2ban
    print_success "تم تثبيت Fail2Ban"
}

# ============================================
# النسخ الاحتياطي
# ============================================
backup_manager() {
    print_title "💾 إدارة النسخ الاحتياطي"
    
    if [[ -f "$(dirname "$0")/scripts/backup.sh" ]]; then
        bash "$(dirname "$0")/scripts/backup.sh"
    else
        print_info "إنشاء نسخة احتياطية..."
        local backup_dir="/var/backups/laravel"
        mkdir -p "$backup_dir"
        
        for site in /var/www/*/; do
            if [[ -f "$site/.deploy-info" ]]; then
                local site_name=$(basename "$site")
                local backup_file="$backup_dir/${site_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
                tar -czf "$backup_file" "$site"
                print_success "تم إنشاء نسخة احتياطية: $backup_file"
            fi
        done
    fi
}

# ============================================
# مراقبة الأداء
# ============================================
performance_monitor() {
    print_title "📊 مراقبة الأداء"
    
    if [[ -f "$(dirname "$0")/scripts/monitor.sh" ]]; then
        bash "$(dirname "$0")/scripts/monitor.sh"
    else
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}📊 إحصائيات النظام${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${CYAN}💻 وحدة المعالجة المركزية (CPU):${NC}"
        echo "    $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% مستخدم"
        echo ""
        echo -e "  ${CYAN}💾 الذاكرة (RAM):${NC}"
        free -h | grep "Mem:" | awk '{print "    المستخدمة: " $3 " / الإجمالي: " $2}'
        echo ""
        echo -e "  ${CYAN}💿 المساحة التخزينية (Disk):${NC}"
        df -h / | tail -1 | awk '{print "    المستخدمة: " $3 " / الإجمالي: " $2 " (" $5 ")"}'
        echo ""
        echo -e "  ${CYAN}🖥️ العمليات النشطة:${NC}"
        echo "    $(ps aux | wc -l) عملية"
        echo ""
        echo -e "  ${CYAN}🌐 اتصالات الشبكة:${NC}"
        echo "    $(ss -tun | tail -n +2 | wc -l) اتصال نشط"
    fi
}

# ============================================
# الدوال المساعدة
# ============================================
install_system_packages() {
    print_title "تثبيت الحزم الأساسية"
    apt update
    apt install -y curl wget git unzip zip nginx jq software-properties-common
    print_success "تم تثبيت الحزم الأساسية"
}

install_php() {
    local version="$1"
    print_title "تثبيت PHP $version"
    
    add-apt-repository ppa:ondrej/php -y
    apt update
    
    local extensions="fpm cli common mysql zip gd mbstring curl xml bcmath tokenizer json redis"
    for ext in $extensions; do
        apt install -y "php$version-$ext"
    done
    
    print_success "تم تثبيت PHP $version"
}

install_database() {
    local type="$1"
    local db_name="$2"
    local db_user="$3"
    local db_pass="$4"
    
    if [[ "$type" == "لا تثبيت" ]]; then
        return
    fi
    
    print_title "تثبيت قاعدة البيانات $type"
    
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
    
    print_success "تم تثبيت قاعدة البيانات $db_name"
}

create_system_user() {
    local username="$1"
    print_title "إنشاء مستخدم النظام $username"
    
    if id "$username" &>/dev/null; then
        print_warning "المستخدم $username موجود بالفعل"
    else
        useradd -m -s /bin/bash "$username"
        print_success "تم إنشاء المستخدم $username"
    fi
    
    usermod -a -G www-data "$username"
}

create_directory_structure() {
    local site_path="$1"
    local username="$2"
    print_title "إنشاء هيكل المجلدات"
    
    mkdir -p "$site_path"/{public,storage,logs,bootstrap/cache,releases,shared}
    mkdir -p "$site_path/shared"/storage/{app,framework/{cache,sessions,views,data},logs}
    
    chown -R "$username":"$username" "$site_path"
    chmod -R 755 "$site_path"
    chmod -R 775 "$site_path"/storage
    chmod -R 775 "$site_path"/bootstrap/cache
    
    print_success "تم إنشاء هيكل المجلدات في $site_path"
}

clone_repository() {
    local repo_url="$1"
    local branch="$2"
    local site_path="$3"
    local username="$4"
    print_title "استنساخ المشروع من GitHub"
    
    # إنشاء مفتاح SSH
    mkdir -p "/home/$username/.ssh"
    ssh-keygen -t ed25519 -f "/home/$username/.ssh/id_ed25519" -N "" -q
    chown -R "$username":"$username" "/home/$username/.ssh"
    
    local release_id=$(date +%Y%m%d_%H%M%S)
    local release_dir="$site_path/releases/$release_id"
    
    sudo -u "$username" git clone "$repo_url" "$release_dir"
    sudo -u "$username" git -C "$release_dir" checkout "$branch"
    
    ln -sfn "$site_path/shared/storage" "$release_dir/storage"
    ln -sfn "$release_dir" "$site_path/current"
    
    print_success "تم استنساخ المشروع"
}

setup_environment() {
    local site_path="$1"
    local username="$2"
    local domain="$3"
    local db_type="$4"
    local db_name="$5"
    local db_user="$6"
    local db_pass="$7"
    print_title "إعداد ملف البيئة"
    
    local env_file="$site_path/current/.env"
    
    if [[ -f "$site_path/current/.env.example" ]]; then
        cp "$site_path/current/.env.example" "$env_file"
    else
        touch "$env_file"
    fi
    
    cat > "$env_file" << EOF
APP_NAME="${domain%.*}"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://$domain

LOG_CHANNEL=stack
LOG_LEVEL=debug

EOF

    if [[ "$db_type" != "لا تثبيت" ]]; then
        cat >> "$env_file" << EOF
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
    
    print_success "تم إعداد ملف .env"
}

install_composer_dependencies() {
    local site_path="$1"
    local username="$2"
    print_title "تثبيت تبعيات Composer"
    
    if ! command -v composer &> /dev/null; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
    fi
    
    sudo -u "$username" bash <<EOF
cd "$site_path/current"
composer install --no-interaction --optimize-autoloader --no-dev
php artisan key:generate
php artisan storage:link
php artisan config:cache
php artisan route:cache
php artisan view:cache
EOF
    
    print_success "تم تثبيت التبعيات"
}

run_migrations() {
    local site_path="$1"
    local username="$2"
    print_title "تشغيل هجرات قاعدة البيانات"
    
    sudo -u "$username" php "$site_path/current/artisan" migrate --force
    print_success "تم تشغيل الهجرات"
}

setup_php_fpm() {
    local username="$1"
    local php_version="$2"
    local site_path="$3"
    print_title "إعداد PHP-FPM"
    
    cat > "/etc/php/$php_version/fpm/pool.d/$username.conf" << EOF
[$username]
user = $username
group = $username

listen = /run/php/php$php_version-$username-fpm.sock
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

    systemctl restart "php$php_version-fpm"
    print_success "تم إعداد PHP-FPM"
}

setup_nginx() {
    local project_name="$1"
    local domains=("${@:2:${#@}-4}")
    local site_path="${@: -3:1}"
    local php_version="${@: -2:1}"
    local username="${@: -1}"
    
    print_title "إعداد Nginx"
    
    local server_names=$(printf "%s " "${domains[@]}" "www.${domains[@]}")
    
    cat > "/etc/nginx/sites-available/$project_name" << EOF
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
        fastcgi_pass unix:/run/php/php$php_version-$username-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.env {
        deny all;
        return 404;
    }
    
    location ~ /\.git {
        deny all;
        return 404;
    }
    
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
    
    print_success "تم إعداد Nginx"
}

install_ssl() {
    local domains=("$@")
    print_title "تثبيت SSL"
    
    if ! command -v certbot &> /dev/null; then
        apt install -y certbot python3-certbot-nginx
    fi
    
    local ssl_domains=""
    for domain in "${domains[@]}"; do
        ssl_domains="$ssl_domains -d $domain -d www.$domain"
    done
    
    certbot --nginx $ssl_domains --non-interactive --agree-tos --email "admin@${domains[0]}" --redirect
    
    print_success "تم تثبيت SSL"
}

setup_webhook() {
    local project_name="$1"
    local domain="$2"
    local branch="$3"
    local php_version="$4"
    print_title "إعداد Webhook للنشر التلقائي"
    
    local webhook_secret=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    local webhook_path="/var/www/webhooks/$project_name"
    mkdir -p "$webhook_path"
    
    cat > "$webhook_path/index.php" << 'PHPEOF'
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

    cat > "$webhook_path/.env" << EOF
WEBHOOK_SECRET=$webhook_secret
PROJECT_NAME=$project_name
BRANCH=$branch
EOF

    cat > "/etc/nginx/sites-available/webhook-$project_name" << EOF
server {
    listen 80;
    server_name webhook.$domain;
    root $webhook_path;
    
    location / {
        try_files \$uri /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$php_version-fpm.sock;
        fastcgi_param WEBHOOK_SECRET $webhook_secret;
        fastcgi_param PROJECT_NAME $project_name;
        fastcgi_param BRANCH $branch;
    }
}
EOF

    ln -sf "/etc/nginx/sites-available/webhook-$project_name" "/etc/nginx/sites-enabled/"
    nginx -t && systemctl reload nginx
    
    print_success "تم إعداد Webhook"
    echo -e "  ${CYAN}Webhook URL:${NC} http://webhook.$domain/"
    echo -e "  ${CYAN}Secret:${NC} $webhook_secret"
}

setup_supervisor() {
    local project_name="$1"
    local site_path="$2"
    local username="$3"
    print_title "إعداد Supervisor لـ Queue Worker"
    
    apt install -y supervisor
    
    cat > "/etc/supervisor/conf.d/${project_name}_worker.conf" << EOF
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

    supervisorctl reread
    supervisorctl update
    supervisorctl start "${project_name}_worker:*"
    
    print_success "تم إعداد Supervisor"
}

setup_cron_jobs() {
    local project_name="$1"
    local site_path="$2"
    local username="$3"
    print_title "إعداد المهام المجدولة"
    
    cat > "/etc/cron.d/$project_name" << EOF
* * * * * $username php $site_path/current/artisan schedule:run >> $site_path/logs/cron.log 2>&1
0 2 * * * $username php $site_path/current/artisan backup:run >> $site_path/logs/backup.log 2>&1
EOF

    chmod 644 "/etc/cron.d/$project_name"
    print_success "تم إعداد المهام المجدولة"
}

create_deploy_script() {
    local project_name="$1"
    local site_path="$2"
    print_title "إنشاء سكربت النشر السريع"
    
    cat > "/usr/local/bin/deploy-$project_name" << 'DEPLOYSCRIPT'
#!/bin/bash
PROJECT_NAME="$1"
SITE_PATH="/var/www/$PROJECT_NAME"
PROJECT_USER=$(stat -c '%U' "$SITE_PATH/current" 2>/dev/null || echo "www-data")
RELEASE_ID=$(date +%Y%m%d_%H%M%S)
RELEASE_PATH="$SITE_PATH/releases/$RELEASE_ID"

echo "🚀 بدء نشر $PROJECT_NAME..."

if [ ! -d "$SITE_PATH/current/.git" ]; then
    echo "❌ المشروع ليس مستنسخاً من Git"
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
sudo systemctl reload "php$PHP_VERSION-fpm"

cd "$SITE_PATH/releases" && ls -t | tail -n +6 | xargs -r rm -rf

echo "✅ تم نشر $PROJECT_NAME بنجاح!"
DEPLOYSCRIPT

    chmod +x "/usr/local/bin/deploy-$project_name"
    print_success "تم إنشاء سكربت النشر: deploy-$project_name"
}

# ============================================
# بدء التنفيذ
# ============================================
check_root
main_menu
