# ────────────────────────────────────────────────────────────────────────────────
# powershell -ExecutionPolicy Bypass -File bin\go-toolchain.ps1
# ────────────────────────────────────────────────────────────────────────────────
# run the following for execution over the internet:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   iwr -useb 'https://raw.githubusercontent.com/da-moon/psutils/master/bin/go-toolchain.ps1'| iex
# ────────────────────────────────────────────────────────────────────────────────

param($cmd)
set-strictmode -off
if (($PSVersionTable.PSVersion.Major) -lt 5) {
  Write-Output "PowerShell 5 or later is required to run go-toolchain."
  Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
  break
}

# [ NOTE ] => show notification to change execution policy:
$allowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
if ((Get-ExecutionPolicy).ToString() -notin $allowedExecutionPolicy) {
  Write-Output "PowerShell requires an execution policy in [$($allowedExecutionPolicy -join ", ")] to run go-toolchain."
  Write-Output "For example, to set the execution policy to 'RemoteSigned' please run :"
  Write-Output "'Set-ExecutionPolicy RemsoteSigned -scope CurrentUser'"
  break
}
# [ NOTE ] => quit if anything goes wrong
$old_erroractionpreference = $erroractionpreference
$erroractionpreference = 'stop'
# ────────────────────────────────────────────────────────────────────────────────
function bootstrap([string]$bootstrap_dir) {
  if (Test-Path -Path $bootstrap_dir -PathType Container) {
    Remove-Item "$bootstrap_dir" -Recurse -Force -ErrorAction Stop
  }
  $null = New-Item -ItemType Directory -Path $bootstrap_dir -Force -ErrorAction Stop
  Write-Output "caching helper libraries"
  $zipurl = 'https://github.com/da-moon/psutils/archive/master.zip'
  $zipfile = "$bootstrap_dir\psutils.zip"
  [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
  Invoke-WebRequest "$zipurl" -OutFile $zipfile
  # ────────────────────────────────────────────────────────────────────────────────
  Expand-Archive -Path "$zipfile" -DestinationPath $bootstrap_dir
  Copy-Item "$bootstrap_dir\*master\*" $bootstrap_dir -Recurse -Force
  $null = Remove-Item "$bootstrap_dir\*master" -Recurse -Force -ErrorAction Stop
  $null = Remove-Item "$zipfile" -Recurse -Force -ErrorAction Stop
}
#
# ─── IMPORTS ────────────────────────────────────────────────────────────────────
#
$cache_dir = "$Env:TEMP\da-moon\psutils"
if (-not(Test-Path -Path $cache_dir -PathType Container)) {
  bootstrap $cache_dir
}
# ────────────────────────────────────────────────────────────────────────────────
$libraries = @("network-io","messages", "common", "path", "getopt", "shim")
foreach ($library in $libraries) {
  $target = $cache_dir + "\lib\$library.ps1"
  if (-not(Test-Path $target -PathType leaf)) {
    bootstrap $cache_dir
  }
  . $target
}
function get_latest_go_version() {
  
}
#
# ─── DEFAULTS ───────────────────────────────────────────────────────────────────
#
$GOROOT = "c:\go"
$GOPATH = $Env:USERPROFILE + "\go"
$GO_VERSION="1.16"

function go_install (){
  #
  # ─── VARIABLES ──────────────────────────────────────────────────────────────────
  #
  $DOWNLOAD_URL="https://github.com/thongtech/go-windows-arm/releases/download/$GO_VERSION/go$GO_VERSION.windows-arm.zip"
  $TMP_DIR= $Env:TEMP + "\go"
  $ZIP_FILE= $TMP_DIR + "\go.zip"
  $start_time = Get-Date
  # ────────────────────────────────────────────────────────────────────────────────
  if (Test-Path -Path $TMP_DIR -PathType Container) {
    warn "Go toolchain temporary directory [$TMP_DIR] exist.removing it for a fresh install."
    Remove-Item $TMP_DIR -Force -Recurse -ErrorAction Stop
  }
  info "creating temporary directory [$TMP_DIR] to store go toolchain archive."
  $null = New-Item -ItemType Directory -Path $TMP_DIR -Force -ErrorAction Stop
  # ────────────────────────────────────────────────────────────────────────────────
  info "Downloading go toolchain v$GO_VERSION archive and storing it in [$ZIP_FILE]"
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
}
#
# ─── CLI HELP ───────────────────────────────────────────────────────────────────
#
function usage() {
  Write-Host "Usage: go-toolchain  [options]" -f darkgreen
}

function summary() {
  Write-Host "Summary: installs go toolchain and common development tools on windows" -f darkyellow
}
function help() {
  usage
  Write-Host ""
  summary
  Write-Host "
Help: install go toolchain and a set of widely used tools.

Options:
  -d, --development-tools
    * Installs a collection of packages
    which are used for develping go applications.
    * Default is [TRUE].

  -i, --install <version>
    * installs or re-install go toolchain
    * If the version is not specified, it would
    install the latest version.

  -p GOPATH, --go-path GOPATH
    * GOPATH directory. Libraries and binaries built by go toolchain
    are installed here
    * Default is [$GOPATH].

  -r GOROOT, --go-root GOROOT
    * GOROOT directory. Go toolchain is installed in this directory
    * Default is [$GOROOT].

  -s, --shim
    * Creates a shim for 'go-toolchain' and adds it to path

  -u, --update
    Update local copy of 'go-toolchain' script

  -h, --help                    shows help message
  -v, --version                 shows script version
" -f darkgray
}
#
# ────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: E X E C U T I O N   S T A R T : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────────────────
#

Clear-Host
if (-not ( $cmd -or $args)) {
  help
  exit 0
}
if (!$cmd -and @('--version', '-v') -contains $args) {
  Write-Host "v0.0.1"
  exit 0
}
if (!$cmd -and @('--help', '-h') -contains $args) {
  help
  exit 0
}
# [ NOTE ] =>
# - https://github.com/lukesampson/psutils/blob/master/say.ps1
# $opt, $args, $err = getopt $args 'hf:v:r:' @('input-file=','voice=','rate=', 'help')
$long_flags= @(
  'development-tools',
  'install',
  'go-path=',
  'go-root=',
  'shim',
  'update'
)
$opt, $args , $err = getopt $args 'dip:r:su' $long_flags

if ($err) { "go-toolchain : $err"; exit 1 }
if(($cmd) -and ($cmd.startswith('--'))) {
  $opt_cmd, $args_cmd , $err = getopt $cmd '' $long_flags
  if ($err) { "go-toolchain : $err"; exit 1 }
  $opt_cmd.GetEnumerator() | ForEach-Object {
    $opt[$_.key.ToString()] =  $_.value
    if (($_.key.ToString() -eq 'install') -and ($args_cmd)){
      # [ TODO ] => sanitize version
      $args = $args_cmd
    }
  }
}
[bool] $shim = $opt.s -or $opt.shim
[bool] $update = $opt.u -or $opt.update
[bool] $install =  $opt.i -or $opt.install
if ($install) {
  if ($args) {
    $GO_VERSION=$args[0]
  }
}
if ($install) {
  info "installing go version $GO_VERSION"
}

[bool] $development_tools = $opt.d -or $opt['development-tools']
[string] $go_path = $opt.p -or $opt['go-path']
[string] $go_root = $opt.r -or $opt['go-root']
$opt.GetEnumerator() | ForEach-Object {
  $message = '{0}=>{1}' -f $_.key, $_.value
  Write-Host $message -f darkgreen
}
# [ NOTE ] => Reset $erroractionpreference to original value
$erroractionpreference = $old_erroractionpreference
exit 0

# [bool] $shim = $false
# if ($opt['shim']) { $shim = $opt['shim'] }
# if ($opt['s']) { $shim = $opt['s'] }
# # ────────────────────────────────────────────────────────────────────────────────
# [bool] $update = $false
# if ($opt['update']) { $update = $opt['update'] }
# if ($opt['u']) { $update = $opt['u'] }
# # ────────────────────────────────────────────────────────────────────────────────
# [bool] $install = $false
# if ($opt['install']) { $install = $opt['install'] }
# if ($opt['i']) { $install = $opt['i'] }
# # ────────────────────────────────────────────────────────────────────────────────
# [bool] $development_tools = $false
# if ($opt['development-tools']) { $development_tools = $opt['development-tools'] }
# if ($opt['d']) { $development_tools = $opt['d'] }