#!/bin/bash
# 📡 wifihotspotforpipack.sh — Hotspot Creator & Monitor for Raspberry Pi

ROOT="$HOME/power-wifi-controls"
mkdir -p "$ROOT/logs" "$ROOT/kicked" "$ROOT/wifi-blocked-users"

HOTSPOT_SSID="PI-CONNECT"
read -r -s -p "Choose hotspot password (at least 8 characters): " HOTSPOT_PASS
echo
if [ ${#HOTSPOT_PASS} -lt 8 ]; then echo "Password too short."; exit 1; fi
LOGFILE="$ROOT/logs/hotspot-log.txt"

echo "[📶] Scanning upstream networks..."
mapfile -t networks < <(nmcli -t -f SSID dev wifi | grep -v '^$')
for i in "${!networks[@]}"; do echo "$i) ${networks[$i]}"; done
read -p "Select Wi-Fi to clone: " idx
UPSTREAM="${networks[$idx]}"
read -r -s -p "Password for $UPSTREAM: " upass
echo

echo "[🔗] Connecting to upstream: $UPSTREAM..."
nmcli dev wifi connect "$UPSTREAM" password "$upass"

echo "[🚀] Launching hotspot \"$HOTSPOT_SSID\"..."
nmcli connection delete "$HOTSPOT_SSID" &>/dev/null
nmcli dev wifi hotspot ifname wlan1 ssid "$HOTSPOT_SSID" password "$HOTSPOT_PASS"

echo "[👁️] Monitoring devices..."
while true; do
  clients=$(arp -n | grep wlan1 | awk '{print $1":"$3}')
  for entry in $clients; do
    ip="${entry%%:*}"
    mac="${entry##*:}"
    name=$(avahi-resolve-address "$ip" 2>/dev/null | awk '{print $2}')
    name=${name:-UnknownDevice}
    ts=$(date "+%H:%M:%S %d/%m/%Y")
    echo "$name : $ip at $ts" >> "$LOGFILE"

    # Show warning if kicked
    if [[ -f "$ROOT/kicked/$ip.kicked" ]]; then
      echo "⚠️ $name ($ip) was kicked. Press D to block, E to ignore, F to block MAC."
      read -n1 key; echo
      case "$key" in
        D) touch "$ROOT/wifi-blocked-users/$ip.blocked" ;;
        E) echo "Ignored $name." ;;
        F) iptables -A INPUT -m mac --mac-source "$mac" -j DROP ;;
      esac
    fi
  done
  sleep 10
done
