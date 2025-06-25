#!/bin/bash
############################################
#      🐧 Cloud-Init Template Server       #
#              v1.00 (C) 2025              #
#        by Psylla, The Little Flea        #
#   https://thelittleflea.com/prjx/ClITS   #
#                                          #
# Licensed Under:                          #
#   - https://thelittleflea.com/lic/mit    #
#                                          #
# Easily create a Cloud-Init enabled VM    #
# template with embedded common utilities  #
# accessible in the Proxmox UI.            #
#                                          #
#       Tested on Proxmox (PVE v8.4)       #
############################################

set -euo pipefail
clear

# -------------- Default Configs --------------
CONFIG_FILE="$HOME/.cloudinit-template.sh"

DEFAULT_BRANDING_TITLE="Cloud-Init Template Server"
DEFAULT_BRANDING_NAME="by Psylla, The Little Flea"
DEFAULT_BRANDING_URL="https://thelittleflea.com/prjx/ClITS"
DEFAULT_BRANDING_COPYRIGHT="(C) 2025"
DEFAULT_BRANDING_VERSION="v1.00"
DEFAULT_BRANDING_LOGO="🔧"
DEFAULT_BRANDING_LOGO_ICON="🐧"

DEFAULT_DELIMITER="|"
DEFAULT_STORAGE="local"
DEFAULT_NET_BRIDGE="vmbr0"
DEFAULT_VMUSER="vmuser"
DEFAULT_MEMORY=2048
DEFAULT_CORES=2


# -----------------------------------------------------------
# -------------- EDIT BELOW AT YOUR OWN PERIL ---------------
# -----------------------------------------------------------


# -------------- Load User Config --------------
if [[ -f "$CONFIG_FILE" ]]; then
  #source "$CONFIG_FILE"
  . "$CONFIG_FILE"  # POSIX Compliant
fi

BRANDING_TITLE="${BRANDING_TITLE:-$DEFAULT_BRANDING_TITLE}"
BRANDING_NAME="${BRANDING_NAME:-$DEFAULT_BRANDING_NAME}"
BRANDING_COPYRIGHT="${BRANDING_COPYRIGHT:-$DEFAULT_BRANDING_COPYRIGHT}"
BRANDING_VERSION="${BRANDING_VERSION:-$DEFAULT_BRANDING_VERSION}"
BRANDING_URL="${BRANDING_URL:-$DEFAULT_BRANDING_URL}"
BRANDING_LOGO="${BRANDING_LOGO:-$DEFAULT_BRANDING_LOGO}"
BRANDING_LOGO_ICON="${BRANDING_LOGO_ICON:-$DEFAULT_BRANDING_LOGO_ICON}"

DELIMITER="${DELIMITER:-$DEFAULT_DELIMITER}"
STORAGE="${STORAGE:-$DEFAULT_STORAGE}"
NET_BRIDGE="${NET_BRIDGE:-$DEFAULT_NET_BRIDGE}"
VMUSER="${VMUSER:-$DEFAULT_VMUSER}"
MEMORY="${MEMORY:-$DEFAULT_MEMORY}"
CORES="${CORES:-$DEFAULT_CORES}"

pause() {
  sleep "${1:-2}"
}

# ------------ Informational Header --------------
show_whiptail_header() {
    local header="${1:-"Welcome!"}"
    whiptail --title "$header" --msgbox "\
      ############################################
      #     $BRANDING_LOGO_ICON $BRANDING_TITLE        #
      #              $BRANDING_VERSION $BRANDING_COPYRIGHT              #
      #        $BRANDING_NAME        #
      #   $BRANDING_URL   #
      #                                          #
      # Licensed Under:                          #
      #   - https://thelittleflea.com/lic/mit    #
      #                                          #
      # Easily create a Cloud-Init enabled VM    #
      # template with embedded common utilities  #
      # accessible in the Proxmox UI.            #
      #                                          #
      #       Tested on Proxmox (PVE v8.4)       #
      ############################################" 20 60
}
show_whiptail_header

