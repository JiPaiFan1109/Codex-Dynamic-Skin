$ErrorActionPreference='Stop'
$module=Join-Path $PSScriptRoot '../scripts/skin-manager.ps1'
if(-not(Test-Path $module)){throw 'Skin manager is not implemented.'}
. $module
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
$items=@(
  [pscustomobject]@{Id='image';Kind='Image';IsAvailable=$true},
  [pscustomobject]@{Id='video';Kind='Video';IsAvailable=$true},
  [pscustomobject]@{Id='broken';Kind='Unknown';IsAvailable=$false}
)
Assert (@(Get-DynamicVisibleWallpapers $items All).Count -eq 3) 'All filter hid a broken item'
Assert (@(Get-DynamicVisibleWallpapers $items Image).Count -eq 1) 'Static filter wrong'
Assert (@(Get-DynamicVisibleWallpapers $items Video).Count -eq 1) 'Video filter wrong'
$status=[pscustomobject]@{CurrentId='image';Paused=$false;Error=$null}
$state=Get-DynamicManagerActionState $items[0] $status $false $false
Assert ($state.Apply -and -not $state.Delete -and $state.Rename) 'Current item deletion not disabled'
$state=Get-DynamicManagerActionState $items[2] $status $false $false
Assert (-not $state.Apply -and -not $state.Rename -and $state.Delete) 'Unavailable project actions wrong'
$state=Get-DynamicManagerActionState $items[1] $status $true $false
Assert (-not $state.Import -and -not $state.Apply -and -not $state.Delete -and -not $state.Open) 'Busy state allowed mutation'
$state=Get-DynamicManagerActionState $items[1] $status $false $true
Assert ($state.Import -and -not $state.Apply -and -not $state.Open -and -not $state.Restore) 'PrepareOnly could change real app'
$window=New-DynamicSkinManagerWindow
Assert ($null -ne $window.FindName('WallpaperList') -and $null -ne $window.FindName('PreviewVideo')) 'Window controls missing'
$foreground=$window.FindName('WallpaperList').Foreground.Color
Assert ($foreground.R -gt 180 -and $foreground.G -gt 180 -and $foreground.B -gt 180) 'Card labels have unreadable default foreground'
$window.Close()
Add-Type -AssemblyName System.Drawing
$customIcon=Join-Path ([IO.Path]::GetTempPath()) ('manager-icon-'+[guid]::NewGuid().ToString('N')+'.ico')
try{
  $iconStream=[IO.File]::Create($customIcon)
  try{[Drawing.SystemIcons]::Information.Save($iconStream)}finally{$iconStream.Dispose()}
  $customWindow=New-DynamicSkinManagerWindow -IconPath $customIcon
  try{
    Assert ($null -ne $customWindow.Icon -and $customWindow.Icon.Width -gt 0) 'Manager window did not load the custom icon'
    Remove-Item -LiteralPath $customIcon -Force
  }finally{$customWindow.Close()}
}finally{if(Test-Path -LiteralPath $customIcon){Remove-Item -LiteralPath $customIcon -Force}}
'PASS: filters, unavailable/current/busy/PrepareOnly actions and STA XAML instantiation'
