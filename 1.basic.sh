#!/bin/bash
sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's/http:\/\/security.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list

timedatectl set-timezone Asia/Shanghai
apt update -y && apt install -y vim git tmux ripgrep universal-ctags htop build-essential
apt install -y lua53 sshfs python3-pip net-tools && pip install neovim bat
rm /root/.bashrc
git clone https://gitee.com/leoatchina/leovim.git ~/.leovim && cd ~/.leovim && bash install.sh all
