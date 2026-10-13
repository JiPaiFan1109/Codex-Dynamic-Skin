$ErrorActionPreference='Stop'
$path=Join-Path $PSScriptRoot '../scripts/uninstall-app.ps1'
if(-not(Test-Path $path)){throw 'Application uninstall restore guard is missing'}
. $path
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
$root=Join-Path ([IO.Path]::GetTempPath()) ('skin-uninstall-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item $root -ItemType Directory|Out-Null
  Assert (Invoke-DynamicUninstallRestore -InstallRoot $root -Silent) 'Unused installation should uninstall without prompting'
  Set-Content (Join-Path $root 'state.json') '{}'
  $rejected=$false
  try{Invoke-DynamicUninstallRestore -InstallRoot $root -Silent}catch{$rejected=$true}
  Assert $rejected 'Silent uninstall must refuse an active skin instead of closing Codex'
  Assert (Test-Path (Join-Path $root 'state.json')) 'Refused uninstall removed state'
  function Initialize-DynamicMedia {}
  function Invoke-DynamicEngine { return $false }
  $rejected=$false
  $cancelled=$false
  try{Invoke-DynamicUninstallRestore -InstallRoot $root}catch{$rejected=$true;$cancelled=$_.Exception -is [OperationCanceledException]}
  Assert $rejected 'Cancelled restore must abort uninstall'
  Assert $cancelled 'User cancellation must not be reported as an uninstall error'
  function Invoke-DynamicEngine { return $true }
  Assert (Invoke-DynamicUninstallRestore -InstallRoot $root) 'Successful restore did not permit uninstall'
  Remove-Item -LiteralPath (Join-Path $root 'state.json')
  New-Item (Join-Path $root 'active-theme') -ItemType Directory|Out-Null
  Set-Content (Join-Path $root 'paused') 'true'
  Assert (Invoke-DynamicUninstallRestore -InstallRoot $root -Silent) 'Restored appearance with retained theme files should allow silent uninstall'
}finally{if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}}
'PASS uninstall no-state, silent guard, cancellation and successful restore'
