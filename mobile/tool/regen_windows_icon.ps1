Get-Process -Name pos_mobile -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Add-Type -AssemblyName System.Drawing

function Get-CoreBounds([System.Drawing.Bitmap]$bmp) {
  $rimX = [Math]::Max(4, [int]($bmp.Width * 0.10))
  $rimY = [Math]::Max(4, [int]($bmp.Height * 0.06))
  $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
  for ($y = $rimY; $y -lt $bmp.Height - $rimY; $y++) {
    for ($x = $rimX; $x -lt $bmp.Width - $rimX; $x++) {
      $p = $bmp.GetPixel($x, $y)
      if ($p.A -lt 30) { continue }
      if ($x -lt $minX) { $minX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
  if ($maxX -lt 0) { return New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height }
  $pad = [Math]::Max(2, [int](($maxX - $minX) * 0.01))
  $minX = [Math]::Max(0, $minX - $pad)
  $minY = [Math]::Max(0, $minY - $pad)
  $maxX = [Math]::Min($bmp.Width - 1, $maxX + $pad)
  $maxY = [Math]::Min($bmp.Height - 1, $maxY + $pad)
  return New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
}

# Previous fill 1.33; +10% => 1.463
$Fill = 1.463

function New-Icon {
  param([System.Drawing.Bitmap]$Src, [int]$Size)
  $bounds = Get-CoreBounds $Src
  $cropped = $Src.Clone($bounds, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $fit = [Math]::Min($Size / [double]$cropped.Width, $Size / [double]$cropped.Height)
  $scale = $fit * $Fill
  $dw = [Math]::Max(1, [int]($cropped.Width * $scale))
  $dh = [Math]::Max(1, [int]($cropped.Height * $scale))
  $dx = [int](($Size - $dw) / 2)
  # Keep wordmark; clip bulb top first when zoomed
  $dy = if ($dh -gt $Size) { [int](($Size - $dh) * 0.82) } else { [int](($Size - $dh) / 2) }
  $g.DrawImage($cropped, $dx, $dy, $dw, $dh)
  $g.Dispose(); $cropped.Dispose()
  return $bmp
}

function ConvertTo-ClassicIco {
  param([System.Drawing.Bitmap]$Src, [string]$DestIco, [int[]]$Sizes = @(16, 32, 48, 64, 128, 256))
  $entries = New-Object System.Collections.Generic.List[object]
  foreach ($size in $Sizes) {
    $flat = New-Icon -Src $Src -Size $size
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $data = $flat.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $size)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $flat.UnlockBits($data); $flat.Dispose()
    $xor = New-Object byte[] ($size * $size * 4)
    $maskRowBytes = [Math]::Ceiling($size / 32.0) * 4
    $and = New-Object byte[] ($maskRowBytes * $size)
    for ($y = 0; $y -lt $size; $y++) {
      $srcRow = ($size - 1 - $y) * $stride
      $dstRow = $y * $size * 4
      $maskRow = $y * $maskRowBytes
      for ($x = 0; $x -lt $size; $x++) {
        $si = $srcRow + ($x * 4); $di = $dstRow + ($x * 4)
        $xor[$di] = $bytes[$si]; $xor[$di+1] = $bytes[$si+1]; $xor[$di+2] = $bytes[$si+2]; $xor[$di+3] = $bytes[$si+3]
        if ($bytes[$si+3] -lt 128) {
          $byteIndex = $maskRow + [Math]::Floor($x / 8)
          $bit = 7 - ($x % 8)
          $and[$byteIndex] = $and[$byteIndex] -bor (1 -shl $bit)
        }
      }
    }
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $bw.Write([int32]40); $bw.Write([int32]$size); $bw.Write([int32]($size * 2))
    $bw.Write([int16]1); $bw.Write([int16]32); $bw.Write([int32]0)
    $bw.Write([int32]($xor.Length + $and.Length))
    $bw.Write([int32]0); $bw.Write([int32]0); $bw.Write([int32]0); $bw.Write([int32]0)
    $bw.Write($xor); $bw.Write($and); $bw.Flush()
    $imgBytes = $ms.ToArray(); $bw.Dispose(); $ms.Dispose()
    $entries.Add([pscustomobject]@{ Size = $size; Data = $imgBytes })
  }
  $offset = 6 + (16 * $entries.Count)
  $out = New-Object System.IO.MemoryStream
  $w = New-Object System.IO.BinaryWriter $out
  $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$entries.Count)
  foreach ($e in $entries) {
    $s = $e.Size
    $w.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))
    $w.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))
    $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$e.Data.Length); $w.Write([uint32]$offset)
    $offset += $e.Data.Length
  }
  foreach ($e in $entries) { $w.Write($e.Data) }
  $w.Flush()
  $tmp = "$DestIco.tmp"
  [System.IO.File]::WriteAllBytes((Join-Path (Get-Location) $tmp), $out.ToArray())
  Move-Item -Force $tmp $DestIco
  $w.Dispose(); $out.Dispose()
}

Set-Location "e:\projects\ITARA-POS\mobile"
$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path "assets\brand\itara_nexus_logo_white.png"))
"fill=$Fill"
ConvertTo-ClassicIco -Src $src -DestIco "windows\runner\resources\app_icon.ico"
$densities = @{ 'mipmap-mdpi'=48; 'mipmap-hdpi'=72; 'mipmap-xhdpi'=96; 'mipmap-xxhdpi'=144; 'mipmap-xxxhdpi'=192 }
foreach ($kv in $densities.GetEnumerator()) {
  $dir = "android\app\src\main\res\$($kv.Key)"
  if (-not (Test-Path $dir)) { continue }
  $bmp = New-Icon -Src $src -Size ([int]$kv.Value)
  $bmp.Save((Join-Path $dir "ic_launcher.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
$preview = New-Icon -Src $src -Size 512
$preview.Save("assets\brand\app_icon_launcher_white.png", [System.Drawing.Imaging.ImageFormat]::Png)
$preview.Dispose(); $src.Dispose()
"ok"
