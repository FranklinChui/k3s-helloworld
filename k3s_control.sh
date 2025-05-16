#!/bin/bash

# K3s Control Node Setup Script

# Logging Configuration
LOG_DIR="/var/log/k3s-setup"
LOG_FILE="${LOG_DIR}/control-node-setup.log"

# Ensure log directory exists
setup_logging() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
    chmod 644 "${LOG_FILE}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logging initialized" >> "${LOG_FILE}"
}

# Log function with timestamp and severity
log_message() {
    local severity="${1}"  # INFO, WARN, ERROR
    local message="${2}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${severity}] ${message}" | tee -a "${LOG_FILE}"
}

# Validate system prerequisites
validate_prerequisites() {
    log_message "INFO" "Validating system prerequisites"

    # Check firewall configuration
    local firewall_status=$(systemctl is-active firewalld)
    if [ "${firewall_status}" == "active" ]; then
        log_message "INFO" "Configuring firewall for k3s"
        firewall-cmd --permanent --add-port=6443/tcp
        firewall-cmd --permanent --add-port=10250/tcp
        firewall-cmd --reload
    fi

    # Verify kernel modules
    local required_modules=("br_netfilter" "overlay")
    for module in "${required_modules[@]}"; do
        if ! lsmod | grep -q "${module}"; then
            log_message "WARN" "Module ${module} not loaded. Attempting to load..."
            modprobe "${module}" || log_message "ERROR" "Failed to load ${module}"
        fi
    done

    # Ensure persistent kernel module loading
    cat > /etc/modules-load.d/k3s.conf << EOL
br_netfilter
overlay
EOL

    # Configure sysctl for kubernetes networking
    cat > /etc/sysctl.d/k3s.conf << EOL
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOL
    sysctl --system

    log_message "INFO" "Prerequisites validation completed"
}

# Install k3s control plane
install_k3s_control() {
    log_message "INFO" "Installing k3s control plane"

    # Generate a random token for node joining
    local JOIN_TOKEN=$(openssl rand -hex 16)

    # Install k3s with specific configurations
    INSTALL_K3S_EXEC="server --disable=traefik --write-kubeconfig-mode=644 --token=${JOIN_TOKEN}"

    curl -sfL https://get.k3s.io | sh -s - ${INSTALL_K3S_EXEC} >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log_message "INFO" "K3s control plane installed successfully"
        echo "${JOIN_TOKEN}" > /etc/k3s-join-token
        chmod 600 /etc/k3s-join-token
    else
        log_message "ERROR" "K3s control plane installation failed"
        return 1
    fi
}

# Verify k3s control plane installation
verify_k3s_control() {
    log_message "INFO" "Verifying k3s control plane installation"

    # Ensure k3s binary is in place
    if [ ! -f /usr/local/bin/k3s ]; then
        log_message "ERROR" "K3s binary not found in /usr/local/bin"
        return 1
    fi

    # Verify systemd service
    systemctl is-active k3s >> "${LOG_FILE}" 2>&1
    if [ $? -ne 0 ]; then
        log_message "ERROR" "K3s systemd service is not active"
        return 1
    fi

    # Wait for nodes to be ready
    local retries=10
    local node_ready=false
    while [ $retries -gt 0 ]; do
        if /usr/local/bin/k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; then
            node_ready=true
            break
        fi
        sleep 10
        ((retries--))
    done

    if [ "$node_ready" = false ]; then
        log_message "ERROR" "No nodes found ready after installation"
        return 1
    fi

    # Perform additional verification checks
    /usr/local/bin/k3s kubectl cluster-info >> "${LOG_FILE}" 2>&1
    /usr/local/bin/k3s kubectl get componentstatuses >> "${LOG_FILE}" 2>&1

    log_message "INFO" "K3s control plane verified successfully"
}

# Manual k3s upgrade function
upgrade_k3s_control() {
    log_message "INFO" "Initiating manual k3s control plane upgrade"

    # Backup current configuration
    cp /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.bak

    # Download and install latest k3s version
    curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - server >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        systemctl restart k3s
        log_message "INFO" "K3s control plane upgraded successfully"
    else
        log_message "ERROR" "K3s control plane upgrade failed"
        return 1
    fi
}

# Main execution function
main() {
    setup_logging
    log_message "INFO" "Starting K3s Control Node Setup"

    validate_prerequisites
    install_k3s_control
    verify_k3s_control

    log_message "INFO" "K3s Control Node Setup Completed"
}

# Allow manual execution of specific functions
case "${1}" in
    "install")
        main
        ;;
    "upgrade")
        upgrade_k3s_control
        ;;
    "verify")
        verify_k3s_control
        ;;
    *)
        echo "Usage: $0 {install|upgrade|verify}"
        exit 1
        ;;
esac