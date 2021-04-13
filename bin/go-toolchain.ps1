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
$libraries = @("network-io", "messages", "common", "env", "path", "file", "getopt", "shim")

$cache_dir = "$Env:TEMP\da-moon\psutils"
if ($psscriptroot) {
  if (Test-Path -Path "$psscriptroot\..\lib" -PathType Container) {
    $cache_dir = "$psscriptroot\.."
  }
}
if (-not(Test-Path -Path $cache_dir -PathType Container)) {
  bootstrap $cache_dir
}
# ────────────────────────────────────────────────────────────────────────────────
foreach ($library in $libraries) {
  $target = $cache_dir + "\lib\$library.ps1"
  if (-not(Test-Path $target -PathType leaf)) {
    bootstrap $cache_dir
  }
  . $target
}
function get_latest_go_version() {
  [OutputType([string])]
  [string]$uri = "https://golang.org/dl/?mode=json"
  set_tls_policies
  return $(Invoke-WebRequest `
    -Uri $uri `
    -Method GET `
    -ContentType "application/json" `
    -UseBasicParsing | ConvertFrom-Json).version[0]
}
function get_go_url {
  param (
    [Parameter(Mandatory = $false)][string]$version = "$(get_latest_go_version)"
  )
  
}
# ─── DEFAULTS ───────────────────────────────────────────────────────────────────
$DEFAULT_GOROOT = "c:\go"
$DEFAULT_GOPATH = $Env:USERPROFILE + "\go"
$STATIC_CHECK = "2020.1.6"
# ────────────────────────────────────────────────────────────────────────────────
if (-not (Test-Path Env:GOROOT)) {
  $Env:GOROOT = $DEFAULT_GOROOT
}
if (-not (Test-Path Env:GOPATH)) {
  $Env:GOPATH = $DEFAULT_GOPATH
}
function go_env () {
  param(
    [Parameter(Mandatory = $false)][string]$go_root = $Env:GOROOT,
    [Parameter(Mandatory = $false)][string]$go_path = $Env:GOPATH
  )
  ensure_user_profile
  # ────────────────────────────────────────────────────────────────────────────────
  info "ensuring PATH is updated and Go environment variables are present"
  $profile_lines = @(
    ('$Env:GOROOT="' + $go_root + '"'),
    ('$Env:GOPATH="' + $go_path + '"'),
    '$Env:GO111MODULE="on"',
    '$Env:PATH="$Env:GOROOT\bin;$Env:GOPATH\bin;$Env:PATH"'
  )
  foreach ($line in $profile_lines) {
    $exists = Select-String -Quiet -SimpleMatch "$line" -Path $PROFILE.CurrentUserAllHosts
    if (-not $exists ) {
      info "adding [$line] to profile file."
      Write-Output "$line" | Out-File $PROFILE.CurrentUserAllHosts -Encoding ascii -Append
    }
  }
  . $PROFILE.CurrentUserAllHosts
}
function go_install (){
  param(
    [Parameter(Mandatory = $true)][string]$download_url,
    [Parameter(Mandatory = $false)][string]$go_root = $Env:GOROOT,
    [Parameter(Mandatory = $false)][string]$go_path = $Env:GOPATH,
    [Parameter(Mandatory = $false)][bool]$force = $false
  )

  #
  # ─── VARIABLES ──────────────────────────────────────────────────────────────────
  #
  [string] $TMP_DIR = $Env:TEMP + "\go"
  [string] $ZIP_FILE = $TMP_DIR + "\go.zip"
  # ────────────────────────────────────────────────────────────────────────────────
  # recreate_dir "$TMP_DIR"  "Go toolchain temporary directory was succesfully created"
  # info "Downloading toolchain $GO_VERSION archive and storing it in [$ZIP_FILE]"
  # download "$download_url" "$ZIP_FILE"
  # if ($force){
  #   recreate_dir "$go_root" "GOROOT directory was succesfully deleted and recreated"
  # }else{
  #   info "ensuring GOROOT directory exists"
  #   ensure_dir "$go_root"
  # }
  # info "ensuring GOPATH directory exists"
  # ensure_dir "$go_path"
  # info "Extracting [$ZIP_FILE] to [$go_root]"
  # Expand-Archive -Path "$ZIP_FILE" -DestinationPath $go_root
  if (Test-Path -Path "$go_root\go" -PathType Container) {
    movedir "$go_root\go\*" $go_root
    # Remove-Item "$go_root\go" -Force -Recurse -ErrorAction Stop
  }
  # ────────────────────────────────────────────────────────────────────────────────
  go_env "$go_root" "$go_path"
  go version
  # ────────────────────────────────────────────────────────────────────────────────
  info "cleaning up"
  Remove-Item "$TMP_DIR" -Force -Recurse -ErrorAction SilentlyContinue
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
    * Default is [$DEFAULT_GOPATH].

  -r GOROOT, --go-root GOROOT
    * GOROOT directory. Go toolchain is installed in this directory
    * Default is [$DEFAULT_GOROOT].

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
if (-not (Get-Command "git" -ErrorAction Ignore) ) {
  abort "go-toolchain : git not found in path"
}
# [ NOTE ] =>
# - https://github.com/lukesampson/psutils/blob/master/say.ps1
# $opt, $args, $err = getopt $args 'hf:v:r:' @('input-file=','voice=','rate=', 'help')
$long_flags= @(
  'development-tools',
  'install',
  'force',
  'go-path=',
  'go-root=',
  'shim',
  'update'
)
$opt, $args , $err = getopt $args 'difp:r:su' $long_flags

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
#
# ─── LOG TIME ───────────────────────────────────────────────────────────────────
#
$start_time = Get-Date
[bool] $force = $opt.f -or $opt.force
[bool] $install = $opt.i -or $opt.install
[string] $go_version=""
if ($install) {
  if ($args) {
    $go_version = 'go' + $args[0]
  }
}
if ($install) {
  [string] $go_path = $Env:GOPATH
  if ($opt['go-path']) { $go_path = $opt['go-path'] }
  elseif ($opt['p']) { $go_path = $opt['p'] }

  [string] $go_root = $Env:GOROOT
  if ($opt['go-root']) { $go_root = $opt['go-root'] }
  elseif ($opt['r']) { $go_root = $opt['r'] }
  [string] $architecture = $Env:PROCESSOR_ARCHITECTURE.ToLower()
  [string] $os="windows"
  if ($go_version.Length -eq 0) {
    $go_version = get_latest_go_version
  }
  if ($architecture -eq "x86") {
    $architecture = "386"
  }
  [string] $download_url = "https://storage.googleapis.com/golang/$go_version.$os-$architecture.zip"
  if ($architecture -eq "arm64") {
    $go_version = "1.16"
    $download_url = "https://github.com/thongtech/go-windows-arm/releases/download/$go_version/go$go_version.windows-arm.zip"
  }
  info "installing Go toolchain"
  Write-Host "
  arch          = $($Env:PROCESSOR_ARCHITECTURE.ToLower())
  version       = $go_version
  download-url  = $download_url
  GOPATH        = $go_path
  GOROOT        = $go_root
  " -f darkgray
  go_install "$download_url" "$go_root" "$go_path" $force
}
[bool] $development_tools = $opt.d -or $opt['development-tools']
if ($development_tools) {
  if (-not (Get-Command "go" -ErrorAction Ignore) ) {
    . $PROFILE.CurrentUserAllHosts
  }
  if (Get-Command "go" -ErrorAction Ignore)  {
    GO111MODULE=on go get -u -v mvdan.cc/gofumpt 
    GO111MODULE=on go get -u -v golang.org/x/tools/gopls 
    GO111MODULE=off go get -u -v github.com/github-release/github-release 
    GO111MODULE=off go get -u -v github.com/mdempsky/gocode 
    GO111MODULE=off go get -u -v github.com/uudashr/gopkgs/cmd/gopkgs 
    GO111MODULE=off go get -u -v github.com/ramya-rao-a/go-outline 
    GO111MODULE=off go get -u -v github.com/acroca/go-symbols 
    GO111MODULE=off go get -u -v golang.org/x/tools/cmd/guru 
    GO111MODULE=off go get -u -v golang.org/x/tools/cmd/gorename 
    GO111MODULE=off go get -u -v github.com/fatih/gomodifytags 
    GO111MODULE=off go get -u -v github.com/haya14busa/goplay/cmd/goplay 
    GO111MODULE=off go get -u -v github.com/josharian/impl 
    GO111MODULE=off go get -u -v github.com/tylerb/gotype-live 
    GO111MODULE=off go get -u -v github.com/rogpeppe/godef 
    GO111MODULE=off go get -u -v github.com/zmb3/gogetdoc 
    GO111MODULE=off go get -u -v golang.org/x/tools/cmd/goimports 
    GO111MODULE=off go get -u -v github.com/sqs/goreturns 
    GO111MODULE=off go get -u -v winterdrache.de/goformat/goformat 
    GO111MODULE=off go get -u -v golang.org/x/lint/golint 
    GO111MODULE=off go get -u -v github.com/cweill/gotests/... 
    GO111MODULE=off go get -u -v github.com/alecthomas/gometalinter 
    GO111MODULE=off go get -u -v honnef.co/go/tools/... 
    GO111MODULE=off go get -u -v github.com/mgechev/revive 
    GO111MODULE=off go get -u -v github.com/sourcegraph/go-langserver 
    GO111MODULE=off go get -u -v github.com/go-delve/delve/cmd/dlv 
    GO111MODULE=off go get -u -v github.com/davidrjenni/reftools/cmd/fillstruct 
    GO111MODULE=off go get -u -v github.com/godoctor/godoctor 
    GO111MODULE=off go get -u -v github.com/cuonglm/gocmt 
    GO111MODULE=off go get -u -v github.com/palantir/go-compiles 
    GO111MODULE=off go get -u -v github.com/mohae/nocomment/cmd/nocomment 
    GO111MODULE=off go get -u -v github.com/eandre/discover/...  
    GO111MODULE=off go get -u -v honnef.co/go/tools/cmd/staticcheck
    go get -u -v -d github.com/stamblerre/gocode
    go build -o  $(go env GOPATH)/bin/gocode-gomod github.com/stamblerre/gocode
    Push-Location $(go env GOPATH)/src/honnef.co/go/tools/cmd/staticcheck
    git checkout "$STATIC_CHECK"
    go get
    go install
    Pop-Location
  }
}
[bool] $shim = $opt.s -or $opt.shim
[bool] $update = $opt.u -or $opt.update
# [ NOTE ] => Reset $erroractionpreference to original value
$erroractionpreference = $old_erroractionpreference
success "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

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