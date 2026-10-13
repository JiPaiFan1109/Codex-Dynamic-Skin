[CmdletBinding()]
param([string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'CodexDynamicSkin'),[string]$ResultPath)
$ErrorActionPreference='Stop'

function Get-DynamicUpgradeBlockReason {
  param([string]$InstallRoot)
  $root=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
  $runtime=Join-Path $root 'engine/runtime/node/node.exe'
  try {
    $processes=@(Get-CimInstance Win32_Process -Filter "Name='node.exe' OR Name='powershell.exe' OR Name='CodexSkinManager.exe'")
    foreach($process in $processes){
      if([string]$process.ExecutablePath -ieq $runtime){return '安装运行环境仍被使用，请关闭相关程序后重试；无法确认归属的进程不会被自动终止。'}
      if([string]$process.ExecutablePath -ieq (Join-Path $root 'CodexSkinManager.exe')){return '请先关闭换肤管理中心，再重试安装。'}
      if($process.CommandLine -and ([string]$process.CommandLine).IndexOf(($root+'\scripts\manage-background.ps1'),[StringComparison]::OrdinalIgnoreCase) -ge 0){return '请先关闭换肤管理中心，再重试安装。'}
    }
  }catch{return '无法检查换肤后台是否已经退出，本次安装不会替换文件。请稍后重试。'}
  return $null
}

function Invoke-DynamicUpgradePreparation {
  param([string]$InstallRoot)
  $root=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
  $runtime=Join-Path $root 'engine/runtime/node/node.exe'
  $handles=New-Object 'Collections.Generic.List[object]'
  try {
    $processes=@(Get-CimInstance Win32_Process -Filter "Name='node.exe' OR Name='powershell.exe' OR Name='CodexSkinManager.exe'" -ErrorAction Stop)
    foreach($process in $processes){
      if([string]$process.ExecutablePath -ieq (Join-Path $root 'CodexSkinManager.exe')){return '请先关闭换肤管理中心，再重试安装。'}
      if($process.CommandLine -and ([string]$process.CommandLine).IndexOf(($root+'\scripts\manage-background.ps1'),[StringComparison]::OrdinalIgnoreCase) -ge 0){return '请先关闭换肤管理中心，再重试安装。'}
    }
    $nodes=@($processes|Where-Object {[string]$_.ExecutablePath -ieq $runtime})
    if(-not $nodes.Count){return $null}
    $blocked='仍有无法验证身份的进程占用安装运行环境，请退出相关程序或重启后再安装。未修改安装文件。'
    $statePath=Join-Path $root 'state.json'
    if(-not(Test-Path -LiteralPath $statePath -PathType Leaf) -or (Get-Item -LiteralPath $statePath).Length -gt 64KB){return ($blocked+' 后台身份记录不存在或超出限制。')}
    $state=[IO.File]::ReadAllText($statePath)|ConvertFrom-Json -ErrorAction Stop
    if([string]$state.nodePath -ine $runtime){return ($blocked+' 运行环境记录不一致。')}
    $records=@(
      @{Id=[int]$state.injectorPid;Started=$state.injectorStartedAt;Script=(Join-Path $root 'engine/scripts/injector.mjs');SavedScript=[string]$state.injectorPath;Flags=@('--watch')},
      @{Id=[int]$state.videoPid;Started=$state.videoStartedAt;Script=(Join-Path $root 'engine/scripts/video-server.mjs');SavedScript=[string]$state.videoScript;Flags=@('--config','--ready',(Join-Path $root 'video-theme.json'),(Join-Path $root 'video-ready.json'))}
    )
    # Validate every runtime occupant before stopping any process. A filename
    # passed as data to node -e is not an injector; require the script argv position.
    foreach($process in $nodes){
      $matches=@($records|Where-Object {$_.Id -gt 0 -and $_.Id -eq [int]$process.ProcessId})
      if($matches.Count -ne 1){return ($blocked+' 存在未记录的运行进程。')}
      $record=$matches[0]
      if(-not $record.Started -or $record.SavedScript -ine $record.Script){return ($blocked+' 脚本身份记录不完整。')}
      $exePattern='(?:"'+[regex]::Escape($runtime)+'"|'+[regex]::Escape($runtime)+')'
      $scriptPattern='(?:"'+[regex]::Escape($record.Script)+'"|'+[regex]::Escape($record.Script)+')'
      if([string]$process.CommandLine -notmatch ('(?i)^\s*'+$exePattern+'\s+'+$scriptPattern+'(?=\s|$)')){return ($blocked+' 后台脚本启动位置不一致。')}
      foreach($flag in $record.Flags){
        if([string]$process.CommandLine -notmatch ('(?i)(?:^|[\s"])'+[regex]::Escape($flag)+'(?=$|[\s"])')){return ($blocked+' 后台参数不完整。')}
      }
      $handle=Get-Process -Id ([int]$process.ProcessId) -ErrorAction SilentlyContinue
      if(-not $handle){continue}
      $handles.Add($handle)
      $started=if($record.Started -is [datetime]){$record.Started.ToUniversalTime()}else{[datetime]::Parse([string]$record.Started,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()}
      if($handle.StartTime.ToUniversalTime().Ticks -ne $started.Ticks -or $handle.Path -ine $runtime){return ($blocked+' 进程启动时间或运行文件发生变化。')}
    }
    foreach($handle in $handles){
      Stop-Process -InputObject $handle -Force -ErrorAction Stop
      if(-not $handle.WaitForExit(10000)){return '换肤后台未能退出，本次安装未替换文件。请退出相关程序后重试。'}
    }
    return Get-DynamicUpgradeBlockReason $root
  }catch{return ('无法安全检查或停止换肤后台，本次安装未替换文件。具体原因：'+$_.Exception.Message)}
  finally{foreach($handle in $handles){$handle.Dispose()}}
}

if($MyInvocation.InvocationName -ne '.'){
  $reason=Invoke-DynamicUpgradePreparation $InstallRoot
  if($ResultPath){[IO.File]::WriteAllText([IO.Path]::GetFullPath($ResultPath),[string]$reason,(New-Object Text.UTF8Encoding($false)))}
  if($reason){Write-Output $reason;exit 10}
  exit 0
}
