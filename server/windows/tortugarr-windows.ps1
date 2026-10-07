<#
.SYNOPSIS
  Tortugarr's Windows helper for a server running in WSL2 (WSL2 is not supported officially;
  this is a best-effort helper). Started by the Linux installer inside WSL, with one UAC prompt.

.DESCRIPTION
  setup     port forwarding from the Windows LAN address into WSL (v4tov4 to 127.0.0.1, so the
            WSL address changing at every boot does not matter), firewall rules in the group
            "Tortugarr" for exactly those ports, and a keep-alive that starts the distro at
            Windows start-up and keeps it (and every other WSL distro) running. It reports
            'ok' only when every forwarded port answers on the LAN address.
  refresh   run by the keep-alive at boot/logon: moves the forwarding when the LAN address changed.
  status    what is set up, read only.
  remove    takes away what setup recorded in C:\ProgramData\Tortugarr\windows-state.json, and
            also what it finds without a record (the 'Tortugarr' firewall group, our forwarding
            for -Ports and the firewall's ports, the tasks).

  setup writes windows-state.json before every change and after every step, so a crash, a
  power cut or a closed window at any point leaves a record that remove can clean up from.

  Never touches .wslconfig: networkingMode=mirrored and friends are global to every WSL
  distro and Docker Desktop on the machine.

.EXAMPLE
  tortugarr-windows.ps1 setup -Ports 8096,5055,8989,7878,9696,6767,8080 -PeerPort 6881 -Distro Ubuntu
  tortugarr-windows.ps1 status
  tortugarr-windows.ps1 remove -Ports 8096,5055 -Distro Ubuntu
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('setup', 'refresh', 'status', 'remove')]
  [string]$Command = 'status',
  [string]$Ports = '',
  [int]$PeerPort = 0,
  [string]$Distro = '',
  # On a network Windows calls Public: ask (interactive), private (switch the network to
  # Private - recommended at home), localsubnet (allow on Public too, local subnet only), leave.
  [ValidateSet('ask', 'private', 'localsubnet', 'leave')]
  [string]$PublicNetwork = 'ask',
  [string]$LogFile = '',
  [switch]$Pause,
  [switch]$DryRun
)

