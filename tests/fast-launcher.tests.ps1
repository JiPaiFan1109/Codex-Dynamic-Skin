$ErrorActionPreference='Stop'
$scriptPath=Join-Path (Split-Path $PSScriptRoot -Parent) 'engine/scripts/launch-dream-skin.ps1'
if(-not(Test-Path -LiteralPath $scriptPath)){throw 'FAIL: lightweight launcher is missing'}
. $scriptPath
if(-not(Get-Command Test-DynamicQuickState -ErrorAction SilentlyContinue)){throw 'FAIL: launcher has no pure state validator'}
$root='C:\Skin'
$state=[pscustomobject]@{
  schemaVersion=3;platform='windows'
  port=9345;browserId='browser-123';codexPackageFamilyName='OpenAI.Codex_2p2nqsd0c76g0'
  codexExe='C:\Codex\ChatGPT.exe'
  profilePath='C:\Skin\cdp-profile';themeDir='C:\Skin\active-theme';pauseFile='C:\Skin\paused'
  nodePath='C:\Skin\engine\runtime\node\node.exe';injectorPath='C:\Skin\engine\scripts\injector.mjs'
  injectorPid=11;injectorStartedAt='2026-10-02T01:02:03.0000000Z'
  videoPid=22;videoStartedAt='2026-10-02T01:02:04.0000000Z';videoScript='C:\Skin\engine\scripts\video-server.mjs';videoReadyPath='C:\Skin\video-ready.json'
}
$processes=@(
 [pscustomobject]@{Id=11;Path=$state.nodePath;StartedAt=$state.injectorStartedAt},
 [pscustomobject]@{Id=22;Path=$state.nodePath;StartedAt=$state.videoStartedAt}
)
function Assert-Equal($Actual,$Expected,$Message){if($Actual-ne$Expected){throw "FAIL: $Message"}}
Assert-Equal (Test-DynamicQuickState -State $state -StateRoot $root -Processes $processes -BrowserId 'browser-123') $true 'healthy dynamic session'
$jsonState=$state.PSObject.Copy();$jsonState.injectorStartedAt=[datetime]::Parse($state.injectorStartedAt);$jsonState.videoStartedAt=[datetime]::Parse($state.videoStartedAt)
Assert-Equal (Test-DynamicQuickState -State $jsonState -StateRoot $root -Processes $processes -BrowserId 'browser-123') $true 'ConvertFrom-Json DateTime state'
Assert-Equal (Test-DynamicQuickState -State $state -StateRoot $root -Processes $processes -BrowserId 'different') $false 'wrong browser identity'
Assert-Equal (Test-DynamicQuickState -State $state -StateRoot $root -Processes @($processes[0]) -BrowserId 'browser-123') $false 'missing video server'
$static=$state.PSObject.Copy();$static.videoPid=$null;$static.videoStartedAt=$null;$static.videoScript=$null;$static.videoReadyPath=$null
Assert-Equal (Test-DynamicQuickState -State $static -StateRoot $root -Processes @($processes[0]) -BrowserId 'browser-123') $true 'healthy static session'
$wrongPath=$state.PSObject.Copy();$wrongPath.profilePath='C:\Other\profile'
Assert-Equal (Test-DynamicQuickState -State $wrongPath -StateRoot $root -Processes $processes -BrowserId 'browser-123') $false 'foreign profile'
$reused=@([pscustomobject]@{Id=11;Path=$state.nodePath;StartedAt='2026-10-02T02:00:00.0000000Z'},$processes[1])
Assert-Equal (Test-DynamicQuickState -State $state -StateRoot $root -Processes $reused -BrowserId 'browser-123') $false 'reused PID'
$managedCodex=[pscustomobject]@{ProcessId=31;ParentProcessId=300;ExecutablePath=$state.codexExe;CommandLine='"C:\Codex\ChatGPT.exe" --remote-debugging-address=127.0.0.1 --remote-debugging-port=9345 --user-data-dir=C:\Skin\cdp-profile'}
$managedRenderer=[pscustomobject]@{ProcessId=32;ParentProcessId=31;ExecutablePath=$state.codexExe;CommandLine='"C:\Codex\ChatGPT.exe" --type=renderer --user-data-dir=C:\Skin\cdp-profile'}
$ordinaryCodex=[pscustomobject]@{ProcessId=41;ParentProcessId=400;ExecutablePath=$state.codexExe;CommandLine='"C:\Codex\ChatGPT.exe"'}
Assert-Equal (Test-DynamicQuickCodexState -State $state -Processes @($managedCodex,$managedRenderer)) $true 'exclusive managed Codex instance'
Assert-Equal (Test-DynamicQuickCodexState -State $state -Processes @($managedCodex,$managedRenderer,$ordinaryCodex)) $false 'ordinary Codex alongside Dream Skin'
Assert-Equal (Test-DynamicQuickCodexState -State $state -Processes @($ordinaryCodex)) $false 'ordinary Codex without Dream Skin'
'PASS: lightweight launcher identity, dynamic/static session and fallback cases'
