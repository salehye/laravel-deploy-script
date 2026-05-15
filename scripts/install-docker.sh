#!/bin/bash
# ============================================
# سكربت تثبيت Docker و Docker Compose
# ============================================

set -e

# الألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${YELLOW}ℹ️${NC} $1"; }

# التحقق من الصلاحيات
if [[ $EUID -ne 0 ]]; then
    print_error "هذا السكربت يحتاج صلاحيات root"
    exit 1
fi

print_info "بدء تثبيت Docker..."

# إزالة الإصدارات القديمة
print_info "إزالة الإصدارات القديمة..."
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# تثبيت التبعيات
print_info "تثبيت التبعيات..."
apt update
apt install -y ca-certificates curl gnupg lsb-release

# إضافة مفتاح Docker الرسمي
print_info "إضافة مفتاح Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# إضافة المستودع
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# تثبيت Docker
print_info "تثبيت Docker Engine..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# تثبيت Docker Compose (الإصدار القديم للتوافق)
print_info "تثبيت Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# إضافة المستخدم الحالي لمجموعة docker
usermod -aG docker $SUDO_USER 2>/dev/null || true

# تشغيل Docker
systemctl enable docker
systemctl start docker

# التحقق من التثبيت
if docker --version &> /dev/null; then
    print_success "تم تثبيت Docker بنجاح"
    docker --version
    docker-compose --version
else
    print_error "فشل تثبيت Docker"
    exit 1
fi

print_success "اكتمل التثبيت!"
