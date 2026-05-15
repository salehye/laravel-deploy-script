#!/bin/bash
# ============================================
# Docker & Docker Compose Installation Script
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${YELLOW}ℹ️${NC} $1"; }

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    print_error "This script requires root privileges"
    exit 1
fi

print_info "Starting Docker installation..."

# Remove old versions
print_info "Removing old versions..."
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install dependencies
print_info "Installing dependencies..."
apt update
apt install -y ca-certificates curl gnupg lsb-release

# Add Docker official GPG key
print_info "Adding Docker GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
print_info "Installing Docker Engine..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Docker Compose (standalone for compatibility)
print_info "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add current user to docker group
usermod -aG docker $SUDO_USER 2>/dev/null || true

# Start Docker
systemctl enable docker
systemctl start docker

# Verify installation
if docker --version &> /dev/null; then
    print_success "Docker installed successfully"
    docker --version
    docker-compose --version
else
    print_error "Docker installation failed"
    exit 1
fi

print_success "Installation complete!"
