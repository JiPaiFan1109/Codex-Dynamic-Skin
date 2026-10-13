$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'engine/scripts/launch-dream-skin.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dream-skin-diagnostics-' + [guid]::NewGuid().ToString('N'))
$scripts = Join-Path $fixture 'engine/scripts'
[void][IO.Directory]::CreateDirectory($scripts)
try {
  # A deliberately failing child exercises the real detached launcher and redirection.
  "Write-Host 'diagnostic-start-marker'; throw 'diagnostic-failure-marker'" | Set-Content (Join-Path $scripts 'start-dream-skin.ps1') -Encoding UTF8
  Start-DynamicFullLauncher -ScriptRoot $scripts
  Start-DynamicFullLauncher -ScriptRoot $scripts
  $deadline = (Get-Date).AddSeconds(8)
  do {
    Start-Sleep -Milliseconds 200
    $errors = @(Get-ChildItem (Join-Path $fixture 'logs') -Filter '*-error.log' -ErrorAction SilentlyContinue)
    $complete = @($errors | Where-Object { (Get-Content $_.FullName -Raw) -match 'diagnostic-failure-marker' })
  } while ($complete.Count -lt 2 -and (Get-Date) -lt $deadline)
  if ($complete.Count -ne 2) { throw 'FAIL: consecutive launches must retain separate child failure logs' }
  $outputs = @(Get-ChildItem (Join-Path $fixture 'logs') -Filter '*-output.log')
  if (@($outputs | Where-Object { (Get-Content $_.FullName -Raw) -match 'diagnostic-start-marker' }).Count -ne 2) {
    throw 'FAIL: hidden startup output was not preserved'
  }
  'PASS: independent startup output and failure logs survive consecutive hidden launches.'
} finally {
  # The generated fixture is the only recursive cleanup target.
  $resolved = [IO.Path]::GetFullPath($fixture)
  if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid fixture path' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
