#!/bin/bash
# Get the absolute path of where the script is actually stored

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- FORMATTING ---
print_header() {
    echo "--------------------------------------------------------------------------------"
    printf "%-25s | %-50s\n" "PROPERTY" "VALUE"
    echo "--------------------------------------------------------------------------------"
}

# --- FUNCTION: RELOAD HOTSPOT ---
reload_hotspot() {
    echo ">>> Applying changes..."
    nmcli connection down bridge-wifi >/dev/null 2>&1
    nmcli connection up bridge-wifi >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "✅ Success! Hotspot restarted with new settings."
    else
        echo "❌ Error: Could not restart hotspot. Check logs."
    fi
    sleep 2
}

# --- FUNCTION: SHOW INFO ---
show_info() {
    echo ""
    echo ""
    echo ""
    echo "======================================================="
    echo "           HOTSPOT DEEP INSPECTION & CONTROL"
    echo "======================================================="

    # Check if connection exists
    if ! nmcli connection show bridge-wifi >/dev/null 2>&1; then
        echo "❌ ERROR: 'bridge-wifi' profile not found."
        echo "   Please run setup or office mode first."
        echo "======================================================="
        read -p "Press Enter to exit..."
        exit 1
    fi

    echo "--------------------------------------------------------------------------------"
    echo " DISCOVERY STATUS (mDNS / Bonjour)"
    echo "--------------------------------------------------------------------------------"
    if command -v avahi-browse &> /dev/null; then
        # Look for mobile devices or workstations on the bridge
        echo ">>> Scanning for discoverable devices (3s)..."
        TIMEOUT_SCAN=$(timeout 3s avahi-browse -t -r _workstation._tcp 2>/dev/null | grep "=")
        if [ -n "$TIMEOUT_SCAN" ]; then
            echo "✅ DISCOVERABLE: iPhone/Peers found on LAN."
        else
            echo "⚠️  NOT DISCOVERABLE: No mDNS devices found yet."
        fi
    else
        echo "ℹ️  TIP: Install 'avahi-tools' to test iPhone discovery."
    fi

    print_header

    # 1. BASIC INFO (SSID, PASSWORD, IFACE)
    SSID=$(nmcli -g 802-11-wireless.ssid connection show bridge-wifi 2>/dev/null)
    PASS=$(nmcli -s -g 802-11-wireless-security.psk connection show bridge-wifi 2>/dev/null)
    IFACE=$(nmcli -g connection.interface-name connection show bridge-wifi 2>/dev/null)

    printf "%-25s | %-50s\n" "SSID (Name)" "$SSID"
    printf "%-25s | %-50s\n" "Password" "$PASS"
    printf "%-25s | %-50s\n" "Interface" "$IFACE"

    # 2. IP INFO
    IP_ADDR=$(ip -4 -o addr show br0 2>/dev/null | awk '{print $4}')
    MAC_ADDR=$(cat /sys/class/net/$IFACE/address 2>/dev/null)
    printf "%-25s | %-50s\n" "Bridge IP (Gateway)" "${IP_ADDR:-Not Active}"
    printf "%-25s | %-50s\n" "MAC Address" "$MAC_ADDR"

    # 3. WIRELESS DETAILS (Band, Channel, Tx Power)
    IW_INFO=$(iw dev "$IFACE" info 2>/dev/null)
    CHANNEL=$(echo "$IW_INFO" | grep "channel" | awk '{print $2}')
    FREQ=$(echo "$IW_INFO" | grep "channel" | awk '{print $3}' | tr -d '()')
    TX_POWER=$(echo "$IW_INFO" | grep "txpower" | awk '{print $2, $3}')

    if [[ -n "$FREQ" ]]; then
        if [[ "$FREQ" > "2400" && "$FREQ" < "2500" ]]; then BAND="2.4 GHz";
        elif [[ "$FREQ" > "5000" ]]; then BAND="5 GHz";
        else BAND="Unknown ($FREQ MHz)"; fi
    else
        BAND="Inactive"
        CHANNEL="N/A"
    fi

    printf "%-25s | %-50s\n" "Frequency Band" "$BAND"
    printf "%-25s | %-50s\n" "Channel" "$CHANNEL"
    printf "%-25s | %-50s\n" "TX Power" "${TX_POWER:-Default}"

    # 4. SECURITY & MODE
    # Note: Using full property name to avoid nmcli errors
    SEC_PROTO=$(nmcli -g 802-11-wireless-security.key-mgmt connection show bridge-wifi 2>/dev/null)
    MODE=$(nmcli -g 802-11-wireless.mode connection show bridge-wifi 2>/dev/null)

    printf "%-25s | %-50s\n" "Security Protocol" "${SEC_PROTO:-None}"
    printf "%-25s | %-50s\n" "Mode" "$MODE"

    echo "--------------------------------------------------------------------------------"
    echo " CONNECTED CLIENTS (Live Station Dump)"
    echo "--------------------------------------------------------------------------------"
    printf "%-17s | %-15s | %-10s | %s\n" "MAC ADDRESS" "IP ADDRESS" "SIGNAL" "SPEED"
    echo "--------------------------------------------------------------------------------"

    # 5. DETAILED CLIENT LIST
    STATION_MACS=$(sudo iw dev "$IFACE" station dump 2>/dev/null | grep "Station" | awk '{print $2}')

    if [ -z "$STATION_MACS" ]; then
        echo "  (No devices currently connected)"
    else
        for mac in $STATION_MACS; do
            STATS=$(sudo iw dev "$IFACE" station get "$mac" 2>/dev/null)
            SIGNAL=$(echo "$STATS" | grep "signal:" | awk '{print $2, $3}')
            BITRATE=$(echo "$STATS" | grep "tx bitrate:" | awk '{print $3, $4}')

            # ARP Lookup for IP
            CLIENT_IP=$(ip neigh show | grep -i "$mac" | awk '{print $1}')
            if [ -z "$CLIENT_IP" ]; then CLIENT_IP="(Unknown)"; fi

            printf "%-17s | %-15s | %-10s | %s\n" "$mac" "$CLIENT_IP" "$SIGNAL" "$BITRATE"
        done
    fi

    echo "======================================================="
    echo "  1) Refresh Info"
    echo "  2) Change Wi-Fi Name (SSID)"
    echo "  3) Change Password"
    echo "  4) Restart/Reset Hotspot"
    echo "  m) Return to Main Menu"
    echo "  q) Quit"
    echo "======================================================="
    read -p "Enter choice: " choice

    case $choice in
        1) show_info ;;
        2)
            read -p "Enter new SSID Name: " new_ssid
            if [ -n "$new_ssid" ]; then
                nmcli connection modify bridge-wifi 802-11-wireless.ssid "$new_ssid"
                reload_hotspot
            fi
            show_info
            ;;
        3)
            read -p "Enter new Password (min 8 chars): " new_pass
            if [ ${#new_pass} -ge 8 ]; then
                nmcli connection modify bridge-wifi wifi-sec.psk "$new_pass"
                reload_hotspot
                show_info
            else
                echo "❌ Error: Password too short!"
                sleep 2
                show_info
            fi
            ;;
        4)
            reload_hotspot
            show_info
            ;;
        m) sudo "$SCRIPT_DIR/0_run_me_first.sh" ;;
        q) exit 0 ;;
        *) show_info ;;
    esac
}

# Run the function
show_info
