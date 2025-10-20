# How to Install Kubernetes on Ubuntu 24.04

Based on the guide from [install-kubernetes-ubuntu](https://www.cherryservers.com/blog/install-kubernetes-ubuntu).

---

## Overview

This guide walks you through setting up a Kubernetes cluster on Ubuntu 24.04 using a custom installation script. It covers:

- Preparing nodes by disabling swap

- Installing Kubernetes components

- Configuring the master node

- Setting up your development machine

- Joining worker nodes to the cluster

- Troubleshooting common issues

---

## Installation Script

Use the following script to install Kubernetes on a node:

```bash

k8s_cluster/install_k8s_node.sh  --help

Usage:  k8s_cluster/install_k8s_node.sh <master|worker> [join-command]

master  Run  full  master  setup (includes kubeadm  init  and  Calico  install)

worker  Run  worker  setup.  Provide  the  full  'sudo kubeadm join ...'  command  as  second  argument

or  paste  it  when  prompted.

Examples:

k8s_cluster/install_k8s_node.sh  master

k8s_cluster/install_k8s_node.sh  worker  "sudo kubeadm join 10.0.0.1:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"

```
---

## Joining Worker Nodes

To add a worker node to the cluster:

1. Run the installation script with the join command:

```bash

k8s_cluster/install_k8s_node.sh  worker  "sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"

```

2. If you don’t have the join command, retrieve it from the master node:

```bash

kubeadm  token  create  --print-join-command

```

## Configure Dev Machine

To set up your development machine to access the cluster:

1. Install Kubernetes utilities:

```bash

sudo  apt  install  -y  kubelet  kubeadm  kubectl

```

2. Copy the Kubernetes config file from the master node:

```bash

scp  user@<master-ip>:/home/user/.kube/config  ~/.kube/config

```

3. Edit the config file on your dev machine:

Replace:

```yaml

server: https://127.0.0.1:6443

```

With:

```yaml

server: https://<master-node-ip>:6443

```

This ensures your dev machine communicates with the correct master node.

---

## Troubleshooting

-  **Swap not disabled**: Ensure swap is turned off on all nodes.
```bash
sudo  swapoff  -a
sudo  sed  -i  '/ swap / s/^/#/'  /etc/fstab
```

-  **Firewall issues**: Open required ports (e.g., 6443, 10250).

-  **Token expired**: Regenerate using `kubeadm token create`.

-  **Config file errors**: Double-check IP addresses and paths.

-  **Calico not working**: Verify network plugin installation.

---