# -------------- Show On Exit --------------
check_whiptail_exit() {
  local exit_code="$1"
  local action="${2:-exit}"  # Default action is to exit

  if [ "$exit_code" -eq 255 ]; then
    whiptail --title "$BRANDING_TITLE" \
      show_whiptail_header "Operation cancelled by user. Exiting..."
      #--msgbox "Operation cancelled by user. Exiting..." 10 50
    [ "$action" = "return" ] && return 1 || exit 1
  elif [ "$exit_code" -ne 0 ]; then
    whiptail --title "$BRANDING_TITLE" \
      show_whiptail_header "Unexpected error occurred. Exit code: $exit_code"
      #--msgbox "Unexpected error occurred. Exit code: $exit_code" 10 50
    [ "$action" = "return" ] && return 1 || exit 1
  fi
}

# -------------- Dependency Check --------------
for cmd in curl whiptail qm cloud-localds openssl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    show_header
    echo "Installing missing package for: $cmd"
    apt-get update && apt-get install -y "$cmd"
  fi
done

# --------------- Next Available ID -------------
# This logic detects the next unused ID in the selected range
function find_next_vmid() {
  local min=$1
  local max=$2

  existing_ids=($(qm list | awk -v min="$min" -v max="$max" '$1 >= min && $1 <= max {print $1}' | sort -n))
  for ((id=min; id<=max; id++)); do
    if [[ ! " ${existing_ids[*]} " =~ " $id " ]]; then
      echo "$id"
      return
    fi
  done

  echo "$((max + 1))"  # fallback if range full
}

