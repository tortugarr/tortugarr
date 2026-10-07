# Runs the helper's Register-KeepAlive with the REAL New-ScheduledTask* cmdlets (they only build
# objects) - for a Windows test VM only, never on an everyday PC.
# Register-/Start-ScheduledTask are stubs that print what they were given. Checks that
# the task gets a CimInstance MSFT_TaskExecAction (not a ScriptBlock). No administrator rights,
# nothing is registered.
#   powershell -ExecutionPolicy Bypass -File keepalive-objects.ps1 -Helper <tortugarr-windows.ps1>
param([Parameter(Mandatory)] [string]$Helper)
$ErrorActionPreference = 'Stop'
# Loaded first, so the stubs below are not hidden by an auto-load (see crash-case.ps1).
Import-Module ScheduledTasks
$Root = Join-Path ([IO.Path]::GetTempPath()) 'tortugarr-keepalive-objects'; $DryRun = $false; $TestMode = $false
$ast = [Management.Automation.Language.Parser]::ParseFile($Helper, [ref]$null, [ref]$null)
$ast.FindAll({ $args[0] -is [Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object { Invoke-Expression $_.Extent.Text }
$script:bad = 0
function Copy-Self { New-Item -ItemType Directory -Force -Path $Root | Out-Null; Join-Path $Root 'tortugarr-windows.ps1' }
function Register-ScheduledTask($TaskName, $Action, $Settings, $Trigger, $Principal, [switch]$Force) {
  Write-Host "$TaskName : Action=$($Action.GetType().Name) [$($Action.CimClass.CimClassName)] $($Action.Execute) $($Action.Arguments)"
  Write-Host "   Settings=$($Settings.CimClass.CimClassName) Trigger=$($Trigger.CimClass.CimClassName) every $($Trigger.Repetition.Interval) Principal=$($Principal.LogonType)"
  if ($Action.CimClass.CimClassName -ne 'MSFT_TaskExecAction' -or $Settings.CimClass.CimClassName -notlike 'MSFT_TaskSettings*' -or $Trigger.Repetition.Interval -ne 'PT5M') { $script:bad++ }
}
function Start-ScheduledTask($TaskName) { Write-Host "Start-ScheduledTask $TaskName (stub)" }
if ((Get-Command Register-ScheduledTask).CommandType -ne 'Function') { throw 'stub not active' }
Register-KeepAlive 'TestDistro'
Remove-Item $Root -Recurse -Force -ErrorAction SilentlyContinue
if ($script:bad) { Write-Host "FAIL ($script:bad)" -ForegroundColor Red; exit 1 } else { Write-Host 'PASS: real task objects' -ForegroundColor Green }
