[CmdletBinding()]
param([switch]$Silent)
$ErrorActionPreference='Stop'

function Invoke-DynamicUninstallRestore {
  param([string]$InstallRoot,[switch]$Silent)
  # A restored manager retains theme files, but marks the appearance inactive.
  $hasTheme=(Test-Path (Join-Path $InstallRoot 'video-theme.json')) -or (Test-Path (Join-Path $InstallRoot 'active-theme'))
  $hasSkin=(Test-Path (Join-Path $InstallRoot 'state.json')) -or
    ($hasTheme -and -not (Test-Path (Join-Path $InstallRoot 'paused')))
  if(-not $hasSkin){return $true}
  if($Silent){throw '请先在换肤管理中心恢复原始外观，再执行静默卸载。'}
  Initialize-DynamicMedia -InstallRoot $InstallRoot
  if((Invoke-DynamicEngine -StateRoot $InstallRoot -Restore) -ne $true){throw '已取消恢复，卸载已停止。'}
  return $true
}

if($MyInvocation.InvocationName -ne '.'){
  try {
    . (Join-Path $PSScriptRoot 'media.ps1')
    $null=Invoke-DynamicUninstallRestore -InstallRoot (Split-Path $PSScriptRoot -Parent) -Silent:$Silent
    exit 0
  }catch{
    if(-not $Silent){Add-Type -AssemblyName PresentationFramework;[Windows.MessageBox]::Show($_.Exception.Message,'卸载未完成','OK','Warning')|Out-Null}
    exit 1
  }
}
