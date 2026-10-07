$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'engine/scripts/common-windows.ps1')

$managed=[pscustomobject]@{ProcessId=10}
$foreign=[pscustomobject]@{ProcessId=20}
$exclusive=[pscustomobject]@{Managed=@($managed);Foreign=@();IsExclusive=$true}
$mixed=[pscustomobject]@{Managed=@($managed);Foreign=@($foreign);IsExclusive=$false}
$script:confirmCalls=0
$script:confirmResult=$false
function Confirm-DreamSkinRestart {param($Message)$script:confirmCalls++;return $script:confirmResult}

$action=Resolve-DreamSkinCodexCoexistenceAction -Status $exclusive -PromptRestart -Message 'fixture'
if($action-ne'continue' -or $script:confirmCalls-ne0){throw 'FAIL: exclusive session should continue without prompting'}

$threw=$false
try{Resolve-DreamSkinCodexCoexistenceAction -Status $mixed -Message 'fixture'|Out-Null}catch{$threw=$true}
if(-not$threw){throw 'FAIL: mixed profiles without interactive consent were accepted'}

$action=Resolve-DreamSkinCodexCoexistenceAction -Status $mixed -PromptRestart -Message 'fixture'
if($action-ne'cancel' -or $script:confirmCalls-ne1){throw 'FAIL: declined coexistence prompt should cancel startup'}

$script:confirmResult=$true
$action=Resolve-DreamSkinCodexCoexistenceAction -Status $mixed -PromptRestart -Message 'fixture'
if($action-ne'restart' -or $script:confirmCalls-ne2){throw 'FAIL: accepted coexistence prompt should authorize one restart'}

$script:confirmCalls=0
$action=Resolve-DreamSkinCodexCoexistenceAction -Status $mixed -RestartExisting -Message 'fixture'
if($action-ne'restart' -or $script:confirmCalls-ne0){throw 'FAIL: explicit restart authorization should not prompt again'}

'PASS: mixed Codex profiles require explicit restart consent.'
