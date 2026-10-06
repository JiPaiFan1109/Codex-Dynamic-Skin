[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Test-DynamicPathEqual {
  param([string]$Left,[string]$Right)
  if(-not $Left -or -not $Right){return $false}
  try{return [IO.Path]::GetFullPath($Left).TrimEnd('\') -ieq [IO.Path]::GetFullPath($Right).TrimEnd('\')}
  catch{return $false}
}

function Test-DynamicTimestampEqual {
  param($Left,$Right)
  try{return ([datetime]$Left).ToUniversalTime().Ticks-eq([datetime]$Right).ToUniversalTime().Ticks}
  catch{return $false}
}

function Test-DynamicQuickState {
  param([object]$State,[string]$StateRoot,[object[]]$Processes,[string]$BrowserId)
  if($null-eq$State -or "$($State.schemaVersion)"-ne'3' -or "$($State.platform)"-ine'windows'){return $false}
  if("$($State.browserId)"-cne$BrowserId -or $BrowserId-cnotmatch '^[A-Za-z0-9._-]{1,200}$'){return $false}
  if("$($State.codexPackageFamilyName)"-cnotmatch '^OpenAI\.Codex_[A-Za-z0-9]+$'){return $false}
  $root=[IO.Path]::GetFullPath($StateRoot)
  $expected=@{
    profilePath=Join-Path $root 'cdp-profile';themeDir=Join-Path $root 'active-theme';pauseFile=Join-Path $root 'paused'
    nodePath=Join-Path $root 'engine\runtime\node\node.exe';injectorPath=Join-Path $root 'engine\scripts\injector.mjs'
  }
  foreach($key in $expected.Keys){if(-not(Test-DynamicPathEqual "$($State.$key)" $expected[$key])){return $false}}
  $injector=@($Processes|Where-Object{[int]$_.Id-eq[int]$State.injectorPid})
  if($injector.Count-ne1 -or -not(Test-DynamicPathEqual $injector[0].Path $State.nodePath) -or -not(Test-DynamicTimestampEqual $injector[0].StartedAt $State.injectorStartedAt)){return $false}
  if($State.videoPid){
    if(-not(Test-DynamicPathEqual $State.videoScript (Join-Path $root 'engine\scripts\video-server.mjs')) -or
      -not(Test-DynamicPathEqual $State.videoReadyPath (Join-Path $root 'video-ready.json'))){return $false}
    $video=@($Processes|Where-Object{[int]$_.Id-eq[int]$State.videoPid})
    if($video.Count-ne1 -or -not(Test-DynamicPathEqual $video[0].Path $State.nodePath) -or -not(Test-DynamicTimestampEqual $video[0].StartedAt $State.videoStartedAt)){return $false}
  }
  return $true
}

function Start-DynamicFullLauncher {
  param([string]$ScriptRoot)
  $script=Join-Path $ScriptRoot 'start-dream-skin.ps1'
  $quoted='"'+$script.Replace('"','\"')+'"'
  Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File $quoted -PromptRestart" -WindowStyle Hidden|Out-Null
}

function Initialize-DynamicQuickPackageLauncher {
  if('CodexDynamicSkin.QuickPackageLauncher'-as[type]){return}
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace CodexDynamicSkin {
  [ComImport,Guid("2e941141-7f97-4756-ba1d-9decde894a3d"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IApplicationActivationManager { [PreserveSig] int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,[MarshalAs(UnmanagedType.LPWStr)] string arguments,uint options,out uint processId); }
  [ComImport,Guid("45ba127d-10a8-46ea-8ab7-56ea9078943c")] class ApplicationActivationManager {}
  public static class QuickPackageLauncher {
    public static uint Launch(string id,string args){var manager=(IApplicationActivationManager)new ApplicationActivationManager();try{uint pid;Marshal.ThrowExceptionForHR(manager.ActivateApplication(id,args??String.Empty,0,out pid));return pid;}finally{if(Marshal.IsComObject(manager))Marshal.FinalReleaseComObject(manager);}}
  }
}
'@
}

function Invoke-DynamicQuickLauncher {
  param([string]$ScriptRoot=$PSScriptRoot)
  $engineRoot=Split-Path $ScriptRoot -Parent
  $stateRoot=Split-Path $engineRoot -Parent
  try{
    $statePath=Join-Path $stateRoot 'state.json'
    $info=Get-Item -LiteralPath $statePath -ErrorAction Stop
    if($info.Length-lt2 -or $info.Length-gt65536){throw 'Invalid state size'}
    $state=[IO.File]::ReadAllText($statePath)|ConvertFrom-Json -ErrorAction Stop
    $port=[int]$state.port
    if($port-lt1024 -or $port-gt65535){throw 'Invalid port'}
    $version=Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/version" -TimeoutSec 1 -MaximumRedirection 0 -ErrorAction Stop
    $uri=[Uri]"$($version.webSocketDebuggerUrl)"
    $match=[regex]::Match($uri.AbsolutePath,'^/devtools/browser/(?<id>[A-Za-z0-9._-]{1,200})$')
    if($uri.Scheme-ne'ws' -or $uri.Host-ne'127.0.0.1' -or $uri.Port-ne$port -or -not$match.Success){throw 'Endpoint identity mismatch'}
    $pids=@([int]$state.injectorPid);if($state.videoPid){$pids += [int]$state.videoPid}
    $processes=@();foreach($processId in $pids){$p=Get-Process -Id $processId -ErrorAction SilentlyContinue;if($p){$processes += [pscustomobject]@{Id=$p.Id;Path=$p.Path;StartedAt=$p.StartTime.ToUniversalTime().ToString('o')}}}
    if(-not(Test-DynamicQuickState -State $state -StateRoot $stateRoot -Processes $processes -BrowserId $match.Groups['id'].Value)){throw 'Managed services need recovery'}
    Initialize-DynamicQuickPackageLauncher
    $aumid="$($state.codexPackageFamilyName)!App"
    $args="--remote-debugging-address=127.0.0.1 --remote-debugging-port=$port --user-data-dir=`"$($state.profilePath)`""
    if([CodexDynamicSkin.QuickPackageLauncher]::Launch($aumid,$args)-le0){throw 'Window activation failed'}
    return $true
  }catch{
    Start-DynamicFullLauncher -ScriptRoot $ScriptRoot
    return $false
  }
}

if($MyInvocation.InvocationName-ne'.'){[void](Invoke-DynamicQuickLauncher)}
