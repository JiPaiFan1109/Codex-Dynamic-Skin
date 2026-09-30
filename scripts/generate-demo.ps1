param([string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'engine\assets\demo-background.png'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$bitmap=New-Object Drawing.Bitmap 1280,720
$graphics=[Drawing.Graphics]::FromImage($bitmap)
$brush=New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(0,0)),([Drawing.Point]::new(1280,720)),([Drawing.Color]::FromArgb(14,31,52)),([Drawing.Color]::FromArgb(3,8,19))
try {
  $graphics.FillRectangle($brush,0,0,1280,720)
  $random=New-Object Random 20260930
  $star=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(100,170,205,235))
  try { for($i=0;$i -lt 180;$i++){ $graphics.FillEllipse($star,$random.Next(1280),$random.Next(720),2,2) } } finally {$star.Dispose()}
  $bitmap.Save([IO.Path]::GetFullPath($OutputPath),[Drawing.Imaging.ImageFormat]::Png)
} finally {$brush.Dispose();$graphics.Dispose();$bitmap.Dispose()}
