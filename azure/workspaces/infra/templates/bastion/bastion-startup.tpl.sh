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
    lsb-release \
    make \
    redis-tools \
    unzip

# install azure cli
writeLog "installing azure cli"
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update -y
sudo apt-get install -y azure-cli
az version

# install kubectl
KUBECTL_MINOR=${cluster_version}
writeLog "installing kubectl $KUBECTL_MINOR"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubectl

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

# configure az, aks and kubectl
# note that cluster may be still CREATING so wait up to 5 min for that to complete
writeLog "configuring k8s tools as root"
az login --service-principal -u ${client_id} -p ${client_secret} --tenant ${tenant_id}
az account set --subscription ${subscription_id}
sudo az aks install-cli
max_loops=10
current_loop=0
while [ $current_loop -lt $max_loops ]; do
    # az aks get-credentials --overwrite-existing --resource-group ${resource_group} --name ${cluster_name}
    output=$(az aks get-credentials --overwrite-existing --resource-group ${resource_group} --name ${cluster_name} 2>&1)
    if [[ ! $output =~ "CREATING" ]]; then
        break
    else
        echo "OUTPUT: $output"
    fi
    echo "Cluster still creating. Waiting for 30s."
    sleep 30
    ((current_loop++))
done
kubectl config set-context --current --namespace=paragon

writeLog "configuring k8s tools as ubuntu"
echo "alias k=kubectl" > /home/ubuntu/.bash_aliases && chown ubuntu:ubuntu /home/ubuntu/.bash_aliases
sudo -u ubuntu kubectl config set-context --current --namespace=paragon

writeLog "paragon setup complete"
