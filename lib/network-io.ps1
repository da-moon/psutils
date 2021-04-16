# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $network_io_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($network_io_url)
# ────────────────────────────────────────────────────────────────────────────────

# [ NOTE ] => 
# - https://stackoverflow.com/a/21422517
# [ NOTE ] => 
# - https://stackoverflow.com/a/21422517
function set_tls_policies(){
  [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
}
function native_download([string]$url, [string] $targetFile) {
  set_tls_policies ;
  $dir = Split-Path -parent $targetFile
  if (-not(Test-Path -Path $dir -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
  }

  $uri = New-Object "System.Uri" "$url"
  $request = [System.Net.HttpWebRequest]::Create($uri)
  $request.set_Timeout(15000)
  $response = $request.GetResponse()
  $totalLength = [System.Math]::Floor($response.get_ContentLength() / 1024)
  $responseStream = $response.GetResponseStream()
  $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
  $buffer = New-Object byte[] 10KB
  $count = $responseStream.Read($buffer, 0, $buffer.length)
  $downloadedBytes = $count
  while ($count -gt 0) {
    $targetStream.Write($buffer, 0, $count)
    $count = $responseStream.Read($buffer, 0, $buffer.length)
    $downloadedBytes = $downloadedBytes + $count
    Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes / 1024)) / $totalLength) * 100)
  }
  Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
  $targetStream.Flush()
  $targetStream.Close()
  $targetStream.Dispose()
  $responseStream.Dispose()
}
function aria2_download([string]$url, [string] $targetFile) {
  if(-not (Get-Command "aria2c" -ErrorAction Ignore) ){
    throw [System.ArgumentException] "'aria2c' was not found in PATH"
  }
  set_tls_policies;
  # [ NOTE ] => ensuring parent exists.
  $dir = Split-Path -parent $targetFile
  if (-not(Test-Path -Path $dir -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
  }
  $file = Split-Path "$targetFile" -Leaf
  aria2c -k 1M -c -j16 -x16 --dir="$dir" --out="$file" "$url"
}
function download([string]$url, [string] $targetFile) {
  if (Get-Command "aria2c" -ErrorAction Ignore) {
    aria2_download "$url" "$targetFile"
  }
  else {
    native_download "$url" "$targetFile"
  }
}
