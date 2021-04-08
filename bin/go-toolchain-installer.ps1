# Usage: powershell -ExecutionPolicy Bypass -File go-toolchain-installer.ps1
# Summary: installs go aarch64 toolchain on windows
# Help: downloads aarch64 go toolchain archive
#       and sets up environment variables
#       run the following for execution over the internet:
#       
#       Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#       iwr -useb 'https://raw.githubusercontent.com/da-moon/windows-on-arm/master/go-toolchain.ps1'| iex
# 
# ────────────────────────────────────────────────────────────────────────────────
# [ NOTE ] quit if anything goes wrong
$old_erroractionpreference = $erroractionpreference
$erroractionpreference = 'stop'
# [ NOTE ] => Check OS and ensure we are running on Windows
if (-Not ($Env:OS -eq "Windows_NT")) {
  Write-Host "Error: This script only supports Windows machines. Exiting..."
  exit 1
}
#
# ─── VARIABLES ──────────────────────────────────────────────────────────────────
#
$VERSION="1.16"
$DOWNLOAD_URL="https://github.com/thongtech/go-windows-arm/releases/download/$VERSION/go$VERSION.windows-arm.zip"
$TMP_DIR= $Env:TEMP + "\go"
$ZIP_FILE= $TMP_DIR + "\go.zip"
$Env:GOROOT="c:\go"
$Env:GOPATH=$Env:USERPROFILE + "\go"
# ────────────────────────────────────────────────────────────────────────────────
Clear-Host
if (($PSVersionTable.PSVersion.Major) -lt 5) {
  Write-Output "PowerShell 5 or later is required to run go-toolchain-installer."
  Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
  break
}
$start_time = Get-Date
# ────────────────────────────────────────────────────────────────────────────────
#
# ─── IMPORTING LIBRARIES ────────────────────────────────────────────────────────
#
# ────────────────────────────────────────────────────────────────────────────────
$library_repo_root_url="https://raw.githubusercontent.com/da-moon/psutils/master"
$libraries = @("network-io", "messages")
foreach ($library in $libraries) {
  $target=$library_repo_root_url+'/'+"$library"+".ps1"
  Invoke-Expression (new-object net.webclient).downloadstring($target)
}
# ────────────────────────────────────────────────────────────────────────────────
if (Test-Path -Path $TMP_DIR -PathType Container) {
  warn "Go toolchain temporary directory [$TMP_DIR] exist.removing it for a fresh install."
  Remove-Item $TMP_DIR -Force -Recurse -ErrorAction Stop
}
info "creating temporary directory [$TMP_DIR] to store go toolchain archive."
$null = New-Item -ItemType Directory -Path $TMP_DIR -Force -ErrorAction Stop
# ────────────────────────────────────────────────────────────────────────────────
info "Downloading go toolchain v$VERSION archive and storing it in [$ZIP_FILE]"
download_file "$DOWNLOAD_URL" "$ZIP_FILE"
# ────────────────────────────────────────────────────────────────────────────────

if (Test-Path -Path $Env:GOROOT -PathType Container) {
  warn "Go toolchain root directory [$Env:GOROOT] exist.removing it for a fresh install."
  Remove-Item $Env:GOROOT -Force -Recurse -ErrorAction Stop
}
info "creating Go toolchain root directory [$Env:GOROOT]."
$null = New-Item -ItemType Directory -Path $Env:GOROOT -Force -ErrorAction Stop
# ────────────────────────────────────────────────────────────────────────────────
if (-not(Test-Path -Path $Env:GOPATH -PathType Container)) {
  info "creating GOPATH directory [$Env:GOPATH]."
  $null = New-Item -ItemType Directory -Path $Env:GOPATH -Force -ErrorAction Stop
}
info "creating Go toolchain root directory [$Env:GOROOT]."
info "Extracting [$ZIP_FILE] to [$Env:GOROOT]"
Expand-Archive -Path "$ZIP_FILE" -DestinationPath $Env:GOROOT
# ────────────────────────────────────────────────────────────────────────────────
$parent=Split-Path -parent $PROFILE.CurrentUserAllHosts 
if (-not(Test-Path -Path $parent -PathType Container)) {
  warn "The directory [$parent] does not exist.trying to create it."
  $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
  info "The directory [$parent] has been created."
}
if (-not(Test-Path -Path $PROFILE.CurrentUserAllHosts -PathType Leaf)) {
  $null = New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force -ErrorAction Stop
  info "The file [$PROFILE.CurrentUserAllHosts] has been created."
}
# ────────────────────────────────────────────────────────────────────────────────
info "ensuring PATH is updated and Go environment variables are present"
$profile_lines = @(
  ('$Env:GOROOT="' + $Env:GOROOT + '"'),
  ('$Env:GOPATH="' + $Env:GOPATH + '"'),
  '$Env:GO111MODULE="on"',
  '$Env:PATH="$Env:GOROOT\bin;$Env:GOPATH\bin;$Env:PATH"'
)
foreach ($line in $profile_lines) {
  $exists=Select-String -Quiet -SimpleMatch "$line" -Path $PROFILE.CurrentUserAllHosts
  if (-not $exists ){
    info "adding [$line] to profile file."
    Write-Output "$line" | Out-File $PROFILE.CurrentUserAllHosts -Encoding ascii -Append
  }
}
. $PROFILE.CurrentUserAllHosts
go version
# ────────────────────────────────────────────────────────────────────────────────
info "cleaning up"
Remove-Item "$TMP_DIR" -Force -Recurse -ErrorAction SilentlyContinue
success "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
# ────────────────────────────────────────────────────────────────────────────────
# [ NOTE ] => Reset $erroractionpreference to original value
$erroractionpreference = $old_erroractionpreference 
