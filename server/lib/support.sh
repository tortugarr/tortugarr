# shellcheck shell=bash
# Support bundle: what someone helping needs - versions, status, doctor, the install log and
# recent container logs - with every password, API key and token removed, and checked.

# Every secret this install knows: secrets.json, Seerr's API key, the VPN settings.
support_secrets() {
  {
    jq -r '.. | strings' "$(SECRETS_FILE)" 2>/dev/null
    jq -r '.main.apiKey // empty' "$CONFIG_DIR/seerr/settings.json" 2>/dev/null
    [ -f "$INSTALL_DIR/overrides/vpn.env" ] && sed -n 's/^[A-Z_]*\(KEY\|PASSWORD\|USER\|ADDRESSES\)=//p' "$INSTALL_DIR/overrides/vpn.env"
    [ -f "$INSTALL_DIR/.env" ] && sed -n 's/^[A-Z_]*\(PASSWORD\|KEY\|TOKEN\)=//p' "$INSTALL_DIR/.env" | tr -d "'\""
  } | awk 'length($0) >= 6' | sort -u
}

# Replaces each secret, and anything that looks like a key or token, with ***.
support_scrub() {
  local dir=$1 list=$2
  local f
  # Literal secrets first (fixed strings, longest first so a key inside a longer value goes too).
  awk '{ print length($0) "\t" $0 }' "$list" | sort -rn | cut -f2- > "$list.sorted"
  find "$dir" -type f | while read -r f; do
    awk -v listfile="$list.sorted" '
      BEGIN { while ((getline s < listfile) > 0) secrets[++n] = s }
      { line = $0
        for (i = 1; i <= n; i++) { while ((p = index(line, secrets[i])) > 0) line = substr(line, 1, p - 1) "***" substr(line, p + length(secrets[i])) }
        print line }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    # Patterns: tokens, API keys and passwords that are not in the list (for example a user session token).
    sed -i -E \
      -e 's/(Token=\\?")[^"\\]*/\1***/g' \
      -e 's/([?&](api_?key|apikey|token|X-Api-Key)=)[^&[:space:]"]*/\1***/Ig' \
      -e 's/((api[_-]?key|password|passwd|secret|token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?)[^"'"'"'[:space:],}]+/\1***/Ig' \
      "$f"
  done
}

cmd_support() {
  require_install
  header "$(t support_header)"
  local stamp work out list
  stamp=$(date +%Y%m%d-%H%M%S)
  work=$(mktemp -d); out="$INSTALL_DIR/support/tortugarr-support-$stamp.tar.gz"
  mkdir -p "$work/logs" "$INSTALL_DIR/support"
  step "$(t support_collecting)"
  {
    echo "Tortugarr $INSTALLED_VERSION, collected $(date -u +%FT%TZ)"
    echo "OS: $(os_pretty), kernel $(uname -r), arch $(arch), platform $(is_wsl && echo WSL2 || echo Linux)"
    echo "Docker: $(docker version --format '{{.Server.Version}}' 2>/dev/null), compose $(docker compose version --short 2>/dev/null)"
    echo "Disk: $(df -h "$DATA_DIR" "$INSTALL_DIR" 2>/dev/null | tail -n +2 | awk '{print $6": "$4" free of "$2}' | paste -sd ';' -)"
  } > "$work/summary.txt"
  # Settings that describe the install (ports, choices) - state.json holds no secrets, scrubbed anyway.
  cp "$(STATE_FILE)" "$work/state.json" 2>/dev/null
  cp "$TORTUGARR_APP/versions.env" "$work/versions.env" 2>/dev/null
  dc ps -a --format 'table {{.Service}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}' > "$work/containers.txt" 2>&1
  (run_doctor) > "$work/doctor.txt" 2>&1
  is_wsl && windows_helper_status > "$work/windows.txt" 2>&1
  ls -t "$INSTALL_DIR"/logs/tortugarr-*.log 2>/dev/null | head -3 | while read -r l; do cp "$l" "$work/logs/"; done
  local svc
  for svc in $(expected_services); do
    docker logs --tail 400 "tortugarr-$svc" > "$work/logs/$svc.log" 2>&1
  done
  sed -i 's/\x1b\[[0-9;]*m//g' "$work"/*.txt 2>/dev/null

  step "$(t support_scrubbing)"
  list=$(mktemp); support_secrets > "$list"
  support_scrub "$work" "$list"
  # Check: not one known secret may be left - otherwise no bundle at all.
  local leaks; leaks=$(grep -rlF -f "$list" "$work" 2>/dev/null | wc -l)
  rm -f "$list" "$list.sorted"
  if [ "$leaks" -gt 0 ]; then
    rm -rf "$work"
    die "$(t support_leak)"
  fi
  tar -czf "$out" -C "$work" . && rm -rf "$work"
  chmod 644 "$out"
  [ -n "$INVOKER" ] && [ "$INVOKER" != root ] && chown "$INVOKER" "$out" 2>/dev/null
  good "$(t support_done "$out")"
  say "$(t support_share)"
}