# First of all, before anything else runs: QuickEdit off in this window. A click in a console
# window with QuickEdit on starts a text selection, and the script stops at its next line of
# output until Esc or Enter - a click froze setup, also one right after UAC (Win11 VM,
# 2026-10-07). Only for this window (ENABLE_EXTENDED_FLAGS 0x80 on, ENABLE_QUICK_EDIT_MODE
# 0x40 off). A click in the second before PowerShell itself has started cannot be prevented.
if ($Command -in 'setup', 'remove' -and $env:TORTUGARR_WINDOWS_TEST -ne '1') {
  try {
    Add-Type -Namespace Tortugarr -Name Console -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(System.IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(System.IntPtr h, uint m);
'@
    $consoleIn = [Tortugarr.Console]::GetStdHandle(-10)
    [uint32]$consoleMode = 0
    if ([Tortugarr.Console]::GetConsoleMode($consoleIn, [ref]$consoleMode)) {
      [Tortugarr.Console]::SetConsoleMode($consoleIn, (($consoleMode -band (-bnot 0x40)) -bor 0x80)) | Out-Null
    }
  } catch { }  # no console (hidden run) or not allowed: nothing to switch off
}

$ErrorActionPreference = 'Stop'
$script:exitCode = 0
# Test mode, for tests/windows only: a scratch folder instead of ProgramData, no administrator
# check, and a deliberate crash at a named step. Refuses to run unless every command that
# changes Windows is a test stub, so a test can never touch the real machine.
$TestMode = $env:TORTUGARR_WINDOWS_TEST -eq '1'
if (-not $TestMode) { $Root = Join-Path $env:ProgramData 'Tortugarr' }
else {
  if (-not $env:TORTUGARR_WINDOWS_TEST_ROOT) { throw 'Test mode needs TORTUGARR_WINDOWS_TEST_ROOT.' }
  $Root = $env:TORTUGARR_WINDOWS_TEST_ROOT
  foreach ($c in 'netsh', 'Set-NetConnectionProfile', 'New-NetFirewallRule', 'Remove-NetFirewallRule',
    'Register-ScheduledTask', 'Unregister-ScheduledTask', 'Start-ScheduledTask', 'Stop-Process', 'Start-Process') {
    if ((Get-Command $c).CommandType -ne 'Function') { throw "Test mode: '$c' is not stubbed - refusing to run." }
  }
}
$StateFile = Join-Path $Root 'windows-state.json'
$FwGroup = 'Tortugarr'
$Mode = 'wsl'
$PortList = @($Ports -split '[,; ]+' | Where-Object { $_ } | ForEach-Object { [int]$_ })
if ($LogFile) { Start-Transcript -Path $LogFile -Force | Out-Null }

function Write-Ok($m) { Write-Host "  ok  $m" -ForegroundColor Green }
function Write-Note($m) { Write-Host "  ..  $m" -ForegroundColor DarkGray }
function Write-Warn($m) { Write-Host "  !!  $m" -ForegroundColor Yellow }

function Assert-Admin {
  # Test mode is an administrator unless a test says otherwise.
  $isAdmin = if ($TestMode) { $env:TORTUGARR_WINDOWS_TEST_NOT_ADMIN -ne '1' }
    else { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
  if (-not $isAdmin) {
    throw 'Run this in an administrator PowerShell (right-click > Run as administrator).'
  }
}

# The parameter names are deliberately unusual: a step's script block runs inside this function,
# so a variable in the block with the same name (PowerShell ignores case: $action = $Action) would
# be this function's parameter instead of the caller's variable. That broke Register-ScheduledTask.
function Invoke-Step([string]$TortugarrStepName, [scriptblock]$TortugarrStepBody) {
  if ($DryRun) { Write-Note "[dry-run] $TortugarrStepName"; return }
  & $TortugarrStepBody
}

# Test mode only: crash on purpose at a named step. 'kill' is a power cut or a closed window:
# the process ends at once - no catch, no finally, no clean-up.
function Test-FailPoint([string]$Name) {
  if (-not $TestMode -or $env:TORTUGARR_WINDOWS_FAIL_AT -ne $Name) { return }
  Write-Warn "[test] crash at '$Name' ($env:TORTUGARR_WINDOWS_FAIL_HOW)"
  if ($env:TORTUGARR_WINDOWS_FAIL_HOW -eq 'kill') { [Environment]::Exit(9) }
  throw "[test] deliberate failure at '$Name'"
}

function Get-State {
  if (Test-Path $StateFile) {
    $s = Get-Content $StateFile -Raw | ConvertFrom-Json
    # Normalise to a hashtable so it can be extended.
    $h = @{}
    $s.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
    return $h
  }
  return @{}
}

# Each forwarding entry once (ip + port).
function Get-UniquePortProxy($Entries) {
  $seen = @{}
  foreach ($e in @($Entries)) {
    if (-not $e) { continue }
    $k = "$($e.ip)/$([int]$e.port)"
    if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; @{ ip = [string]$e.ip; port = [int]$e.port } }
  }
}

function Save-State($State) {
  if ($DryRun) { return }
  New-Item -ItemType Directory -Force -Path $Root | Out-Null
  $State['portproxy'] = @(Get-UniquePortProxy $State['portproxy'])
  # Written to a temporary file of this process's own and swapped in with File.Replace, which
  # never deletes the old file first: a crash or a second writer can never leave the state file
  # missing or half written. (Move-Item -Force deletes the target first - with two keep-alive
  # tasks writing at once, the state file disappeared in the Win11 VM on 2026-10-07.)
  $tmp = "$StateFile.$PID.tmp"
  $State | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp -Encoding UTF8
  # [NullString]::Value, not $null: PowerShell turns $null into "" for a .NET string argument.
  if (Test-Path $StateFile) { [IO.File]::Replace($tmp, $StateFile, [NullString]::Value) }
  else { [IO.File]::Move($tmp, $StateFile) }
}

# One helper run at a time on this PC (setup, refresh, remove): two keep-alive runs at once
# both saw no keep-alive and started one each, and wrote the state file at the same time.
function Enter-Lock([int]$Seconds) {
  # A test gets a lock of its own per scratch folder. (Not GetHashCode(): it differs per process.)
  $name = if ($TestMode) { 'Global\Tortugarr-test-' + (($Root -replace '[^A-Za-z0-9]', '') | ForEach-Object { $_.Substring([Math]::Max(0, $_.Length - 80)) }) } else { 'Global\TortugarrWindowsHelper' }
  $script:lock = New-Object Threading.Mutex($false, $name)
  try { $got = $script:lock.WaitOne($Seconds * 1000) }
  catch [Threading.AbandonedMutexException] { $got = $true }  # its holder died - the lock is ours now
  if (-not $got) { $script:lock = $null }
  return $got
}

function Exit-Lock {
  if ($script:lock) { try { $script:lock.ReleaseMutex() } catch { } ; $script:lock = $null }
}

# A step is finished: written down at once.
function Complete-Step($State, [string]$Name) {
  $State['steps_done'] = @(@($State['steps_done']) + $Name | Where-Object { $_ })
  Save-State $State
}

# The helper's own copy in ProgramData: the keep-alive runs it, and remove can always be run
# from there by hand - so it is put there before anything else is changed.
function Copy-Self {
  New-Item -ItemType Directory -Force -Path $Root | Out-Null
  $self = Join-Path $Root 'tortugarr-windows.ps1'
  if ($PSCommandPath -ne $self) { Invoke-Step "copy helper to $self" { Copy-Item $PSCommandPath $self -Force } }
  return $self
}

# The LAN address: the IPv4 address of the adapter that has the default gateway.
function Get-LanIp {
  $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
  if (-not $cfg) { throw 'No active network adapter with a default gateway was found.' }
  return $cfg.IPv4Address.IPAddress
}

function Get-ActiveProfile {
  Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -ne 'Disconnected' } | Select-Object -First 1
}

function Test-PublicNetwork {
  $p = Get-ActiveProfile
  return ($p -and $p.NetworkCategory -eq 'Public')
}

