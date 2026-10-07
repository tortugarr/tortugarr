# Deliberate crash test for windows/tortugarr-windows.ps1, on a FAKE Windows (crash-case.ps1).
# Run it with PowerShell 7 on Linux (tests/windows/crash-test.sh) - never on an everyday
# Windows PC. For each step of setup it crashes on
# purpose, both as an error (the helper must undo everything at once) and as a hard kill - a
# power cut or a closed window (the state file must cover everything that is there, and
# 'remove' must then clean it all up). Also: leftovers with no state file at all.
#   pwsh -File crash-test.ps1 -Helper <tortugarr-windows.ps1> -Base <scratch dir>
param([Parameter(Mandatory)] [string]$Helper, [Parameter(Mandatory)] [string]$Base)
$ErrorActionPreference = 'Stop'
$Case = Join-Path $PSScriptRoot 'crash-case.ps1'
$Ports = '58096,58055,58989'; $Peer = 56881; $Distro = 'TestDistro'
$script:fails = 0; $script:passes = 0
$Exe = (Get-Process -Id $PID).Path

function New-Work([string]$Name, $System) {
  $w = Join-Path $Base $Name
  if (Test-Path $w) { Remove-Item $w -Recurse -Force }
  New-Item -ItemType Directory -Path $w | Out-Null
  $System | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $w 'system.json') -Encoding UTF8
  return $w
}
# A PC with things that are not Tortugarr's, which must survive everything.
function New-System {
  @{ lan_ip = '192.0.2.10'; distro = $Distro; keepalive = $false
     network = @{ name = 'TestNet'; index = 7; category = 'Public' }
     portproxy = @(@{ kind = 'v4tov4'; ip = '0.0.0.0'; port = 3390; to = '10.0.0.5/3389' })
     firewall = @(@{ name = 'Other app'; group = 'Other'; port = '1234'; profile = 'Any' })
     tasks = @('Other task') }
}
function Invoke-Helper([string]$Work, [string]$FailAt, [string]$How, [string[]]$HelperArgs) {
  $env:TORTUGARR_WINDOWS_FAIL_AT = $FailAt; $env:TORTUGARR_WINDOWS_FAIL_HOW = $How
  $ErrorActionPreference = 'Continue'
  $out = & $Exe -NoProfile -ExecutionPolicy Bypass -File $Case -Helper $Helper -Work $Work -HelperArgList ($HelperArgs -join '|') 2>&1
  $rc = $LASTEXITCODE
  $env:TORTUGARR_WINDOWS_FAIL_AT = ''; $env:TORTUGARR_WINDOWS_FAIL_HOW = ''
  Add-Content (Join-Path $Work 'output.log') ("`n### $($HelperArgs -join ' ') fail=$FailAt/$How rc=$rc"), ($out | Out-String)
  return $rc
}
function Get-Sys([string]$Work) {
  # Unreadable means two runs wrote the fake machine at once - the lock did not work.
  try { Get-Content (Join-Path $Work 'system.json') -Raw | ConvertFrom-Json }
  catch { Check 'the fake machine is readable (one helper run at a time)' $false $_.Exception.Message; [pscustomobject]@{ portproxy = @(); firewall = @(); tasks = @() } }
}
function Get-HelperState([string]$Work) {
  $f = Join-Path (Join-Path $Work 'ProgramData-Tortugarr') 'windows-state.json'
  if (Test-Path $f) { Get-Content $f -Raw | ConvertFrom-Json }
}
function Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:passes++; Write-Host "  PASS  $Name" -ForegroundColor Green }
  else { $script:fails++; Write-Host "  FAIL  $Name  $Detail" -ForegroundColor Red }
}
function Get-Ours($Sys) {
  [pscustomobject]@{
    forwarding = @($Sys.portproxy | Where-Object { $_ -and $_.kind -in 'v4tov4', 'v4tov6' -and $_.to -in @("127.0.0.1/$($_.port)", "::1/$($_.port)") })
    firewall = @($Sys.firewall | Where-Object { $_ -and $_.group -eq 'Tortugarr' })
    tasks = @($Sys.tasks | Where-Object { $_ -like 'Tortugarr*' })
  }
}
# Everything Tortugarr is gone, everything else is untouched, the network is Public again.
function Test-Clean([string]$Name, [string]$Work, [string]$Network = 'Public') {
  $s = Get-Sys $Work; $o = Get-Ours $s
  $left = @()
  if ($o.forwarding) { $left += "forwarding $($o.forwarding.port -join ',')" }
  if ($o.firewall) { $left += "firewall $($o.firewall.name -join ',')" }
  if ($o.tasks) { $left += "tasks $($o.tasks -join ',')" }
  if ($s.keepalive) { $left += 'keep-alive running' }
  if ($s.network.category -ne $Network) { $left += "network $($s.network.category)" }
  if (Get-HelperState $Work) { $left += 'state file' }
  if (-not ($s.portproxy | Where-Object { $_.port -eq 3390 }) -or -not ($s.firewall | Where-Object { $_.name -eq 'Other app' }) -or 'Other task' -notin $s.tasks) { $left += 'SOMETHING ELSE WAS REMOVED' }
  Check "$Name - all clean" ($left.Count -eq 0) ($left -join '; ')
}
# After a hard crash: the state file must name everything that is there.
function Test-Covered([string]$Name, [string]$Work) {
  $s = Get-Sys $Work; $o = Get-Ours $s; $st = Get-HelperState $Work
  $miss = @()
  if (-not $st) { $miss += 'no state file' }
  else {
    if ($st.setup -ne 'running') { $miss += "setup=$($st.setup)" }
    if ($s.network.category -eq 'Private' -and -not $st.network_profile) { $miss += 'network change not recorded' }
    foreach ($f in $o.forwarding) { if (-not ($st.portproxy | Where-Object { $_.ip -eq $f.ip -and [int]$_.port -eq [int]$f.port })) { $miss += "forwarding $($f.port) not recorded" } }
    if ($o.firewall -and $st.firewall_group -ne 'Tortugarr') { $miss += 'firewall not recorded' }
    if (($o.tasks -or $s.keepalive) -and -not $st.keepalive) { $miss += 'keep-alive not recorded' }
  }
  $there = "network=$($s.network.category) forwarding=$($o.forwarding.Count) firewall=$($o.firewall.Count) tasks=$($o.tasks.Count) steps=$(@($st.steps_done) -join ',')"
  Check "$Name - state covers what is there ($there)" ($miss.Count -eq 0) ($miss -join '; ')
}

