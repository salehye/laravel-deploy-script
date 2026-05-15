#!/bin/bash
# ============================================
# Performance Monitor & System Statistics
# ============================================

# Colors
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

print_success() { echo -e "${GREEN}✅${NC} $1"; }

# System Info
print_header "📊 System Statistics"

echo -e "${BLUE}💻 CPU:${NC}"
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
cpu_cores=$(nproc)
echo "    Usage: ${cpu_usage}%"
echo "    Cores: $cpu_cores"

if (( $(echo "$cpu_usage > 80" | bc -l) )); then
    echo -e "    ${RED}⚠️ High CPU usage!${NC}"
fi

echo ""
echo -e "${BLUE}💾 Memory (RAM):${NC}"
free -h | grep "Mem:" | awk '{print "    Used: " $3 " / Total: " $2}'

echo ""
echo -e "${BLUE}💿 Disk Space:${NC}"
df -h / | tail -1 | awk '{print "    Used: " $3 " / Total: " $2 " (" $5 ")"}'

disk_percent=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_percent" -gt 85 ]; then
    echo -e "    ${RED}⚠️ Low disk space!${NC}"
fi

echo ""
echo -e "${BLUE}🖥️ Active Processes:${NC}"
echo "    Total: $(ps aux | wc -l)"
echo "    Running: $(ps aux | grep -c " R ")"
echo "    Sleeping: $(ps aux | grep -c " S ")"

echo ""
echo -e "${BLUE}🌐 Network Connections:${NC}"
echo "    Active TCP: $(ss -t | tail -n +2 | wc -l)"
echo "    Active UDP: $(ss -u | tail -n +2 | wc -l)"

echo ""
print_header "🐳 Docker Containers"

if command -v docker &> /dev/null; then
    containers_total=$(docker ps -a | tail -n +2 | wc -l)
    containers_running=$(docker ps | tail -n +2 | wc -l)
    
    echo "    Total containers: $containers_total"
    echo "    Running: $containers_running"
    
    if [ "$containers_running" -gt 0 ]; then
        echo ""
        echo "    Active containers:"
        docker ps --format "    table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2
    fi
else
    echo "    ⚠️ Docker is not installed"
fi

echo ""
print_header "🌐 Nginx Sites"

sites_total=$(ls /etc/nginx/sites-enabled/ 2>/dev/null | wc -l)
echo "    Deployed sites: $sites_total"

for site in /etc/nginx/sites-enabled/*; do
    if [ -f "$site" ]; then
        site_name=$(basename "$site")
        server_name=$(grep -E "server_name" "$site" | head -1 | awk '{print $2}' | sed 's/;//')
        echo "    - $site_name ($server_name)"
    fi
done

echo ""
print_header "🗄️ Databases"

if command -v mysql &> /dev/null; then
    db_count=$(mysql -e "SHOW DATABASES;" | grep -v -E "Database|information_schema|performance_schema|mysql|sys" | wc -l)
    echo "    Database count: $db_count"
    
    echo ""
    echo "    Database sizes:"
    mysql -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES GROUP BY table_schema ORDER BY SUM(data_length + index_length) DESC LIMIT 10;" 2>/dev/null | tail -n +2 | while read db size; do
        echo "    - $db: ${size}MB"
    done
fi

echo ""
print_header "📈 Performance Recommendations"

if [ "$disk_percent" -gt 80 ]; then
    echo "    🔧 Clean old logs:"
    echo "       sudo journalctl --vacuum-time=7d"
    echo "       sudo apt autoremove --purge"
fi

if [ "$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)" -gt 90 ]; then
    echo "    🔧 Consider increasing Swap:"
    echo "       sudo fallocate -l 2G /swapfile"
    echo "       sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
fi

# Check PHP-FPM pools
for pool in /etc/php/*/fpm/pool.d/*.conf; do
    if [ -f "$pool" ]; then
        pool_name=$(basename "$pool" .conf)
        if systemctl is-active --quiet "php*-fpm"; then
            echo "    ✅ PHP-FPM pool: $pool_name is running"
        fi
    fi
done

echo ""
print_success "Monitoring complete"
