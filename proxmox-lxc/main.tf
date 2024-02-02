terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.13.0"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.10"
    }

    ssh = {
      source  = "loafoe/ssh"
      version = "2.6.0"
    }
  }
}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/${lower(data.coder_workspace.me.owner)}"
  auth = "token"
  startup_script = <<EOT
  #!/bin/sh
  until stat /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml > /dev/null 2> /dev/null; do sleep 1; done
  cat /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml | grep -v 'proxy-domain:\|app-name:\|bind-addr:' | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp

  echo "bind-addr: 127.0.0.1:13337" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp
  echo "proxy-domain: '$VSCODE_PROXY_URI'" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp
  echo "app-name: '$CODER_WORKSPACE_NAME'" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp

  mv /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml

  sudo systemctl restart code-server@${data.coder_workspace.me.owner}
  EOT

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat cpu"
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat mem"
  }
  metadata {
    key          = "home"
    display_name = "Home Usage"
    interval     = 600 # every 10 minutes
    timeout      = 30  # df can take a while on large filesystems
    script       = "coder stat disk --path /home/${lower(data.coder_workspace.me.owner)}"
  }
}

data "coder_parameter" "a10_cpu_cores_count" {
  name         = "a10_cpu_cores_count"
  display_name = "CPU Cores Count"
  description  = ""
  default      = 4
  type         = "string"
  icon         = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64' fill='rgba(255,255,255,1)'%3E%3Cpath d='M6 18H18V6H6V18ZM14 20H10V22H8V20H5C4.44772 20 4 19.5523 4 19V16H2V14H4V10H2V8H4V5C4 4.44772 4.44772 4 5 4H8V2H10V4H14V2H16V4H19C19.5523 4 20 4.44772 20 5V8H22V10H20V14H22V16H20V19C20 19.5523 19.5523 20 19 20H16V22H14V20ZM8 8H16V16H8V8Z'%3E%3C/path%3E%3C/svg%3E"
  mutable      = false
  option {
    name  = "1 vCpu"
    value = 1
  }
  option {
    name  = "2 vCpus"
    value = 2
  }
  option {
    name  = "4 vCpus"
    value = 4
  }
  option {
    name  = "6 vCpus"
    value = 6
  }
  option {
    name  = "8 vCpus"
    value = 8
  }
}

data "coder_parameter" "a20_memory_size" {
  name         = "a20_memory_size"
  display_name = "Memory Size"
  description  = ""
  default      = 4096
  type         = "string"
  icon         = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64' fill='rgba(255,255,255,1)'%3E%3Cpath d='M3 7H21V17H19V15H17V17H15V15H13V17H11V15H9V17H7V15H5V17H3V7ZM2 5C1.44772 5 1 5.44772 1 6V18C1 18.5523 1.44772 19 2 19H22C22.5523 19 23 18.5523 23 18V6C23 5.44772 22.5523 5 22 5H2ZM11 9H5V12H11V9ZM13 9H19V12H13V9Z'%3E%3C/path%3E%3C/svg%3E"
  mutable      = false
  option {
    name  = "1 GB"
    value = 1024
  }
  option {
    name  = "2 GB"
    value = 2048
  }
  option {
    name  = "4 GB"
    value = 4096
  }
  option {
    name  = "6 GB"
    value = 6144
  }
  option {
    name  = "8 GB"
    value = 8192
  }
}

data "coder_parameter" "a30_disk_size" {
  name         = "a30_disk_size"
  display_name = "Disk Size"
  description  = ""
  default      = 24
  type         = "string"
  icon         = "/icon/database.svg"
  mutable      = false
  option {
    name  = "8 GB"
    value = 8
  }
  option {
    name  = "16 GB"
    value = 16
  }
  option {
    name  = "24 GB"
    value = 24
  }
  option {
    name  = "32 GB"
    value = 32
  }
  option {
    name  = "64 GB"
    value = 64
  }
}

data "coder_parameter" "a40_should_install_code_server" {
  name         = "a40_should_install_code_server"
  display_name = "Install Code Server"
  description  = "Should Code Server be installed after deploy?"
  default      = 1
  type         = "string"
  icon         = "/icon/code.svg"
  mutable      = false
  option {
    name  = "Yes"
    value = 1
  }
  option {
    name  = "No"
    value = 0
  }
}


data "coder_workspace" "me" {
}

