#!/bin/bash
sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's/http:\/\/security.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list

timedatectl set-timezone Asia/Shanghai
apt update -y && apt install -y vim git tmux ripgrep universal-ctags htop build-essential
apt install -y lua5.3 
apt install -y sshfs python3-pip net-tools && pip install neovim bat

rm /root/.bashrc

if [ -d ~/.leovim ]; then
    cd ~/.leovim && git pull
else
    git clone https://gitee.com/leoatchina/leovim.git ~/.leovim
fi
cd ~/.leovim && bash install.sh all

if [ $# -gt 0 ] && [ $1 -gt 104 ]; then
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/*
    sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo "sshd Done"
fi
