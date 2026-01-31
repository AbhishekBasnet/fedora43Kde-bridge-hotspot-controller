#!/bin/bash
# Get the absolute path of where the script is actually stored

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_row() {
    printf "%-20s | %-20s | %-40s\n" "$1" "$2" "$3"
}

scan() {
    clear
    echo "======================================================="
    echo "             NETWORK DISCOVERY SCANNER"
    echo "======================================================="

    # --- HOTSPOT CONTEXT ---
    # Show user which network we are actually scanning
    BR_IP=$(ip -4 -o addr show br0 2>/dev/null | awk '{print $4}')
    SSID=$(nmcli -g 802-11-wireless.ssid connection show bridge-wifi 2>/dev/null)

    if [ -z "$BR_IP" ]; then
        echo "❌ ERROR: Bridge (br0) is not active. Cannot scan."
        echo "   Please activate Office Mode first."
        read -p "Press Enter to return..."
        exit 1
    fi

    echo "  • Hotspot SSID : ${SSID:-Unknown}"
    echo "  • Gateway IP   : $BR_IP"
    echo "  • Scan Target  : Local Subnet"
    echo "-------------------------------------------------------"
    echo ">>> Scanning network... (This may take a few seconds)"
    echo ""

    echo "------------------------------------------------------------------------------------"
    printf "%-20s | %-20s | %-40s\n" "IP ADDRESS" "MAC ADDRESS" "HOSTNAME / DETAILS"
    echo "------------------------------------------------------------------------------------"

    # 1. CHECK FOR NMAP (Preferred Method)
    if command -v nmap &> /dev/null; then
        # Nmap is available: Use it for a fast ARP scan
        sudo nmap -sn "$BR_IP" | awk '
            /Nmap scan report for/ {
                ip=$5;
                gsub(/[()]/, "", ip);
                hostname=$5;
                if ($5 == ip) hostname="Unknown";
            }
            /MAC Address:/ {
                mac=$3;
                vendor=$4 " " $5 " " $6;
                printf "%-20s | %-20s | %-40s\n", ip, mac, vendor
            }
        '

        # Print self (Bridge) manually
        MY_MAC=$(cat /sys/class/net/br0/address 2>/dev/null)
        MY_IP=${BR_IP%/*} # Remove CIDR
        print_row "$MY_IP" "$MY_MAC" "(This Computer)"

    else
        # 2. FALLBACK: NATIVE BASH PING SWEEP
        SUBNET=$(echo "$BR_IP" | cut -d. -f1-3)

        # Run parallel pings
        for i in {1..254}; do
            ping -c 1 -W 1 "$SUBNET.$i" >/dev/null 2>&1 &
        done
        wait

        # Read ARP table
        cat /proc/net/arp | grep -v "IP address" | while read line; do
            IP=$(echo "$line" | awk '{print $1}')
            MAC=$(echo "$line" | awk '{print $4}')
            DEVICE=$(echo "$line" | awk '{print $6}')

            if [ "$DEVICE" == "br0" ] && [ "$MAC" != "00:00:00:00:00:00" ]; then
                print_row "$IP" "$MAC" "Generic Device"
            fi
        done

        echo "------------------------------------------------------------------------------------"
        echo "ℹ️  TIP: Install 'nmap' (sudo dnf install nmap) for"
        echo "         manufacturer names and better detection."
    fi

    echo "------------------------------------------------------------------------------------"
    echo ">>> Scan Complete."
    echo "======================================================="
    echo "  r) Re-scan Network"
    echo "  m) Return to Main Menu"
    echo "  q) Quit"
    echo "======================================================="
    read -p "Enter choice: " choice

    case $choice in
        r) scan ;;
        m) sudo "$SCRIPT_DIR/0_run_me_first.sh" ;;
        q) exit 0 ;;
        *) scan ;;
    esac
}

# Run the scan function
scan
