[CmdletBinding()]
param([string]$NodeRuntimePath,[string]$IsccPath,[string]$OutputDirectory)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if(-not $OutputDirectory){$OutputDirectory=Join-Path $repo 'dist'}
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
if((Test-Path (Join-Path $OutputDirectory 'app-package')) -or (Test-Path (Join-Path $OutputDirectory 'Codex-Skin-Manager-Setup.exe'))){throw 'Use an empty output directory to avoid replacing an existing build.'}
if(-not $IsccPath){
  $IsccPath=@((Join-Path $repo '.tools/inno/compiler/ISCC.exe'),"${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe","$env:ProgramFiles/Inno Setup 7/ISCC.exe")|Where-Object{Test-Path -LiteralPath $_}|Select-Object -First 1
}
if(-not $IsccPath){throw 'Install Inno Setup and pass -IsccPath with ISCC.exe.'}
$version=(Get-Content (Join-Path $repo 'VERSION') -Raw).Trim()
$buildRoot=Join-Path ([IO.Path]::GetTempPath()) ('skin-app-build-'+[guid]::NewGuid().ToString('N'))
New-Item $buildRoot -ItemType Directory|Out-Null
try {
  & (Join-Path $PSScriptRoot 'build-release.ps1') -NodeRuntimePath $NodeRuntimePath -OutputDirectory $buildRoot|Write-Host
  $package=Join-Path $buildRoot 'package'
  Expand-Archive -LiteralPath (Join-Path $buildRoot "Codex-Dynamic-Skin-$version-windows-x64.zip") -DestinationPath $package
  New-Item $OutputDirectory -ItemType Directory -Force|Out-Null
  & $IsccPath ("/DSourceRoot=$package") ("/DAppVersion=$version") ("/O$OutputDirectory") (Join-Path $repo 'installer/windows.iss')
  if($LASTEXITCODE -ne 0){throw 'Windows setup compilation failed.'}
  $setup=Join-Path $OutputDirectory 'Codex-Skin-Manager-Setup.exe'
  $sum=(Get-FileHash $setup -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($setup)
  [IO.File]::WriteAllText(($setup+'.sha256'),$sum+"`n",(New-Object Text.UTF8Encoding($false)))
  # Keep an inspectable copy of exactly the files used to compile this installer.
  $audit=Join-Path $OutputDirectory 'app-package'
  if(Test-Path $audit){throw 'app-package already exists; use an empty output directory.'}
  Copy-Item -LiteralPath $package -Destination $audit -Recurse
  Copy-Item -LiteralPath (Join-Path $buildRoot "Codex-Dynamic-Skin-$version-windows-x64.zip") -Destination $OutputDirectory
  Copy-Item -LiteralPath (Join-Path $buildRoot "Codex-Dynamic-Skin-$version-windows-x64.zip.sha256") -Destination $OutputDirectory
  Write-Output $setup
  Write-Output $sum
}finally{
  if([IO.Path]::GetFullPath($buildRoot).StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)){
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
  }
}
