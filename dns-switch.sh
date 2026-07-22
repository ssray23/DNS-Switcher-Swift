#!/bin/bash

# ─────────────────────────────────────────────
# dns-switch.sh
#
# How this script works:
# This script switches the Wi-Fi DNS server settings on macOS.
# - In "stream" mode, it sets DNS to SmartDNSProxy IPs to allow bypasses for streaming, flushes your local DNS cache,
#   and prompts you to disable iCloud Private Relay in System Settings (as Private Relay bypasses custom DNS in Safari).
# - In "normal" mode, it resets DNS to automatic (DHCP) and prompts you to turn iCloud Private Relay back ON.
# - It extracts and colorizes your iCloud Private Relay state directly from macOS system plists, polling the plist 
#   for changes after prompting you to toggle Private Relay and click 'Done' in System Settings.
#
# Usage:
#   bash dns-switch.sh stream  → SmartDNSProxy + open iCloud to pause Private Relay (needed for Safari)
#   bash dns-switch.sh normal  → Automatic + open iCloud to enable Private Relay (needed for Safari)
#   bash dns-switch.sh status  → Show current DNS
# ─────────────────────────────────────────────

SMART_DNS="35.178.60.174 45.77.61.165"

# ANSI Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

WIFI_INTERFACE=$(networksetup -listallnetworkservices | grep -i "wi-fi\|airport" | head -1)

if [ -z "$WIFI_INTERFACE" ]; then
    echo "ERROR: Could not detect Wi-Fi interface. Check: networksetup -listallnetworkservices"
    exit 1
fi


flush_dns() {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    echo "  DNS cache flushed."
}

get_relay_status() {
    python3 -c '
import plistlib, subprocess

def get_nested_val(val, objects):
    if isinstance(val, plistlib.UID):
        return get_nested_val(objects[val.data], objects)
    elif isinstance(val, dict):
        return {k: get_nested_val(v, objects) for k, v in val.items() if k != "$class"}
    elif isinstance(val, list):
        return [get_nested_val(v, objects) for v in val]
    return val

status = "OFF"
try:
    res = subprocess.run(["defaults", "export", "com.apple.networkserviceproxy", "-"], capture_output=True)
    if res.returncode == 0:
        data = plistlib.loads(res.stdout)
        if "NSPServiceStatusManagerInfo" in data:
            status_info = plistlib.loads(data["NSPServiceStatusManagerInfo"])
            objects = status_info.get("$objects", [])
            top = status_info.get("$top", {})
            if "ServiceStatus" in top:
                service_status = get_nested_val(top["ServiceStatus"], objects)
                global_status = service_status.get("PrivacyProxyServiceStatus")
                if global_status == 1:
                    status = "ON (Active)"
                    net_statuses = service_status.get("PrivacyProxyNetworkStatuses", {}).get("NS.objects", [])
                    for ns in net_statuses:
                        if ns.get("PrivacyProxyNetworkStatus") != 1:
                            status = "PAUSED"
                            break
                elif global_status == 2:
                    status = "PAUSED"
                else:
                    status = "OFF"
except:
    status = "OFF"
print(status)
' 2>/dev/null || echo "OFF"
}

