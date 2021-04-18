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
  [string] $git_version = "2.31.1",
  [string] $git_patch_version = "1"
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

$libraries = @("common", "network-io");
foreach ($library in $libraries) {
  if (($psscriptroot) -and (Test-Path "$psscriptroot\$library.ps1" -PathType leaf)) {
    . "$psscriptroot\$library.ps1";
  } else {
    $library_url = "https://raw.githubusercontent.com/da-moon/psutils/master/lib/$library.ps1";
    Invoke-Expression (New-Object net.webclient).downloadstring($library_url);
  }
}
# ────────────────────────────────────────────────────────────────────────────────
$TMP_DIR = $Env:TEMP + '\git';
$DOWNLOAD_URL = 'https://github.com/git-for-windows/git/releases/download/v' + $git_version + '.windows.' + $git_patch_version + '/MinGit-' + $git_version + '-busybox-64-bit.zip';
$ZIP_FILE = $TMP_DIR + '\git.zip'
# ────────────────────────────────────────────────────────────────────────────────
Write-Output (
  'installing git ' + $git_version);
$start_time = Get-Date;
New-Item `
  -Type Directory `
  -Path ($Env:ProgramFiles + '\Bin') `
  -ErrorAction SilentlyContinue `
  -Force | Out-Null ;
download $DOWNLOAD_URL $ZIP_FILE | Out-Null ;
Expand-Archive `
  $ZIP_FILE `
  -ErrorAction SilentlyContinue `
  -DestinationPath ($Env:ProgramFiles + '\mingit') `
  -Force  | Out-Null ;
New-Item `
  -Type Directory `
  -Path ($Env:ProgramData + '\Bin') `
  -ErrorAction SilentlyContinue `
  -Force | Out-Null ;
if (is_admin) {
  # [ NOTE ] needs admin priviledge
  New-Item `
    -Itemtype SymbolicLink `
    -Path ($Env:ProgramData + '\Bin') `
    -name "git.exe" `
    -Value ($Env:ProgramFiles + '\mingit\cmd\git.exe')  | Out-Null
}else{
  $Env:PATH = "$Env:ProgramFiles\mingit\cmd;$Env:PATH"
}
git --version | Out-Null ;
Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null;
Write-Output ('Time taken: ' + $((Get-Date).Subtract($start_time).Seconds) + ' second(s)');
# # ────────────────────────────────────────────────────────────────────────────────
# # [ NOTE ] => Reset $erroractionpreference to original value
$erroractionpreference = $old_erroractionpreference
