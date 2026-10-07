$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'scripts/install.ps1')
$temp=Join-Path ([IO.Path]::GetTempPath()) ('dynamic-legacy-test-'+[guid]::NewGuid().ToString('N'))
$legacy=Join-Path $temp 'CodexDreamSkin'
$target=Join-Path $temp 'CodexDynamicSkin'
$stage=Join-Path $target '.install-fixture'
New-Item -ItemType Directory -Path (Join-Path $legacy 'active-theme'),(Join-Path $legacy 'media\earth'),$stage -Force|Out-Null
try{
  Set-Content -LiteralPath (Join-Path $legacy 'active-theme\theme.json') -Value '{"schemaVersion":1,"id":"earth-orbit","image":"preview.jpg"}' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $legacy 'active-theme\preview.jpg') -Value 'preview' -Encoding UTF8
  $videoPath=Join-Path $legacy 'media\earth\background.mp4'
  [IO.File]::WriteAllBytes($videoPath,[byte[]](1,2,3,4,5))
  $hash=(Get-FileHash -LiteralPath $videoPath -Algorithm SHA256).Hash.ToLowerInvariant()
  [IO.File]::WriteAllText((Join-Path $legacy 'video-theme.json'),([ordered]@{
    schema='codex-dream-skin-video/1';filePath=$videoPath;expectedSize=5;expectedSha256=$hash
  }|ConvertTo-Json -Compress))
  Set-Content -LiteralPath (Join-Path $legacy 'state.json') -Value '{"injectorPid":123}'
  New-Item -ItemType Directory -Path (Join-Path $legacy 'cdp-profile')|Out-Null
  Set-Content -LiteralPath (Join-Path $legacy 'cdp-profile\lock') -Value 'do not migrate'

  $result=Copy-DynamicSkinLegacyStateToStage -LegacyRoot $legacy -InstallRoot $target -StageRoot $stage
  if(-not$result.Migrated){throw 'FAIL: valid legacy theme was not migrated'}
  if(-not(Test-Path (Join-Path $stage 'active-theme\theme.json'))){throw 'FAIL: active theme was not copied'}
  $migratedVideo=Get-Content (Join-Path $stage 'video-theme.json') -Raw|ConvertFrom-Json
  $expectedVideo=Join-Path $target 'media\earth\background.mp4'
  if([IO.Path]::GetFullPath($migratedVideo.filePath)-ine[IO.Path]::GetFullPath($expectedVideo)){throw 'FAIL: migrated video path still points at the legacy install'}
  if(-not(Test-Path (Join-Path $stage 'media\earth\background.mp4'))){throw 'FAIL: configured video was not copied'}
  if(Test-Path (Join-Path $stage 'state.json')){throw 'FAIL: stale process state was migrated'}
  if(Test-Path (Join-Path $stage 'cdp-profile')){throw 'FAIL: legacy debugging profile was migrated'}

  $occupied=Join-Path $temp 'occupied';$occupiedStage=Join-Path $occupied '.install-fixture'
  New-Item -ItemType Directory -Path (Join-Path $occupied 'active-theme'),$occupiedStage -Force|Out-Null
  $skipped=Copy-DynamicSkinLegacyStateToStage -LegacyRoot $legacy -InstallRoot $occupied -StageRoot $occupiedStage
  if($skipped.Migrated -or (Test-Path (Join-Path $occupiedStage 'active-theme'))){throw 'FAIL: existing target theme was overwritten by migration'}
  'PASS: legacy theme and video migrate without stale runtime state.'
}finally{
  if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
