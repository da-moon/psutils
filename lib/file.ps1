# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $file_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/file.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($file_url)
# ────────────────────────────────────────────────────────────────────────────────


# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

$library="messages"
if (($psscriptroot) -and (Test-Path "$psscriptroot\$library.ps1" -PathType leaf)) {
  . "$psscriptroot\$library.ps1"
}
else {
  $library_url = "https://raw.githubusercontent.com/da-moon/psutils/master/lib/$library.ps1"
  Invoke-Expression (New-Object net.webclient).downloadstring($library_url)
}
function fname($path) { Split-Path $path -leaf }
function strip_filename($path) { $path -replace [regex]::escape((fname $path)) }
function is_directory([String] $path) {
  return (Test-Path $path) -and (Get-Item $path) -is [System.IO.DirectoryInfo]
}
function ensure_dir([string]$dir)  {
  if (-not(Test-Path $dir)) { 
    $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
  }
  Resolve-Path $dir
}

function movedir([string]$from,[string] $to) {
  if ( `
    (Get-Command "robocopy" -ErrorAction Ignore) `
    -and  (-not($from.Contains('*'))) `
    -and (-not($to.Contains('*')))`
   ) {
    $from = $from.trimend('\')
    $to = $to.trimend('\')
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.FileName = 'robocopy.exe'
    $proc.StartInfo.Arguments = "`"$from`" `"$to`" /e /move"
    $proc.StartInfo.RedirectStandardOutput = $true
    $proc.StartInfo.RedirectStandardError = $true
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $proc.Start()
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ge 8) {
      debug $out
      throw "Could not find '$(fname $from)'! (error $($proc.ExitCode))"
    }
    1..10 | ForEach-Object {
      if (Test-Path $from) {
        Start-Sleep -Milliseconds 100
      }
    }
    return
  }
  Copy-Item `
    -Path $from `
    -Destination $to `
    -Force `
    -Recurse
  Remove-Item `
    -Path $from `
    -Recurse `
    -Force
  return
}
# [ synopsis ] : removes the directory if it exists and
# then recreates it
function recreate_dir(){
  param(
    [Parameter(Mandatory = $true)][string]$dir,
    [Parameter(Mandatory = $false)][string]$msg
  )
  if (Test-Path -Path $dir -PathType Container) {
    warn "directory exists : [$dir]"
    info "removing directory : [$dir]"
    Remove-Item $dir -Force -Recurse -ErrorAction Stop
  }
  info "creating directory : [$dir]."
  $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
  if ($msg){
    info "$msg"
  }
}