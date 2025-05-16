#!/bin/bash

# K3s Worker Node Setup Script
# Modular, Testable, and Logging-Enabled Deployment

# Logging Configuration
LOG_DIR="/var/log/k3s-setup"
LOG_FILE="${LOG_DIR}/worker-node-setup.log"

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
        log_message "INFO" "Configuring firewall for k3s worker"
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

# Install k3s worker node
install_k3s_worker() {
    log_message "INFO" "Installing k3s worker node"

    # Require control node IP and join token as arguments
    if [ $# -ne 2 ]; then
        log_message "ERROR" "Usage: install_k3s_worker CONTROL_NODE_IP JOIN_TOKEN"
        return 1
    fi

    local CONTROL_NODE_IP="${1}"
    local JOIN_TOKEN="${2}"

    # Install k3s worker with specific configurations
    INSTALL_K3S_EXEC="agent --server https://${CONTROL_NODE_IP}:6443 --token ${JOIN_TOKEN}"

    curl -sfL https://get.k3s.io | sh -s - ${INSTALL_K3S_EXEC} >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log_message "INFO" "K3s worker node installed successfully"
    else
        log_message "ERROR" "K3s worker node installation failed"
        return 1
    fi
}

# Verify k3s worker node installation
verify_k3s_worker() {
    log_message "INFO" "Verifying k3s worker node installation"

    # Check systemd k3s service status
    systemctl is-active k3s-agent >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log_message "INFO" "K3s worker node systemd service is active"
    else
        log_message "ERROR" "K3s worker node systemd service is not active"
        return 1
    fi

    # Additional verification checks could include checking logs, resource usage
    journalctl -u k3s-agent -n 50 >> "${LOG_FILE}" 2>&1

    log_message "INFO" "K3s worker node verified successfully"
}

# Manual k3s worker upgrade function
upgrade_k3s_worker() {
    log_message "INFO" "Initiating manual k3s worker node upgrade"

    # Backup current configuration
    cp /etc/systemd/system/k3s-agent.service /etc/systemd/system/k3s-agent.service.bak

    # Download and install latest k3s version
    curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - agent >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        systemctl restart k3s-agent
        log_message "INFO" "K3s worker node upgraded successfully"
    else
        log_message "ERROR" "K3s worker node upgrade failed"
        return 1
    fi
}

# Main execution function
main() {
    # Require control node IP and join token as arguments
    if [ $# -ne 2 ]; then
        log_message "ERROR" "Usage: $0 CONTROL_NODE_IP JOIN_TOKEN"
        exit 1
    fi

    setup_logging
    log_message "INFO" "Starting K3s Worker Node Setup"

    validate_prerequisites
    install_k3s_worker "${1}" "${2}"
    verify_k3s_worker

    log_message "INFO" "K3s Worker Node Setup Completed"
}

# Allow manual execution of specific functions
case "${1}" in
    "install")
        main "${2}" "${3}"
        ;;
    "upgrade")
        upgrade_k3s_worker
        ;;
    "verify")
        verify_k3s_worker
        ;;
    *)
        echo "Usage: $0 {install CONTROL_NODE_IP JOIN_TOKEN|upgrade|verify}"
        exit 1
        ;;
esac