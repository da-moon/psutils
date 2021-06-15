#
# ────────────────────────────────────────────────────────── I ──────────
#   :::::: F U N C T I O N S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────
#

# ─── MESSAGE ────────────────────────────────────────────────────────────────────  
function abort($msg, [int] $exit_code = 1) { 
  write-host $msg -f red
  exit $exit_code
}
function error($msg) { 
  write-host "[ERROR] $msg" -f darkred 
}
function warn($msg) {
  write-host "[WARN]  $msg" -f darkyellow 
}
function info($msg) {  
  write-host "[INFO]  $msg" -f darkcyan 
}
function debug($msg) {  
  write-host "[DEBUG]  $msg" -f darkgray 
}
function success($msg) { 
  write-host  "[DONE] $msg" -f darkgreen 
}
Function Debug-String {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [string] $String
    ,
    [switch] $CaretNotation
  )

  begin {
    $re = [regex] '\p{C}'
  }
  process {
    $re.Replace($String, {
        param($match)
        $handled = $False
        if (-not $CaretNotation) {
          $handled = $True
          switch ([Int16] [char] $match.Value) {
            0 { '`0'; break }
            7 { '`a'; break }
            8 { '`b'; break }
            12 { '`f'; break }
            10 { '`n'; break }
            13 { '`r'; break }
            9 { '`t'; break }
            11 { '`v'; break }
            default { $handled = $false }
          }
        }
        if (-not $handled) {
          switch ([Int16] [char] $match.Value) {
            10 { '$'; break } 
            { $_ -ge 0 -and $_ -le 31 -or $_ -eq 127 } {
              '^' + [char] (64 + $_)
              break
            }
            default { '`u{{{0}}}' -f ([int16] [char] $_).ToString('x') }
          }
        }
      })
  }
}
# ─── SYSTEM UTILITY FUNCTIONS ───────────────────────────────────────────────────
# [ TODO ] use pwd function
# function ssh([Parameter(ValueFromRemainingArguments = $true)]$params) { & ssh -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' $params }
function Set-SSH-Config { 
  param (
    [Parameter(Mandatory = $true)][string] $hostname,
    [Parameter(Mandatory = $true)][string] $user,
    [Parameter(Mandatory = $true)][string] $addr
  )
  (Get-Content -Raw $Env:UserProfile\.ssh\config) `
    -replace ('(?s)\r?\nHost {0}.*?MACs hmac-sha2-512\r?\n' `
      -f $hostname) `
  | Set-Content $Env:UserProfile\.ssh\config ;
  "`nHost {0}
    `tHostName {1}
    `tUser {2}
    `tStrictHostKeyChecking no
    `tCheckHostIP no
    `tServerAliveInterval 240
    `tXAuthLocation /usr/sbin/xauth
    `tForwardX11 yes
    `tForwardX11Trusted yes
    `tUserKnownHostsFile /dev/null
    `tMACs hmac-sha2-512`n" -f `
    $hostname, `
    $addr, `
    $user `
  | Out-File -Encoding ascii -Append $Env:UserProfile\.ssh\config ;
  
  ((Get-Content -Raw $Env:UserProfile\.ssh\config ) `
      -replace "(?m)^\s*`r`n", '').trim() `
    -replace "`t", "  " `
    -replace "^\s\s*", "  " `
  | Set-Content $Env:UserProfile\.ssh\config ;
}
Function Set-WSL-DNS {
  Get-DnsClientServerAddress -AddressFamily ipv4 | `
    Select-Object -ExpandProperty ServerAddresses | `
    Get-Unique | `
    Select-Object -First 3 | `
    ForEach-Object { `
      wsl -u root -- `
      /bin/bash -c ('
    set -ex;
    sed -i \"/nameserver {0}/d\" /etc/resolv.conf && \
    echo \"nameserver {0}\" >> /etc/resolv.conf
    ' -f $_) }
}
function Test-Admin {
  return ([System.Security.Principal.WindowsIdentity]::GetCurrent().UserClaims | ? { $_.Value -eq 'S-1-5-32-544' })
}
Function Get-CoreCount() {
  Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty NumberOfLogicalProcessors
}
Function Get-Hostname() {
  return (Get-WmiObject -Class Win32_ComputerSystem -Property Name).Name
}
Function Get-Environment-Variables {
  param (
    [Parameter(Mandatory = $false)][string] $Variable
  )
  if ($Variable) {
    Get-ChildItem Env:* | `
      Where-Object -FilterScript { $_.Name -match $Variable } | Select-Object -ExpandProperty Value
    return
  }
  Get-ChildItem Env:*
}
# ─── PATHUTILS ──────────────────────────────────────────────────────────────────
Function Get-WD() {
  param (
    [string] $path
  )
  Get-Location | Select-Object -ExpandProperty Path
}
function add_line_to_file([string] $line, [string] $path) {
  $parent = Split-Path -parent $path 
  if (-not(Test-Path -Path $parent -PathType Container)) {
    warn "The directory [$parent] does not exist.trying to create it."
    try {
      $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
      info "The directory [$parent] has been created."
    } catch {
      throw $_.Exception.Message
    }
  }
  if (-not(Test-Path -Path $path -PathType Leaf)) {
    try {
      $null = New-Item -ItemType File -Path $path -Force -ErrorAction Stop
      info "The file [$path] has been created."
    } catch {
      throw $_.Exception.Message
    }
  }
  If (!(Select-String -Path $path -pattern $line)) {
    $line | Out-File "$path"  -Encoding ascii -Append
  }
}
function add_line_to_profile([string] $line) {
  add_line_to_file "$line" $PROFILE.CurrentUserAllHosts
}