# Windows often calls a new network Public, where rules for private networks do not apply and
# the TV could not connect - silently. Decide what to do, and say it plainly.
function Resolve-PublicNetwork([string]$Choice, $State) {
  if (-not (Test-PublicNetwork)) { return 'private-already' }
  $p = Get-ActiveProfile
  Write-Warn "Windows has set the network '$($p.Name)' to Public. Firewall rules for private networks do not apply there."
  if ($Choice -eq 'ask') {
    Write-Host '      1) Set this network to Private (recommended at home)'
    Write-Host '      2) Allow the Tortugarr ports on Public networks too, but only from the local subnet'
    Write-Host '         (this also applies on cafe or hotel Wi-Fi you join later)'
    Write-Host '      3) Leave it - then TVs and phones on this network cannot reach the server'
    # No default, and keys pressed before the question are thrown away first: an Enter that
    # ended a text selection (or anything typed while the window was busy) is never an answer.
    try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
    do { $a = (Read-Host '      Choose 1, 2 or 3').Trim() } while ($a -notin '1', '2', '3')
    $Choice = switch ($a) { '1' { 'private' } '2' { 'localsubnet' } '3' { 'leave' } }
  }
  if ($Choice -eq 'private') {
    # Written down before the change, so remove (also after a crash) can set it back to Public.
    if (-not $State['network_profile']) {
      $State['network_profile'] = @{ name = [string]$p.Name; index = [int]$p.InterfaceIndex; was = 'Public' }
      Save-State $State
    }
    Invoke-Step "set network '$($p.Name)' to Private" { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private }
    Test-FailPoint 'network'
    Write-Ok "Network '$($p.Name)' is now Private"
  } elseif ($Choice -eq 'leave') {
    Write-Warn 'Left as Public: devices on this network cannot reach the Tortugarr server.'
  }
  return $Choice
}

# Every portproxy entry on the machine, read from the registry (netsh's own output is
# translated with the Windows display language). Keys: kind, ip, port, to.
function Get-PortProxyEntries {
  if ($TestMode) { return Get-TestPortProxyEntries }
  $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\PortProxy'
  foreach ($kind in 'v4tov4', 'v4tov6', 'v6tov4', 'v6tov6') {
    $key = Join-Path $base "$kind\tcp"
    if (-not (Test-Path $key)) { continue }
    $props = Get-ItemProperty $key
    foreach ($prop in $props.PSObject.Properties) {
      if ($prop.Name -like 'PS*') { continue }
      $listen = $prop.Name -split '/'
      [pscustomobject]@{ kind = $kind; ip = $listen[0]; port = [int]$listen[1]; to = [string]$prop.Value }
    }
  }
}

function Test-OwnedEntry($State, [string]$Ip, [int]$Port) {
  foreach ($e in @($State['portproxy'])) {
    if ($e -and $e.ip -eq $Ip -and [int]$e.port -eq $Port) { return $true }
  }
  return $false
}

# Ports on $Ip that belong to someone else: an existing portproxy entry we did not
# create, or a Windows program listening there. Those are never replaced.
function Get-ForeignPorts([int[]]$PortList, [string]$Ip, $State) {
  $entries = @(Get-PortProxyEntries)
  $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
  $fwPorts = @(Get-FirewallPorts)
  foreach ($p in $PortList) {
    if (Test-OwnedEntry $State $Ip $p) { continue }
    # Lost state file: forwarding of our kind on a port our firewall group opens is ours.
    if ($p -in $fwPorts -and ($entries | Where-Object { $_.port -eq $p -and $_.ip -eq $Ip -and (Test-OurTarget $_) })) { continue }
    $hit = $entries | Where-Object { $_.port -eq $p -and $_.ip -in @($Ip, '0.0.0.0', '*', '::') } | Select-Object -First 1
    if ($hit) { [pscustomobject]@{ port = $p; what = "port forwarding $($hit.ip):$p -> $($hit.to) ($($hit.kind))" }; continue }
    $l = $listeners | Where-Object { $_.LocalPort -eq $p -and $_.LocalAddress -in @($Ip, '0.0.0.0', '::') } | Select-Object -First 1
    if ($l) {
      $proc = (Get-Process -Id $l.OwningProcess -ErrorAction SilentlyContinue).ProcessName
      [pscustomobject]@{ port = $p; what = "program '$proc' listens on $($l.LocalAddress):$p" }
    }
  }
}

# What our forwarding points at. 127.0.0.1 is where WSL's localhost relay (wslrelay.exe) listens
# for the ports the distro publishes, whatever address the distro got this boot - a rule aimed at
# a 172.x WSL address breaks on the next reboot. Not ::1: measured in a Win11 VM on 2026-10-07,
# wslrelay listened on 127.0.0.1 only, so v4tov6 to ::1 reset every connection.
# Earlier versions made v4tov6 to ::1; those are still recognised as ours and replaced.
function Test-OurTarget($Entry) {
  $Entry.kind -in 'v4tov4', 'v4tov6' -and $Entry.to -in @("127.0.0.1/$($Entry.port)", "::1/$($Entry.port)")
}

