$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/media.ps1')
Initialize-DynamicMedia -InstallRoot (Join-Path $PSScriptRoot '..')
$libraryScript = Join-Path $PSScriptRoot '../scripts/wallpaper-library.ps1'
if (-not (Test-Path $libraryScript)) { throw 'Wallpaper library is not implemented.' }
. $libraryScript
function Assert($Condition,$Message) { if (-not $Condition) { throw $Message } }
function Reject([scriptblock]$Action) { $rejected=$false; try { & $Action } catch { $rejected=$true }; Assert $rejected 'Unsafe operation was accepted' }
$root = Join-Path ([IO.Path]::GetTempPath()) ('wallpaper-library-' + [guid]::NewGuid().ToString('N'))
try {
  $ids = @('11111111111111111111111111111111','22222222222222222222222222222222','33333333333333333333333333333333','44444444444444444444444444444444')
  foreach ($id in $ids) {
    $dir = Join-Path $root "wallpaper-library/items/$id"
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $dir 'wallpaper.png'),[byte[]]@(1,2,3))
    $metadata = @{schema='codex-dynamic-skin-wallpaper/1';id=$id;name='中文壁纸';kind='Image';mediaFile='wallpaper.png';thumbnailFile='thumbnail.png';size=3;sha256=(Get-FileHash (Join-Path $dir 'wallpaper.png')).Hash.ToLowerInvariant();importedAtUtc='2026-10-11T00:00:00Z'}
    [IO.File]::WriteAllText((Join-Path $dir 'item.json'),($metadata | ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
  }
  [IO.File]::WriteAllText((Join-Path $root "wallpaper-library/items/$($ids[2])/item.json"),'{broken')
  Remove-Item -LiteralPath (Join-Path $root "wallpaper-library/items/$($ids[3])/wallpaper.png")
  $items = @(Get-DynamicWallpaperItems $root)
  Assert ($items.Count -eq 4) 'Corrupt item hid other items'
  Assert (@($items | Where-Object IsAvailable).Count -eq 2) 'Missing files or malformed metadata accepted'
  Assert (@(Get-DynamicWallpaperItems $root).Count -eq 4) 'Library did not persist'
  $old = Get-DynamicWallpaperItem $root $ids[0]
  $renamed = Rename-DynamicWallpaper $root $ids[0] ('星空' * 50)
  Assert ($renamed.Name.Length -eq 100 -and $renamed.MediaPath -eq $old.MediaPath -and $renamed.Sha256 -eq $old.Sha256) 'Rename changed media'
  Reject { Rename-DynamicWallpaper $root $ids[0] ('星' * 121) }
  Reject { Rename-DynamicWallpaper $root $ids[0] "bad`nname" }
  Reject { Get-DynamicWallpaperItem $root '../escape' }
  $path = Join-Path $root "wallpaper-library/items/$($ids[1])/item.json"
  $original = [IO.File]::ReadAllText($path)
  foreach ($unsafe in @('../other.png','C:\other.png','sub/file.png')) {
    $entry = $original | ConvertFrom-Json; $entry.mediaFile=$unsafe
    [IO.File]::WriteAllText($path,($entry | ConvertTo-Json))
    Assert (-not (Get-DynamicWallpaperItem $root $ids[1]).IsAvailable) 'Unsafe media path accepted'
  }
  [IO.File]::WriteAllText($path,$original.Replace('codex-dynamic-skin-wallpaper/1','unknown/1'))
  Assert (-not (Get-DynamicWallpaperItem $root $ids[1]).IsAvailable) 'Unknown schema accepted'
  $writer=${function:Write-DreamSkinUtf8FileAtomically}
  try{
    function Write-DreamSkinUtf8FileAtomically {param($Path,$Content);throw 'simulated metadata write failure'}
    Reject {Rename-DynamicWallpaper $root $ids[0] 'new name'}
  }finally{Set-Item Function:Write-DreamSkinUtf8FileAtomically $writer}
  Assert ((Get-DynamicWallpaperItem $root $ids[0]).Name -eq $renamed.Name) 'Failed rename lost previous metadata'
  $outside=Join-Path $root 'wallpaper-library-sibling'
  [IO.Directory]::CreateDirectory($outside)|Out-Null
  [IO.File]::WriteAllText((Join-Path $outside 'keep.txt'),'untouched')
  $junction=Join-Path $root 'wallpaper-library/items/55555555555555555555555555555555'
  New-Item -ItemType Junction -Path $junction -Value $outside|Out-Null
  try{
    $unsafe=@(Get-DynamicWallpaperItems $root|Where-Object Id -eq '55555555555555555555555555555555')
    Assert ($unsafe.Count -eq 1 -and -not $unsafe[0].IsAvailable) 'Library followed an external junction'
    Reject {Rename-DynamicWallpaper $root '55555555555555555555555555555555' 'escape'}
    Assert ([IO.File]::ReadAllText((Join-Path $outside 'keep.txt')) -eq 'untouched') 'Sibling directory was modified'
  }finally{[IO.Directory]::Delete($junction)}
  'PASS: persistent metadata, corruption isolation, Chinese rename, path and name validation'
} finally { if(Test-Path -LiteralPath $root){ Remove-Item -LiteralPath $root -Recurse -Force } }
