$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'engine/scripts/common-windows.ps1')

function Assert-Equal($Actual,$Expected,$Message){
  if($Actual-ne$Expected){throw "FAIL: $Message (expected=$Expected actual=$Actual)"}
}

$profile='C:\Skin\cdp-profile'
$managed=[pscustomobject]@{
  ProcessId=10;ParentProcessId=900;ExecutablePath='C:\Codex\ChatGPT.exe'
  CommandLine='"C:\Codex\ChatGPT.exe" --remote-debugging-address=127.0.0.1 --remote-debugging-port=9345 --user-data-dir=C:\Skin\cdp-profile'
}
$managedRenderer=[pscustomobject]@{
  ProcessId=11;ParentProcessId=10;ExecutablePath='C:\Codex\ChatGPT.exe'
  CommandLine='"C:\Codex\ChatGPT.exe" --type=renderer --user-data-dir=C:\Skin\cdp-profile'
}
$ordinary=[pscustomobject]@{
  ProcessId=20;ParentProcessId=901;ExecutablePath='C:\Codex\ChatGPT.exe'
  CommandLine='"C:\Codex\ChatGPT.exe"'
}
$ordinaryRenderer=[pscustomobject]@{
  ProcessId=21;ParentProcessId=20;ExecutablePath='C:\Codex\ChatGPT.exe'
  CommandLine='"C:\Codex\ChatGPT.exe" --type=renderer'
}

$mixed=@($managed,$managedRenderer,$ordinary,$ordinaryRenderer)
$roots=@(Get-DreamSkinCodexMainProcesses -Processes $mixed)
Assert-Equal $roots.Count 2 'renderer processes must not be classified as app instances'
$status=Get-DreamSkinCodexInstanceStatus -Processes $mixed -Port 9345 -ProfilePath $profile
Assert-Equal $status.Managed.Count 1 'managed Dream Skin root must be recognized'
Assert-Equal $status.Foreign.Count 1 'ordinary root must be recognized as a foreign instance'
Assert-Equal $status.IsExclusive $false 'mixed profiles must not be reusable'

$healthy=Get-DreamSkinCodexInstanceStatus -Processes @($managed,$managedRenderer) -Port 9345 -ProfilePath $profile
Assert-Equal $healthy.Managed.Count 1 'single managed root must be present'
Assert-Equal $healthy.Foreign.Count 0 'single managed profile must have no foreign instance'
Assert-Equal $healthy.IsExclusive $true 'single managed profile must be reusable'

$unknown=[pscustomobject]@{ProcessId=30;ParentProcessId=902;ExecutablePath='C:\Codex\ChatGPT.exe';CommandLine=$null}
$unknownStatus=Get-DreamSkinCodexInstanceStatus -Processes @($unknown) -Port 9345 -ProfilePath $profile
Assert-Equal $unknownStatus.Foreign.Count 1 'an unreadable root must fail closed as foreign'
Assert-Equal $unknownStatus.IsExclusive $false 'an unreadable root must not be reused'

'PASS: Codex roots are classified by managed profile without counting renderer children.'