# Leaves an entry that is already exactly right alone and changes only what differs: Windows'
# forwarding service (iphlpsvc) takes from seconds to minutes to listen again on a port whose
# entry was deleted and added - a second `sudo tortugarr windows` on a working setup made every
# port stop answering for a few minutes (Win11 VM, 2026-10-07). Returns the ports it changed.
function Set-PortForwarding([int[]]$PortList, [string]$Ip) {
  $current = @(Get-PortProxyEntries)
  foreach ($p in $PortList) {
    $here = @($current | Where-Object { $_.ip -eq $Ip -and $_.port -eq $p })
    if ($here.Count -eq 1 -and $here[0].kind -eq 'v4tov4' -and $here[0].to -eq "127.0.0.1/$p") {
      Write-Note "portproxy $($Ip):$p -> 127.0.0.1:$p is already there"
      continue
    }
    $p
    Invoke-Step "portproxy $($Ip):$p -> 127.0.0.1:$p" {
      # Our own earlier entry on this address and port, also an old v4tov6 one (the ports were
      # checked for anyone else's entries before this).
      netsh interface portproxy delete v4tov6 listenaddress=$Ip listenport=$p 2>$null | Out-Null
      netsh interface portproxy delete v4tov4 listenaddress=$Ip listenport=$p 2>$null | Out-Null
      netsh interface portproxy add v4tov4 listenaddress=$Ip listenport=$p connectaddress=127.0.0.1 connectport=$p | Out-Null
    }
    Test-FailPoint 'forwarding'
  }
}

# Removes only entries that still look like ours (to 127.0.0.1 or, from older versions, ::1 on
# the same port).
function Remove-PortForwarding($Entries) {
  $current = @(Get-PortProxyEntries)
  foreach ($e in $Entries) {
    foreach ($now in @($current | Where-Object { $_.kind -in 'v4tov4', 'v4tov6' -and $_.ip -eq $e.ip -and $_.port -eq [int]$e.port })) {
      if (-not (Test-OurTarget $now)) { Write-Warn "Leaving $($e.ip):$($e.port) alone: it now points at $($now.to), not at Tortugarr"; continue }
      Invoke-Step "remove portproxy $($now.kind) $($now.ip):$($now.port)" {
        netsh interface portproxy delete $now.kind listenaddress=$($now.ip) listenport=$($now.port) 2>$null | Out-Null
      }
    }
  }
}

# Any HTTP answer counts (also 302, 401, 404): every forwarded port is a web page. A reset or a
# timeout means nothing answers there.
# At most about 5 seconds per try, whatever happens: 2.5 s to connect, 2.5 s for the first bytes
# of an answer. (A blocked or not-yet-listening port must never make the window look frozen.)
function Test-HttpAnswers([string]$Address, [int]$Port) {
  if ($TestMode) { return Test-TestHttpAnswers $Address $Port }
  $c = New-Object Net.Sockets.TcpClient
  try {
    if (-not $c.ConnectAsync($Address, $Port).Wait(2500)) { return $false }
    $c.ReceiveTimeout = 2500; $c.SendTimeout = 2500
    $stream = $c.GetStream()
    $req = [Text.Encoding]::ASCII.GetBytes("GET / HTTP/1.0`r`nHost: $($Address):$Port`r`n`r`n")
    $stream.Write($req, 0, $req.Length)
    $buf = New-Object byte[] 16
    $n = $stream.Read($buf, 0, $buf.Length)
    return ($n -ge 5 -and [Text.Encoding]::ASCII.GetString($buf, 0, $n).StartsWith('HTTP/'))
  } catch { return $false } finally { $c.Dispose() }
}

# Each forwarded port must answer on the LAN address - through the forwarding, as a TV would
# connect - before it is reported ok. Waits up to $WaitSeconds for a service that is still
# starting. Says why a port fails, and returns the ports that do not answer.
# The check below runs on this PC, where Windows' firewall does not apply. Other devices on a
# network Windows calls Public are blocked unless our rules cover Public too ("localsubnet").
# Returns the network's name when that is the case.
function Get-BlockingPublicNetwork {
  $p = Get-ActiveProfile
  if (-not $p -or "$($p.NetworkCategory)" -ne 'Public') { return }
  $rules = @(Get-NetFirewallRule -Group $FwGroup -ErrorAction SilentlyContinue)
  if ($rules | Where-Object { "$($_.Profile)" -match 'Public|Any' }) { return }
  return [string]$p.Name
}

# $Changed: ports whose forwarding was just added - Windows may need minutes before it listens
# there, so a port that still fails then is "still starting", not "does not work".
# $WaitSeconds is the limit for the whole check, all ports together. A line every round says
# what it is waiting for, so the window never looks frozen.
function Test-ForwardedPorts([int[]]$PortList, [string]$Ip, [int]$WaitSeconds, [int[]]$Changed = @()) {
  if ($TestMode) { $WaitSeconds = [int]$env:TORTUGARR_WINDOWS_TEST_WAIT }
  # Blocked for other devices anyway (Public network): no point in waiting.
  $blocked = Get-BlockingPublicNetwork
  if ($blocked) { $WaitSeconds = 0 }
  $start = Get-Date; $deadline = $start.AddSeconds($WaitSeconds)
  $left = @($PortList); $round = 0
  while ($true) {
    $round++
    $still = @()
    foreach ($p in $left) {
      # Every port is tried in the first round; later rounds stop at the limit (a port not
      # tried again keeps the result it had).
      if ($round -gt 1 -and (Get-Date) -gt $deadline) { $still += $p; continue }
      if (-not (Test-HttpAnswers $Ip $p)) { $still += $p }
    }
    $left = $still
    if ($left.Count -eq 0 -or (Get-Date) -gt $deadline) { break }
    Write-Note ("waiting for {0} to answer ... {1} s of at most {2} s" -f ($left -join ', '), [int]((Get-Date) - $start).TotalSeconds, $WaitSeconds)
    Start-Sleep -Seconds 3
  }
  # Answers here but blocked for everyone else: not ok (Win11 VM, 2026-10-07). Those ports are
  # also kept in $script:blockedPorts, so the summary can tell "blocked" from "broken".
  $script:blockedPorts = @()
  foreach ($p in $PortList) {
    if ($p -notin $left -and $blocked) {
      Write-Warn "http://$($Ip):$p answers on this PC, but the firewall blocks other devices: network '$blocked' is Public"
      $left += $p; $script:blockedPorts += $p; continue
    }
    if ($p -notin $left) { Write-Ok "http://$($Ip):$p answers"; continue }
    if (-not (Test-HttpAnswers '127.0.0.1' $p)) { Write-Warn "http://$($Ip):$p does not answer - nothing answers on 127.0.0.1:$p either (is Tortugarr running in WSL?)" }
    elseif ($p -in $Changed) { Write-Warn "http://$($Ip):$p does not answer yet - its forwarding was just set up and Windows can take a few minutes to start it; check again with 'sudo tortugarr doctor'" }
    else { Write-Warn "http://$($Ip):$p does not answer, but 127.0.0.1:$p does - the forwarding does not work" }
  }
  return $left
}

