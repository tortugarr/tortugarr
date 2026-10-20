# Runs windows/tortugarr-windows.ps1 once against a FAKE Windows: every command that would
# change the machine (netsh, firewall, network profile, scheduled tasks, processes) is a stub
# that reads and writes $Work/system.json instead. Runs with PowerShell 7 on Linux (no Windows
# involved at all) or inside a Windows test VM - never on an everyday Windows PC.
# Started by crash-test.ps1, one process per run, so a 'kill' crash ends only this process.
param(
  [Parameter(Mandatory)] [string]$Helper,
  [Parameter(Mandatory)] [string]$Work,
  # The helper's arguments joined with '|': setup|-Ports|8096,5055|-Distro|Ubuntu
  [string]$HelperArgList = ''
)
$ErrorActionPreference = 'Stop'
$SystemFile = Join-Path $Work 'system.json'
$CallLog = Join-Path $Work 'calls.log'

# Load the real modules first: a module that auto-loads later (on first use, inside a function)
# lands in a nearer scope and would hide the stubs below - the real command would run.
if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) { Import-Module ScheduledTasks, NetSecurity, NetConnection, NetTCPIP, CimCmdlets }

function Get-Sys { Get-Content $SystemFile -Raw | ConvertFrom-Json }
function Set-Sys($Sys) { $Sys | ConvertTo-Json -Depth 6 | Set-Content $SystemFile -Encoding UTF8 }
function Write-Call([string]$Text) { Add-Content $CallLog $Text }

