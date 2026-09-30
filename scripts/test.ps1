[CmdletBinding()]
param([string]$NodeRuntimePath)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $NodeRuntimePath) { $NodeRuntimePath = Join-Path $root 'engine/runtime/node/node.exe' }
if (-not (Test-Path -LiteralPath $NodeRuntimePath -PathType Leaf)) {
  throw 'Pass -NodeRuntimePath with the pinned Node 24.19.0 executable, or build/extract the Release ZIP first.'
}
& $NodeRuntimePath --test (Join-Path $root 'tests/*.test.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Node test suite failed.' }
foreach ($test in Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter '*.ps1' -File | Sort-Object Name) {
  Write-Host ('Running ' + $test.Name)
  $arguments = @('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',$test.FullName)
  if ($test.Name -like 'install-*') { $arguments += @('-NodeRuntimePath',$NodeRuntimePath) }
  & powershell.exe @arguments
  if ($LASTEXITCODE -ne 0) { throw ('Windows test failed: ' + $test.Name) }
}
Write-Host 'All Windows and Node tests passed.'
