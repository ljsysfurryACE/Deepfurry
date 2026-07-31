#!/bin/sh
# Cloud LTE OS Dashboard v2 ☁️
# Enhanced TUI with dialog if available, fallback to plain shell

HAS_DIALOG=$(command -v dialog 2>/dev/null)

# Color codes for fallback
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

get_ip() {
    ifconfig eth0 2>/dev/null | grep "inet " | awk '{print $2}'
}

get_wifi_ssid() {
    iw dev wlan0 link 2>/dev/null | grep "SSID" | awk '{print $2}'
}

get_uptime() {
    uptime 2>/dev/null | awk -F'up' '{print $2}' | cut -d, -f1 | sed 's/^ *//'
}

get_ram() {
    free -m 2>/dev/null | awk '/Mem:/{printf "%dMB / %dMB (%d%%)", $3, $2, $3*100/$2}'
}

get_disk() {
    df -h / 2>/dev/null | tail -1 | awk '{print $3 "/" $2}'
}

get_cpu_temp() {
    cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f°C", $1/1000}' || echo "N/A"
}

if [ -n "$HAS_DIALOG" ]; then
    # ===== DIALOG MODE =====
    while true; do
        IP=$(get_ip)
        SSID=$(get_wifi_ssid)
        UPTIME=$(get_uptime)
        RAM=$(get_ram)

        dialog --clear --title "☁️ Cloud LTE OS 7.1.5" \
            --colors \
            --backtitle "Cloud LTE OS Dashboard" \
            --menu "\nZ"\
"        IP: ${IP:-Not connected}\n"\
"        WiFi: ${SSID:-N/A}\n"\
"        Uptime: ${UPTIME:-?}\n"\
"        RAM: ${RAM}\n"\
"        ════════════════════════════\n"\
"        Select an option:" 20 60 9 \
            1 "📊 System Info" \
            2 "🌐 Network / WiFi" \
            3 "💾 Disk & Storage" \
            4 "🔍 Process Monitor" \
            5 "📦 Package Manager (deep)" \
            6 "🔌 File Server (:8080)" \
            7 "💿 Install to Disk" \
            8 "🖥 Shell" \
            9 "🔒 Shutdown / Reboot" \
            2>/tmp/menu_choice

        [ $? -ne 0 ] && clear && exit 0

        choice=$(cat /tmp/menu_choice)
        case "$choice" in
            1)
                dialog --title "System Info" --msgbox "\
Hostname: $(hostname)\n\
Kernel:   $(uname -r)\n\
CPU:      $(grep -c processor /proc/cpuinfo) cores\n\
RAM:      $(get_ram)\n\
Uptime:   $(get_uptime)\n\
Temp:     $(get_cpu_temp)\n\
Date:     $(date '+%Y-%m-%d %H:%M')\n\
IP:       $(get_ip)" 14 50
                ;;
            2)
                dialog --menu "Network & WiFi" 15 50 4 \
                    1 "📶 Scan WiFi" \
                    2 "🔑 Connect to WiFi" \
                    3 "📡 Network Status" \
                    4 "🔄 Renew DHCP" \
                    2>/tmp/net_choice
                net=$(cat /tmp/net_choice)
                case "$net" in
                    1)
                        dialog --infobox "Scanning... (10s)" 3 20
                        iw dev wlan0 scan 2>/dev/null | grep "SSID:" | awk '{print $2}' > /tmp/wifi_list
                        dialog --textbox /tmp/wifi_list 15 40
                        ;;
                    2)
                        dialog --inputbox "Enter SSID:" 8 40 2>/tmp/ssid
                        dialog --passwordbox "Enter Password:" 8 40 2>/tmp/psk
                        SSID=$(cat /tmp/ssid); PSK=$(cat /tmp/psk)
                        [ -n "$SSID" ] && {
                            wpa_passphrase "$SSID" "$PSK" > /tmp/wpa.conf 2>/dev/null
                            wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf 2>/dev/null
                            sleep 2
                            udhcpc -i wlan0 2>/dev/null &
                            dialog --msgbox "Connecting to $SSID..." 5 40
                        }
                        ;;
                    3)
                        dialog --title "Network Status" --msgbox "\
$(ifconfig wlan0 2>/dev/null || echo "wlan0: down")\n\
$(ifconfig eth0 2>/dev/null | head -3)" 14 60
                        ;;
                    4)
                        udhcpc -i eth0 2>/dev/null &
                        dialog --msgbox "DHCP renewed" 5 30
                        ;;
                esac
                ;;
            3)
                dialog --title "Disk Info" --msgbox "$(df -h 2>/dev/null)" 14 60
                ;;
            4)
                while true; do
                    ps aux 2>/dev/null | head -25 > /tmp/pslist
                    dialog --title "Process Monitor (top 25)" --textbox /tmp/pslist 18 70
                    break
                done
                ;;
            5)
                dialog --menu "Package Manager" 12 50 4 \
                    1 "📋 List Installed" \
                    2 "🔍 Update Package List" \
                    3 "📥 Install Package" \
                    4 "♻ Check System Update" \
                    2>/tmp/deep_choice
                dpkg=$(cat /tmp/deep_choice)
                case "$dpkg" in
                    1) deep list 2>/dev/null > /tmp/deep_out; dialog --textbox /tmp/deep_out 12 50;;
                    2) deep update 2>/dev/null > /tmp/deep_out; dialog --textbox /tmp/deep_out 12 60;;
                    3) deep list 2>/dev/null; dialog --inputbox "Package name:" 8 40 2>/tmp/pkg; PKG=$(cat /tmp/pkg); [ -n "$PKG" ] && deep install "$PKG" 2>/dev/null > /tmp/deep_out && dialog --textbox /tmp/deep_out 12 60;;
                    4) deep upgrade 2>/dev/null > /tmp/deep_out; dialog --textbox /tmp/deep_out 12 60;;
                esac
                ;;
            6)
                httpd -p 8080 -h /root 2>/dev/null &
                dialog --msgbox "File Server started on :8080\nIP: $(get_ip):8080" 6 40
                ;;
            7)
                dialog --yesno "Install Cloud LTE OS to disk?\nThis will overwrite the target disk!" 7 40
                [ $? -eq 0 ] && (install.sh 2>/dev/null; dialog --msgbox "Installation complete" 5 30)
                ;;
            8)
                dialog --clear
                clear
                echo "☁️ Cloud LTE Shell (type 'exit' to return)"
                /bin/sh -l
                ;;
            9)
                dialog --menu "Power" 10 30 2 \
                    1 "🔁 Reboot" \
                    2 "⏻ Shutdown" \
                    2>/tmp/pwr
                pwr=$(cat /tmp/pwr)
                [ "$pwr" = "1" ] && reboot
                [ "$pwr" = "2" ] && poweroff
                ;;
        esac
    done
