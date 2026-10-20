# shellcheck shell=bash
# The optional Windows helper for an install inside WSL2 (unsupported, best effort):
# windows/tortugarr-windows.ps1 does port forwarding, firewall rules and keep-alive on the
# Windows side, elevated with one UAC prompt. Never touches .wslconfig.

# WIN_PS (full path, also under sudo) comes from lib/detect.sh.
WIN_STATE=/mnt/c/ProgramData/Tortugarr/windows-state.json

# Windows programs can be started from here (WSL interop is on and works).
win_interop_ok() {
  is_wsl && [ -x "$WIN_PS" ] && "$WIN_PS" -NoProfile -Command 'exit 0' >/dev/null 2>&1
}

# The WSL distro name. sudo drops WSL_DISTRO_NAME from the environment, so look in the
# parent processes (the user's shell still has it).
wsl_distro_name() {
  [ -n "${WSL_DISTRO_NAME:-}" ] && { echo "$WSL_DISTRO_NAME"; return; }
  local pid=$$ v
  while [ "${pid:-0}" -gt 1 ]; do
    v=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^WSL_DISTRO_NAME=//p' | head -1)
    [ -n "$v" ] && { echo "$v"; return; }
    pid=$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null)
  done
}

win_helper_set_up() { [ -f "$WIN_STATE" ]; }

# Something of ours is on Windows: the state file, or - after a setup that never wrote one -
# the 'Tortugarr' firewall group or keep-alive tasks (read without administrator rights).
win_helper_present() {
  win_helper_set_up && return 0
  win_interop_ok || return 1
  [ "$("$WIN_PS" -NoProfile -Command "if ((Get-NetFirewallRule -Group Tortugarr -EA SilentlyContinue) -or (Get-ScheduledTask -TaskName 'Tortugarr keepalive*' -EA SilentlyContinue)) { 'yes' }" 2>/dev/null | tr -d '\r')" = yes ]
}

# The ports the stack publishes, from state.json, and the torrent peer port.
win_ports() {
  local f; f=$(STATE_FILE)
  jq -r --arg c "$(jq -r .torrent_client "$f")" --argjson u "$(jq -r '.usenet // false' "$f")" '
    [.ports.jellyfin, .ports.seerr, .ports.sonarr, .ports.radarr, .ports.prowlarr, .ports.bazarr]
    + (if $c != "none" then [.ports.torrent_web] else [] end)
    + (if $u then [.ports.sabnzbd] else [] end)
    | map(select(. != null) | tostring) | join(",")' "$f"
}
win_peer_port() {
  local f; f=$(STATE_FILE)
  [ "$(jq -r .torrent_client "$f")" = none ] && { echo 0; return; }
  jq -r '.ports.torrent_peer // 0' "$f"
}

# The command an administrator can run by hand (WSL interop off, UAC declined, ...).
win_manual_command() {
  local action=$1; shift
  local path="\\\\wsl.localhost\\$(wsl_distro_name)${INSTALL_DIR//\//\\}\\app\\windows\\tortugarr-windows.ps1"
  # The helper keeps a copy of itself there (setup puts it there first); uninstall removes the
  # WSL side afterwards.
  [ "$action" = remove ] && [ -f /mnt/c/ProgramData/Tortugarr/tortugarr-windows.ps1 ] && path='C:\ProgramData\Tortugarr\tortugarr-windows.ps1'
  printf 'powershell -ExecutionPolicy Bypass -File "%s" %s %s\n' "$path" "$action" "$*"
}

# Runs the helper elevated (one UAC prompt) and shows what it did. Returns its exit code.
win_helper_run() {
  local action=$1; shift
  local tmp win_tmp script log
  win_tmp=$("$WIN_PS" -NoProfile -Command '[IO.Path]::GetTempPath()' 2>/dev/null | tr -d '\r')
  tmp=$(wslpath -u "$win_tmp" 2>/dev/null) || return 98
  cp "$TORTUGARR_APP/windows/tortugarr-windows.ps1" "$tmp/tortugarr-windows.ps1" || return 98
  script=$(wslpath -w "$tmp/tortugarr-windows.ps1"); log=$(wslpath -w "$tmp/tortugarr-windows.log")
  rm -f "$tmp/tortugarr-windows.log"
  local args="'-NoProfile','-ExecutionPolicy','Bypass','-File','$script','$action','-LogFile','$log'" a
  for a in "$@"; do args+=",'$a'"; done
  "$WIN_PS" -NoProfile -Command "try { \$p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @($args); exit \$p.ExitCode } catch { exit 99 }" >/dev/null 2>&1
  local rc=$?
  # The helper's own output, without the transcript's header and footer.
  [ -f "$tmp/tortugarr-windows.log" ] && tr -d '\r' < "$tmp/tortugarr-windows.log" | sed -n '/^\*\*\*\*\*\*\*\*\*\*/,$p' | grep -v '^\*\*\*\*\|^Windows PowerShell transcript\|^Start time\|^End time\|^Username\|^RunAs User\|^Configuration Name\|^Machine\|^Host Application\|^Process ID\|^PSVersion\|^PSEdition\|^PSCompatible\|^BuildVersion\|^CLRVersion\|^WSManStack\|^PSRemoting\|^Serialization\|^Transcript started' | sed '/^$/d; s/^/    /'
  return $rc
}

