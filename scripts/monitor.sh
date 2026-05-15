#!/bin/bash
# ============================================
# سكربت مراقبة الأداء وإحصائيات النظام
# ============================================

# الألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# معلومات النظام
print_header "📊 إحصائيات النظام"

echo -e "${BLUE}💻 وحدة المعالجة المركزية (CPU):${NC}"
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
cpu_cores=$(nproc)
echo "    الاستخدام: ${cpu_usage}%"
echo "    عدد النوى: $cpu_cores"

if (( $(echo "$cpu_usage > 80" | bc -l) )); then
    echo -e "    ${RED}⚠️ ارتفاع في استخدام CPU!${NC}"
fi

echo ""
echo -e "${BLUE}💾 الذاكرة (RAM):${NC}"
free -h | grep "Mem:" | awk '{print "    المستخدمة: " $3 " / الإجمالي: " $2 " (" $3/$2*100 "%)"}'

echo ""
echo -e "${BLUE}💿 المساحة التخزينية (Disk):${NC}"
df -h / | tail -1 | awk '{print "    المستخدمة: " $3 " / الإجمالي: " $2 " (" $5 ")"}'

disk_percent=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_percent" -gt 85 ]; then
    echo -e "    ${RED}⚠️ المساحة التخزينية منخفضة!${NC}"
fi

echo ""
echo -e "${BLUE}🖥️ العمليات النشطة:${NC}"
echo "    العدد الإجمالي: $(ps aux | wc -l)"
echo "    العمليات قيد التشغيل: $(ps aux | grep -c " R ")"
echo "    العمليات في انتظار: $(ps aux | grep -c " S ")"

echo ""
echo -e "${BLUE}🌐 اتصالات الشبكة:${NC}"
echo "    اتصالات TCP النشطة: $(ss -t | tail -n +2 | wc -l)"
echo "    اتصالات UDP: $(ss -u | tail -n +2 | wc -l)"

echo ""
print_header "🐳 حاويات Docker"

if command -v docker &> /dev/null; then
    containers_total=$(docker ps -a | tail -n +2 | wc -l)
    containers_running=$(docker ps | tail -n +2 | wc -l)
    
    echo "    عدد الحاويات الكلي: $containers_total"
    echo "    حاويات قيد التشغيل: $containers_running"
    
    if [ "$containers_running" -gt 0 ]; then
        echo ""
        echo "    الحاويات النشطة:"
        docker ps --format "    table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2
    fi
else
    echo "    ⚠️ Docker غير مثبت"
fi

echo ""
print_header "🌐 مواقع Nginx"

sites_total=$(ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)
echo "    عدد المواقع المنشورة: $sites_total"

for site in /etc/nginx/sites-enabled/*; do
    if [ -f "$site" ]; then
        site_name=$(basename "$site")
        server_name=$(grep -E "server_name" "$site" | head -1 | awk '{print $2}' | sed 's/;//')
        echo "    - $site_name ($server_name)"
    fi
done

echo ""
print_header "🗄️ قواعد البيانات"

if command -v mysql &> /dev/null; then
    db_count=$(mysql -e "SHOW DATABASES;" | grep -v -E "Database|information_schema|performance_schema|mysql|sys" | wc -l)
    echo "    عدد قواعد البيانات: $db_count"
    
    # حجم قواعد البيانات
    echo ""
    echo "    حجم قواعد البيانات:"
    mysql -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES GROUP BY table_schema ORDER BY SUM(data_length + index_length) DESC LIMIT 10;" 2>/dev/null | tail -n +2 | while read db size; do
        echo "    - $db: ${size}MB"
    done
fi

echo ""
print_header "📈 توصيات الأداء"

# فحص وتحسينات مقترحة
if [ "$disk_percent" -gt 80 ]; then
    echo "    🔧 قم بتنظيف السجلات القديمة:"
    echo "       sudo journalctl --vacuum-time=7d"
    echo "       sudo apt autoremove --purge"
fi

if [ "$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)" -gt 90 ]; then
    echo "    🔧 قم بزيادة Swap:"
    echo "       sudo fallocate -l 2G /swapfile"
    echo "       sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
fi

# فحص PHP-FPM
for pool in /etc/php/*/fpm/pool.d/*.conf; do
    if [ -f "$pool" ]; then
        pool_name=$(basename "$pool" .conf)
        if systemctl is-active --quiet "php*-fpm"; then
            echo "    ✅ PHP-FPM pool: $pool_name يعمل"
        fi
    fi
done

echo ""
print_success "اكتملت عملية المراقبة"
