# ────────────────────────────────────────────────────────────────────────────────
# powershell -ExecutionPolicy Bypass -File bin\install-aria2.ps1
# ────────────────────────────────────────────────────────────────────────────────
# run the following for execution over the internet:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   iwr -useb 'https://raw.githubusercontent.com/da-moon/psutils/master/bin/install-aria2.ps1'| iex
# ────────────────────────────────────────────────────────────────────────────────
#
# ─── PARAMS ─────────────────────────────────────────────────────────────────────
#
param (
  [string] $version = "1.35.0"
)

Clear-Host
# [ NOTE ] quit if anything goes wrong
$old_erroractionpreference = $erroractionpreference
$erroractionpreference = 'stop'
# [ NOTE ] => Check OS and ensure we are running on Windows
if (-Not ($Env:OS -eq "Windows_NT")) {
  Write-Host "Error: This script only supports Windows machines. Exiting..."
  exit 1
}
if (($PSVersionTable.PSVersion.Major) -lt 5) {
  Write-Output "PowerShell 5 or later is required to run go-toolchain-installer."
  Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
  break
}
if ($Env:PROCESSOR_ARCHITECTURE.ToLower() -ne 'amd64' ) {
  throw [System.ArgumentException] "this script does not support the following cpu architecture: '$Env:PROCESSOR_ARCHITECTURE'"
}
#
# ─── VARIABLES ──────────────────────────────────────────────────────────────────
#
$TMP_DIR = $Env:TEMP + '\aria2';
$NETWORK_IO_URL = "https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1"
$ZIP_FILE = $TMP_DIR + '\aria2.zip'
$DOWNLOAD_URL = 'https://github.com/aria2/aria2/releases/download/release-' + $version + '/aria2-' + $version + '-win-64bit-build1.zip';
# ────────────────────────────────────────────────────────────────────────────────
Invoke-Expression (New-Object net.webclient).downloadstring($NETWORK_IO_URL);
Write-Output ('installing aria2 ' + $version);
$start_time = Get-Date;
New-Item `
  -Type Directory `
  -Path ($Env:ProgramData + '\Bin') `
  -ErrorAction SilentlyContinue `
  -Force | Out-Null ;
  ;
download $DOWNLOAD_URL $ZIP_FILE ;
Expand-Archive `
  $ZIP_FILE `
  -DestinationPath $TMP_DIR `
  -Force  | Out-Null ;
Remove-Item `
-Path $ZIP_FILE `
-Recurse `
-Force  | Out-Null ;
Copy-Item ($TMP_DIR + '\aria2*\aria2c.exe')  ($Env:ProgramData + '\Bin') -Force | Out-Null ;
aria2c --version | Out-Null ;
Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null;
Write-Output ('Time taken: ' + $((Get-Date).Subtract($start_time).Seconds) + ' second(s)');
# ────────────────────────────────────────────────────────────────────────────────
# [ NOTE ] => Reset $erroractionpreference to original value
$erroractionpreference = $old_erroractionpreference