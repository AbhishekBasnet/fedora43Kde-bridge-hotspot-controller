# Fedora Hotspot Master Controller

## Overview

This repository contains a suite of Bash scripts designed to automate the creation and management of a transparent network bridge on Fedora workstations (specifically tested on Fedora 43 KDE Plasma).

Unlike standard NAT hotspots, this solution creates a Layer 2 transparent bridge (`br0`). This allows devices connected via Wi-Fi to appear directly on the wired network subnet, enabling seamless discovery for protocols such as mDNS (Bonjour), printing, and local file sharing.

## Features

- **Transparent Bridging:** Bridges the Ethernet interface to a Wi-Fi Access Point, bypassing double-NAT issues.
- **Mode Switching:**
  - *Office Mode:* Activates the bridge and Hotspot.
  - *Home Mode:* Disables the bridge, restores standard Wi-Fi power saving, and reactivates the standard wired connection.
- **Shell Integration:** Automatically detects the user's shell (Bash, Zsh, or Fish) and injects aliases for quick access.
- **Network Scanning:** Integrated tools to discover devices connected to the bridge via `nmap` or ARP/Ping sweeps.
- **Client Management:** View connected stations, signal strength, and transmission rates in real-time.
- **Fail-Safe Recovery:** Includes a rescue script to scrub configurations and restore networking to factory defaults.

## Prerequisites

**Operating System:** Fedora Linux (NetworkManager based).

**Hardware:**
- 1x Ethernet Interface (Wired uplink)
- 1x Wi-Fi Interface (Wireless AP downlink)

**Dependencies:**
- `nmcli` (NetworkManager Command Line Interface)
- `firewall-cmd` (Firewalld)
- `nmap` (Optional, recommended for detailed network scanning)
- `iw` (For wireless signal monitoring)

## Installation

1. Clone this repository to your local machine.
2. Navigate to the directory containing the scripts.
3. Execute the initialization script to set permissions and configure shell aliases:

```bash
./0_run_me_first.sh
```

Upon successful execution, the script will generate an alias (default: `my-bridge-hotspot`). You may need to source your shell configuration file (e.g., `source ~/.bashrc`) or restart your terminal for the alias to take effect.

## Usage

The suite is controlled via a central menu system. Run the main controller using the generated alias or by executing `0_run_me_first.sh` directly.

### 1. First Time Setup

Select **Option 1** from the menu to initialize the bridge. This process will:

- Identify Ethernet and Wi-Fi interfaces.
- Create the `br0` bridge interface.
- Configure the Wi-Fi Access Point with WPA2 security.
- Apply sysctl and firewall rules to enable IP forwarding and multicast snooping.

**Default Credentials:**
- **SSID:** `Fedora-Bridge-Hotspot`
- **Password:** `joshuaHotspot`

> **Note:** These credentials can be changed via the Hotspot Manager (Option 5).

### 2. Office Mode (Activate)

Select **Option 2** to enable the hotspot environment. This activates the bridge, connects the Ethernet slave, and brings up the Wi-Fi AP. It ensures the GUI tray icon reflects the active bridge state.

### 3. Home Mode (Deactivate)

Select **Option 3** to return to standard networking. This executes a tear-down of the bridge, stops the AP, and restores the standard wired connection profile.

### 4. Network Scanning

Select **Option 6** to scan the local subnet. The script utilizes `nmap` (if available) or a native ping sweep to identify connected clients, displaying their IP addresses, MAC addresses, and vendor information.

### 5. Management & Configuration

Select **Option 5** to view detailed status information.

- **View Credentials:** Displays current SSID and Password.
- **Connected Clients:** Lists live associations with signal strength (dBm) and RX/TX bitrates.
- **Modify Settings:** Allows changing the SSID or Password without re-running the full setup.

## Troubleshooting & Recovery

### Android Connection Issues

If Android devices (specifically Android 12+) fail to connect, it is often due to Protected Management Frames (PMF) settings. You may need to disable PMF in the connection profile. This can be done by editing `1_setup_bridge.sh` or running the following command:

```bash
nmcli connection modify bridge-wifi wifi-sec.pmf disable
```

### Emergency Reset

If networking becomes unstable or the bridge fails to disengage, select **Option 4** (Emergency Reset). This script performs a hard reset by:

- Deleting all `bridge`, `bridge-ethernet`, and `bridge-wifi` profiles.
- Reverting IP forwarding and firewall rules.
- Restarting the NetworkManager networking stack.
- Re-detecting the Ethernet hardware and creating a clean connection profile ("My Wired Connection").
