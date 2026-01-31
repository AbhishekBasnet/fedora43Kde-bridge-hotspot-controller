#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Define formatting for the table
print_header() {
    echo "----------------------------------------------------------------------------------------------------"
    printf "%-30s %-25s %-10s %-30s\n" "FILE / TARGET" "FUNCTION" "STATUS" "SYSTEM LOCATION / DETAILS"
    echo "----------------------------------------------------------------------------------------------------"
}

print_row() {
    printf "%-30s %-25s %-10s %-30s\n" "$1" "$2" "$3" "$4"
}

echo "======================================================="
echo "   FEDORA HOTSPOT MASTER CONTROLLER (v2.4 - Space Fix)"
echo "======================================================="
echo "Checking script integrity..."
echo ""

print_header

# Updated list of files
files=("1_setup_bridge.sh" "2_office_mode.sh" "3_home_mode.sh" "4_rescue_reset.sh" "5_hotspot_details.sh" "6_network_scan.sh")
missing_files=0
pwd=$(pwd)

# 1. CHECK FILE PERMISSIONS
for file in "${files[@]}"; do
    FULL_PATH="$SCRIPT_DIR/$file" # Combine the dir and the filename
    if [ -f "$FULL_PATH" ]; then
        if [ -x "$FULL_PATH" ]; then
            print_row "$file" "Check Executable" "[OK]" "Found in $SCRIPT_DIR"
        else
            chmod +x "$FULL_PATH"
            print_row "$file" "Fixing Permissions" "[UPDATED]" "Changed to Executable"
        fi
    else
        print_row "$file" "Check Existence" "[MISSING]" "Not found in $SCRIPT_DIR"
        missing_files=$((missing_files + 1))
    fi
done

echo "======================================================="
echo "  "
echo "============== Shell Configs =========================="
echo "  "

# 2. UNIVERSAL SHELL CONFIGURATION (Supports Spaces with Nested Quotes)
TARGET_PATH=$(realpath "$0")
ALIAS_NAME="my-bridge-hotspot"

check_shell_config() {
    local shell_bin="$1"  # e.g., zsh
    local shell_rc="$2"   # e.g., $HOME/.zshrc
    local shell_name="$3" # e.g., Zsh
    local is_fish="$4"    # true/false

    if command -v "$shell_bin" >/dev/null 2>&1; then
        touch "$shell_rc"

        # Produces: alias name="'/path with spaces/file'"
        if [ "$is_fish" = true ]; then
            local ALIAS_LINE="alias $ALIAS_NAME \"'$TARGET_PATH'\""
            local SOURCE_CMD="source $shell_rc"
        else
            local ALIAS_LINE="alias $ALIAS_NAME=\"'$TARGET_PATH'\""
            local SOURCE_CMD="source $shell_rc"
        fi

        if grep -Fq "'$TARGET_PATH'" "$shell_rc"; then
            print_row "$shell_name" "Check Alias" "[PRESENT]" "Nested quotes found"
            echo -e "   ✅ \033[1;32mReady!\033[0m To use now, run: \033[1;36m$SOURCE_CMD\033[0m"
        else
            echo -e "\n# Added by Fedora Hotspot Controller\n$ALIAS_LINE" >> "$shell_rc"
            print_row "$shell_name" "Injecting Alias" "[UPDATED]" "Added with \"' '\" quotes"
            echo -e "   👉 \033[1;33mACTION REQUIRED:\033[0m Run \033[1;36m$SOURCE_CMD\033[0m to enable the command."
        fi
    else
        print_row "$shell_name" "Check Install" "[N/A]" "Not installed"
    fi
}

check_shell_config "bash" "$HOME/.bashrc" "Bash" false
check_shell_config "zsh" "$HOME/.zshrc" "Zsh" false
check_shell_config "fish" "$HOME/.config/fish/config.fish" "Fish" true

# Function to Display the Menu
show_menu() {
    echo "======================================================="
    echo "   FEDORA HOTSPOT CONTROL PANEL"
    echo "======================================================="
    echo "  1) FIRST TIME SETUP (1_setup_bridge.sh)"
    echo "  2) OFFICE MODE (Activate Bridge)"
    echo "  3) HOME MODE (Normal Internet)"
    echo "  4) EMERGENCY RESET"
    echo "-------------------------------------------------------"
    echo "  5) HOTSPOT MANAGER (Check/Edit/Restart)"
    echo "  6) NETWORK SCANNER (Find Devices)"
    echo "-------------------------------------------------------"
    echo "  q) Quit"
    echo "======================================================="
    read -p "Enter choice: " choice

case $choice in
        1) sudo "$SCRIPT_DIR/1_setup_bridge.sh" ;;
        2) sudo "$SCRIPT_DIR/2_office_mode.sh" ;;
        3) sudo "$SCRIPT_DIR/3_home_mode.sh" ;;
        4) sudo "$SCRIPT_DIR/4_rescue_reset.sh" ;;
        5) sudo "$SCRIPT_DIR/5_hotspot_details.sh" ;;
        6) sudo "$SCRIPT_DIR/6_network_scan.sh" ;;
        q) exit 0 ;;
        *) echo "Invalid option"; sleep 1; show_menu ;;
    esac
}

show_menu
