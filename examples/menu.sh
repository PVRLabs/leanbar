#!/bin/bash
# Flat desk menu. SwiftBar shows the first line in the bar; LeanBar shows LB.
# Status lines have no command. Actions use an absolute executable and terminal=false.

hour=$(date +%H)
case $hour in
  0[5-9]|1[01]) hello="Morning" ;;
  1[2-6]) hello="Afternoon" ;;
  1[7-9]|2[01]) hello="Evening" ;;
  *) hello="Night" ;;
esac

when=$(date '+%a %-d %b · %-I:%M %p')
host=$(scutil --get ComputerName 2>/dev/null || hostname -s 2>/dev/null || printf 'This Mac')
host=${host//|/}
host=${host//$'\n'/ }
if (( ${#host} > 32 )); then host="${host:0:32}"; fi

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

free_gb=$(df -g / 2>/dev/null | awk 'NR==2 { print $4 }')

printf '%s\n---\n' "$hello"
printf '%s desk | color=blue size=15\n' "$hello"
printf '%s | size=12\n' "$when"
printf -- '---\n'
printf '%s | color=gray size=11\n' "$host"
printf '%s | color=%s size=13\n' "$power_line" "$power_color"
if [[ "$free_gb" =~ ^[0-9]+$ ]]; then
  printf '%s GB free | size=12\n' "$free_gb"
fi
printf -- '---\n'
printf 'Open | color=gray size=11\n'
printf 'Project page | shell=/usr/bin/open param1=https://github.com/PVRLabs/leanbar terminal=false\n'
printf 'Downloads | shell=/usr/bin/open param1="%s" terminal=false\n' "$HOME/Downloads"
printf -- '---\n'
printf 'Say hello | color=blue shell=/usr/bin/say param1="Hello from LeanBar" terminal=false refresh=true\n'
