[CmdletBinding()]
param([string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'CodexDynamicSkin'))
$ErrorActionPreference='Stop'

function Get-DynamicUpgradeBlockReason {
  param([string]$InstallRoot)
  $root=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
  $runtime=Join-Path $root 'engine/runtime/node/node.exe'
  try {
    $processes=@(Get-CimInstance Win32_Process -Filter "Name='node.exe' OR Name='powershell.exe' OR Name='CodexSkinManager.exe'")
    foreach($process in $processes){
      if([string]$process.ExecutablePath -ieq $runtime){return '换肤后台仍在运行，请先恢复原始外观，再关闭管理中心并重试安装。'}
      if([string]$process.ExecutablePath -ieq (Join-Path $root 'CodexSkinManager.exe')){return '请先关闭换肤管理中心，再重试安装。'}
      if($process.CommandLine -and ([string]$process.CommandLine).IndexOf(($root+'\scripts\manage-background.ps1'),[StringComparison]::OrdinalIgnoreCase) -ge 0){return '请先关闭换肤管理中心，再重试安装。'}
    }
  }catch{return '无法检查换肤后台是否已经退出，本次安装不会替换文件。请稍后重试。'}
  return $null
}

if($MyInvocation.InvocationName -ne '.'){
  $reason=Get-DynamicUpgradeBlockReason $InstallRoot
  if($reason){Write-Output $reason;exit 10}
  exit 0
}
