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

echo ">>> EMERGENCY RESET INITIATED..."
print_header

# --- STEP 1: DELETE CONFIGURATIONS ---
# Reverses the profile creation in File 1
execute_cmd "nmcli con delete bridge-wifi" "Delete Hotspot Config" "Removed"
execute_cmd "nmcli con delete bridge-ethernet" "Delete Wired Config" "Removed"
execute_cmd "nmcli con delete Bridge" "Delete Bridge Config" "Removed"

# --- STEP 2: FIREWALL & KERNEL CLEANUP ---
# Reverses the specific mDNS rule added in File 1
sudo firewall-cmd --zone=nm-shared --remove-forward-port=port=5353:proto=udp >/dev/null 2>&1
print_row "firewall-cmd --remove-forward-port" "Close mDNS Forwarding" "0" "Firewall Cleaned"

sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null
print_row "sysctl -w net.ipv4.ip_forward=0" "Disable IP Forwarding" "0" "Kernel Reset"

# --- STEP 3: RESTART NETWORK STACK ---
execute_cmd "nmcli networking off" "Disable All Networking" "Clearing States..."
sleep 2
execute_cmd "nmcli networking on" "Enable All Networking" "Restarting Stack..."

# --- STEP 4: HARDWARE RECOVERY ---
echo "------------------------------------------------------------------------------------------------------------------------"
echo ">>> CLEANING DUPLICATES & WAITING FOR HARDWARE..."

# 1. DELETE ALL EXISTING DUPLICATES FIRST
# This finds any connection named "My Wired Connection" and deletes it
DUPLICATES=$(nmcli -t -f NAME,UUID connection show | grep "^My Wired Connection:" | cut -d: -f2)
if [ -n "$DUPLICATES" ]; then
    for uuid in $DUPLICATES; do
        nmcli connection delete uuid "$uuid" >/dev/null 2>&1
    done
    print_row "nmcli con delete" "Clean Duplicates" "0" "Removed old profiles"
fi

MAX_RETRIES=15; COUNT=0; ETH_FOUND=0
while [ $COUNT -lt $MAX_RETRIES ]; do
    ETH_DEV=$(nmcli -t -f DEVICE,TYPE device | grep ':ethernet' | head -n1 | cut -d: -f1)
    if [ -n "$ETH_DEV" ]; then ETH_FOUND=1; break; fi
    echo -ne "    Waiting for Ethernet card... ($COUNT/$MAX_RETRIES)\r"; sleep 1; COUNT=$((COUNT+1))
done
echo ""

if [ $ETH_FOUND -eq 1 ]; then
    # Create a fresh friendly connection profile
    FINAL_NAME="My Wired Connection"
    # Note: We now know there are NO duplicates, so this will be the only one
    execute_cmd "nmcli connection add type ethernet con-name \"$FINAL_NAME\" ifname $ETH_DEV" "Create Friendly Profile" "$FINAL_NAME"
    nmcli connection up "$FINAL_NAME" >/dev/null 2>&1
else
    print_row "check device" "Hardware Check" "1" "TIMED OUT: No Ethernet Found"
    exit 1
fi

echo ">>> RESET COMPLETE. Back to factory defaults."
echo "-------------------------------------------------------"
echo "  1) Run Setup (1_setup_bridge.sh)"
echo "  m) Return to Main Menu"
read -p "Select [1/m]: " next_choice
case $next_choice in
    1) sudo "$SCRIPT_DIR/1_setup_bridge.sh" ;;
    m) sudo "$SCRIPT_DIR/0_run_me_first.sh" ;;
    *) exit 0 ;;
esac
