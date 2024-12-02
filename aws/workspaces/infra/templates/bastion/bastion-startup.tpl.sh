#!/bin/bash
set +e

function writeLog() {
    echo -e "\n\n$(date -Iseconds) $1\n"
}

writeLog "paragon setup starting as $(whoami) from $0"
sudo mkdir -p /etc/apt/keyrings

# install misc tools
writeLog "installing misc tools"
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    jq \
    make \
    redis-tools \
    unzip

# install aws cli v2
writeLog "installing aws cli v2"
sudo apt-get remove -y awscli
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
aws --version

# install kubectl
KUBECTL_MINOR=${cluster_version}
writeLog "installing kubectl $KUBECTL_MINOR"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubectl

# install eksctl
writeLog "installing eksctl"
curl -fsSL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# install helm
writeLog "installing helm"
curl -fsSL https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install -y helm

# install nodejs
NODE_MAJOR=18
writeLog "installing node $NODE_MAJOR"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update -y
sudo apt-get install -y nodejs
sudo npm install -g npx

# install terraform
writeLog "installing terraform"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform

# install docker
writeLog "installing docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update -y
sudo apt-get install -y \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin
sudo usermod -a -G docker ubuntu
# systemctl enable containerd.service
# service docker start

# install cloudflare zero trust and register tunnel
# see https://bwriteLog.cloudflare.com/automating-cloudflare-tunnel-with-terraform/
if [[ ! -z "${tunnel_id}" ]]; then
    writeLog "installing cloudflare tunnel"
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb

    sudo mkdir -p /etc/cloudflared

    cat > /etc/cloudflared/cert.json << EOF
{
    "AccountTag"   : "${account_id}",
    "TunnelID"     : "${tunnel_id}",
    "TunnelName"   : "${tunnel_name}",
    "TunnelSecret" : "${tunnel_secret}"
}
EOF

    sudo cat > /etc/cloudflared/config.yml << EOF
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/cert.json
writeLogfile: /var/writeLog/cloudflared.writeLog
writeLoglevel: info

ingress:
  - hostname: ${tunnel_name}
    service: ssh://localhost:22
  - hostname: "*"
    service: hello-world
EOF

    sudo cloudflared service install
    sudo systemctl start cloudflared
else
    writeLog "skipped cloudflare tunnel"
fi

# configure aws, eksctl and kubectl
# note that cluster may be still CREATING so wait up to 5 min for that to complete
writeLog "configuring k8s tools as root"
aws configure set region ${aws_region}
max_loops=10
current_loop=0
while [ $current_loop -lt $max_loops ]; do
    # aws eks --region ${aws_region} update-kubeconfig --name ${cluster_name}
    output=$(aws eks --region ${aws_region} update-kubeconfig --name ${cluster_name} 2>&1)
    if [[ ! $output =~ "CREATING" ]]; then
        break
    fi
    echo "Cluster still creating. Waiting for 30s."
    sleep 30
    ((current_loop++))
done
$(eksctl get iamidentitymapping --cluster ${cluster_name} --arn arn:aws:iam::${aws_account_id}:role/${bastion_role} || eksctl create iamidentitymapping --cluster ${cluster_name} --arn arn:aws:iam::${aws_account_id}:role/${bastion_role} --group system:masters --username ${bastion_role})
kubectl config set-context --current --namespace=paragon

writeLog "configuring k8s tools as ubuntu"
echo "alias k=kubectl" > /home/ubuntu/.bash_aliases && chown ubuntu:ubuntu /home/ubuntu/.bash_aliases
sudo -u ubuntu aws configure set region ${aws_region}
sudo -u ubuntu aws eks --region ${aws_region} update-kubeconfig --name ${cluster_name}
sudo -u ubuntu kubectl config set-context --current --namespace=paragon

writeLog "paragon setup complete"
