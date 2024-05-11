#!/bin/bash


if [ $# -ne 1 ]; then    
    echo "Please input the k8s ctrl ip."
    exit 1
fi
ip=$1
scp ./calico.yaml root@$ip:/tmp && ssh -o StrictHostKeyChecking=no root@$ip 'kubectl apply -f /tmp/calico.yaml'