$setup = @('setup', '-Ports', $Ports, '-PeerPort', "$Peer", '-Distro', $Distro, '-PublicNetwork', 'private')
New-Item -ItemType Directory -Force -Path $Base | Out-Null

Write-Host 'Full setup, then remove'
$w = New-Work 'ok' (New-System)
$rc = Invoke-Helper $w '' '' $setup
$s = Get-Sys $w; $o = Get-Ours $s; $st = Get-HelperState $w
Check 'setup succeeds' ($rc -eq 0) "rc=$rc"
Check 'forwarding is v4tov4 to 127.0.0.1' (@($o.forwarding | Where-Object { $_.kind -eq 'v4tov4' -and $_.to -eq "127.0.0.1/$($_.port)" }).Count -eq 3) (($o.forwarding | ForEach-Object { "$($_.kind) $($_.to)" }) -join '; ')
Check 'everything set up' ($o.forwarding.Count -eq 3 -and $o.firewall.Count -eq 5 -and $o.tasks.Count -eq 1 -and $s.keepalive -and $s.network.category -eq 'Private') "fw=$($o.forwarding.Count) rules=$($o.firewall.Count) tasks=$($o.tasks.Count)"
Check 'one keep-alive task' ((@($s.tasks | Where-Object { $_ -like 'Tortugarr*' }) -join ',') -eq 'Tortugarr keepalive') ($s.tasks -join ',')
Check 'keep-alive started by setup, only after the state file said done' ($s.task_started_when -eq 'done' -and $s.keepalive_starts -eq 1) "when=$($s.task_started_when) starts=$($s.keepalive_starts)"
Check 'state says done' ($st.setup -eq 'done' -and (@($st.steps_done) -join ',') -eq 'network,forwarding,firewall,keepalive') "$($st.setup) $(@($st.steps_done) -join ',')"
$rc = Invoke-Helper $w '' '' @('remove')
Check 'remove succeeds' ($rc -eq 0) "rc=$rc"
Test-Clean 'after remove' $w

