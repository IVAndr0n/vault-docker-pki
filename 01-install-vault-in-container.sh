#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Name:           01-install-vault-in-container.sh
# Description:    Installation and initial configuration of the Vault
# Code revision:  Andrey Eremchuk, https://github.com/IVAndr0n/
# ------------------------------------------------------------------------------
set -o xtrace

# Checking if a file with variables exists in the current directory
variables=config-docker.env
location="$(cd "$(dirname -- "$0")" && pwd -P)"

if [ -f "${location}/${variables}" ]; then
    echo "Loading variables from a ${variables} file"
    . "${location}/${variables}"
else
    echo "The ${variables} file was not found."
    exit 1
fi

# Function to install required components in RHEL/CentOS
install_prerequisites_rhel() {
  echo "Perform updates and install prerequisites"
  sudo yum-config-manager --enable rhui-REGION-rhel-server-releases-optional
  sudo yum-config-manager --enable rhui-REGION-rhel-server-supplementary
  sudo yum-config-manager --enable rhui-REGION-rhel-server-extras
  sudo yum -y check-update

  for package in "${required_packages_rhel[@]}"; do
    if ! command -v "${package}" >/dev/null 2>&1; then
      sudo yum install -q -y "${package}"
    fi
  done

  sudo systemctl start ntpd.service
  sudo systemctl enable ntpd.service
  sudo timedatectl set-timezone UTC
}

# Function to install required components in Debian/Ubuntu
install_prerequisites_ubuntu() {
  echo "Perform updates and install prerequisites"
  sudo apt -qq -y update

  for package in "${required_packages_ubuntu[@]}"; do
    if ! command -v "${package}" >/dev/null 2>&1; then
      sudo apt install -qq -y "${package}"
    fi
  done

  sudo systemctl start ntp.service
  sudo systemctl enable ntp.service
  sudo timedatectl set-timezone UTC
  echo "Disable reverse DNS lookup in SSH"
  sudo sh -c 'echo "\nUseDNS no" >> /etc/ssh/sshd_config'
  sudo service ssh restart
}

if command -v yum >/dev/null 2>&1; then
  echo "RHEL/CentOS system detected"
  install_prerequisites_rhel
  user_rhel
elif command -v apt >/dev/null 2>&1; then
  echo "Debian/Ubuntu system detected"
  install_prerequisites_ubuntu
  user_ubuntu
else
  echo "Prerequisites not installed and user not created due to OS detection failure"
  exit 1
fi

# Download Vault
echo "Download Vault"
curl -o ${download_dir}/${vault_zip} -fsSL ${vault_url} || {
  echo "Failed to download Vault ${vault_version}"
  exit 1
}

# Install Vault
echo "Installing Vault ${vault_version}"
sudo unzip -o ${download_dir}/${vault_zip} -d ${vault_dir_bin}
sudo chmod 0755 ${vault_dir_bin}/${vault_file_bin}

echo "Granting mlock syscall to vault binary"
sudo setcap cap_ipc_lock=+ep ${vault_dir_bin}/${vault_file_bin}

echo "$(${vault_dir_bin}/${vault_file_bin} --version)"

# Configuration Vault
echo "We create directories"
mkdir -p ${vault_dir_config}
mkdir -p ${vault_dir_data}
mkdir -p ${vault_dir_logs}
mkdir -p ${vault_dir_crt}
mkdir -p ${vault_dir_tls}

echo "Configuring Vault"
tee ${vault_dir_config}/${vault_file_config} <<EOF
listener "tcp" {
  address               = "0.0.0.0:8200"
  tls_disable           = 1
}
storage "file" {
    path                = "${docker_vault_dir_data}"
}
ui                      = true
disable_mlock           = true
log_level               = "error"
api_addr                = "http://${vault_server_fqdn}:8200"
EOF

docker network create -d bridge ${docker_network}

docker run -d \
  --name ${docker_container_name} \
  --network ${docker_network} \
  -p 8200:8200 \
  --restart=always \
  -v ${vault_dir_config}:${docker_vault_dir_config} \
  -v ${vault_dir_data}:${docker_vault_dir_data} \
  -v ${vault_dir_logs}:${docker_vault_dir_logs} \
  -v ${vault_dir_crt}:${docker_vault_dir_crt} \
  -v ${vault_dir_tls}:${docker_vault_dir_tls} \
  --cap-add=IPC_LOCK \
  hashicorp/vault vault server -config=${docker_vault_dir_config}/${vault_file_config}

# `hashicorp/vault server -dev -dev-root-token-id="root"  - dev mode`

sleep 5
export VAULT_ADDR=http://${vault_server_fqdn}:8200
export VAULT_SKIP_VERIFY=true
export VAULT_NAMESPACE=${namespace_vault}

vault status
