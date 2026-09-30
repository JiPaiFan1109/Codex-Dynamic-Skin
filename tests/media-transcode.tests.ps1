$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/media.ps1')
Initialize-DynamicMedia -InstallRoot (Join-Path $PSScriptRoot '..')
$root = Join-Path ([IO.Path]::GetTempPath()) ('dynamic-transcode-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
try {
  $prepared = New-DynamicPreparedMedia -SourcePath (Join-Path $PSScriptRoot '../docs/media/earth-demo.mp4') -Kind Video -StateRoot $root
  $file = Wait-DynamicWinRT ([Windows.Storage.StorageFile]::GetFileFromPathAsync($prepared.Path)) ([Windows.Storage.StorageFile])
  $props = Wait-DynamicWinRT ($file.Properties.GetVideoPropertiesAsync()) ([Windows.Storage.FileProperties.VideoProperties,Windows.Storage,ContentType=WindowsRuntime])
  if ($props.Width -gt 1920 -or $props.Height -gt 1080 -or $props.Duration.TotalSeconds -lt 7) { throw 'Invalid output dimensions or duration' }
  # Inspect MP4 track handler boxes without requiring any external media binary.
  $bytes = [IO.File]::ReadAllBytes($prepared.Path)
  $ascii = [Text.Encoding]::ASCII.GetString($bytes)
  if ($ascii.Contains('soun')) { throw 'Audio track remains in output' }
  if (-not $ascii.Contains('avc1')) { throw 'Output is not H.264' }
  "PASS: real MediaTranscoder, $($props.Width)x$($props.Height), $($props.Duration.TotalSeconds)s, $($prepared.Size) bytes, H.264, no audio"
} finally {
  if ([IO.Path]::GetFullPath($root).StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $root -Recurse -Force }
}