show_status() {
    local context="$1"
    echo ""
    echo "Interface : $WIFI_INTERFACE"
    
    local dns_now
    dns_now=$(networksetup -getdnsservers "$WIFI_INTERFACE")
    
    local colored_dns=""
    local first=true
    while IFS= read -r line; do
        if [ "$first" = true ]; then
            first=false
        else
            colored_dns+=$'\n'
        fi
        
        if [ "$line" = "35.178.60.174" ] || [ "$line" = "45.77.61.165" ]; then
            colored_dns+="${GREEN}${line}${RESET}"
        else
            colored_dns+="${line}"
        fi
    done <<< "$dns_now"
    echo -e "DNS now   : $colored_dns"

    local relay_status
    relay_status=$(get_relay_status)
    local active_relay="$relay_status"
    
    local colored_relay="$relay_status"
    if [ "$relay_status" = "ON (Active)" ]; then
        colored_relay="${GREEN}ON (Active)${RESET}"
    elif [ "$relay_status" = "OFF" ]; then
        colored_relay="${RED}OFF${RESET}"
    elif [ "$relay_status" = "PAUSED" ]; then
        colored_relay="${YELLOW}PAUSED${RESET}"
    fi

    if [ "$context" = "stream" ] && [ "$relay_status" = "ON (Active)" ]; then
        active_relay="PENDING"
        echo -e "Private Relay: ${YELLOW}[Pending toggle to OFF in System Settings]${RESET}"
    elif [ "$context" = "normal" ] && { [ "$relay_status" = "OFF" ] || [ "$relay_status" = "PAUSED" ]; }; then
        active_relay="PENDING"
        echo -e "Private Relay: ${YELLOW}[Pending toggle to ON in System Settings]${RESET}"
    else
        echo -e "Private Relay: $colored_relay"
    fi

    # Print streaming notes if using SmartDNSProxy
    if [[ "$dns_now" =~ "35.178.60.174" ]] || [[ "$dns_now" =~ "45.77.61.165" ]]; then
        echo ""
        echo "💡 Reminder: It is advisable to reactivate your IP on the SmartDNSProxy My Account page"
        echo "   (https://www.smartdnsproxy.com/MyAccount) to ensure a seamless streaming experience."
        if [ "$active_relay" = "OFF" ] || [ "$active_relay" = "PAUSED" ]; then
            echo ""
            echo -e "🎉 You can now enjoy your favorite streaming services (i.e. Sony LIV, Jio Hotstar) on Safari browser for the best experience!"
        fi
    fi
    echo ""
}

manage_relay() {
    local action="$1" # "off" or "on"
    
    local current_status
    current_status=$(get_relay_status)

    if [ "$action" = "off" ]; then
        if [ "$current_status" = "OFF" ] || [ "$current_status" = "PAUSED" ]; then
            return 0
        fi
        echo ""
        echo "⚠️  iCloud Private Relay needs to be OFF to watch streaming content via SmartDNSProxy (relevant if using Safari browser)."
        echo "   Opening iCloud Settings... Please toggle Private Relay OFF and click 'Done' at the bottom."
        open "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?email/prefs/accountDetails?path=InternetPrivacy"
        return 1
    else
        if [ "$current_status" = "ON (Active)" ]; then
            return 0
        fi
        echo ""
        echo "ℹ️  Opening iCloud Settings... Please toggle Private Relay back ON and click 'Done' at the bottom (if using Safari browser)."
        open "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?email/prefs/accountDetails?path=InternetPrivacy"
        return 1
    fi
}

case "$1" in
    stream)
        echo ""
        echo "Switching to SmartDNSProxy (streaming mode)..."
        networksetup -setdnsservers "$WIFI_INTERFACE" $SMART_DNS
        flush_dns
        echo "  Set to: $SMART_DNS"
        manage_relay "off"
        if [ $? -eq 1 ]; then
            echo ""
            read -r -p "👉 Press [Enter] once you have toggled Private Relay OFF and clicked 'Done' in System Settings..."
            echo -n "Syncing settings status..."
            for i in {1..10}; do
                cur=$(get_relay_status)
                if [ "$cur" = "OFF" ] || [ "$cur" = "PAUSED" ]; then
                    break
                fi
                echo -n "."
                sleep 0.5
            done
            echo ""
        fi
        show_status "stream"
        ;;
    normal)
        echo ""
        echo "Switching to Automatic DNS (router decides)..."
        networksetup -setdnsservers "$WIFI_INTERFACE" "Empty"
        flush_dns
        echo "  DNS is now Automatic (no manual entries)."
        manage_relay "on"
        if [ $? -eq 1 ]; then
            echo ""
            read -r -p "👉 Press [Enter] once you have toggled Private Relay ON and clicked 'Done' in System Settings..."
            echo -n "Syncing settings status..."
            for i in {1..10}; do
                cur=$(get_relay_status)
                if [ "$cur" = "ON (Active)" ]; then
                    break
                fi
                echo -n "."
                sleep 0.5
            done
            echo ""
        fi
        show_status "normal"
        ;;
    status)
        show_status "status"
        ;;
    *)
        echo ""
        echo "Usage: bash dns-switch.sh [stream|normal|status]"
        echo ""
        echo "Modes:"
        echo "  stream  → SmartDNSProxy   ($SMART_DNS)"
        echo "  normal  → Automatic       (blank — router hands DNS via DHCP)"
        echo "  status  → Show current DNS"
        echo ""
        ;;
esac