# ─── DOCKER FUNCTION ────────────────────────────────────────────────────────────
# [ TODO ] => add function to update host's ssh config for ease of sshing into the
# container
function Remove-StoppedContainers {  
  docker container rm $(docker container ls -q)
}
function Remove-AllContainers {  
  docker container rm -f $(docker container ls -aq)
}
function Get-ContainerIPAddress {  
  param (
    [string] $id
  )
  & docker inspect --format '{{ .NetworkSettings.Networks.nat.IPAddress }}' $id
}

# ─── HYPERV FUNCTONS ────────────────────────────────────────────────────────────

function Set-Hyperv-Down { 
  param (
    [string] $name = $Env:VMName
  )
  $box = Get-VM -Name $name -ErrorAction SilentlyContinue
  if ($box) {
    if ($box.State -ne "off" ) {
      Stop-VM -TurnOff -Force -Name $name
    }
  }
}
function Get-Hyperv-IP-Addr { 
  param (
    [string] $name = $Env:VMName
  )
  $box = Get-VM -Name $name -ErrorAction SilentlyContinue
  if ($box) {
    if ($box.State -ne "off" ) {
      $IPV4Pattern = '^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$'
      Get-Vm -Name $Env:VMName  | `
        Select-Object -ExpandProperty Networkadapters | `
        Select-Object -ExpandProperty IPAddresses | `
        Where-Object -FilterScript { $_ -match $IPV4Pattern }
    }
  }
}

function Set-Hyperv-Up { 
  param (
    [string] $name = $Env:VMName
  )
  $box = Get-VM -Name $name -ErrorAction SilentlyContinue
  if ($box) {
    if ($box.State -ne "Running" ) {
      Start-VM -Name $name
    }
    # ssh config setup
    $addr = Get-Hyperv-IP-Addr | Select-Object -First 1
    # [ NOTE ] : we are assuming that the box's username is
    # the same as the host's logged in user
    Set-SSH-Config $name $Env:USERNAME $addr
  }
}
function New-Hyperv-Session { 
  param (
    [string] $name = $Env:VMName
  )
  Set-Hyperv-Up $name
  VMConnect $hostname $name
  $hostname = Get-Hostname ;
}

#
# ────────────────────────────────────────────────────── I ──────────
#   :::::: A L I A S E S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────
#

# ─── TERRAFORM ALIASES ──────────────────────────────────────────────────────────
function tf([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform $params }
function tfi([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform init $params }
function tfa([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform apply -auto-approve $params }
function tfd([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform destroy -auto-approve $params }
function tfp([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform plan $params }
function tfw([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform workspace $params }
function tfwl([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform workspace list $params }
function tfws([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform workspace select $params }
function tfo([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform output $params }
# ─── HYPERV ALIASES ─────────────────────────────────────────────────────────────
Set-Alias vmup Set-Hyperv-Up
Set-Alias vmdown Set-Hyperv-Down
Set-Alias vmip Get-Hyperv-IP-Addr
Set-Alias vmc New-Hyperv-Session
Set-Alias lsvm Get-VM
# ─── NIX ALIASES ────────────────────────────────────────────────────────────────
Set-Alias nproc  Get-CoreCount
Set-Alias hostname  Get-Hostname
Set-Alias which  Get-Command
Set-Alias printenv Get-Environment-Variables
If (Test-Path Alias:pwd) { Remove-Item Alias:pwd }
Set-Alias pwd Get-WD
# ─── DOCKER ALIASES ─────────────────────────────────────────────────────────────
Set-Alias drm  Remove-StoppedContainers
Set-Alias drmf  Remove-AllContainers  
Set-Alias dip  Get-ContainerIPAddress  

#
# ────────────────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: E N V I R O N M E N T   V A R I A B L E S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────────────────────────────
#

# ─── VIRTUALIZATION ENVIRONMENT VARIABLES ───────────────────────────────────────
$Env:VMName = 'ArchLinux'
$Env:VAGRANT_DEFAULT_PROVIDER = "hyperv"
# ─── DOCKER ENVIRONMENT VARIABLES ───────────────────────────────────────────────
$Env:DOCKER_BUILDKIT = 1
$Env:COMPOSE_DOCKER_CLI_BUILD = 1
$Env:BUILDKIT_PROGRESS = "plain"
# ─── PYTHON ENVIRONMENT VARIABLES ───────────────────────────────────────────────
$Env:PATH = $Env:PATH + ";$HOME\.poetry\bin" + ";$HOME\AppData\Local\bin"
# ─── GOLANG ENVIRONMENT VARIABLES ───────────────────────────────────────────────
$Env:GOROOT = $Env:SystemDrive + "\go"
$Env:GOPATH = $Env:UserProfile + "\go"
$Env:GO111MODULE = "on"
$Env:PATH = "$Env:GOROOT\bin;$Env:GOPATH\bin;$Env:PATH"
# ─── MISC ENVIRONMENT VARIABLES ─────────────────────────────────────────────────
$Env:DISPLAY = "localhost:0.0"
$Env:VAULT_SKIP_VERIFY = "true"
$Env:CONSUL_SCHEME = "https"
$Env:CONSUL_HTTP_SSL = "true"
$Env:CONSUL_HTTP_SSL_VERIFY = "false"
