$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/skin-manager.ps1')
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
$window=New-DynamicSkinManagerWindow
try{
  $preview=$window.FindName('GalleryPreview')
  $details=$window.FindName('GalleryDetails')
  Assert ($null -ne $preview -and $null -ne $details) 'Gallery preview/details layout is missing'
  $window.FindName('PlayButton').Visibility='Visible'
  $window.ShowActivated=$false;$window.Show()
  foreach($size in @(@(1180,860),@(960,720))){
    $window.Width=$size[0];$window.Height=$size[1];$window.UpdateLayout()
    $origin=New-Object Windows.Point 0,0
    $previewPosition=$preview.TranslatePoint($origin,$window.Content)
    $detailsPosition=$details.TranslatePoint($origin,$window.Content)
    $listPosition=$window.FindName('WallpaperList').TranslatePoint($origin,$window.Content)
    Assert ($preview.ActualWidth -gt $details.ActualWidth*1.4) 'Preview does not dominate gallery'
    Assert ($detailsPosition.X -gt $previewPosition.X+$preview.ActualWidth) 'Details overlap large preview'
    Assert ($listPosition.Y -ge $previewPosition.Y+$preview.ActualHeight) 'Wallpaper library is not below preview'
    foreach($name in @('ImportButton','ApplyButton','PlayButton','OpenButton','RestoreButton')){
      $control=$window.FindName($name);$position=$control.TranslatePoint($origin,$window.Content)
      Assert ($control.ActualWidth -gt 0 -and $position.X -ge 0 -and $position.X+$control.ActualWidth -le $window.Content.ActualWidth+1) "Action is clipped horizontally: $name"
      Assert ($position.Y -ge 0 -and $position.Y+$control.ActualHeight -le $window.Content.ActualHeight+1) "Action is clipped vertically: $name"
    }
  }
  foreach($name in @('SelectedFormat','SelectedSize','SelectedImportedAt','SelectedStatus')){Assert ($null -ne $window.FindName($name)) "Gallery detail is missing: $name"}
  'PASS: gallery dominates preview, details align, library stays below, actions fit at 1180x860 and 960x720'
}finally{$window.Close()}
