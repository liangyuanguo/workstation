#!/bin/bash

master_node_ip=$1
proxy=$2
domain=$3
zerotier_net=${4:-"-"}

cluster_crcd=$(sudo cat /var/snap/microk8s/current/args/kube-proxy  | grep cluster-cidr | awk -F "=" '{print $2}')
if [ -z "$cluster_crcd" ]; then
    echo "Usage: $0 master_node_ip [proxy [cluster_crcd [zerotier_net]]]"
    exit 1
fi

# 装包
sudo apt update
# sudo apt install -y ssh
snap list | awk '{print $1}' | grep microk8s || sudo snap install microk8s --classic
# join k8s 记得先关闭代理，或设置no_proxy


ip a s | grep "$master_node_ip/" -q
if [ $? -eq 0 ]; then
    mkdir /home/ubuntu/.kube
    sudo microk8s.config > /home/ubuntu/.kube/config
    sudo chmod 600 /home/ubuntu/.kube/config
    sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
    snap list | awk '{print $1}' | grep kubectl || sudo snap install kubectl --classic
    # snap list | awk '{print $1}' | grep docker || sudo snap install docker
    snap list | awk '{print $1}' | grep zerotier || sudo snap install zerotier
    sudo snap enable zerotier

    if [ $zerotier_net != "-" ]; then
        sudo zerotier-cli join $zerotier_net
    fi

fi

if ! [ -z "$proxy" ]; then
    cat /etc/environment | grep -v PROXY  > /tmp/env
    echo "HTTPS_PROXY=http://${proxy}" >> /tmp/env
    echo "HTTP_PROXY=http://${proxy}" >> /tmp/env
    echo "NO_PROXY=localhost,127.0.0.1,.local,*.local,.internal,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,${cluster_crcd},*.${domain},${domain}" >> /tmp/env
    sudo mv /tmp/env /etc/environment
    cat /etc/bash.bashrc | awk '!/export / && !/PROXY/ && !/ */'   > /tmp/bashrc
    echo "export HTTPS_PROXY=http://${proxy}" >> /tmp/bashrc
    echo "export HTTP_PROXY=http://${proxy}" >> /tmp/bashrc
    echo "export NO_PROXY=localhost,127.0.0.1,.local,*.local,.internal,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,${cluster_crcd},*.${domain},${domain}" >> /tmp/bashrc
    sudo mv /tmp/bashrc /etc/bash.bashrc
fi

