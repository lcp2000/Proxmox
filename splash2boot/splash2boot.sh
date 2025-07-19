#!/bin/bash
###########################################
#              Splash 2 Boot              #
#              v.1.00 © 2025              #
#        by Psylla, The Little Flea       #
#      https://thelittleflea.com/s2b      #
#                                         #
#   Adds a Splash Screen to Grub config   #
#                                         #
#       Tested on Proxmox (PVE 8.4)       #
###########################################

set -e
clear


########################
# USER SETTINGS
########################
#
# Path to splash image
wget -nc https://github.com/lcp2000/Proxmox/tree/main/splash2boot/splash2boot.jpg
SPLASH_IMAGE="splash2boot.jpg"




        ##################################
        ## Edit Below At Your Own Peril ##
        ##################################




#####################################################
# Check for Dependencies and Install them if needed.
#####################################################
#
# Check for required tools and optionally install whiptail (simplified, adjust as needed)
required_cmds=(whiptail)
declare -A required_packages=(
    [whiptail]="whiptail"
)

missing_cmds=()
for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_cmds+=("${required_packages[$cmd]}")
    fi
done

if [ ${#missing_cmds[@]} -gt 0 ]; then
    unique_pkgs=$(printf "%s\n" "${missing_cmds[@]}" | sort -u | xargs)
    if whiptail --yesno "The following required packages are missing:\n\n$unique_pkgs\n\nInstall them now?" 15 60; then
        apt-get update && apt-get install -y $unique_pkgs || {
            whiptail --msgbox "Installation failed. Please install manually:\napt install -y $unique_pkgs" 12 60
            exit 1
        }
    else
        whiptail --msgbox "Required tools not installed. Exiting." 8 50
        exit 1
    fi
fi



#####################################################
# FUNCTIONS
#####################################################
#
show_splash_screen() {
    whiptail --title "ℹWelcome!" --msgbox "\
###########################################
#            🔧 Splash 2 Boot             #
#               v.1.00 © 2025             #
#        by Psylla, The Little Flea       #
#      https://thelittleflea.com/s2b      #
#                                         #
#   Adds a Splash Screen to Grub config   #
#                                         #
#       Tested on Proxmox (PVE 8.4)       #
###########################################" 20 47
}



########################
# MENU ITEMS
# Main interactive menu
########################
#
show_main_menu() {
    while true; do
        choice=$(whiptail --title "🔧 Splash 2 Boot" --menu "Choose an option:" 15 60 4 \
            1 "Install TLF Boot Splash Logo" \
            2 "Exit" \
            3>&1 1>&2 2>&3) || exit

        case "$choice" in
            1) install ;;
            2) clear; exit 0 ;;
        esac
    done
}


#####################################################
# START
#####################################################
#

install() {

    while true; do
        choice=$(whiptail --title "🔧 Splash 2 Boot" --menu "Are you sure you wish to continue\nwith splash image installation?\n\nChoose an option:" 15 60 4 \
            1 "Continue Install..." \
            2 "Exit" \
            3>&1 1>&2 2>&3) || exit

        case "$choice" in
            1) install ;;
            2) clear; exit 0 ;;
        esac
    done

  echo "Copying splash image into VM..."
  mkdir -p /boot/grub
  bash -c "cat > /boot/grub/bootsplash.jpg" < "$SPLASH_IMAGE"

  echo

  echo "Configuring GRUB..."
  bash -c "sed -i 's|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND=/boot/grub/bootsplash.jpg|' /etc/default/grub || echo 'GRUB_BACKGROUND=/boot/grub/bootsplash.jpg' >> /etc/default/grub"
  update-grub
}

show_splash_screen

show_main_menu
