$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'scripts/media.ps1');Initialize-DynamicMedia -InstallRoot $repo
function Assert($Condition,$Message){if(-not $Condition){throw $Message}}
foreach($name in @('Install-DreamSkinRuntimeEngine','Stop-DreamSkinTrayProcess','Resolve-DreamSkinCommunityApplyUri','Import-DreamSkinThemeZip','Use-DreamSkinSavedTheme')){
  Assert (-not(Get-Command $name -ErrorAction SilentlyContinue)) ('Unused upstream feature remains: '+$name)
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('skin-seeding-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item (Join-Path $root 'themes/preset-romantic-rose') -ItemType Directory -Force|Out-Null
  Set-Content (Join-Path $root 'themes/preset-romantic-rose/user-owned.txt') 'preserve'
  $paths=Initialize-DreamSkinThemeStore -SkillRoot (Join-Path $repo 'engine') -StateRoot $root
  Assert (Test-Path (Join-Path $root 'themes/preset-romantic-rose/user-owned.txt')) 'Startup deleted an unrelated legacy theme directory'
  Assert (-not(Test-Path (Join-Path $root 'themes/preset-neutral'))) 'Startup still seeds the unused saved-theme picker'
  Assert ((Read-DreamSkinTheme -ThemeDirectory $paths.Active).Theme.id -eq 'preset-neutral') 'Neutral default did not initialize'
}finally{if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}}
'PASS no unused upstream functions, no preset seeding and no unsolicited deletion'
