function New-DynamicWallpaperThumbnail {
  param([string]$MediaPath,[ValidateSet('Image','Video')][string]$Kind,[string]$DestinationPath)
  $stream=$null
  try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    Add-Type -AssemblyName PresentationCore,WindowsBase
    $null=[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
    $null=[Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
    $null=[Windows.Graphics.Imaging.BitmapTransform,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
    $null=[Windows.Graphics.Imaging.PixelDataProvider,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
    $null=[Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
    $null=[Windows.Storage.FileProperties.StorageItemThumbnail,Windows.Storage.FileProperties,ContentType=WindowsRuntime]
    Assert-DreamSkinNoReparseComponents -Path $MediaPath
    Assert-DreamSkinNoReparseComponents -Path $DestinationPath
    $file=Wait-DynamicWinRT ([Windows.Storage.StorageFile]::GetFileFromPathAsync([IO.Path]::GetFullPath($MediaPath))) ([Windows.Storage.StorageFile])
    if($Kind -eq 'Video'){
      $stream=Wait-DynamicWinRT ($file.GetThumbnailAsync([Windows.Storage.FileProperties.ThumbnailMode]::SingleItem,480)) ([Windows.Storage.FileProperties.StorageItemThumbnail])
      if(-not $stream -or $stream.Type -ne [Windows.Storage.FileProperties.ThumbnailType]::Image){return $false}
    }else{
      $stream=Wait-DynamicWinRT ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    }
    $decoder=Wait-DynamicWinRT ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $scale=[Math]::Min(1.0,[Math]::Min(480.0/$decoder.OrientedPixelWidth,480.0/$decoder.OrientedPixelHeight))
    $width=[uint32][Math]::Max(1,[Math]::Floor($decoder.OrientedPixelWidth*$scale))
    $height=[uint32][Math]::Max(1,[Math]::Floor($decoder.OrientedPixelHeight*$scale))
    $transform=New-Object Windows.Graphics.Imaging.BitmapTransform
    # Transform sizes precede EXIF orientation; swap for rotated source images.
    if($decoder.OrientedPixelWidth -ne $decoder.PixelWidth){$transform.ScaledWidth=$height;$transform.ScaledHeight=$width}
    else{$transform.ScaledWidth=$width;$transform.ScaledHeight=$height}
    $pixels=Wait-DynamicWinRT ($decoder.GetPixelDataAsync([Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,[Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied,$transform,[Windows.Graphics.Imaging.ExifOrientationMode]::RespectExifOrientation,[Windows.Graphics.Imaging.ColorManagementMode]::DoNotColorManage)) ([Windows.Graphics.Imaging.PixelDataProvider])
    $bytes=$pixels.DetachPixelData()
    $bitmap=[Windows.Media.Imaging.BitmapSource]::Create([int]$width,[int]$height,96,96,[Windows.Media.PixelFormats]::Pbgra32,$null,$bytes,([int]$width*4))
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $output=[IO.File]::Create($DestinationPath)
    try{$encoder.Save($output)}finally{$output.Dispose()}
    return $true
  }catch{
    if(Test-Path -LiteralPath $DestinationPath -PathType Leaf){
      try{Assert-DreamSkinNoReparseComponents -Path $DestinationPath;Remove-Item -LiteralPath $DestinationPath -Force}catch{}
    }
    return $false
  }finally{if($stream){$stream.Dispose()}}
}
