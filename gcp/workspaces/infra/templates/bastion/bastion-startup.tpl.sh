#!/bin/bash
set +e

function writeLog() {
    echo -e "\n\n$(date -Iseconds) ##### $1\n"
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

# install gcp cli
writeLog "installing gcp cli"
curl -sSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update -y
sudo apt-get install -y google-cloud-cli
gcloud version

# authenticating gcp cli
writeLog "authenticating gcp cli"
gcloud auth activate-service-account -q --key-file=/home/${admin_user}/auth_token.json
gcloud config set project ${project} -q
sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin

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
curl -fsSL https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
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

# Create and configure aliases file
writeLog "configuring aliases for ubuntu"
cat > /home/ubuntu/.bash_aliases << 'EOF'
# Kubernetes aliases
alias k=kubectl
alias kg="kubectl get"
alias kd="kubectl describe"
alias kl="kubectl logs"
alias kx="kubectl exec -it"
alias ksec="kubectl get secret -n paragon paragon-secrets -o jsonpath='{.data}' | jq -r 'to_entries[] | \"\(.key): \(.value | @base64d)\"' | sort"
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

# Common aliases
alias ll="ls -Ahl"
alias hi="history | grep"
EOF

# Ensure proper permissions
chown ubuntu:ubuntu /home/ubuntu/.bash_aliases
chmod 644 /home/ubuntu/.bash_aliases

# configure gke and kubectl
writeLog "configuring k8s tools as ubuntu"
sudo -u ubuntu gcloud container clusters get-credentials --region ${region} ${cluster_name}
sudo -u ubuntu kubectl config set-context --current --namespace=paragon

writeLog "paragon setup complete"
