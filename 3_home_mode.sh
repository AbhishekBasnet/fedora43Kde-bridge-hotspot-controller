#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- FORMATTING FUNCTIONS (Retained) ---
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

echo ">>> SWITCHING TO HOME MODE (Restoring Normal Internet)..."
print_header

# --- STEP 1: DEACTIVATE PROFILES (Do NOT delete hardware) ---
# We bring the slaves down first, then the master bridge
execute_cmd "nmcli connection down bridge-wifi" "Stop Hotspot" "AP Mode Stopped"
execute_cmd "nmcli connection down bridge-ethernet" "Release Wired Slave" "Slave Released"
execute_cmd "nmcli connection down Bridge" "Deactivate Bridge Master" "br0 Hidden"

# --- STEP 2: RESTORE SYSTEM STATE ---
sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null
WIFI_IF=$(nmcli -t -f DEVICE,TYPE device | grep ':wifi' | head -n1 | cut -d: -f1)
sudo iw dev "$WIFI_IF" set power_save on 2>/dev/null

# --- STEP 3: RE-ACTIVATE PRIMARY WIRED CONNECTION ---
ORIG_PROFILE=$(nmcli -t -f NAME,TYPE connection show | grep ':ethernet' | grep -v 'bridge-ethernet' | head -n1 | cut -d: -f1)
if [ -n "$ORIG_PROFILE" ]; then
    # Force the original profile UP to refresh the KDE tray status
    execute_cmd "nmcli connection up \"$ORIG_PROFILE\"" "Restore Wired Profile" "$ORIG_PROFILE"
fi

echo "------------------------------------------------------------------------------------------------------------------------"
echo ">>> HOME MODE ACTIVE. (Bridge hidden, Wired restored)."
read -p "Press [Enter] to return..."
sudo "$SCRIPT_DIR/0_run_me_first.sh"