foreach ($at in 'network', 'forwarding', 'firewall', 'keepalive', 'end') {
  Write-Host "Crash at '$at' as an error"
  $w = New-Work "throw-$at" (New-System)
  $rc = Invoke-Helper $w $at 'throw' $setup
  Check 'setup reports failure' ($rc -eq 1) "rc=$rc"
  $log = Get-Content (Join-Path $w 'output.log') -Raw
  Check 'a plain xx line, no PowerShell error record' ($log -match '  xx  Windows side not set up' -and $log -notmatch 'Line \||At line|CategoryInfo|Exception:') ($log.Substring([Math]::Max(0, $log.Length - 300)))
  Test-Clean 'undone at once' $w

  Write-Host "Crash at '$at' as a hard kill (power cut / closed window)"
  $w = New-Work "kill-$at" (New-System)
  $rc = Invoke-Helper $w $at 'kill' $setup
  Check 'process was killed' ($rc -eq 9) "rc=$rc"
  Test-Covered 'after kill' $w
  $rc = Invoke-Helper $w '' '' @('remove')
  Check 'remove succeeds' ($rc -eq 0) "rc=$rc"
  Test-Clean 'after remove (state file only, no -Ports)' $w
}

Write-Host 'A service that does not answer: set up, but exit code 3 (not ok)'
$sys = New-System; $sys.dead_ports = @(58055)
$w = New-Work 'dead-port' $sys
$rc = Invoke-Helper $w '' '' $setup
$st = Get-HelperState $w; $o = Get-Ours (Get-Sys $w)
Check 'exit code 3' ($rc -eq 3) "rc=$rc"
Check 'still set up, not undone' ($st.setup -eq 'done' -and $o.forwarding.Count -eq 3)
Check 'the window names the port and says why' ((Get-Content (Join-Path $w 'output.log') -Raw) -match '58055 does not answer - nothing answers on 127\.0\.0\.1:58055')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Upgrade from the old v4tov6-to-::1 forwarding (the Win11 VM bug): setup replaces it'
$sys = New-System
$old = @{ distro = $Distro; mode = 'wsl'; firewall_group = 'Tortugarr'; setup = 'done'; ports = @(58096, 58055, 58989); portproxy = @() }
foreach ($p in 58096, 58055, 58989) {
  $sys.portproxy += @{ kind = 'v4tov6'; ip = '192.0.2.10'; port = $p; to = "::1/$p" }
  $old.portproxy += @{ ip = '192.0.2.10'; port = $p }
}
$w = New-Work 'upgrade' $sys
New-Item -ItemType Directory -Path (Join-Path $w 'ProgramData-Tortugarr') | Out-Null
$old | ConvertTo-Json -Depth 5 | Set-Content (Join-Path (Join-Path $w 'ProgramData-Tortugarr') 'windows-state.json')
$rc = Invoke-Helper $w '' '' $setup
$o = Get-Ours (Get-Sys $w)
Check 'setup succeeds and every port answers' ($rc -eq 0) "rc=$rc"
Check 'no v4tov6 left, three v4tov4' (-not ($o.forwarding | Where-Object { $_.kind -eq 'v4tov6' }) -and $o.forwarding.Count -eq 3) (($o.forwarding | ForEach-Object { "$($_.kind) $($_.port)" }) -join '; ')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Two keep-alive runs at the same time, after the LAN address changed (the Win11 VM finding)'
$w = New-Work 'concurrent' (New-System)
Invoke-Helper $w '' '' $setup | Out-Null
$s = Get-Sys $w; $s.lan_ip = '192.0.2.77'; $s.keepalive = $false; $s.keepalive_starts = 0
$s | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $w 'system.json')
$env:TORTUGARR_TEST_START_AT = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 6000
$procs = 1..4 | ForEach-Object {
  Start-Process -FilePath $Exe -PassThru -RedirectStandardOutput (Join-Path $w "par$_.out") -RedirectStandardError (Join-Path $w "par$_.err") `
    -ArgumentList @('-NoProfile', '-File', $Case, '-Helper', $Helper, '-Work', $w, '-HelperArgList', 'refresh')
}
$procs | ForEach-Object { $_.WaitForExit() }
$env:TORTUGARR_TEST_START_AT = ''
$st = Get-HelperState $w; $s = Get-Sys $w; $o = Get-Ours $s
Check 'state file still there and readable' ([bool]$st)
Check 'state lists each forwarding once, on the new address' ((@($st.portproxy | ForEach-Object { "$($_.ip)/$($_.port)" }) -join ',') -eq '192.0.2.77/58096,192.0.2.77/58055,192.0.2.77/58989') (($st.portproxy | ForEach-Object { "$($_.ip)/$($_.port)" }) -join ',')
Check 'forwarding moved to the new address' ((@($o.forwarding | ForEach-Object { "$($_.ip)/$($_.port)" }) -join ',') -eq '192.0.2.77/58096,192.0.2.77/58055,192.0.2.77/58989') (($o.forwarding | ForEach-Object { "$($_.ip)/$($_.port)" }) -join ',')
Check 'exactly one keep-alive started' ($s.keepalive_starts -eq 1) "starts=$($s.keepalive_starts)"
Check 'no temporary state files left' (-not (Get-ChildItem (Join-Path $w 'ProgramData-Tortugarr') -Filter '*.tmp'))
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'State file lost while everything is set up: setup writes it again (no "conflict")'
$w = New-Work 'lost-state' (New-System)
Invoke-Helper $w '' '' $setup | Out-Null
Remove-Item (Join-Path (Join-Path $w 'ProgramData-Tortugarr') 'windows-state.json')
$rc = Invoke-Helper $w '' '' $setup
$st = Get-HelperState $w
Check 'setup succeeds again' ($rc -eq 0 -and $st.setup -eq 'done') "rc=$rc"
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove (network left Private - its old setting went with the state file)' $w 'Private'

Write-Host 'Upgrade from the two old keep-alive tasks: setup replaces them with one'
$sys = New-System; $sys.tasks = @('Other task', 'Tortugarr keepalive (boot)', 'Tortugarr keepalive (logon)')
$w = New-Work 'old-tasks' $sys
Invoke-Helper $w '' '' $setup | Out-Null
Check 'only the new task is left' ((@((Get-Sys $w).tasks | Where-Object { $_ -like 'Tortugarr*' }) -join ',') -eq 'Tortugarr keepalive') ((Get-Sys $w).tasks -join ',')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Setup again on a working setup: forwarding that is already right is left alone'
$w = New-Work 'rerun' (New-System)
Invoke-Helper $w '' '' $setup | Out-Null
Remove-Item (Join-Path $w 'calls.log')
$rc = Invoke-Helper $w '' '' $setup
$calls = @(Get-Content (Join-Path $w 'calls.log') | Where-Object { $_ -like 'netsh*portproxy*' })
Check 'second setup succeeds' ($rc -eq 0) "rc=$rc"
Check 'no portproxy delete or add at all' ($calls.Count -eq 0) ($calls -join '; ')
Check 'the window says they are already there' ((Get-Content (Join-Path $w 'output.log') -Raw) -match '58096 -> 127\.0\.0\.1:58096 is already there')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'New forwarding that Windows has not started yet: "still starting", not "does not work"'
$sys = New-System; $sys.forwarding_slow = $true
$w = New-Work 'slow-forwarding' $sys
$rc = Invoke-Helper $w '' '' $setup
$log = Get-Content (Join-Path $w 'output.log') -Raw
Check 'exit code 3' ($rc -eq 3) "rc=$rc"
Check 'says the forwarding is still starting' ($log -match '58096 does not answer yet - its forwarding was just set up')
Check 'does not say it does not work' ($log -notmatch 'the forwarding does not work')
$s = Get-Sys $w; $s.forwarding_slow = $false; $s | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $w 'system.json')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Network left Public, rules for private networks only: blocked for other devices, not ok'
$w = New-Work 'public-leave' (New-System)
$leave = @('setup', '-Ports', $Ports, '-PeerPort', "$Peer", '-Distro', $Distro, '-PublicNetwork', 'leave')
$rc = Invoke-Helper $w '' '' $leave
$log = Get-Content (Join-Path $w 'output.log') -Raw
Check 'exit code 4 (left Public by choice - not a failure)' ($rc -eq 4) "rc=$rc"
Check 'says it was the user''s choice, not "did not answer"' ($log -match 'Left as Public by your choice' -and $log -notmatch 'did not answer on')
Check "says the firewall blocks other devices on the Public network" ($log -match "58096 answers on this PC, but the firewall blocks other devices: network 'TestNet' is Public")
Check 'no plain ok for a port' ($log -notmatch 'ok  http://192\.0\.2\.10:58096 answers')
Check 'state records this run''s answer' ((Get-HelperState $w).public_network -eq 'leave') (Get-HelperState $w).public_network
$localsub = @('setup', '-Ports', $Ports, '-PeerPort', "$Peer", '-Distro', $Distro, '-PublicNetwork', 'localsubnet')
$rc = Invoke-Helper $w '' '' $localsub
Check 'with rules for Public too (local subnet): ok, exit 0' ($rc -eq 0) "rc=$rc"
Check 'state records the new answer' ((Get-HelperState $w).public_network -eq 'localsubnet') (Get-HelperState $w).public_network
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Ports that time out: one overall limit, a progress line every round'
$sys = New-System; $sys.forwarding_slow = $true; $sys.answer_delay_ms = 1000
$w = New-Work 'timeouts' $sys
$env:TORTUGARR_WINDOWS_TEST_WAIT = '8'
$t = Get-Date
$rc = Invoke-Helper $w '' '' $setup
$secs = ((Get-Date) - $t).TotalSeconds
$env:TORTUGARR_WINDOWS_TEST_WAIT = ''
$log = Get-Content (Join-Path $w 'output.log') -Raw
Check 'exit code 3' ($rc -eq 3) "rc=$rc"
Check 'progress lines while waiting' ($log -match 'waiting for 58096, 58055, 58989 to answer \.\.\. \d+ s of at most 8 s')
# 8 s limit + at most one round (3 ports x 1 s) + the 127.0.0.1 checks (3 x 1 s) + process start-up.
Check "whole check stays near the limit (took $([int]$secs) s, limit 8 s)" ($secs -lt 30) "$secs s"
$s = Get-Sys $w; $s.forwarding_slow = $false; $s.answer_delay_ms = 0; $s | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $w 'system.json')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Blocked by a Public network: reported at once, no waiting'
$sys = New-System; $sys.forwarding_slow = $true; $sys.answer_delay_ms = 1000
$w = New-Work 'blocked-nowait' $sys
$env:TORTUGARR_WINDOWS_TEST_WAIT = '60'
$t = Get-Date
$rc = Invoke-Helper $w '' '' $leave
$secs = ((Get-Date) - $t).TotalSeconds
$env:TORTUGARR_WINDOWS_TEST_WAIT = ''
Check "no waiting (took $([int]$secs) s, a wait would be 60 s)" ($secs -lt 30) "$secs s"
Check 'no progress lines' ((Get-Content (Join-Path $w 'output.log') -Raw) -notmatch 'waiting for')
$s = Get-Sys $w; $s.forwarding_slow = $false; $s.answer_delay_ms = 0; $s | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $w 'system.json')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'The network question has no default: Enter alone or a wrong key asks again'
$sys = New-System; $sys.answers = @('', 'x', '2')
$w = New-Work 'ask' $sys
$ask = @('setup', '-Ports', $Ports, '-PeerPort', "$Peer", '-Distro', $Distro, '-PublicNetwork', 'ask')
$rc = Invoke-Helper $w '' '' $ask
$asked = @(Get-Content (Join-Path $w 'calls.log') | Where-Object { $_ -like 'Read-Host*' })
Check 'asked three times, took the 2' ($asked.Count -eq 3 -and $asked[2] -like "*-> '2'") ($asked -join '; ')
Check 'the answer was local subnet, not the old default Private' ((Get-HelperState $w).public_network -eq 'localsubnet' -and (Get-Sys $w).network.category -eq 'Public') "$((Get-HelperState $w).public_network) $((Get-Sys $w).network.category)"
Check 'setup succeeds' ($rc -eq 0) "rc=$rc"
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Not run as administrator: a plain message and exit 1, nothing changed'
$w = New-Work 'not-admin' (New-System)
$env:TORTUGARR_WINDOWS_TEST_NOT_ADMIN = '1'
$rc = Invoke-Helper $w '' '' $setup
$env:TORTUGARR_WINDOWS_TEST_NOT_ADMIN = ''
$log = Get-Content (Join-Path $w 'output.log') -Raw
Check 'exit code 1' ($rc -eq 1) "rc=$rc"
Check 'one plain line, no stack trace' ($log -match '  xx  Run this in an administrator PowerShell' -and $log -notmatch 'Line \||At line|CategoryInfo') $log
Test-Clean 'nothing changed' $w

Write-Host 'Hard kill at the firewall, then setup again, then remove'
$w = New-Work 'kill-rerun' (New-System)
Invoke-Helper $w 'firewall' 'kill' $setup | Out-Null
$rc = Invoke-Helper $w '' '' $setup
$st = Get-HelperState $w
Check 'second setup succeeds' ($rc -eq 0 -and $st.setup -eq 'done') "rc=$rc"
Check 'the original Public network is still recorded' ($st.network_profile.was -eq 'Public')
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Reconfigure: a port changes'
$w = New-Work 'reconfigure' (New-System)
Invoke-Helper $w '' '' $setup | Out-Null
$re = @('setup', '-Ports', '58097,58055,58989', '-PeerPort', "$Peer", '-Distro', $Distro, '-PublicNetwork', 'private')
$rc = Invoke-Helper $w '' '' $re
$o = Get-Ours (Get-Sys $w)
Check 'old port forwarding gone, new one there' ($rc -eq 0 -and 58096 -notin $o.forwarding.port -and 58097 -in $o.forwarding.port) "ports=$($o.forwarding.port -join ',')"
Invoke-Helper $w '' '' @('remove') | Out-Null
Test-Clean 'after remove' $w

Write-Host 'Leftovers with NO state file (a setup from before this fix): forwarding + firewall group, network Private'
$sys = New-System
$sys.network.category = 'Private'
foreach ($p in 58096, 58055, 58989) {
  $sys.portproxy += @{ kind = 'v4tov6'; ip = '192.0.2.10'; port = $p; to = "::1/$p" }
  $sys.firewall += @{ name = "Tortugarr TCP $p"; group = 'Tortugarr'; port = "$p"; profile = 'Private, Domain' }
}
$sys.portproxy += @{ kind = 'v4tov6'; ip = '192.0.2.10'; port = 58200; to = '::1/9999' }
$w = New-Work 'nostate' $sys
$rc = Invoke-Helper $w '' '' @('remove')
$s = Get-Sys $w
Check 'remove succeeds' ($rc -eq 0) "rc=$rc"
Check 'a v4tov6 entry that is not ours is kept' ([bool]($s.portproxy | Where-Object { $_.port -eq 58200 }))
$s.portproxy = @($s.portproxy | Where-Object { $_.port -ne 58200 }); $s | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $w 'system.json')
Test-Clean 'found from the firewall group (network left Private - unknown without state)' $w 'Private'

Write-Host 'Leftovers with NO state file and no firewall group: forwarding only, remove -Ports'
$sys = New-System
foreach ($p in 58096, 58055) { $sys.portproxy += @{ kind = 'v4tov6'; ip = '192.0.2.99'; port = $p; to = "::1/$p" } }
$w = New-Work 'nostate-ports' $sys
$rc = Invoke-Helper $w '' '' @('remove', '-Ports', $Ports, '-Distro', $Distro)
Check 'remove succeeds' ($rc -eq 0) "rc=$rc"
Test-Clean 'found from -Ports (also on an old address)' $w

Write-Host ''
$color = if ($script:fails) { 'Red' } else { 'Green' }
Write-Host "$($script:passes) passed, $($script:fails) failed" -ForegroundColor $color
exit [int]($script:fails -gt 0)
