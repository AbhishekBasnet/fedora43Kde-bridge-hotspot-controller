#!/bin/bash
# Get the absolute path of where the script is actually stored
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# --- FORMATTING FUNCTIONS ---
print_header() {
    echo "------------------------------------------------------------------------------------------------------------------------"
    printf "%-40s | %-30s | %-10s | %-30s\n" "LITERAL COMMAND" "FUNCTION" "STATUS" "SYSTEM FILE / DETAILS"
    echo "------------------------------------------------------------------------------------------------------------------------"
}

print_row() {
    local cmd="$1"
    local func="$2"
    local status="$3"
    local details="$4"
    if [ ${#cmd} -gt 38 ]; then cmd="${cmd:0:35}..."; fi
    if [ "$status" == "0" ]; then status_txt="[SUCCESS]"; else status_txt="[FAILED]"; fi
    printf "%-40s | %-30s | %-10s | %s\n" "$cmd" "$func" "$status_txt" "$details"
}

execute_cmd() {
    local cmd_str="$1"
    local func_desc="$2"
    local file_finder="$3"
    eval "$cmd_str" > /dev/null 2>&1
    local exit_code=$?
    local info="-"
    if [ $exit_code -eq 0 ] && [ -n "$file_finder" ]; then
        info=$(eval "$file_finder" 2>/dev/null | awk '{print $2}')
    fi
    print_row "$cmd_str" "$func_desc" "$exit_code" "$info"
    if [ $exit_code -ne 0 ]; then
        echo "!!! CRITICAL ERROR: $cmd_str failed."
        exit 1
    fi
}

echo ">>> INITIALIZING TRANSPARENT BRIDGE SETUP..."
print_header

# --- STEP 1: SCAN DEVICES ---
ETH_IF=$(nmcli -t -f DEVICE,TYPE device | grep ':ethernet' | head -n1 | cut -d: -f1)
WIFI_IF=$(nmcli -t -f DEVICE,TYPE device | grep ':wifi' | head -n1 | cut -d: -f1)

# --- STEP 2: CLEANUP ---
nmcli con delete Bridge bridge-ethernet bridge-wifi >/dev/null 2>&1

# --- STEP 3: CREATE BRIDGE (Optimized for Discovery) ---
# Disable snooping and forward-delay to make discovery instant
# --- STEP 3: CREATE BRIDGE (Corrected) ---
# Removed arp-interval and arp-validate as they are bond-specific properties
cmd="nmcli con add type bridge ifname br0 con-name Bridge stp no \
    bridge.forward-delay 0 \
    bridge.multicast-snooping no"
execute_cmd "$cmd" "Create Transparent Bridge" "nmcli -f FILENAME con show Bridge"

# --- STEP 4: ADD ETHERNET ---
cmd="nmcli con add type ethernet ifname $ETH_IF master br0 con-name bridge-ethernet"
execute_cmd "$cmd" "Bind Ethernet to Bridge" "nmcli -f FILENAME con show bridge-ethernet"

# --- STEP 5: CONFIGURATION & WIFI (Corrected) ---
read -p ">>> Disable Wi-Fi Power Saving? [Y/n]: " ps_choice
[[ "$ps_choice" =~ ^[Nn]$ ]] && PS_VAL=3 || PS_VAL=2

# Removed connection.keepalive as it is incompatible with Wi-Fi AP mode
cmd="nmcli con add type wifi ifname $WIFI_IF mode ap con-name bridge-wifi master br0 \
    ssid Fedora-Bridge-Hotspot \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk joshuaHotspot \
    wifi-sec.pmf disable \
    802-11-wireless.band a \
    802-11-wireless.channel 44 \
    802-11-wireless.powersave $PS_VAL \
    connection.autoconnect yes \
    connection.autoconnect-priority 100 \
    ipv6.method disabled"

execute_cmd "$cmd" "Create Optimized Hotspot" "nmcli -f FILENAME con show bridge-wifi"
# --- STEP 6: KERNEL & FIREWALL TWEAKS ---
echo ">>> Applying Discovery & Stability Tweaks..."
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
sudo sysctl -w net.ipv4.conf.br0.proxy_arp=1 >/dev/null
sudo iw dev "$WIFI_IF" set power_save off 2>/dev/null
# Allow traffic to move between bridge ports in Fedora Firewall
sudo firewall-cmd --zone=nm-shared --add-forward-port=port=5353:proto=udp >/dev/null 2>&1

# --- STEP 7: ACTIVATION ---
nmcli con down "$(nmcli -t -f NAME,TYPE con show --active | grep ':ethernet' | cut -d: -f1)" >/dev/null 2>&1
execute_cmd "nmcli con up Bridge" "Activate Bridge" ""
execute_cmd "nmcli con up bridge-ethernet" "Activate Wired" ""
execute_cmd "nmcli con up bridge-wifi" "Activate Wifi" ""
echo ">>> Enabling Hairpin Mode for Android/iPhone discovery..."
sudo bridge link set dev "$WIFI_IF" hairpin on

# --- NEW: INLINE HOTSPOT SUMMARY ---
echo ""
echo "======================================================="
echo "           CURRENT HOTSPOT CREDENTIALS"
echo "======================================================="
SSID=$(nmcli -g 802-11-wireless.ssid connection show bridge-wifi 2>/dev/null)
PASS=$(nmcli -s -g 802-11-wireless-security.psk connection show bridge-wifi 2>/dev/null)
IP_ADDR=$(ip -4 -o addr show br0 2>/dev/null | awk '{print $4}')

printf "%-20s : %s\n" "SSID Name" "$SSID"
printf "%-20s : %s\n" "Password" "$PASS"
printf "%-20s : %s\n" "Bridge IP" "${IP_ADDR:-Activating...}"
printf "%-20s : %s\n" "Select option5 5 for full HOTSPOT info."
echo "======================================================="
echo ""

# --- THE MENU ---
echo "What would you like to do next?"
echo "  5) Full Hotspot Manager (Deep Inspection)"
echo "  6) Scan Network for Devices"
echo "  m) Return to Main Menu"
echo "  q) Quit"
echo "-------------------------------------------------------"
read -p "Select [5/6/m/q]: " next_choice

case $next_choice in
    5) sudo "$SCRIPT_DIR/5_hotspot_details.sh" ;;
    6) sudo "$SCRIPT_DIR/6_network_scan.sh" ;;
    m) sudo "$SCRIPT_DIR/0_run_me_first.sh" ;;
    q) exit 0 ;;
    *) exit 0 ;;
esac