function netsh {
  $a = @($args | ForEach-Object { "$_" })
  Write-Call "netsh $($a -join ' ')"
  if ($a[1] -ne 'portproxy') { return }
  $kv = @{}; $a | Where-Object { $_ -match '=' } | ForEach-Object { $k, $v = $_ -split '=', 2; $kv[$k] = $v }
  $sys = Get-Sys
  $rest = @($sys.portproxy | Where-Object { $_ -and -not ($_.kind -eq $a[3] -and $_.ip -eq $kv.listenaddress -and [int]$_.port -eq [int]$kv.listenport) })
  if ($a[2] -eq 'add') { $rest += [pscustomobject]@{ kind = $a[3]; ip = $kv.listenaddress; port = [int]$kv.listenport; to = "$($kv.connectaddress)/$($kv.connectport)" } }
  if ($a[2] -in 'add', 'delete') { $sys.portproxy = $rest; Set-Sys $sys }
}
function Get-TestPortProxyEntries { @((Get-Sys).portproxy | Where-Object { $_ }) }
# As measured in a Windows 11 test VM on 2026-10-07: WSL's relay listens on 127.0.0.1 only, so a
# port answers on the LAN address only through a v4tov4 entry to 127.0.0.1 (v4tov6 to ::1
# resets). dead_ports: services that do not run.
function Test-TestHttpAnswers([string]$Address, [int]$Port) {
  $sys = Get-Sys
  # answer_delay_ms: each try takes this long (a port that times out).
  if ($sys.answer_delay_ms) { Start-Sleep -Milliseconds ([int]$sys.answer_delay_ms) }
  if ($Port -in @($sys.dead_ports)) { return $false }
  if ($Address -eq '127.0.0.1') { return $true }
  # forwarding_slow: Windows has not started listening on new forwarding yet.
  if ($sys.forwarding_slow) { return $false }
  [bool]($sys.portproxy | Where-Object { $_ -and $_.kind -eq 'v4tov4' -and $_.ip -eq $Address -and [int]$_.port -eq $Port -and $_.to -eq "127.0.0.1/$Port" })
}
function Get-NetTCPConnection { }
function Get-NetIPConfiguration {
  [pscustomobject]@{ IPv4DefaultGateway = '192.0.2.1'; NetAdapter = [pscustomobject]@{ Status = 'Up' }; IPv4Address = [pscustomobject]@{ IPAddress = (Get-Sys).lan_ip } }
}
function Get-NetConnectionProfile([int]$InterfaceIndex, $ErrorAction) {
  $n = (Get-Sys).network
  if ($InterfaceIndex -and $InterfaceIndex -ne $n.index) { return }
  [pscustomobject]@{ Name = $n.name; InterfaceIndex = $n.index; NetworkCategory = $n.category; IPv4Connectivity = 'Internet' }
}
function Set-NetConnectionProfile([int]$InterfaceIndex, [string]$NetworkCategory) {
  Write-Call "Set-NetConnectionProfile $InterfaceIndex $NetworkCategory"
  $sys = Get-Sys; $sys.network.category = $NetworkCategory; Set-Sys $sys
}
function Get-NetFirewallRule([string]$Group, $ErrorAction) {
  @((Get-Sys).firewall | Where-Object { $_ -and (-not $Group -or $_.group -eq $Group) })
}
function New-NetFirewallRule {
  param($DisplayName, $Group, $Direction, $Action, $Protocol, $LocalPort, $Profile, $RemoteAddress)
  Write-Call "New-NetFirewallRule $DisplayName"
  $sys = Get-Sys
  $sys.firewall = @(@($sys.firewall | Where-Object { $_ }) + [pscustomobject]@{ name = $DisplayName; group = $Group; port = "$LocalPort"; profile = "$Profile" })
  Set-Sys $sys
}
function Remove-NetFirewallRule {
  param([Parameter(ValueFromPipeline)] $InputObject)
  process {
    if (-not $InputObject) { return }
    Write-Call "Remove-NetFirewallRule $($InputObject.name)"
    $sys = Get-Sys; $sys.firewall = @($sys.firewall | Where-Object { $_ -and $_.name -ne $InputObject.name }); Set-Sys $sys
  }
}
function Get-NetFirewallPortFilter {
  param([Parameter(ValueFromPipeline)] $InputObject)
  process { if ($InputObject) { [pscustomobject]@{ LocalPort = $InputObject.port } } }
}
function New-ScheduledTaskAction { [pscustomobject]@{ kind = 'action' } }
function New-ScheduledTaskSettingsSet { [pscustomobject]@{ kind = 'settings' } }
function New-ScheduledTaskPrincipal { [pscustomobject]@{ kind = 'principal' } }
function New-ScheduledTaskTrigger { [pscustomobject]@{ kind = 'trigger'; Repetition = $null } }
function Register-ScheduledTask {
  param($TaskName, $Action, $Settings, $Trigger, $Principal, [switch]$Force)
  if ($Action -isnot [pscustomobject] -or $Action.kind -ne 'action') { throw "Register-ScheduledTask: -Action is not a task action ($($Action.GetType().Name))" }
  if (@($Trigger).Count -ne 3) { throw "Register-ScheduledTask: expected 3 triggers (boot, logon, now), got $(@($Trigger).Count)" }
  Write-Call "Register-ScheduledTask $TaskName"
  $sys = Get-Sys; $sys.tasks = @(@($sys.tasks | Where-Object { $_ -and $_ -ne $TaskName }) + $TaskName); Set-Sys $sys
}
function Unregister-ScheduledTask {
  param($TaskName, [switch]$Confirm, $ErrorAction)
  Write-Call "Unregister-ScheduledTask $TaskName"
  $sys = Get-Sys; $sys.tasks = @($sys.tasks | Where-Object { $_ -and $_ -ne $TaskName }); Set-Sys $sys
}
function Get-ScheduledTask([string]$TaskName, $ErrorAction) {
  @((Get-Sys).tasks | Where-Object { $_ -and $_ -like $TaskName } | ForEach-Object { [pscustomobject]@{ TaskName = $_; State = 'Ready' } })
}
# Stands in for the task's refresh run: records what the state file said when the task was
# started, and starts the keep-alive the way refresh does.
function Start-ScheduledTask([string]$TaskName) {
  Write-Call "Start-ScheduledTask $TaskName"
  $f = Join-Path $env:TORTUGARR_WINDOWS_TEST_ROOT 'windows-state.json'
  $setup = if (Test-Path $f) { (Get-Content $f -Raw | ConvertFrom-Json).setup } else { 'no state file' }
  $sys = Get-Sys
  $sys | Add-Member -NotePropertyName task_started_when -NotePropertyValue "$setup" -Force
  if (-not $sys.keepalive) { $sys.keepalive = $true; $sys | Add-Member -NotePropertyName keepalive_starts -NotePropertyValue ([int]$sys.keepalive_starts + 1) -Force }
  Set-Sys $sys
}
function Get-CimInstance {
  # As slow as the real process query, so two unlocked runs would both see "no keep-alive".
  Start-Sleep -Milliseconds 800
  $sys = Get-Sys
  if ($sys.keepalive) { [pscustomobject]@{ ProcessId = 4242; CommandLine = "wsl.exe -d $($sys.distro) --exec sleep infinity" } }
}
function Stop-Process([int]$Id, [switch]$Force, $ErrorAction) {
  Write-Call "Stop-Process $Id"
  if ($Id -eq 4242) { $sys = Get-Sys; $sys.keepalive = $false; Set-Sys $sys }
}
# The user's answers to Read-Host, in order, from system.json "answers".
function Read-Host([string]$Prompt) {
  $sys = Get-Sys
  $list = @($sys.answers)
  $a = if ($list.Count) { [string]$list[0] } else { throw "Read-Host '$Prompt': no answer left" }
  $sys.answers = @($list | Select-Object -Skip 1)
  Set-Sys $sys
  Write-Call "Read-Host '$Prompt' -> '$a'"
  return $a
}

function Start-Process {
  param($FilePath, $ArgumentList, $WindowStyle)
  Write-Call "Start-Process $FilePath $($ArgumentList -join ' ')"
  if ("$ArgumentList" -match 'sleep infinity') {
    $sys = Get-Sys; $sys.keepalive = $true
    $sys | Add-Member -NotePropertyName keepalive_starts -NotePropertyValue ([int]$sys.keepalive_starts + 1) -Force
    Set-Sys $sys
  }
}

$env:TORTUGARR_WINDOWS_TEST = '1'
$env:TORTUGARR_WINDOWS_TEST_ROOT = Join-Path $Work 'ProgramData-Tortugarr'
# Runs started together by crash-test.ps1 wait for the same moment, so they really overlap.
if ($env:TORTUGARR_TEST_START_AT) {
  $ms = [long]$env:TORTUGARR_TEST_START_AT - [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if ($ms -gt 0) { Start-Sleep -Milliseconds $ms }
}
$list = @($HelperArgList -split '\|' | Where-Object { $_ })
$named = @{}
for ($i = 1; $i -lt $list.Count; $i += 2) { $named[$list[$i].TrimStart('-')] = $list[$i + 1] }
& $Helper $list[0] @named
# The helper ends with `exit <code>`; under -File that is the process exit code, so pass it on.
exit [int]$LASTEXITCODE