else
    # ===== FALLBACK SHELL MODE (no dialog) =====
    while true; do
        clear
        IP=$(get_ip)
        SSID=$(get_wifi_ssid)
        UPTIME=$(get_uptime)
        RAM=$(get_ram)
        DISK=$(get_disk)

        echo -e "${CYAN}=====================================${NC}"
        echo -e "  ${GREEN}☁️ Cloud LTE OS 7.1.5${NC}"
        echo -e "${CYAN}=====================================${NC}"
        echo -e "  ${YELLOW}IP:${NC}     ${IP:-Not connected}"
        echo -e "  ${YELLOW}WiFi:${NC}   ${SSID:-N/A}"
        echo -e "  ${YELLOW}RAM:${NC}    ${RAM}"
        echo -e "  ${YELLOW}Disk:${NC}   ${DISK}"
        echo -e "  ${YELLOW}CPU:${NC}    $(grep -c processor /proc/cpuinfo) cores | $(get_cpu_temp)"
        echo -e "  ${YELLOW}Up:${NC}     ${UPTIME:-?}"
        echo -e "${CYAN}=====================================${NC}"
        echo -e "  ${GREEN}1${NC}) 📊 System Info"
        echo -e "  ${GREEN}2${NC}) 🌐 Network / WiFi"
        echo -e "  ${GREEN}3${NC}) 💾 Disk & Storage"
        echo -e "  ${GREEN}4${NC}) 🔍 Process Monitor"
        echo -e "  ${GREEN}5${NC}) 📦 Package Manager"
        echo -e "  ${GREEN}6${NC}) 🔌 Start File Server :8080"
        echo -e "  ${GREEN}7${NC}) 💿 Install to Disk"
        echo -e "  ${GREEN}8${NC}) 🖥 Shell"
        echo -e "  ${GREEN}9${NC}) 🔒 Power (Reboot/Shutdown)"
        echo -e "  ${GREEN}q${NC}) Quit"
        echo -e "${CYAN}=====================================${NC}"
        echo -ne "Choice: "
        read choice

        case "$choice" in
            1)
                echo; uname -a
                echo "CPU: $(grep -c processor /proc/cpuinfo) cores"
                free -m | head -3
                echo "Temp: $(get_cpu_temp)"
                echo "Date: $(date)"
                echo; echo "Press Enter..."; read x
                ;;
            2)
                echo "1) Scan WiFi"
                echo "2) Connect WiFi"
                echo "3) Network Status"
                read net
                case "$net" in
                    1) iw dev wlan0 scan 2>/dev/null | grep "SSID:"; echo; echo "Press Enter..."; read x;;
                    2) echo -n "SSID: "; read ssid; echo -n "Pass: "; read -s psk; echo; wpa_passphrase "$ssid" "$psk" > /tmp/wpa.conf; wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf 2>/dev/null; sleep 2; udhcpc -i wlan0 2>/dev/null & echo "Connecting..."; sleep 1;;
                    3) ifconfig; echo; echo "Press Enter..."; read x;;
                esac
                ;;
            3) df -h; echo; echo "Press Enter..."; read x;;
            4) ps aux | head -25; echo; echo "Press Enter..."; read x;;
            5)
                echo "1) List installed"
                echo "2) Update package list"
                echo "3) Install package"
                read dpkg
                case "$dpkg" in
                    1) deep list;;
                    2) deep update;;
                    3) echo -n "Package: "; read pkg; deep install "$pkg";;
                esac
                echo; echo "Press Enter..."; read x
                ;;
            6) httpd -p 8080 -h /root & echo "Started :8080"; sleep 1;;
            7) install.sh; echo; echo "Press Enter..."; read x;;
            8) echo "Type exit to return"; /bin/sh -l;;
            9)
                echo "1) Reboot  2) Shutdown"
                read pwr
                [ "$pwr" = "1" ] && reboot
                [ "$pwr" = "2" ] && poweroff
                ;;
            q|Q) clear; exit 0;;
        esac
    done
fi
