#!/bin/bash
apt update -y && apt install -y vim git tmux ripgrep universal-ctags htop build-essential
apt install -y lua5.3 sshfs python3-pip net-tools && pip install neovim bat && git clone https://gitee.com/leoatchina/leovim.git /root/.leovim && cd /root/.leovim && ./install.sh all
