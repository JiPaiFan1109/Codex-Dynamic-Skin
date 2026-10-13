$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/skin-manager.ps1')
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
function Get-DreamSkinCodexInstall { [pscustomobject]@{Version='26.1000';Executable='C:\Codex\Codex.exe'} }
$connection=Get-DynamicCodexConnection
Assert ($connection.Available -and $connection.Message -like '*26.1000*') 'Registered Codex was not detected'
function Get-DreamSkinCodexInstall { throw 'No registered package' }
$missing=Get-DynamicCodexConnection
Assert (-not $missing.Available -and $missing.Message -like '*Codex*' -and $missing.Error) 'Missing Codex needs a useful status'
$selected=[pscustomobject]@{Id='a';IsAvailable=$true}
$status=[pscustomobject]@{CurrentId=$null;Error=$null}
$actions=Get-DynamicManagerActionState $selected $status $false $false $false
Assert (-not $actions.Apply -and -not $actions.Open -and $actions.Import) 'Missing Codex must disable engine actions while allowing imports'
$actions=Get-DynamicManagerActionState $selected $status $false $false $true
Assert ($actions.Apply -and $actions.Open) 'Detected Codex must enable engine actions'
$window=New-DynamicSkinManagerWindow
try {Assert ($null -ne $window.FindName('ConnectionText') -and $null -ne $window.FindName('DetectButton')) 'Connection status and retry controls are missing'}finally{$window.Close()}
'PASS Codex detection, missing-package state, action gating and controls'
