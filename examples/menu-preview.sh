#!/bin/bash
# Screenshot stand-in for examples/menu.sh.
# Machine name and free disk are fixed sample values.

hour=$(date +%H)
case $hour in
  0[5-9]|1[01]) hello="Morning" ;;
  1[2-6]) hello="Afternoon" ;;
  1[7-9]|2[01]) hello="Evening" ;;
  *) hello="Night" ;;
esac

when=$(date '+%a %-d %b · %-I:%M %p')
host="MacBook Pro"

power_line="On AC power"
power_color="green"
batt=$(pmset -g batt 2>/dev/null || true)
pct=$(printf '%s\n' "$batt" | awk 'match($0, /[0-9]+%/) { print substr($0, RSTART, RLENGTH - 1); exit }')
battery_state=$(printf '%s\n' "$batt" | awk -F ';' '/[0-9]+%/ { state=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", state); print state; exit }')
if [[ "$pct" =~ ^[0-9]+$ ]]; then
  if [[ "$battery_state" == discharging ]]; then
    if (( pct <= 20 )); then
      power_line="Battery ${pct}% · low"
      power_color="red"
    else
      power_line="Battery ${pct}% · unplugged"
      power_color="orange"
    fi
  elif [[ "$battery_state" == charging ]]; then
    power_line="Battery ${pct}% · charging"
    power_color="blue"
  elif [[ "$battery_state" == "not charging" ]]; then
    power_line="Battery ${pct}% · not charging"
    power_color="green"
  elif [[ "$battery_state" == charged ]]; then
    power_line="Battery ${pct}% · charged"
    power_color="green"
  else
    power_line="Battery ${pct}%"
    power_color="green"
  fi
fi

printf '%s\n---\n' "$hello"
printf '%s desk | color=blue size=15\n' "$hello"
printf '%s | size=12\n' "$when"
printf -- '---\n'
printf '%s | color=gray size=11\n' "$host"
printf '%s | color=%s size=13\n' "$power_line" "$power_color"
printf '128 GB free | size=12\n'
printf -- '---\n'
printf 'Open | color=gray size=11\n'
printf 'Project page | shell=/usr/bin/open param1=https://github.com/PVRLabs/leanbar terminal=false\n'
printf 'Downloads | shell=/usr/bin/open param1="%s" terminal=false\n' "$HOME/Downloads"
printf -- '---\n'
printf 'Say hello | color=blue shell=/usr/bin/say param1="Hello from LeanBar" terminal=false refresh=true\n'
