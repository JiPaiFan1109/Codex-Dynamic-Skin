$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manager = Join-Path $repo 'scripts/manage-background.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('dynamic-cli-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
try {
  & $manager -InstallRoot $repo -StateRoot $root -VideoPath (Join-Path $repo 'docs/media/earth-demo.mp4') -PrepareOnly | Out-Null
  if (Test-Path (Join-Path $root 'active-theme')) { throw 'PrepareOnly changed configuration' }
  if (@(Get-ChildItem -LiteralPath $root -Filter background.mp4 -Recurse).Count -ne 1) { throw 'CLI did not prepare video' }
  try { & $manager -InstallRoot $repo -StateRoot $root -ImagePath 'missing.png'; throw 'Expected rejection' } catch { if ($_.Exception.Message -eq 'Expected rejection') { throw } }
  'PASS: CLI preparation and custom-root application rejection'
} finally {
  if ([IO.Path]::GetFullPath($root).StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $root -Recurse -Force }
}
