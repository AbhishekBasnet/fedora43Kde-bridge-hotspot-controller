#!/bin/bash
# Get the absolute path of where the script is actually stored
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
print_header() {
    echo "------------------------------------------------------------------------------------------------------------------------"
    printf "%-40s | %-30s | %-10s | %-30s\n" "LITERAL COMMAND" "FUNCTION" "STATUS" "SYSTEM FILE / DETAILS"
    echo "------------------------------------------------------------------------------------------------------------------------"
}

print_row() {
    local cmd="$1"; local func="$2"; local status="$3"; local details="$4"
    if [ "$status" == "0" ]; then status_txt="[SUCCESS]"; else status_txt="[FAILED]"; fi
    printf "%-40s | %-30s | %-10s | %s\n" "${cmd:0:38}" "$func" "$status_txt" "$details"
}

execute_cmd() {
    eval "$1" > /dev/null 2>&1
    local ret=$?
    print_row "$1" "$2" "$ret" "$3"
    return $ret
}

echo ">>> SWITCHING TO OFFICE MODE (Activating Bridge)..."
print_header

# --- STEP 1: PRE-FLIGHT ---
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
WIFI_IF=$(nmcli -t -f DEVICE,TYPE device | grep ':wifi' | head -n1 | cut -d: -f1)

# --- STEP 2: ACTIVATE SAVED PROFILES ---
# Bringing the 'Bridge' connection up will automatically recreate the br0 device
execute_cmd "nmcli connection up Bridge" "Activate Master Bridge" "br0 Started"
execute_cmd "nmcli connection up bridge-ethernet" "Attach Wired to Bridge" "Slave Mode"
execute_cmd "nmcli connection up bridge-wifi" "Start Hotspot" "AP Mode"

# --- STEP 3: DISCOVERY TWEAKS ---
# These will now work because br0 exists again
sudo sysctl -w net.ipv4.conf.br0.proxy_arp=1 >/dev/null
echo 0 | sudo tee /sys/class/net/br0/bridge/multicast_snooping >/dev/null
sudo bridge link set dev "$WIFI_IF" hairpin on

# --- STEP 4: GUI SYNC ---
# A quick toggle forces the KDE applet to show the Bridge as the active icon
nmcli networking off && sleep 1 && nmcli networking on
nmcli connection up Bridge >/dev/null 2>&1

echo "------------------------------------------------------------------------------------------------------------------------"
echo ">>> OFFICE MODE ACTIVE. (GUI synced)."
sleep 1
sudo "$SCRIPT_DIR/5_hotspot_details.sh"
