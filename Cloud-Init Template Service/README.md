<center><img src="https://thelittleflea.com/wp-content/uploads/2025/06/T600-Proxmox-Penguin-Trans-BG.webp" height=269></center>

<h2>Proxmox Cloud-Init Template Service</h2>

A terminal-based utility that helps you build cloud-init–ready Linux VM templates in Proxmox VE, so you can stop clicking through the web UI and start templating like a boss.

It simplifies the creation of cloud-init–enabled VM templates using official Linux cloud images. The script presents a menu-driven interface (via whiptail) to select from a list of popular distributions (e.g., Ubuntu, Debian, CentOS, Fedora, Gentoo, openSUSE), and automatically downloads, imports, and configures them as reusable Proxmox templates.
<p><b>FEATURES:</b></p>

Supports official qcow2 cloud images (NoCloud or GenericCloud)

Imports as VMs, sets required flags, enables serial console

Converts VMs into reusable cloud-init templates

Uses whiptail as the user interface

Designed for simplicity, speed, and Proxmox sanity

Smart image selection tailored for Proxmox compatibility

Downloads and caches the official distro image selected for future use (qcow2 format)

Automatically handles:
- Image download and caching
- VM import and configuration
- Cloud-Init setup (e.g., serial console, networking, disk resize)

Uses clearly tagged distro labels for broad terminal compatibility

Modular structure for easy extension

<b>SUPPORTED DISTROS:</b>
- Ubuntu, Debian, CentOS, AlmaLinux, Rocky, Fedora, openSUSE, Gentoo (and more)

<b>INTENDED AUDIENCE:</b>
- Proxmox users who like automation, dislike repetition, and aren’t afraid of a little bash scripting magic.
- Proxmox administrators who want to rapidly deploy VMs from reusable, cloud-init–ready Linux templates using a simple UI.

<b>REQUIREMENTS:</b>
- bash, whiptail, curl, qm, and a caffeine source of your choice

<b>LICENSE:</b>
- <a href="https://raw.githubusercontent.com/lcp2000/Proxmox/refs/heads/Licensing/MIT%20LICENSE">MIT</a> or the "If it works, you're welcome to buy me a cup of coffee" license.

