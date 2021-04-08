# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $file_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/file.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($file_url)
# ────────────────────────────────────────────────────────────────────────────────


# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

$messages_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/messages.ps1'
Invoke-Expression (New-Object net.webclient).downloadstring($messages_url)

function fname($path) { Split-Path $path -leaf }
function strip_filename($path) { $path -replace [regex]::escape((fname $path)) }
function is_directory([String] $path) {
  return (Test-Path $path) -and (Get-Item $path) -is [System.IO.DirectoryInfo]
}

function movedir($from, $to) {
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

  if($proc.ExitCode -ge 8) {
      debug $out
      throw "Could not find '$(fname $from)'! (error $($proc.ExitCode))"
  }

  # wait for robocopy to terminate its threads
  1..10 | ForEach-Object {
      if (Test-Path $from) {
          Start-Sleep -Milliseconds 100
      }
  }
}
