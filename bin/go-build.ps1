# ────────────────────────────────────────────────────────────────────────────────
# powershell -ExecutionPolicy Bypass -File go-build.ps1
# ────────────────────────────────────────────────────────────────────────────────
# run the following for execution over the internet:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   iwr -useb 'https://raw.githubusercontent.com/da-moon/windows-on-arm/master/go-toolchain.ps1'| iex
# ────────────────────────────────────────────────────────────────────────────────

param($cmd)
set-strictmode -off
if (($PSVersionTable.PSVersion.Major) -lt 5) {
  Write-Output "PowerShell 5 or later is required to run go-build."
  Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
  break
}

# [ NOTE ] => show notification to change execution policy:
$allowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
if ((Get-ExecutionPolicy).ToString() -notin $allowedExecutionPolicy) {
  Write-Output "PowerShell requires an execution policy in [$($allowedExecutionPolicy -join ", ")] to run go-build."
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
$cache_dir="$Env:TEMP\da-moon\psutils"
if (-not(Test-Path -Path $cache_dir -PathType Container)) {
  bootstrap $cache_dir
}
# ────────────────────────────────────────────────────────────────────────────────
$libraries = @("messages","common","path","getopt","shim")
foreach ($library in $libraries) {
  $target = $cache_dir + "\lib\$library.ps1"
  if (-not(Test-Path $target -PathType leaf)) {
    bootstrap $cache_dir
  }
  . $target
}
#
# ─── CLI HELP ───────────────────────────────────────────────────────────────────
#
function usage(){
  Write-Host "Usage: go-build <repo> [options]" -f darkgreen
}

function summary(){
  Write-Host "Summary: builds go packages" -f darkyellow
}
# [ TODO ] =>
# - validate os
# - validate arch
# - check for git
# - check for go in path
function help(){
usage
Write-Host ""
summary
Write-Host " 
Help: builds go packages

Options:
  -a, --artifact                override the location to store built artifact.
  -b, --branch                  override build branch name
  -c, --cpu                     target cpu architecture.
  -l, --ld-flags                extra ldflags to pass in at build time
  -m, --main-package            relative path to 'main' package from repo's root
  -o, --os                      target operating system
  -r, --root-dir                override the root directory to clone the repo

  -s, --shim                    creates a shim for 'go-build' and adds it to path
  -u, --update                  update local copy of 'go-build' script
  
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
if ('--version' -contains $cmd -or (!$cmd -and '-v' -contains $args)) {
  Write-Host "v0.0.1"
}
elseif (@($null, '--help') -contains $cmd -or $args[0] -contains '-h') {
  help
}
else {
  if(!($cmd)) {
    help
  }else{
    # [ NOTE ] =>
    # - https://github.com/lukesampson/psutils/blob/master/say.ps1
    # $opt, $args, $err = getopt $args 'hf:v:r:' @('input-file=','voice=','rate=', 'help')

    $opt, $repo, $err = getopt $args 'abclmorsu:' 'artifact','branch','cpu','ld-flags','main-package','os','root-dir','shim', 'update'
    if ($err) { "go-build : $err"; exit 1 }
    $artifact = $opt.artifact -or $opt.a
    $branch = $opt.branch -or $opt.b
    $cpu = $opt.cpu -or $opt.c
    $ld_flags = $opt.ld_flags -or $opt.l
    $main_package = $opt.main_package -or $opt.m
    $os = $opt.os -or $opt.o
    $root_dir = $opt.root_dir -or $opt.r
    $shim = $opt.s -or $opt.shim
    $update = $opt.u -or $opt.update
    Write-Host "
  artifact=$artifact
  branch=$branch
  cpu=$cpu
  ld_flags=$ld_flags
  main_package=$main_package
  os=$os
  root_dir=$root_dir
  shim=$shim
  update=$update
  " -f darkred
    # if (!$repo) { error '<repo(s)> missing'; usage; exit 1 }
    if ($repo.length -gt 1) {
      try {
        throw [System.ArgumentException] "multiple repos were given: '$repo'"
      } catch {
        abort "ERROR: $_"
      }
    }
  }
  exit 0
}
