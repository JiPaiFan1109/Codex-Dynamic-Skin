[CmdletBinding()]
param([string]$PackagePath,[string]$IsccPath)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if(-not $PackagePath){$PackagePath=Join-Path $repo 'dist/app-package'}
if(-not $IsccPath){$IsccPath=Join-Path $repo '.tools/inno/compiler/ISCC.exe'}
$root=Join-Path ([IO.Path]::GetTempPath()) ('skin-setup-test-'+[guid]::NewGuid().ToString('N'))
$installed=Join-Path $root '中文安装目录'
New-Item $root -ItemType Directory|Out-Null
$uninstalled=$false
function Run-Setup($Path,$Arguments){
  $process=Start-Process -FilePath $Path -ArgumentList $Arguments -WindowStyle Hidden -PassThru
  $process.WaitForExit()
  if($process.ExitCode -ne 0){throw "Setup process failed: $($process.ExitCode)"}
}
try{
  $version=(Get-Content (Join-Path $PackagePath 'VERSION') -Raw).Trim()
  & $IsccPath /Q ("/DSourceRoot=$PackagePath") ("/DAppVersion=$version") ("/DTestInstallRoot=$installed") ("/O$root") (Join-Path $PSScriptRoot 'windows.iss')
  if($LASTEXITCODE -ne 0){throw 'Isolated setup compilation failed'}
  $setup=Join-Path $root 'Codex-Skin-Manager-Setup.exe'
  Run-Setup $setup @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="'+(Join-Path $root 'install.log')+'"'))
  foreach($name in @('CodexSkinManager.exe','engine/runtime/node/node.exe','engine/launcher/CodexDynamicSkinLauncher.exe','appearance/skin-manager.ico','scripts/skin-manager.xaml','unins000.exe')){
    if(-not(Test-Path (Join-Path $installed $name))){throw "Installed application missing $name"}
  }
  # The installed files must be the bytes in the audited production payload.
  foreach($item in Get-ChildItem $installed -Recurse -File|Where-Object Name -NotLike 'unins*'){
    $relative=$item.FullName.Substring($installed.Length+1)
    if((Get-FileHash $item.FullName).Hash -ne (Get-FileHash (Join-Path $PackagePath $relative)).Hash){throw "Installed file differs: $relative"}
  }
  # Exercise the actual installed EXE and its hidden PowerShell child, not just the XAML loader.
  $manager=$null;$child=$null
  try{
    $manager=Start-Process -FilePath (Join-Path $installed 'CodexSkinManager.exe') -ArgumentList '--prepare-only' -WindowStyle Hidden -PassThru
    $deadline=[datetime]::UtcNow.AddSeconds(30)
    do{
      Start-Sleep -Milliseconds 200
      $childInfo=Get-CimInstance Win32_Process -Filter ("ParentProcessId="+$manager.Id+" AND Name='powershell.exe'")|Select-Object -First 1
      if($childInfo){$child=Get-Process -Id $childInfo.ProcessId -ErrorAction SilentlyContinue}
      if($manager.HasExited){throw 'Installed application exited before opening its manager window'}
    }while(($null -eq $child -or $child.MainWindowTitle -ne 'Codex 换肤管理中心') -and [datetime]::UtcNow -lt $deadline)
    if($null -eq $child -or $child.MainWindowTitle -ne 'Codex 换肤管理中心'){throw 'Installed application did not open the manager window'}
    # Refresh/import startup can be busy briefly; Closing intentionally refuses during work.
    do{
      $null=$child.CloseMainWindow()
      Start-Sleep -Milliseconds 300
      $manager.Refresh();$child.Refresh()
    }while(-not $manager.HasExited -and [datetime]::UtcNow -lt $deadline)
    if(-not $manager.HasExited -or $manager.ExitCode -ne 0){throw 'Installed manager failed to close successfully'}
    'PASS installed EXE launches the real WPF manager and exits cleanly'
  }finally{
    if($child -and -not $child.HasExited){Stop-Process -Id $child.Id -Force}
    if($manager -and -not $manager.HasExited){Stop-Process -Id $manager.Id -Force}
  }
  New-Item (Join-Path $installed 'wallpaper-library') -ItemType Directory|Out-Null
  $kept=Join-Path $installed 'wallpaper-library/user-image.txt'
  Set-Content $kept 'keep my wallpaper'
  $obsolete=@('engine/assets/dream-skin.css','engine/assets/theme-package-validator.mjs','engine/scripts/tray-dream-skin.ps1')
  foreach($relative in $obsolete){Set-Content (Join-Path $installed $relative) 'obsolete upstream file'}
  Run-Setup $setup @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
  foreach($relative in $obsolete){if(Test-Path (Join-Path $installed $relative)){throw "Upgrade left an obsolete file: $relative"}}
  if((Get-Content $kept) -ne 'keep my wallpaper'){throw 'Upgrade destroyed wallpaper library'}
  Run-Setup (Join-Path $installed 'unins000.exe') @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
  $uninstalled=$true
  # The uninstall loader exits before its temporary worker removes the original EXE.
  $deadline=[datetime]::UtcNow.AddSeconds(15)
  while((Test-Path (Join-Path $installed 'unins000.exe')) -and [datetime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 150}
  if(Test-Path (Join-Path $installed 'CodexSkinManager.exe')){throw 'Uninstaller left the application executable'}
  if((Get-Content $kept) -ne 'keep my wallpaper'){throw 'Uninstaller destroyed wallpaper library'}
  'PASS real setup extraction with Chinese paths, payload hashes, upgrade preservation and uninstall preservation'
}finally{
  if(-not $uninstalled -and (Test-Path (Join-Path $installed 'unins000.exe'))){
    Run-Setup (Join-Path $installed 'unins000.exe') @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
  }
  if([IO.Path]::GetFullPath($root).StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)){
    Remove-Item -LiteralPath $root -Recurse -Force
  }
}
