#!/bin/bash
set -e

echo ".........----------------#################._.-.-INSTALL STARTED-.-._.#################----------------........."

# ---- Update system ----
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release software-properties-common

# ---- Bash prompt color setup ----
PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '
if ! grep -q "force_color_prompt" ~/.bashrc; then
  echo "force_color_prompt=yes" >> ~/.bashrc
  echo "PS1='$PS1'" >> ~/.bashrc
fi
source ~/.bashrc

# ---- Install base tools ----
sudo apt-get install -y vim jq python3-pip build-essential git

# ---- Install Docker ----
echo ".........---------------- Installing Docker ----------------........."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get install -y docker.io containerd
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# ---- Configure containerd ----
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# ---- Install Kubernetes (v1.31 stable) ----
echo ".........---------------- Installing Kubernetes ----------------........."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet

# ---- Initialize K8s cluster ----
sudo kubeadm reset -f || true
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/16 --skip-token-print

mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# ---- Install Flannel CNI ----
echo ".........---------------- Installing Flannel Network ----------------........."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
sleep 10

# ---- Remove control-plane taint ----
echo "untaint controlplane node"
node=$(kubectl get nodes -o=jsonpath='{.items[0].metadata.name}')
kubectl taint nodes $node node-role.kubernetes.io/control-plane- || true

# ---- Install JC (JSON converter) ----
sudo pip3 install -U jc

# ---- Install Java 17 & Maven ----
echo ".........---------------- Installing Java and Maven ----------------........."
sudo apt install -y openjdk-17-jdk maven
java -version
mvn -v

# ---- Install Jenkins ----
echo ".........---------------- Installing Jenkins ----------------........."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo gpg --dearmor -o /usr/share/keyrings/jenkins.gpg
echo 'deb [signed-by=/usr/share/keyrings/jenkins.gpg] https://pkg.jenkins.io/debian-stable binary/' | sudo tee /etc/apt/sources.list.d/jenkins.list

sudo apt-get update
sudo apt-get install -y fontconfig jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo usermod -aG docker jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

echo ".........----------------#################._.-.-INSTALL COMPLETED SUCCESSFULLY-.-._.#################----------------........."