# -------------- Distro Menu --------------
declare -A DISTROS=(
  ["1"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2 $DELIMITER AlmaLinux 9"
  ["2"]="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 $DELIMITER CentOS 7"
  ["3"]="https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2 $DELIMITER CentOS 8"
  ["4"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-9-latest.x86_64.qcow2 $DELIMITER CentOS 9 Stream"
  ["5"]="https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2 $DELIMITER CentOS 10 Stream"
  ["6"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2 $DELIMITER Debian 12 nocloud"
  ["7"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2 $DELIMITER Debian 12 Server"
  ["8"]="https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2 $DELIMITER Fedora Server"
  ["9"]="https://gentoo.org/releases/amd64/releases/latest/qcow2/gentoo-amd64-cloud-init.qcow2 $DELIMITER Gentoo cloud-init"
  ["10"]="https://download.opensuse.org/tumbleweed/iso/openSUSE-Tumbleweed-NET-x86_64-Current.iso $DELIMITER openSUSE Tumbleweed"
  ["11"]="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2 $DELIMITER Rocky Linux 9"
  ["12"]="https://cloud-images.ubuntu.com/releases/20.10/release/ubuntu-20.10-server-cloudimg-amd64.img $DELIMITER Ubuntu Server 20.10"
  ["13"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img $DELIMITER Ubuntu Server 22.04"
  ["14"]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img $DELIMITER Ubuntu Server 24.04"
  ["15"]="https://cloud-images.ubuntu.com/next/current/next-server-cloudimg-amd64.img $DELIMITER Ubuntu Server 25.04"
)


# Safely read sorted keys with spaces
mapfile -t sorted_keys < <(printf "%s\n" "${!DISTROS[@]}" | sort -n)

# Build whiptail menu options
DISTRO_MENU_ITEMS=()
for key in "${sorted_keys[@]}"; do
  if [[ -v 'DISTROS[$key]' ]]; then
    entry="${DISTROS[$key]}"
    label="  ${entry##*$DELIMITER }  "
    DISTRO_MENU_ITEMS+=("$key" "$label")
  else
    echo "[WARN] Key '$key' not found in DISTROS" >&2
  fi
done

# Show the whiptail Distro menu
DISTRO_CODE=$(whiptail --title "$BRANDING_TITLE" --menu "Choose a Linux Distro to Template:" 20 69 10 "${DISTRO_MENU_ITEMS[@]}" 3>&1 1>&2 2>&3) || exit 1

# Extract URL without the label
DISTRO_URL="${DISTROS[$DISTRO_CODE]% $DELIMITER*}"
FILENAME="/var/lib/vz/template/cache/$(basename "$DISTRO_URL")"

# Extract full line and label
DISTRO_FULL="${DISTROS[$DISTRO_CODE]}"

# Extract Label only
DISTRO_LABEL="${DISTRO_FULL#*$DELIMITER }"

VMID_SCHEME=$(whiptail --title "$BRANDING_TITLE" --menu "Choose VM ID scheme:" 15 50 5 \
  "3-digit" "IDs from 100–999 (e.g. small/dev)" \
  "4-digit" "IDs from 1000–9999 (e.g. production)" \
  "5-digit" "IDs from 10000-19999 (e.g. tools)" \
  "5t-digit" "IDs from 20000+ (e.g. templates)" \
  3>&1 1>&2 2>&3) || exit 1

case "$VMID_SCHEME" in
  "3-digit")  next_vmid=$(find_next_vmid 100 999) ;;
  "4-digit")  next_vmid=$(find_next_vmid 1000 9999) ;;
  "5-digit")  next_vmid=$(find_next_vmid 10000 19999) ;;
  "5t-digit") next_vmid=$(find_next_vmid 20000 29999) ;;
esac

# -------------- Branding Headers --------------
function show_header() {
  #clear
  echo "###############################################"
  echo "#  $BRANDING_LOGO_ICON $BRANDING_TITLE $BRANDING_VERSION     "
  echo "#     $BRANDING_NAME"
  echo "#     $BRANDING_URL"
  echo "###############################################"
  echo
}
show_header

# -------------- Download Image If Needed --------------
echo "Checking cloud image: $FILENAME"
if [[ ! -f "$FILENAME" ]]; then
  echo "Downloading $DISTRO_LABEL image..."
  pause
  curl -L "$DISTRO_URL" -o "$FILENAME"
fi

# --- Dynamic Storage Selection ---
readarray -t STORAGE_LIST < <(pvesm status --enabled 1 --content images | awk 'NR>1 {print $1}')

if [[ ${#STORAGE_LIST[@]} -eq 0 ]]; then
  whiptail --msgbox "No Proxmox storage found that supports VM disk images." 10 60 --title "$BRANDING_TITLE"
  exit 1
fi

STORAGE_MENU_ITEMS=()
for store in "${STORAGE_LIST[@]}"; do
  STORAGE_MENU_ITEMS+=("$store" "")
done

STORAGE=$(whiptail --title "$BRANDING_TITLE" \
  --menu "Choose a target storage volume for the VM disk:" 20 60 10 \
  "${STORAGE_MENU_ITEMS[@]}" \
  3>&1 1>&2 2>&3) || exit 1

# -------------- Prompt for VM Settings --------------
vmid=$(whiptail --inputbox "Enter a unique VM ID:" 10 50 "$next_vmid" --title "$BRANDING_TITLE" 3>&1 1>&2 2>&3) || exit 1
name=$(whiptail --inputbox "Enter VM Name:" 10 50 "${DISTRO_LABEL// /-}-CIT" --title "$BRANDING_TITLE" 3>&1 1>&2 2>&3) || exit 1
fqdn=$(whiptail --inputbox "Enter your Hostname/FQDN:" 10 50 "template-$vmid" --title "$BRANDING_TITLE" 3>&1 1>&2 2>&3) || exit 1

# -------------- Password Entry --------------
plain_pw=$(whiptail --passwordbox "Enter default password for user '$VMUSER':" 10 60 --title " $BRANDING_TITLE" 3>&1 1>&2 2>&3) || exit 1
password_hash=$(openssl passwd -6 "$plain_pw")

# -------------- VM Creation --------------
echo "Creating VM $vmid: $name"
echo
pause
qm create $vmid --name "$name" --memory "$MEMORY" --cores "$CORES" --net0 virtio,bridge="$NET_BRIDGE"
#echo "create $vmid --name \"$name\" --memory \"$MEMORY\" --cores \"$CORES\" --net0 \"virtio\", bridge=\"$NET_BRIDGE\""

qm importdisk $vmid "$FILENAME" "$STORAGE"

STORAGE_TYPE=$(pvesm status --storage "$STORAGE" | awk '/^type:/ {print $2}')

if [[ "$STORAGE_TYPE" == "zfs" || "$STORAGE_TYPE" == "zfspool" || "$STORAGE_TYPE" == "lvmthin" || "$STORAGE_TYPE" == "lvm" ]]; then
  qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$STORAGE:vm-$vmid-disk-0"
else
  UNUSED_DISK=$(qm config "$vmid" | awk '/^unused0:/ {print $2}')
  if [[ -z "$UNUSED_DISK" ]]; then
    echo "Could not find unused0 disk after import"
    exit 1
  fi
  qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$UNUSED_DISK"
fi

qm set $vmid --ide2 "$STORAGE:cloudinit" --boot order=scsi0 --serial0 socket --vga serial0
qm set $vmid --agent enabled=1

# -------------- Cloud-Init ISO --------------
CLOUD_TMP="/tmp/cloudinit-$vmid"
mkdir -p "$CLOUD_TMP"

# cloud-localds creates a disk-image with user-data and/or
# meta-data for cloud-init(1). user-data can contain
# everything which is supported by cloud-init(1).
cat > "$CLOUD_TMP/user-data" <<EOF
#cloud-config
hostname: $name
fqdn: $fqdn
manage_etc_hosts: true
package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
  - openssh-server
  - net-tools
  - curl
  - nano

users:
  - name: $VMUSER
    groups: sudo
    shell: /bin/bash
    lock_passwd: false
    passwd: $password_hash
    ssh_pwauth: true

# This tells cloud-init to allow password-based login via SSH (which is
# disabled by default in many cloud images).
ssh_pwauth: true

# Each command becomes an explicit argument list, so cloud-init won’t
# misinterpret or fail silently due to quoting or escaping issues.
runcmd:
  - [ systemctl, enable, qemu-guest-agent ]
  - [ systemctl, start, qemu-guest-agent ]
  - [ systemctl, enable, ssh ]
  - [ systemctl, start, ssh ]

  # To test runcmd in action, check for existance of file after cloning template.
  - [ touch, /var/tmp/runcmd-success ]
EOF

# Creating the meta-data file
cat > "$CLOUD_TMP/meta-data" <<EOF
instance-id: $name
local-hostname: $name
EOF

# Creating the custom ISO with data taken from user-data and meta-data
cloud-localds -v "$CLOUD_TMP/cloudinit.iso" "$CLOUD_TMP/user-data" "$CLOUD_TMP/meta-data"

# Attach custom ISO to CDROM (ide3)
qm set $vmid --ide3 none
qm importdisk $vmid "$CLOUD_TMP/cloudinit.iso" "$STORAGE"

ISO_DISK=$(qm config "$vmid" | awk -F ': ' '/^unused[0-9]+:/ && /\.raw$/ {print $2}' | tail -n1)

if [[ -n "$ISO_DISK" ]]; then
  qm set $vmid --ide3 "$ISO_DISK,media=cdrom"
else
  echo "Failed to detect imported cloudinit ISO"
  exit 1
fi

# -------------- Convert to Template --------------
if whiptail --yesno "Would you like to convert this VM to a template now?" 10 60 --title " $BRANDING_TITLE"; then
  qm template $vmid
  qm set $vmid --tags TEMPLATE

  #whiptail --msgbox "Success! Template $name ($vmid) created." 10 50 --title " $BRANDING_TITLE"
  show_whiptail_header "Template $vmid ($name) created successfully."
fi

# -------------- Cleanup --------------
rm -rf "$CLOUD_TMP"
