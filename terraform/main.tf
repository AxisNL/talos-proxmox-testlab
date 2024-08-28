terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc3"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "talos-01" {
  vmid          = 201
  target_node = var.pm_host
  name        = "talos-01"
  cores       = 4
  sockets     = 1
  cpu         = "host"
  memory      = 8196
  vm_state    = "running"
  os_type     = "ubuntu"
  scsihw      = "virtio-scsi-pci"
  network {
    bridge    = "vmbr1"
    firewall  = false
    link_down = false
    model     = "virtio"
  }
  agent = 1
  disks {
    ide {
      ide2 {
        cdrom {
          iso = "local:iso/talos-metal-amd64-with-agent.iso"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          discard    = true
          emulatessd = true
          size       = "20G"
          storage    = "local-zfs"
        }
      }
      scsi1 {
        disk {
          discard    = true
          emulatessd = true
          size       = "60G"
          storage    = "local-zfs"
        }
      }
    }
  }
}

output "proxmox_ip_address_talos_01" {
  value = proxmox_vm_qemu.talos-01.*.default_ipv4_address
}

resource "proxmox_vm_qemu" "talos-02" {
  vmid          = 202
  target_node = var.pm_host
  name        = "talos-02"
  cores       = 4
  sockets     = 1
  cpu         = "host"
  memory      = 8196
  vm_state    = "running"
  os_type     = "ubuntu"
  scsihw      = "virtio-scsi-pci"
  network {
    bridge    = "vmbr1"
    firewall  = false
    link_down = false
    model     = "virtio"
  }
  agent = 1
  disks {
    ide {
      ide2 {
        cdrom {
          iso = "local:iso/talos-metal-amd64-with-agent.iso"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          discard    = true
          emulatessd = true
          size       = "20G"
          storage    = "local-zfs"
        }
      }
      scsi1 {
        disk {
          discard    = true
          emulatessd = true
          size       = "60G"
          storage    = "local-zfs"
        }
      }
    }
  }
}

output "proxmox_ip_address_talos_02" {
  value = proxmox_vm_qemu.talos-02.*.default_ipv4_address
}

resource "proxmox_vm_qemu" "talos-03" {
  vmid          = 203
  target_node = var.pm_host
  name        = "talos-03"
  cores       = 4
  sockets     = 1
  cpu         = "host"
  memory      = 8196
  vm_state    = "running"
  os_type     = "ubuntu"
  scsihw      = "virtio-scsi-pci"
  network {
    bridge    = "vmbr1"
    firewall  = false
    link_down = false
    model     = "virtio"
  }
  agent = 1
  disks {
    ide {
      ide2 {
        cdrom {
          iso = "local:iso/talos-metal-amd64-with-agent.iso"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          discard    = true
          emulatessd = true
          size       = "20G"
          storage    = "local-zfs"
        }
      }
      scsi1 {
        disk {
          discard    = true
          emulatessd = true
          size       = "60G"
          storage    = "local-zfs"
        }
      }
    }
  }
}

output "proxmox_ip_address_talos_03" {
  value = proxmox_vm_qemu.talos-03.*.default_ipv4_address
}

resource "proxmox_vm_qemu" "talos-04" {
  vmid          = 204
  target_node = var.pm_host
  name        = "talos-04"
  cores       = 4
  sockets     = 1
  cpu         = "host"
  memory      = 8196
  vm_state    = "running"
  os_type     = "ubuntu"
  scsihw      = "virtio-scsi-pci"
  network {
    bridge    = "vmbr1"
    firewall  = false
    link_down = false
    model     = "virtio"
  }
  agent = 1
  disks {
    ide {
      ide2 {
        cdrom {
          iso = "local:iso/talos-metal-amd64-with-agent.iso"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          discard    = true
          emulatessd = true
          size       = "20G"
          storage    = "local-zfs"
        }
      }
      scsi1 {
        disk {
          discard    = true
          emulatessd = true
          size       = "60G"
          storage    = "local-zfs"
        }
      }
    }
  }
}

output "proxmox_ip_address_talos_04" {
  value = proxmox_vm_qemu.talos-04.*.default_ipv4_address
}
