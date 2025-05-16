#!/usr/bin/env bash
exit

function install_k3s_control(){

# @control node install
sudo ./k3s_control.sh install
TOKEN=$(sudo cat /etc/k3s-join-token)
tail -f /var/log/k3s-setup/control-node-setup.log
# For control node
sudo journalctl -u k3s

}

function install_k3s_worker(){
# @worker node install
sudo ./k3s_er.sh install 192.168.1.47 22989504d75b0e88cb3998e4d3462c38
sudo ./k3s_er.sh install <control_ip_addr> $TOKEN
# For worker nodes
sudo journalctl -u k3s-agent
}

function static_ip() {
    conn_name="enp1s0"
    ipv4_addr="192.168.122.103"
    netmask="24"
    gateway="192.168.122.1"
    dns_server="8.8.8.8,8.8.4.4"
    interface="enp1s0"
    sudo nmcli con mod "$conn_name" \
        ipv4.method "manual" \
        ipv4.addresses "$ipv4_addr/$netmask" \
        ipv4.gateway "$gateway" \
        ipv4.dns "$dns_server"

    sudo nmcli con up "$conn_name"
    sudo systemctl restart NetworkManager
    ip -4 a
}

function test_deploy(){
    # test deploy a snake game
    sudo firewall-cmd --permanent --add-port=30081/tcp
    sudo firewall-cmd --reload
    sudo firewall-cmd --list-ports

    # make sure git is installed
    git clone https://github.com/skynet86/hello-world-k8s.git
    cd hello-world-k8s
    k3s kubectl create -f hello-world.yaml
}