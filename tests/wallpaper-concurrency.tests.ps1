$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $repo 'scripts/media.ps1');Initialize-DynamicMedia -InstallRoot $repo
. (Join-Path $repo 'scripts/wallpaper-library.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('wallpaper-concurrency-'+[guid]::NewGuid().ToString('N'))
$processes=@()
try{
  [IO.Directory]::CreateDirectory($root)|Out-Null
  Add-Type -AssemblyName System.Drawing
  $source=Join-Path $root 'source.png';$bitmap=New-Object Drawing.Bitmap 8,8
  try{$bitmap.Save($source,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
  $item=(Import-DynamicWallpaper $source Image $root).Item
  $child=Join-Path $root 'worker.ps1'
  [IO.File]::WriteAllText($child,@'
param($Repo,$Root,$Id,$Mode,$Source)
$ErrorActionPreference='Stop'
. (Join-Path $Repo 'scripts/media.ps1');Initialize-DynamicMedia -InstallRoot $Repo
. (Join-Path $Repo 'scripts/wallpaper-library.ps1')
if($Mode -eq 'Import'){
  Import-DynamicWallpaper $Source Image $Root|Out-Null
}elseif($Mode -eq 'Apply'){
  Use-DynamicWallpaper $Root $Id {[IO.File]::WriteAllText((Join-Path $Root 'locked'),'yes');Start-Sleep -Seconds 2}|Out-Null
}else{
  try{Remove-DynamicWallpaper $Root $Id;[IO.File]::WriteAllText((Join-Path $Root 'result'),'deleted')}
  catch{[IO.File]::WriteAllText((Join-Path $Root 'result'),'blocked')}
}
'@,(New-Object Text.UTF8Encoding($true)))
  foreach($mode in @('Apply','Delete')){
    if($mode -eq 'Delete'){
      $deadline=[datetime]::UtcNow.AddSeconds(20)
      while(-not(Test-Path (Join-Path $root 'locked'))){if([datetime]::UtcNow -gt $deadline){throw 'Apply never acquired lock'};Start-Sleep -Milliseconds 100}
    }
    $arguments=@('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(ConvertTo-DreamSkinProcessArgument $child),'-Repo',(ConvertTo-DreamSkinProcessArgument $repo),'-Root',(ConvertTo-DreamSkinProcessArgument $root),'-Id',$item.Id,'-Mode',$mode)
    $processes+=Start-Process powershell.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
  }
  foreach($process in $processes){if(-not $process.WaitForExit(30000)){throw 'Concurrent operation timed out'};if($process.ExitCode -ne 0){throw 'Concurrent worker failed'}}
  if([IO.File]::ReadAllText((Join-Path $root 'result')) -ne 'blocked' -or -not(Test-Path -LiteralPath $item.MediaPath)){throw 'Concurrent deletion removed applying wallpaper'}
  $dedup=Join-Path $root 'concurrent-imports'
  for($attempt=0;$attempt -lt 2;$attempt++){
    $arguments=@('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(ConvertTo-DreamSkinProcessArgument $child),'-Repo',(ConvertTo-DreamSkinProcessArgument $repo),'-Root',(ConvertTo-DreamSkinProcessArgument $dedup),'-Mode','Import','-Source',(ConvertTo-DreamSkinProcessArgument $source))
    $processes+=Start-Process powershell.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
  }
  foreach($process in $processes){if(-not $process.WaitForExit(30000)){throw 'Concurrent import timed out'};if($process.ExitCode -ne 0){throw 'Concurrent import worker failed'}}
  if(@(Get-DynamicWallpaperItems $dedup).Count -ne 1){throw 'Concurrent imports saved duplicate content'}
  'PASS: two processes serialize apply/delete and recheck current selection after lock acquisition'
}finally{
  foreach($process in $processes){if(-not $process.HasExited){$process.Kill();$process.WaitForExit()};$process.Dispose()}
  if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
