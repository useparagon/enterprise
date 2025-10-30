#!/bin/bash
set +e

function writeLog() {
    echo -e "\n\n$(date -Iseconds) $1\n"
}

writeLog "paragon setup starting as $(whoami) from $0"
sudo mkdir -p /etc/apt/keyrings

# enable timestamps in shell history
export HISTTIMEFORMAT="%F %T "
echo 'export HISTTIMEFORMAT="%F %T "' >> /home/ubuntu/.bashrc

# unattended support
export DEBIAN_FRONTEND=noninteractive
sudo systemctl stop unattended-upgrades

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

# install cloudflare zero trust and register tunnel
# see https://blog.cloudflare.com/automating-cloudflare-tunnel-with-terraform/
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
logfile: /var/log/cloudflared.log
loglevel: info

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
kubectl version

# install helm
writeLog "installing helm"
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install -y helm
helm version

# install nodejs
NODE_MAJOR=18
writeLog "installing node $NODE_MAJOR"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update -y
sudo apt-get install -y nodejs
sudo npm install -g npx
node --version

# install terraform
writeLog "installing terraform"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform
terraform version

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
systemctl disable containerd.service

# Create and configure aliases file
writeLog "configuring aliases for ubuntu"
cat > /home/ubuntu/.bash_aliases << 'EOF'
# Kubernetes aliases
alias k=kubectl
alias kd="kubectl describe"
alias kev="kubectl get events --sort-by='.lastTimestamp'"
alias kex="kubectl exec -it"
alias kg="kubectl get"
alias kl="kubectl logs"
alias krr="kubectl get deployments --no-headers -o custom-columns=\":metadata.name\" | xargs -I {} kubectl rollout restart deployment/{}"
alias kw="watch kubectl get pods"
alias kwf="watch -- 'kubectl get pods | grep -v fluent'"

kls() {
  local name=$1
  if [ -z "$name" ]; then
    echo "Usage: kls <service-name>"
    return 1
  fi
  shift
  kubectl logs -n paragon -l app.kubernetes.io/name="$name" --all-containers=true --prefix=true "$@"
}

ksec() {
  local name=$${1:-paragon-secrets}
  kubectl get secret $name -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"' | sort
}

# Common aliases
alias ll="ls -Ahl"
alias hi="history | grep"
EOF

# Ensure proper permissions
chown ubuntu:ubuntu /home/ubuntu/.bash_aliases
chmod 644 /home/ubuntu/.bash_aliases

# configure az, aks and kubectl
writeLog "configuring k8s tools as ubuntu"
sudo -u ubuntu az login --service-principal -u ${client_id} -p ${client_secret} --tenant ${tenant_id}
sudo -u ubuntu az account set --subscription ${subscription_id}
sudo -u ubuntu az aks get-credentials --overwrite-existing --resource-group ${resource_group} --name ${cluster_name}
sudo -u ubuntu kubectl config set-context --current --namespace=paragon

writeLog "paragon setup complete"
