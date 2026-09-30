[CmdletBinding(DefaultParameterSetName='Gui')]
param(
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexDynamicSkin'),
  [string]$StateRoot,
  [Parameter(ParameterSetName='Image', Mandatory)][string]$ImagePath,
  [Parameter(ParameterSetName='Video', Mandatory)][string]$VideoPath,
  [switch]$PrepareOnly
)
$ErrorActionPreference = 'Stop'
if (-not $StateRoot) { $StateRoot = $InstallRoot }
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
$StateRoot = [IO.Path]::GetFullPath($StateRoot).TrimEnd('\')
$defaultRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'CodexDynamicSkin')).TrimEnd('\')
if (-not $PrepareOnly -and ($InstallRoot -ine $defaultRoot -or $StateRoot -ine $defaultRoot)) { throw '自定义目录仅支持 -PrepareOnly，不能修改或启动真实 Codex。' }
. (Join-Path $PSScriptRoot 'media.ps1')
Initialize-DynamicMedia -InstallRoot $InstallRoot

function Invoke-SelectedMedia {
  param([string]$Path, [string]$Kind, [scriptblock]$Report)
  $prepared = New-DynamicPreparedMedia -SourcePath $Path -Kind $Kind -StateRoot $StateRoot -Report $Report
  if ($PrepareOnly) { return $prepared }
  Set-DynamicBackground -Prepared $prepared -StateRoot $StateRoot -Apply { Invoke-DynamicEngine -StateRoot $StateRoot }
}
if ($ImagePath -or $VideoPath) {
  if ($ImagePath) { Invoke-SelectedMedia $ImagePath Image } else { Invoke-SelectedMedia $VideoPath Video }
  return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = 'Codex 动态皮肤'; $form.ClientSize = New-Object Drawing.Size(520,265)
$form.StartPosition = 'CenterScreen'; $form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false
$label = New-Object Windows.Forms.Label
$label.Text = '选择本地图片或视频作为 Codex 背景。视频将转换为静音 H.264。'
$label.SetBounds(20,18,480,45); $form.Controls.Add($label)
$status = New-Object Windows.Forms.Label
$status.Text = '就绪'; $status.SetBounds(20,180,480,45); $form.Controls.Add($status)
$progress = New-Object Windows.Forms.ProgressBar
$progress.SetBounds(20,235,480,12); $form.Controls.Add($progress)
$script:dynamicBusy = $false
$buttons = @()
foreach ($spec in @(@('选择静态图片',20,75), @('选择动态视频',270,75), @('打开 Codex',20,125), @('恢复原始外观',270,125))) {
  $button = New-Object Windows.Forms.Button
  $button.Text = $spec[0]; $button.SetBounds($spec[1],$spec[2],230,38)
  $form.Controls.Add($button); $buttons += $button
}
function Invoke-ManagerAction {
  param([scriptblock]$Action)
  if ($script:dynamicBusy) { return }
  $script:dynamicBusy = $true
  foreach ($button in $buttons) { $button.Enabled = $false }
  $progress.Style = 'Marquee'
  try { & $Action; $status.Text = '操作完成。' }
  catch { $status.Text = '操作失败；请查看提示。'; [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Codex 动态皮肤','OK','Error') | Out-Null }
  finally { $progress.Style = 'Blocks'; foreach ($button in $buttons) { $button.Enabled = $true }; $script:dynamicBusy = $false }
}
function Select-ManagerMedia {
  param([string]$Kind)
  $dialog = New-Object Windows.Forms.OpenFileDialog
  if ($Kind -eq 'Image') { $dialog.Filter = '图片|*.png;*.jpg;*.jpeg;*.webp' } else { $dialog.Filter = '视频|*.mp4;*.mov;*.m4v;*.wmv;*.avi;*.mkv;*.webm' }
  try {
    if ($dialog.ShowDialog($form) -eq 'OK') {
      Invoke-ManagerAction {
        $status.Text = '正在准备媒体…'; [Windows.Forms.Application]::DoEvents()
        $result = Invoke-SelectedMedia $dialog.FileName $Kind { param($message) $status.Text = $message; [Windows.Forms.Application]::DoEvents() }
        if ($PrepareOnly) { [Windows.Forms.MessageBox]::Show(('准备完成：' + $result.Path),'Codex 动态皮肤') | Out-Null }
      }
    }
  } finally { $dialog.Dispose() }
}
$buttons[0].Add_Click({ Select-ManagerMedia Image })
$buttons[1].Add_Click({ Select-ManagerMedia Video })
$buttons[2].Add_Click({ Invoke-ManagerAction { if ($PrepareOnly) { throw 'PrepareOnly 模式不能启动 Codex。' }; Invoke-DynamicEngine -StateRoot $StateRoot } })
$buttons[3].Add_Click({ Invoke-ManagerAction { if ($PrepareOnly) { throw 'PrepareOnly 模式不能恢复真实应用。' }; Invoke-DynamicEngine -StateRoot $StateRoot -Restore } })
$form.Add_FormClosing({ if ($script:dynamicBusy) { $_.Cancel = $true } })
try { [void]$form.ShowDialog() } finally { $form.Dispose() }