# The red, bold warning: what happens, why, and the risk. Then two choices and no default -
# the user has to pick one (Enter alone does nothing). Returns 0 for "let the installer do it".
win_caution() {
  echo
  printf '%s%s' "$C_RED" "$C_BOLD"
  say "  ┌─ $(t win_caution_title)"
  local k
  for k in win_what win_what_1 win_what_2 win_what_3 win_why win_why_1 win_risk win_risk_1 win_risk_2 win_risk_3 win_caution_4; do
    say "  │ $(t "$k")"
  done
  say "  └─────────────────────────────────────────────────────────────────────"
  printf '%s' "$C_RESET"
  if [ "$UNATTENDED" = 1 ]; then
    case "${WINDOWS_HELPER:-}" in yes) return 0 ;; no) return 1 ;; esac
    note "$(t win_skipped_unattended)"; return 1
  fi
  say "   1) $(t win_choice_do)"
  say "   2) $(t win_choice_skip)"
  local ans
  while :; do
    read -r -p "$(printf '%s? %s%s ' "$C_BOLD" "$(t q_win_choice)" "$C_RESET")" ans </dev/tty
    case "$ans" in 1) return 0 ;; 2) return 1 ;; esac
    warning "$(t win_choose_1_or_2)"
  done
}

# "I will do it myself": exactly what to run on Windows, printed and saved to a file.
win_write_manual() {
  local ports=$1 peer=$2 distro=$3 ip f p
  ip=$(jq -r .lan_ip "$(STATE_FILE)"); f="$INSTALL_DIR/windows-setup-yourself.txt"
  {
    echo "# Tortugarr in WSL2: the Windows side, done by hand."
    echo "# Run these in an administrator PowerShell on Windows (Start > type PowerShell > Run as administrator)."
    echo "# Why: WSL gets a new internal address at every start and does not start on its own, so"
    echo "# Windows must forward the ports and keep WSL running. This affects every WSL distro."
    echo
    echo "# 1) Forward the Tortugarr ports from the Windows LAN address ($ip) to WSL (through 127.0.0.1,"
    echo "#    where WSL's localhost relay listens):"
    for p in ${ports//,/ }; do
      echo "netsh interface portproxy add v4tov4 listenaddress=$ip listenport=$p connectaddress=127.0.0.1 connectport=$p"
    done
    echo
    echo "# 2) Open exactly those ports in Windows' firewall (private networks):"
    for p in ${ports//,/ }; do
      echo "New-NetFirewallRule -DisplayName 'Tortugarr TCP $p' -Group Tortugarr -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p -Profile Private,Domain"
    done
    if [ "$peer" != 0 ]; then
      echo "New-NetFirewallRule -DisplayName 'Tortugarr peer TCP $peer' -Group Tortugarr -Direction Inbound -Action Allow -Protocol TCP -LocalPort $peer -Profile Private,Domain"
      echo "New-NetFirewallRule -DisplayName 'Tortugarr peer UDP $peer' -Group Tortugarr -Direction Inbound -Action Allow -Protocol UDP -LocalPort $peer -Profile Private,Domain"
    fi
    echo "# If Windows calls your network Public, these rules do not apply there. Set it to Private:"
    echo "#   Settings > Network & internet > (your connection) > Network profile type: Private"
    echo
    echo "# 3) Keep WSL ($distro) running: started when Windows starts (also without anyone logging"
    echo "#    in), at logon, and every 5 minutes - so it also comes back after 'wsl --shutdown'."
    echo "#    The task keeps running as long as the keep-alive does; 'IgnoreNew' stops a second copy."
    echo "\$u = \"\$env:USERDOMAIN\\\$env:USERNAME\""
    echo "\$a = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument '-d $distro --exec env TORTUGARR_KEEPALIVE=1 sleep infinity'"
    echo "\$t3 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)"
    echo "\$t1 = New-ScheduledTaskTrigger -AtStartup; \$t1.Repetition = \$t3.Repetition"
    echo "\$t2 = New-ScheduledTaskTrigger -AtLogOn -User \$u; \$t2.Repetition = \$t3.Repetition"
    echo "\$s = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries"
    echo "\$p = New-ScheduledTaskPrincipal -UserId \$u -LogonType S4U -RunLevel Highest"
    echo "Register-ScheduledTask -TaskName 'Tortugarr keepalive' -Action \$a -Trigger \$t1,\$t2,\$t3 -Settings \$s -Principal \$p"
    echo "Start-ScheduledTask -TaskName 'Tortugarr keepalive'"
    echo
    echo "# Check from another device (or this PC's browser): http://$ip:${ports%%,*} must open."
    echo "# When the Windows LAN address changes, repeat step 1 with the new address (a fixed address"
    echo "# for this PC in your router avoids that)."
    echo "# Or let Tortugarr do all of this later: sudo tortugarr windows"
    echo
    echo "# To undo it:"
    for p in ${ports//,/ }; do echo "netsh interface portproxy delete v4tov4 listenaddress=$ip listenport=$p"; done
    echo "Remove-NetFirewallRule -Group Tortugarr"
    echo "Unregister-ScheduledTask -TaskName 'Tortugarr keepalive' -Confirm:\$false"
  } > "$f"
  chmod 644 "$f"
  sed 's/^/    /' "$f"
  echo
  good "$(t win_manual_saved "$f")"
}

# After install/reconfigure inside WSL: offer the helper; on any failure print the manual command.
offer_windows_helper() {
  is_wsl || return 0
  header "$(t win_header)"
  local ports peer distro
  ports=$(win_ports); peer=$(win_peer_port); distro=$(wsl_distro_name)
  if [ -z "$distro" ]; then warning "$(t win_no_distro)"; return 0; fi
  if ! win_caution; then
    note "$(t win_later)"
    win_write_manual "$ports" "$peer" "$distro"
    return 0
  fi
  if ! win_interop_ok; then
    warning "$(t win_no_interop)"; say "    $(win_manual_command setup -Ports "$ports" -PeerPort "$peer" -Distro "$distro")"
    return 0
  fi
  note "$(t win_uac)"
  local rc=0
  win_helper_run setup -Ports "$ports" -PeerPort "$peer" -Distro "$distro" -PublicNetwork "${WINDOWS_PUBLIC_NETWORK:-ask}" || rc=$?
  if [ "$rc" = 0 ]; then
    good "$(t win_done)"
  elif [ "$rc" = 4 ]; then
    # Network left Public by the user's own choice: set up, but other devices are blocked.
    warning "$(t win_done_left_public)"
  elif [ "$rc" = 3 ]; then
    # Set up, but not every port answered through the forwarding (the window said which).
    warning "$(t win_done_unanswered)"
  else
    warning "$(t win_failed)"; say "    $(win_manual_command setup -Ports "$ports" -PeerPort "$peer" -Distro "$distro")"
  fi
}

# Uninstall: take the Windows side away too (UAC); print the command if that is not possible.
# The ports and distro go along, so leftovers without a state file are found as well.
remove_windows_helper() {
  is_wsl && win_helper_present || return 0
  say "  - $(t u_windows)"
  local ports distro
  ports=$(win_ports 2>/dev/null); distro=$(wsl_distro_name)
  if win_interop_ok && win_helper_run remove -Ports "$ports" -Distro "$distro"; then good "$(t win_removed)"
  else warning "$(t win_remove_manual)"; say "    $(win_manual_command remove -Ports "$ports" -Distro "$distro")"; fi
}

# The keep-alive seen from inside WSL: the `sleep infinity` that wsl.exe started with
# TORTUGARR_KEEPALIVE=1 in its environment. (From Windows, only an administrator can see its
# command line - the doctor runs without that.) Prints one PID per keep-alive.
win_keepalive_pids() {
  local f pid
  for f in /proc/[0-9]*/environ; do
    { tr '\0' '\n' < "$f"; } 2>/dev/null | grep -qx 'TORTUGARR_KEEPALIVE=1' || continue
    pid=${f#/proc/}; echo "${pid%/environ}"
  done
}

# Doctor: what is set up on the Windows side (read only, no UAC).
windows_helper_status() {
  is_wsl || return 0
  if ! win_helper_set_up; then
    if win_helper_present; then warning "$(t win_leftovers)"; else warning "$(t win_not_set_up)"; fi
    return 0
  fi
  win_interop_ok || { warning "$(t win_no_interop)"; return 0; }
  "$WIN_PS" -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w /mnt/c/ProgramData/Tortugarr/tortugarr-windows.ps1)" status 2>&1 | tr -d '\r' | sed 's/^/    /'
  local n; n=$(win_keepalive_pids | wc -l)
  case "$n" in
    1) good "$(t win_keepalive_ok)" ;;
    0) warning "$(t win_keepalive_missing)" ;;
    *) warning "$(t win_keepalive_many "$n")" ;;
  esac
}
