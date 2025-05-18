// ------- Proxmox Provisioning Template -------|>
// Template for cloning a terraform script to create
// clones of an existing template on the Cyber@UCI proxmox instance.
// Comprehensive docs for tags and explanations can be found here: 
// https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/vm_qemu
//
// Personal Notes:
// run `terraform apply` with the `-parallelism=1` to reduce disk bandwith taken
// avg allocation ~40-50sec (Arch Linux)
//
// ---------------------------------------------|>

/// ----------------------------------------------|>
/// VM Settings (Modify to change config)
/// ----------------------------------------------|>
locals {
  /// general settings
  total_vms = 2
  # vm_clone_list = "citri-ws-1a"
  QEMU_agent = 1 //< 0 (false) 1 (true)
  vm_state_after_creation = "running"

  /// general VM settings
  vmid_start_range = 35203
  vm_name_prefix   = "carnage-"
  vm_tags          = "terraform,ubuntu"
  vm_description   = "VMS Partitioned for CPTC Workshop."

  /// storage config
  pve_node      = "cuci-r730-pve02"
  pve_storage   = "pve-pool"
  vm_full_clone = false

  /// compute config
  vm_sockets = 1
  vm_cores   = 1
  vm_memory  = 2048

  /// network config
  vm_linux_bridge = "vmbr3"

  /// CI User Data

  // example for a 10.100.30.X/8 IP specification.
  # prefix_network_ip = "10.100.30."  // MAKE SURE IT ENDS IN A .
  # host_starting_ip_number = 0
  # postfix_network_ip = "/8" // INCLUDE SUBNET MASK

  prefix_network_ip       = "10.100.30." // MAKE SURE IT ENDS IN A .
  host_starting_ip_number = 42
  postfix_network_ip      = "/8" // INCLUDE SUBNET MASK
  gateway_ip              = "10.0.0.1"

  ci_username = "<username>"
  ci_password = "<password>"

  // configure Cloud-Init variables below in the resource.

}

/// ----------------------------------------------|>
/// END VM Settings
/// ----------------------------------------------|>

/// specify provider package, and required version.
terraform {
  required_providers {
    proxmox = {                   //< allows us to refer to path as "proxmox"
      source  = "telmate/proxmox" //< Grabs the proxmox provider support ("bgp/proxmox" is another provider) 
      version = "3.0.1-rc8"       //< Enforce usage of pre-release to avoid fatal error present in 2.X versions. pre-rc7 versions are breaking.
    }
  }
}

module "ranges" {
  source = "./modules/ranges"
}

module "secrets" {
  source = "./modules/secrets"
}

/// specifies the provider (api endpoint) that terraform is modifying.
provider "proxmox" {
  pm_api_url          = module.secrets.pm_api_url          //< URL to proxmox instance
  pm_api_token_id     = module.secrets.pm_api_token_id     //< PROXMOX TOKEN ID (Secrets)
  pm_api_token_secret = module.secrets.pm_api_token_secret //< PROXMOX API Token (Secrets)
  pm_tls_insecure     = true                               //< Enable TLS verification
}

/// provision a given resource, which is the qemu data.
resource "proxmox_vm_qemu" "vm-instance" {
  count       = local.total_vms
  name        = "${local.vm_name_prefix}${count.index+2}" //< Name of new VM (NAMES MUST BE UNIQUE, OR WILL FAIL)
  vmid        = local.vmid_start_range + count.index        //< VMID of new VM
  desc        = local.vm_description                        //< description of the vm (in notes)
  tags        = local.vm_tags                               //< tags applied to the vm
  agent       = local.QEMU_agent                            //< Enable QEMU agent on the VM
  target_node = local.pve_node                              //< node (cuci-r730-pve01)
  clone       = ""                                     //< target clone instance
  bios        = "seabios"                                   //< system BIOS
  full_clone  = local.vm_full_clone                         //< specify full(true)/linked(false) clone
  sockets     = local.vm_sockets                            //< specify number of sockets
  cores       = local.vm_cores                              //< specify number of cores
  memory      = local.vm_memory                             //< in MB

  os_type  = "cloud-init"
  vm_state = local.vm_state_after_creation //< state VM should be placed after creation

  scsihw = "virtio-scsi-single" //< SCSI controller (3.X specification)
  disks {
    ide {
      ide3 {
        cloudinit {
          storage = local.pve_storage
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = 32                //< size of the disk (GB)
          storage = local.pve_storage //< target storage pool
          asyncio = "io_uring"        //< asyncio setting (Default: io_uring)
        }
      }
    }
  }

  network {
    id       = 0                     //< specify network id
    model    = "virtio"              //< specify network card model (default virtio)
    bridge   = local.vm_linux_bridge //< linux bridge
    firewall = true                  //< specify enabling proxmox firewall
  }

  boot = "order=scsi0" //< ensure disk gets created before cloudinit

  /// Cloud-Init-based Variables (you need to change this)
  ciuser     = local.ci_username //< cloud-init username (comment out to disable)
  cipassword = local.ci_password //< cloud-init password (comment out to disable)
  ipconfig0  = "ip=${local.prefix_network_ip}${count.index + local.host_starting_ip_number}${local.postfix_network_ip},gw=${local.gateway_ip}"
}
