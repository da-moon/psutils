# ────────────────────────────────────────────────────────────────────────────────
# powershell -ExecutionPolicy Bypass -File bin\nanoserver\install-git.ps1
# ────────────────────────────────────────────────────────────────────────────────
# run the following for execution over the internet:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   iwr -useb 'https://raw.githubusercontent.com/da-moon/psutils/master/bin/nanoserver/install-git.ps1'| iex
# ────────────────────────────────────────────────────────────────────────────────
#
# ─── PARAMS ─────────────────────────────────────────────────────────────────────
#
param (
  [string] $version = "2.31.1"
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
$NETWORK_IO_URL = "https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1"
$TMP_DIR = $Env:TEMP + '\git';
$DOWNLOAD_URL = 'https://github.com/git-for-windows/git/releases/download/v' + $version + '.windows.1/MinGit-' + $version + '-64-bit.zip';
$ZIP_FILE = $TMP_DIR + '\git.zip'

# ────────────────────────────────────────────────────────────────────────────────
Invoke-Expression (New-Object net.webclient).downloadstring($NETWORK_IO_URL);
Write-Output ('installing git ' + $version);
$start_time = Get-Date;
New-Item `
  -Type Directory `
  -Path ($Env:ProgramData + '\Bin') `
  -ErrorAction SilentlyContinue `
  -Force | Out-Null ;

download $DOWNLOAD_URL $ZIP_FILE ;
Expand-Archive `
  $ZIP_FILE `
  -DestinationPath ($Env:ProgramFiles + '\Git') `
  -Force  | Out-Null ;

$to_add = "$Env:ProgramFiles\Git\mingw64\bin";
$path = [System.Environment]::GetEnvironmentVariable("Path", "User");
[System.Environment]::SetEnvironmentVariable("PATH", $path + ";$to_add", "User");
$Env:PATH = "$Env:ProgramFiles\Git\mingw64\bin;$Env:PATH"
git --version | Out-Null ;

Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null;
Write-Output ('Time taken: ' + $((Get-Date).Subtract($start_time).Seconds) + ' second(s)');
# ────────────────────────────────────────────────────────────────────────────────
# [ NOTE ] => Reset $erroractionpreference to original value
$erroractionpreference = $old_erroractionpreference

# 