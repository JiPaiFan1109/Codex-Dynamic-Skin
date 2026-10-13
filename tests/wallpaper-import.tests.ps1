$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/media.ps1')
Initialize-DynamicMedia -InstallRoot (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot '../scripts/wallpaper-library.ps1')
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
if(-not (Get-Command Import-DynamicWallpaper -ErrorAction SilentlyContinue)){throw 'Wallpaper import is not implemented.'}
$root=Join-Path ([IO.Path]::GetTempPath()) ('wallpaper-import-'+[guid]::NewGuid().ToString('N'))
try {
  [IO.Directory]::CreateDirectory($root)|Out-Null
  Add-Type -AssemblyName System.Drawing
  $source=Join-Path $root 'source.png'
  $bitmap=New-Object Drawing.Bitmap 16,8
  try{$bitmap.Save($source,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
  $state=Join-Path $root 'state'
  $first=Import-DynamicWallpaper $source Image $state
  $second=Import-DynamicWallpaper $source Image $state
  Assert ($first.Item.Id -eq $second.Item.Id -and $second.AlreadyExists) 'Same content did not deduplicate'
  Assert (-not (Test-Path (Join-Path $state 'active-theme')) -and -not (Test-Path (Join-Path $state 'video-theme.json'))) 'Import applied background'
  $bitmap=New-Object Drawing.Bitmap 8,16
  try{$bitmap.Save($source,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
  $third=Import-DynamicWallpaper $source Image $state
  Assert ($third.Item.Id -ne $first.Item.Id) 'Different content with same name was lost'
  Remove-Item -LiteralPath $source
  Assert ((Get-DynamicWallpaperItem $state $first.Item.Id).IsAvailable) 'Library depended on original file'
  Assert (@(Get-DynamicWallpaperItems $state).Count -eq 2) 'Library project count wrong'
  $bad=Join-Path $root 'bad.png';[IO.File]::WriteAllText($bad,'bad')
  $failed=$false;try{Import-DynamicWallpaper $bad Image $state}catch{$failed=$true}
  Assert $failed 'Invalid image imported'
  Assert (@(Get-ChildItem (Join-Path $state 'wallpaper-library/staging') -Force).Count -eq 0) 'Failed import leaked staging files'
  Assert (@(Get-DynamicWallpaperItems $state).Count -eq 2) 'Failed import damaged library'
  $newImage=Join-Path $root 'commit-failure.png';$bitmap=New-Object Drawing.Bitmap 24,20
  try{$bitmap.Save($newImage,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
  $writer=${function:Write-DreamSkinUtf8FileAtomically}
  try{
    function Write-DreamSkinUtf8FileAtomically {param($Path,$Content);throw 'simulated commit failure'}
    $failed=$false;try{Import-DynamicWallpaper $newImage Image $state}catch{$failed=$true}
    Assert $failed 'Commit failure was hidden'
  }finally{Set-Item Function:Write-DreamSkinUtf8FileAtomically $writer}
  Assert (@(Get-DynamicWallpaperItems $state).Count -eq 2 -and @(Get-ChildItem (Join-Path $state 'wallpaper-library/staging') -Force).Count -eq 0) 'Commit failure damaged library or leaked staging'
  $sourceVideo=Join-Path $root 'sample.mp4';[IO.File]::WriteAllBytes($sourceVideo,[byte[]]@(1,2,3))
  $original=${function:Convert-DynamicVideo}
  try {
    function Convert-DynamicVideo {param($SourcePath,$TargetPath,$Report);throw 'simulated decode failure'}
    $failed=$false;try{Import-DynamicWallpaper $sourceVideo Video $state}catch{$failed=$true}
    Assert $failed 'Conversion failure was hidden'
    Assert (@(Get-ChildItem (Join-Path $state 'wallpaper-library/staging') -Force).Count -eq 0) 'Conversion failure leaked temporary files'
    function Convert-DynamicVideo {param($SourcePath,$TargetPath,$Report);[IO.File]::WriteAllBytes($TargetPath,[byte[]]@(4,5,6))}
    $video=Import-DynamicWallpaper $sourceVideo Video $state
    Assert ($video.Item.Kind -eq 'Video' -and $video.Item.Size -eq 3) 'Converted video not saved'
    Assert (@(Get-ChildItem (Split-Path $video.Item.MediaPath) -Filter 'source*').Count -eq 0) 'Original video retained'
  } finally {Set-Item Function:Convert-DynamicVideo $original}
  'PASS: durable imports, content deduplication, source independence, import isolation and failure cleanup'
} finally {if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}}
