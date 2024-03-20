#!/bin/bash
sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's/http:\/\/security.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list

apt update -y && apt install -y vim git tmux ripgrep universal-ctags htop build-essential
apt install -y lua5.3 sshfs python3-pip net-tools && pip install neovim bat
