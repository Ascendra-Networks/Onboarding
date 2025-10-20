# ...existing code...
#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <master|worker> [join-command]
  master        Run full master setup (includes kubeadm init and Calico install)
  worker        Run worker setup. Provide the full 'kubeadm join ...' command as second argument
                or paste it when prompted.
Examples:
  $0 master
  $0 worker "sudo kubeadm join 10.0.0.1:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
EOF
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

ROLE="$1"
JOIN_CMD="${2-}"

if [[ "$ROLE" != "master" && "$ROLE" != "worker" ]]; then
  usage
fi

echo "Selected role: $ROLE"

# Step 2: Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Step 3: Load containerd modules
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# Step 4: Configure Kubernetes IPv4 networking
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Step 5: Install Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Configure containerd
sudo mkdir -p /etc/containerd
sudo sh -c "containerd config default > /etc/containerd/config.toml"
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Step 6: Install Kubernetes components
sudo apt-get install -y curl ca-certificates apt-transport-https
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

if [[ "$ROLE" == "master" ]]; then
  # Step 7: Initialize Kubernetes cluster (only on master node)
  sudo ufw allow 6443
  sudo kubeadm init --pod-network-cidr=10.10.0.0/16

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Step 8: Install Calico network add-on plugin
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
  curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O
  sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 10.10.0.0\/16/g' custom-resources.yaml
  kubectl create -f custom-resources.yaml

  echo "Master setup complete. To add workers, run the displayed 'kubeadm join' command on each worker node."
else
  # Worker node flow
  if [ -z "$JOIN_CMD" ]; then
    echo "No join command provided. Paste the full 'kubeadm join ...' command (including sudo if required), then press Enter:"
    read -r JOIN_CMD
  fi

  if [ -z "$JOIN_CMD" ]; then
    echo "No join command supplied. Exiting."
    exit 1
  fi

  # Run the join command (use eval to allow full command with args)
  echo "Running join command..."
  eval "$JOIN_CMD"

  echo "Worker node has joined the cluster (if the join command succeeded)."
fi