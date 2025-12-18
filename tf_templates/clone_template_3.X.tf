// ------- Proxmox Provisioning Template -------|>
// Template for cloning a terraform script to create
// clones of an existing template on the Cyber@UCI proxmox instance.
// Comprehensive docs for tags and explanations can be found here: 
// https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/vm_qemu
// ---------------------------------------------|>

/// specify provider package, and required version.
terraform {
  required_providers {
    proxmox = {                   //< allows us to refer to path as "proxmox"
      source  = "telmate/proxmox" //< Grabs the proxmox provider support ("bgp/proxmox" is another provider)
      version = "3.0.1-rc7"       //< Enforce usage of pre-release to avoid fatal error present in 2.X versions.
    }
  }
}

/// specifies the provider (api endpoint) that terraform is modifying.
provider "proxmox" {
  pm_api_url          = "<url_here>"          //< URL to proxmox instance
  pm_api_token_id     = "<token_id_here>"     //< PROXMOX TOKEN ID (Secrets)
  pm_api_token_secret = "<secret_token_here>" //< PROXMOX API Token (Secrets)
  pm_tls_insecure     = true                  //< Enable TLS verification
}

/// provision a given resource, which is the qemu data.
resource "proxmox_vm_qemu" "vm-instance" {
  /// general configuration settings
  name        = "<vm_name>"     //< Name of the new VM
  vmid        = 7500            //< VMID of the new VM
  agent       = 1               //< Enable QEMU agent on the VM
  desc        = "<description>" //< description of the vm (in notes)
  tags        = "terraform"     //< tags applied to the vm 
  target_node = "<node_name>"   //< node (cuci-r730-pve01)
  clone       = "<target_name>" //< target clone instance
  bios        = "seabios"       //< system BIOS
  full_clone  = true            //< specify full/shallow clone
  sockets     = 2               //< specify number of sockets
  cores       = 2               //< specify number of cores
  memory      = 2048            //< in MB

  vm_state = "running" //< state VM should be placed after creation

  /// disk configuration settings
  scsihw = "virtio-scsi-single" //< SCSI controller (3.X specification)
  disks {
    scsi {
      scsi0 {
        disk {
          size    = 32         //< size of the disk (GB)
          storage = "pve-pool" //< target storage pool
          asyncio = "io_uring" //< asyncio setting (Default: io_uring)
        }
      }
    }
  }

  /// network configuration settings
  network {
    id       = 0        //< specify network id
    model    = "virtio" //< specify network card model (default virtio)
    bridge   = "vmbr3"  //< comp net, for workshops
    firewall = true     //< specify enabling proxmox firewall
  }
}