resource "coder_app" "code-server" {
  count        = data.coder_parameter.a40_should_install_code_server.value != 0 ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url != "" ? var.proxmox_api_url : null
  pm_user         = var.proxmox_api_user
  pm_password     = var.proxmox_api_password

  pm_tls_insecure = tobool(var.proxmox_api_insecure)

  # For debugging Terraform provider errors:
  pm_log_enable = true
  pm_log_file   = "/tmp/terraform-plugin-proxmox.log"
  pm_debug      = true
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

locals {
  vm_name         = replace("${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}", " ", "_")
  cpu_cores_count = data.coder_parameter.a10_cpu_cores_count.value
  memory_size     = data.coder_parameter.a20_memory_size.value
  disk_size       = data.coder_parameter.a30_disk_size.value
  code_server_bootstrap_script = (data.coder_parameter.a40_should_install_code_server.value == 0 ? "" : <<-EOT
CODE_SERVER_DOWNLOAD_URL=$(curl -sL https://api.github.com/repos/coder/code-server/releases/latest | jq -r '.assets[].browser_download_url' | grep 'amd64.deb')
curl -fL $CODE_SERVER_DOWNLOAD_URL -o /tmp/code_server.deb
dpkg -i /tmp/code_server.deb
rm /tmp/code_server.deb

systemctl enable --now code-server@${data.coder_workspace.me.owner}
EOT
  )
}

variable "proxmox_api_url" {
  description = "Proxmox API URL (example: https://pve.example.com/api2/json)"
  sensitive   = false
}

variable "proxmox_api_user" {
  description = "Proxmox API Username (example: coder@pve)"
  sensitive   = false
}

variable "proxmox_api_password" {
  description = "Proxmox API Password"
  sensitive   = true
}

variable "proxmox_api_insecure" {
  default     = "false"
  description = "Type \"true\" if you have an self-signed TLS certificate"

  validation {
    condition = contains([
      "true",
      "false"
    ], var.proxmox_api_insecure)
    error_message = "Specify true or false."
  }
  sensitive = false
}

variable "proxmox_ssh_host" {
  description = "Proxmox ssh host (example: \"pve.example.com\")"
  default     = "pve.example.com"
  sensitive   = false
}

variable "proxmox_ssh_user" {
  description = "Proxmox ssh username (example: \"root\")"
  default     = "root"
  sensitive   = false
}

variable "proxmox_ssh_key_path" {
  description = "Proxmox ssh key path (example: \"/home/coder/.ssh/id_rsa\")"
  default     = "/home/coder/.ssh/id_rsa"
  sensitive   = false
}

variable "vm_target_node" {
  description = "Container target PVE node (example: \"pve\")"
  default     = "pve"
  sensitive   = false
}

variable "vm_target_storage" {
  description = "Container target storage (example: \"local-lvm\")"
  default     = "local-lvm"
  sensitive   = false
}

variable "vm_target_bridge" {
  description = "Container bridge interface (example: \"vmbr0\")"
  default     = "vmbr0"
  sensitive   = false
}

resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Provision the proxmox VM
resource "proxmox_lxc" "lxc" {

  # This VM's data is persistent! 
  # It will stop/start, but is only
  # deleted when the Coder workspace is
  count = 1

  hostname    = local.vm_name
  target_node = var.vm_target_node

  ssh_public_keys = <<-EOT
    ${tls_private_key.rsa_4096.public_key_openssh}
  EOT

  # Preserve the network config.
  # see: https://github.com/Telmate/terraform-provider-proxmox/issues/112
  lifecycle {
    ignore_changes = [network]
  }

  hastate      = "started"
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  unprivileged = true
  cores        = parseint(local.cpu_cores_count, 10)
  memory       = parseint(local.memory_size, 10)

  features {
    nesting = true
  }
  
  #cpu     = "kvm64"
  rootfs {
    size    = "${parseint(local.disk_size, 10)}G"
    storage = var.vm_target_storage
  }
  network {
    name   = "eth0"
    bridge = var.vm_target_bridge
    ip     = "dhcp"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.proxmox_ssh_user
      host        = var.proxmox_ssh_host
      private_key = file(var.proxmox_ssh_key_path)
    }
    content     = <<EOT
#!/bin/bash
set -ex
export DEBIAN_FRONTEND=noninteractive
apt update -qq && apt install -yqqq sudo git curl jq htop nload locales vim
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
dpkg-reconfigure locales
update-locale LANG=en_US.UTF-8

adduser \
  --shell /bin/bash \
  --gecos 'User for workspace owner' \
  --disabled-password \
  --home '/home/${lower(data.coder_workspace.me.owner)}' \
  '${lower(data.coder_workspace.me.owner)}'

usermod -aG sudo ${lower(data.coder_workspace.me.owner)}

echo '${lower(data.coder_workspace.me.owner)} ALL=(ALL) NOPASSWD: ALL' | tee /etc/sudoers.d/${lower(data.coder_workspace.me.owner)}

mkdir -p /opt/coder
echo '${coder_agent.main.init_script}' | tee /opt/coder/init
chmod 0755 /opt/coder/init

echo '[Unit]
Description=Coder Agent
After=network-online.target
Wants=network-online.target

[Service]
User=${data.coder_workspace.me.owner}
ExecStart=/opt/coder/init
Environment=CODER_AGENT_TOKEN=${coder_agent.main.token}
Restart=always
RestartSec=10
TimeoutStopSec=90
KillMode=process

OOMScoreAdjust=-900
SyslogIdentifier=coder-agent

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/coder-agent.service

${local.code_server_bootstrap_script}

systemctl enable --now coder-agent

until [[ $(systemctl is-active coder-agent) == "active" ]]; do sleep 1; done

sudo -u ${lower(data.coder_workspace.me.owner)} mkdir -p /home/${data.coder_workspace.me.owner}/.config/code-server
sudo -u ${lower(data.coder_workspace.me.owner)} echo "proxy-domain: '$VSCODE_PROXY_URI'" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.tmp
sudo -u ${lower(data.coder_workspace.me.owner)} echo "app-name: '$CODER_WORKSPACE_NAME'" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.tmp


EOT
    destination = "/tmp/proxmox_lxc_${local.vm_name}_coder_agent_bootstrap.sh"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.proxmox_ssh_user
      host        = var.proxmox_ssh_host
      private_key = file(var.proxmox_ssh_key_path)
    }
    inline = [
      "lxc-wait $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') -s RUNNING",
      "pct push $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') /tmp/proxmox_lxc_${local.vm_name}_coder_agent_bootstrap.sh /coder_agent_bootstrap.sh",
      "pct exec $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') /bin/bash /coder_agent_bootstrap.sh"
    ]
  }
}

# Stop the VM from the console
resource "null_resource" "stop_vm" {

  count = data.coder_workspace.me.transition == "stop" ? 1 : 0

  depends_on = [
    proxmox_lxc.lxc
  ]

  connection {
    type        = "ssh"
    user        = var.proxmox_ssh_user
    host        = var.proxmox_ssh_host
    private_key = file(var.proxmox_ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = ["pct stop $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}')"]
  }
}