# Private/Domain networks; with "localsubnet" also Public, but only from the local subnet.
function Set-FirewallRules([int[]]$List, [int]$Peer, [bool]$AlsoPublic) {
  Invoke-Step 'remove old Tortugarr firewall rules' { Get-NetFirewallRule -Group $FwGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule }
  $extra = @{ Profile = 'Private, Domain' }
  if ($AlsoPublic) { $extra = @{ Profile = 'Any'; RemoteAddress = 'LocalSubnet' } }
  foreach ($p in $List) {
    Invoke-Step "firewall allow TCP $p" {
      New-NetFirewallRule -DisplayName "Tortugarr TCP $p" -Group $FwGroup -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p @extra | Out-Null
    }
    Test-FailPoint 'firewall'
  }
  if ($Peer -gt 0) {
    foreach ($proto in 'TCP', 'UDP') {
      Invoke-Step "firewall allow $proto $Peer (torrent peers)" {
        New-NetFirewallRule -DisplayName "Tortugarr peer $proto $Peer" -Group $FwGroup -Direction Inbound -Action Allow -Protocol $proto -LocalPort $Peer @extra | Out-Null
      }
    }
  }
}

function Install-BootScript([string]$DistroName) {
  $self = Copy-Self

    # A hidden, detached `sleep infinity` keeps the distro (and Docker in it) alive. The refresh
  # starts it only when it is not running (also after a manual `wsl --shutdown`), so this can run
  # every few minutes without ever starting a second one. wscript waits for the refresh (True),
  # so the task runs as long as the refresh does and never overlaps itself (IgnoreNew).
  $vbs = Join-Path $Root 'keepalive.vbs'
  $vbsBody = @"
' Tortugarr: refresh port forwarding and make sure the WSL keep-alive runs, with no window.
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$self"" refresh -Distro ""$DistroName""", 0, True
"@
  Invoke-Step "write $vbs" { Set-Content -Path $vbs -Value $vbsBody -Encoding ASCII }
  return $vbs
}

# The hidden `wsl.exe -d <distro> --exec env TORTUGARR_KEEPALIVE=1 sleep infinity` that keeps
# WSL up. The variable lets the doctor in WSL find it: a check from Windows without
# administrator rights cannot read the command line of this (elevated) process.
$KeepAliveArgs = @('--exec', 'env', 'TORTUGARR_KEEPALIVE=1', 'sleep', 'infinity')
$KeepAliveTask = 'Tortugarr keepalive'
$OldKeepAliveTasks = @('Tortugarr keepalive (boot)', 'Tortugarr keepalive (logon)')

function Test-IsAdmin {
  if ($TestMode) { return $true }
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-KeepAlive([string]$DistroName) {
  Start-Process wsl.exe -ArgumentList (@('-d', $DistroName) + $KeepAliveArgs) -WindowStyle Hidden
}

function Test-KeepAliveRunning([string]$DistroName) {
  [bool](Get-CimInstance Win32_Process -Filter "Name='wsl.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'sleep infinity' -and $_.CommandLine -match [regex]::Escape($DistroName) })
}

# One task with three triggers - at boot (also when nobody logs in, such as after an unattended
# Windows Update restart), at logon, and from now on - each repeating every 5 minutes, so the
# keep-alive also comes back after a manual `wsl --shutdown` without waiting for a restart.
# One task, not two: two tasks fired together and each started a keep-alive (Win11 VM,
# 2026-10-07). Started by setup only once the state file says "done".
function Register-KeepAlive([string]$DistroName) {
  $vbs = Install-BootScript $DistroName
  $user = "$env:USERDOMAIN\$env:USERNAME"
  $taskAction = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`""
  $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
  # The one-off trigger starts the 5-minute repetition right after setup; the boot and logon
  # triggers start it again after every restart and logon.
  $now = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
  $every = $now.Repetition
  $boot = New-ScheduledTaskTrigger -AtStartup; $boot.Repetition = $every
  $logon = New-ScheduledTaskTrigger -AtLogOn -User $user; $logon.Repetition = $every
  foreach ($old in $OldKeepAliveTasks) {
    Invoke-Step "remove old task $old" { Unregister-ScheduledTask -TaskName $old -Confirm:$false -ErrorAction SilentlyContinue }
  }
  Invoke-Step "scheduled task `"$KeepAliveTask`"" {
    $p = New-ScheduledTaskPrincipal -UserId $user -LogonType S4U -RunLevel Highest
    Register-ScheduledTask -TaskName $KeepAliveTask -Action $taskAction -Settings $taskSettings `
      -Trigger @($boot, $logon, $now) -Principal $p -Force | Out-Null
  }
  Test-FailPoint 'keepalive'
}

# The ports of the rules in our firewall group - a trace that is there even without a state file.
function Get-FirewallPorts {
  @(Get-NetFirewallRule -Group $FwGroup -ErrorAction SilentlyContinue | Get-NetFirewallPortFilter |
    ForEach-Object { $_.LocalPort } | Where-Object { "$_" -match '^\d+$' } | ForEach-Object { [int]$_ })
}

# Anything Tortugarr may have left on Windows, also without a state file.
function Test-Traces {
  [bool](Get-NetFirewallRule -Group $FwGroup -ErrorAction SilentlyContinue) -or
    [bool](Get-ScheduledTask -TaskName 'Tortugarr keepalive*' -ErrorAction SilentlyContinue)
}

function Restore-NetworkProfile($Saved) {
  $p = Get-NetConnectionProfile -InterfaceIndex ([int]$Saved.index) -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $Saved.name }
  if (-not $p) { Write-Note "Network '$($Saved.name)' is not connected now - left as it is"; return }
  if ($p.NetworkCategory -ne 'Private') { return }
  Invoke-Step "set network '$($Saved.name)' back to Public" { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Public }
  Write-Ok "Network '$($Saved.name)' set back to Public, as it was before Tortugarr"
}

# Takes away everything this helper may have set up - also when only part of it is there (a
# setup that crashed half-way) or when there is no state file at all: the network profile it
# changed, our forwarding entries (from the state, -Ports and the firewall group's ports), the
# firewall group, the tasks, the keep-alive and the files. Each part is tried on its own, so one
# failing part never stops the rest; the state file is kept until everything went well, so
# remove can simply be run again. Sets $script:cleanupFailed when something was left.
function Remove-TortugarrWindows($State, [int[]]$ExtraPorts, [string]$DistroName) {
  $script:cleanupFailed = $false
  function Invoke-Cleanup([string]$TortugarrCleanName, [scriptblock]$TortugarrCleanBody) {
    try { & $TortugarrCleanBody } catch { $script:cleanupFailed = $true; Write-Warn "$($TortugarrCleanName): $($_.Exception.Message)" }
  }
  if (-not $State.Count) {
    if (-not (Test-Traces) -and -not $ExtraPorts) { Write-Note 'No state file and no Tortugarr traces found.' }
    else { Write-Note 'No state file: removing the Tortugarr traces found on this PC.' }
  }
  if ($State['network_profile']) { Invoke-Cleanup 'network profile' { Restore-NetworkProfile $State['network_profile'] } }
  elseif (-not $State.Count) { Write-Note 'Whether Tortugarr set your network to Private is not known without the state file - check it in Settings > Network & internet.' }
  Invoke-Cleanup 'forwarding' {
    $entries = @($State['portproxy'] | Where-Object { $_ })
    # Without a record: our kind of entry (to 127.0.0.1 or ::1 on the same port) on any address.
    $ports = @(@($ExtraPorts) + @(Get-FirewallPorts) | Where-Object { $_ } | Sort-Object -Unique)
    $entries += @(Get-PortProxyEntries | Where-Object { $_.port -in $ports -and (Test-OurTarget $_) } |
      ForEach-Object { [pscustomobject]@{ ip = $_.ip; port = $_.port } })
    if ($entries) { Remove-PortForwarding $entries }
  }
  Invoke-Cleanup 'firewall rules' { Invoke-Step 'remove firewall rules' { Get-NetFirewallRule -Group $FwGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule } }
  foreach ($t in @($KeepAliveTask) + $OldKeepAliveTasks) {
    Invoke-Cleanup "task $t" { Invoke-Step "remove task $t" { Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue } }
  }
  $d = if ($State['distro']) { [string]$State['distro'] } else { $DistroName }
  if ($d) {
    Invoke-Cleanup 'keep-alive' {
      Invoke-Step 'stop keep-alive' {
        Get-CimInstance Win32_Process -Filter "Name='wsl.exe'" |
          Where-Object { $_.CommandLine -match 'sleep infinity' -and $_.CommandLine -match [regex]::Escape($d) } |
          ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
      }
    }
  }
  if ($script:cleanupFailed) {
    Write-Warn "Not everything could be removed - the record is kept in $StateFile; run remove again."
    return
  }
  foreach ($f in 'keepalive.vbs', 'windows-state.json', 'windows-state.json.tmp', 'tortugarr-windows.ps1') {
    Invoke-Step "remove $f" { Remove-Item (Join-Path $Root $f) -Force -ErrorAction SilentlyContinue }
  }
  # The folder too, when nothing else is in it.
  if ((Test-Path $Root) -and -not (Get-ChildItem $Root -Force)) { Invoke-Step "remove $Root" { Remove-Item $Root -Force } }
}

try {
switch ($Command) {
  'setup' {
    Assert-Admin
    if (-not $PortList) { throw 'Give the ports: -Ports 8096,5055,...' }
    if (-not $Distro) { throw 'Give the WSL distro: -Distro <name>' }
    if (-not (Enter-Lock 120)) { throw 'Another Tortugarr helper run is busy - try again in a minute.' }
    $state = Get-State
    $ip = Get-LanIp
    # Check every port before changing anything, so a conflict leaves the machine as it was.
    $foreign = @(Get-ForeignPorts $PortList $ip $state)
    if ($foreign.Count -gt 0) {
      Write-Warn "These ports on $ip are already used by something that is not Tortugarr:"
      $foreign | ForEach-Object { Write-Host "      $($_.port): $($_.what)" }
      Write-Host '      Nothing was changed. Pick other ports with "sudo tortugarr reconfigure" in WSL.'
      throw 'Port conflict with an existing setup - stopped without changes.'
    }
    # From here on the state file is written before each change and after each step, so a
    # crash, a power cut or a closed window at any point leaves a record that remove can clean
    # up from. A plain failure is undone at once, below.
    $state['distro'] = $Distro; $state['mode'] = $Mode; $state['firewall_group'] = $FwGroup
    # public_network is this run's answer, written once it is known - not one from an earlier run.
    $state['setup'] = 'running'; $state['steps_done'] = @(); $state.Remove('public_network')
    Save-State $state
    Copy-Self | Out-Null
    try {
      $public = Resolve-PublicNetwork $PublicNetwork $state
      $state['public_network'] = $public
      Complete-Step $state 'network'
      # A port that is no longer used (reconfigure changed it) or an old LAN address: take our
      # earlier forwarding away first, so nothing is left pointing into WSL.
      $stale = @($state['portproxy'] | Where-Object { $_ -and (([int]$_.port -notin $PortList) -or ($_.ip -ne $ip)) })
      if ($stale.Count -gt 0) { Remove-PortForwarding $stale }
      $state['portproxy'] = @($PortList | ForEach-Object { @{ ip = $ip; port = $_ } })
      Save-State $state
      $changed = @(Set-PortForwarding $PortList $ip)
      Complete-Step $state 'forwarding'
      Write-Ok "Forwarding $($PortList -join ', ') on $ip into WSL$(if ($changed.Count -lt $PortList.Count) { " ($($changed.Count) changed, the rest already right)" })"
      $state['firewall_ports'] = @($PortList) + @($PeerPort | Where-Object { $_ -gt 0 })
      Save-State $state
      Set-FirewallRules $PortList $PeerPort ($public -eq 'localsubnet')
      Complete-Step $state 'firewall'
      $where = if ($public -eq 'localsubnet') { 'private networks, and public ones from the local subnet' } else { 'private networks' }
      Write-Ok "Firewall group '$FwGroup' open for $($PortList -join ', ')$(if ($PeerPort) { " and peer port $PeerPort" }) on $where"
      $state['keepalive'] = $true
      Save-State $state
      Register-KeepAlive $Distro
      Complete-Step $state 'keepalive'
      Write-Ok "Keep-alive task for WSL distro '$Distro': at Windows start-up, at logon and every 5 minutes"
      Test-FailPoint 'end'
    } catch {
      Write-Warn "Setup failed: $($_.Exception.Message)"
      Write-Warn 'Undoing everything this helper had set up, so nothing is left half done...'
      Remove-TortugarrWindows $state $PortList $Distro | Out-Null
      throw "Windows side not set up: $($_.Exception.Message)"
    }
    $state['ports'] = $PortList; $state['peer_port'] = $PeerPort
    $state['setup'] = 'done'
    Save-State $state
    # The first keep-alive is started here, once the state file says "done" - never left to the
    # task's 5-minute repetition: that only begins when one of its triggers fires (a boot, a
    # logon, or the one-off trigger a minute from now), not at registration. In the Win11 VM
    # (2026-10-07) setup finished at 16:51 and nothing started the keep-alive until 17:05.
    # Started by the task, not by this window, so it does not depend on this process.
    Exit-Lock
    Invoke-Step 'start keep-alive now' { Start-ScheduledTask -TaskName $KeepAliveTask }
    $until = (Get-Date).AddSeconds($(if ($TestMode) { 5 } else { 60 }))
    while (-not (Test-KeepAliveRunning $Distro) -and (Get-Date) -lt $until) { Start-Sleep -Seconds 2 }
    if (Test-KeepAliveRunning $Distro) { Write-Ok "Keep-alive is running for WSL distro '$Distro'" }
    else {
      Write-Warn 'The keep-alive did not start within a minute (the task retries every 5 minutes).'
      $script:exitCode = 3
    }
    # Set up - now prove it: every port must answer through the forwarding. Not undone when one
    # does not (a service may just be slow); the exit code 3 tells the installer.
    Write-Note 'Checking that each port answers on the LAN address...'
    # Up to 3 minutes when forwarding was just added (Windows can be that slow to start
    # listening), otherwise 90 seconds for a service that is still starting.
    $dead = @(Test-ForwardedPorts $PortList $ip $(if ($changed.Count) { 180 } else { 90 }) $changed)
    $broken = @($dead | Where-Object { $_ -notin $script:blockedPorts })
    if ($broken.Count -gt 0) {
      Write-Warn "Set up, but $($broken -join ', ') did not answer on $ip - see the lines above."
      $script:exitCode = 3
    } elseif ($dead.Count -gt 0 -and $public -eq 'leave') {
      # Exit code 4: what the user chose, not a failure.
      Write-Warn "Left as Public by your choice: other devices on this network cannot reach Tortugarr (this PC can). 'sudo tortugarr windows' and choice 1 or 2 change that."
      $script:exitCode = 4
    } elseif ($dead.Count -gt 0) {
      Write-Warn "Set up, but the network is Public and the firewall blocks other devices - run 'sudo tortugarr windows' again and choose 1 or 2."
      $script:exitCode = 3
    } else {
      Write-Ok "Done. Devices on your network reach Tortugarr at http://$($ip):$($PortList[0])"
    }
  }
  'refresh' {
    # Runs at boot, at logon and every 5 minutes: the keep-alive back if it is gone (for
    # example after `wsl --shutdown`), and the forwarding moved if the LAN address changed.
    # Another run busy (setup, remove, or a refresh from another trigger): it does the job.
    if (-not (Enter-Lock 30)) { break }
    $state = Get-State
    if (-not $state['ports'] -or $state['mode'] -ne 'wsl' -or $state['setup'] -eq 'running') { break }
    if (-not (Test-KeepAliveRunning $state['distro'])) {
      Start-KeepAlive $state['distro']
      Write-Note "keep-alive for '$($state['distro'])' started again"
    }
    $ip = Get-LanIp
    $old = @($state['portproxy'] | Where-Object { $_.ip -ne $ip })
    if ($old.Count -gt 0) { Remove-PortForwarding $old }
    # Runs hidden at boot: skip (never replace) ports someone else holds on the new address.
    $foreign = @(Get-ForeignPorts ([int[]]$state['ports']) $ip $state)
    $free = @([int[]]$state['ports'] | Where-Object { $_ -notin $foreign.port })
    $foreign | ForEach-Object { Write-Warn "Skipping $($ip):$($_.port) - $($_.what)" }
    $want = @($free | ForEach-Object { @{ ip = $ip; port = $_ } })
    $have = @(Get-UniquePortProxy $state['portproxy'] | ForEach-Object { "$($_.ip)/$($_.port)" }) | Sort-Object
    # The state file is written only when something changes (normally never - this runs every
    # 5 minutes) - and then before the change, like setup.
    if ((@($want | ForEach-Object { "$($_.ip)/$($_.port)" } | Sort-Object) -join ',') -ne ($have -join ',')) {
      $state['portproxy'] = @(@($state['portproxy']) + $want)
      Save-State $state
      Set-PortForwarding $free $ip | Out-Null
      $state['portproxy'] = $want
      Save-State $state
    }
  }
  'status' {
    $state = Get-State
    if (-not $state.Count) {
      if (Test-Traces) { Write-Warn "Tortugarr forwarding, firewall rules or tasks are here, but the state file is missing - run 'sudo tortugarr windows' in WSL to write it again (or 'sudo tortugarr windows remove' to take it all away)." }
      else { Write-Warn 'Nothing set up on the Windows side yet.' }
      break
    }
    if ($state['setup'] -eq 'running') { Write-Warn "The last setup did not finish - run 'sudo tortugarr windows' again, or remove it with 'sudo tortugarr windows remove'." }
    Write-Host "Mode: $($state['mode'])   Distro: $($state['distro'])   LAN: $(Get-LanIp)"
    netsh interface portproxy show v4tov4
    Get-NetFirewallRule -Group $FwGroup -ErrorAction SilentlyContinue | Select-Object DisplayName, Enabled, Profile | Format-Table -AutoSize
    Get-ScheduledTask -TaskName 'Tortugarr keepalive*' -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize
    $running = (wsl.exe -l --running 2>$null) -replace "`0", '' | Select-String -SimpleMatch $state['distro']
    if ($running) { Write-Ok "WSL distro '$($state['distro'])' is running" } else { Write-Warn "WSL distro '$($state['distro'])' is not running" }
    # Windows shows the keep-alive's command line only to administrators; without that, the
    # doctor in WSL checks it from the inside.
    if (-not (Test-IsAdmin)) { Write-Note 'keep-alive: checked from inside WSL (see below)' }
    elseif (Test-KeepAliveRunning $state['distro']) { Write-Ok 'keep-alive is running' }
    else { Write-Warn 'keep-alive is not running (it comes back within 5 minutes)' }
    if ($state['ports']) {
      $dead = @(Test-ForwardedPorts ([int[]]$state['ports']) (Get-LanIp) 0)
      if ($dead.Count -gt 0) { $script:exitCode = 3 }
    }
  }
  'remove' {
    Assert-Admin
    if (-not (Enter-Lock 120)) { throw 'Another Tortugarr helper run is busy - try again in a minute.' }
    Remove-TortugarrWindows (Get-State) $PortList $Distro | Out-Null
    if ($script:cleanupFailed) { throw 'Windows side only partly removed.' }
    Write-Ok 'Windows port forwarding, firewall rules and keep-alive removed'
  }
}
} catch {
  # A plain message, not a PowerShell error record with a stack trace (also shown in WSL). The
  # line number helps with a support bundle.
  Write-Host "  xx  $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "      (tortugarr-windows.ps1, line $($_.InvocationInfo.ScriptLineNumber))" -ForegroundColor DarkGray
  $script:exitCode = 1
} finally {
  # Also when a step failed: the lock is free again and the log is complete.
  Exit-Lock
  if ($LogFile) { Stop-Transcript | Out-Null }
  if ($Pause) { Read-Host 'Press Enter to close this window' | Out-Null }
}
exit $script:exitCode
