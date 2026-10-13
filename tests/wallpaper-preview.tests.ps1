$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/media.ps1')
Initialize-DynamicMedia -InstallRoot (Join-Path $PSScriptRoot '..')
$module=Join-Path $PSScriptRoot '../scripts/wallpaper-preview.ps1'
if(-not(Test-Path $module)){throw 'Wallpaper preview is not implemented.'}
. $module
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
$root=Join-Path ([IO.Path]::GetTempPath()) ('wallpaper-preview-'+[guid]::NewGuid().ToString('N'))
try{
  [IO.Directory]::CreateDirectory($root)|Out-Null
  Add-Type -AssemblyName System.Drawing
  $image=Join-Path $root 'wide.png';$bitmap=New-Object Drawing.Bitmap 1024,512
  try{$bitmap.Save($image,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
  $output=Join-Path $root 'thumbnail.png'
  Assert (New-DynamicWallpaperThumbnail $image Image $output) 'Image thumbnail failed'
  $bitmap=[Drawing.Image]::FromFile($output)
  try{Assert ($bitmap.Width -eq 480 -and $bitmap.Height -eq 240) 'Thumbnail size or aspect ratio wrong'}finally{$bitmap.Dispose()}
  $invalid=Join-Path $root 'invalid.png';[IO.File]::WriteAllText($invalid,'bad')
  Assert (-not (New-DynamicWallpaperThumbnail $invalid Image (Join-Path $root 'bad-thumbnail.png'))) 'Invalid preview did not report failure'
  Assert (-not (Test-Path (Join-Path $root 'bad-thumbnail.png'))) 'Failed thumbnail left fake output'
  $video=Join-Path $PSScriptRoot '../docs/media/earth-demo.mp4'
  $videoThumb=Join-Path $root 'video-thumbnail.png'
  Assert (New-DynamicWallpaperThumbnail $video Video $videoThumb) 'Real H.264 thumbnail failed on this Windows host'
  $bitmap=[Drawing.Image]::FromFile($videoThumb)
  try{Assert ($bitmap.Width -le 480 -and $bitmap.Height -le 480 -and $bitmap.Width -gt 0) 'Video thumbnail wrong dimensions'}finally{$bitmap.Dispose()}
  'PASS: proportionate PNG thumbnail, real video thumbnail, decoder failure fallback and file release'
}finally{if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}}
