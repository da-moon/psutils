#
# ────────────────────────────────────────────────────────── I ──────────
#   :::::: F U N C T I O N S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────
#

# ─── MESSAGE ────────────────────────────────────────────────────────────────────  
function abort($msg, [int] $exit_code = 1) { 
  Write-Host $msg -f red
  exit $exit_code
}
function error($msg) { 
  Write-Host "[ERROR] $msg" -f darkred 
}
function warn($msg) {
  Write-Host "[WARN]  $msg" -f darkyellow 
}
function info($msg) {
  Write-Host "[INFO]  $msg" -f darkcyan 
}
function success($msg) { 
  Write-Host  "[DONE] $msg" -f darkgreen 
}

# ─── DEBUG ──────────────────────────────────────────────────────────────────────
function debug($msg) {  
  Write-Host "[DEBUG]  $msg" -f darkgray 
}
function debug_opt([Hashtable]$opt) {
  $opt.GetEnumerator() | ForEach-Object {
    $message = '{0}=>{1}' -f $_.key, $_.value
    Write-Host $message -f darkgreen
  }
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
# ─── CLI ────────────────────────────────────────────────────────────────────────
function getopt($argv, $shortopts, $longopts) {
  $opts = @{}; $rem = @()

  function err($msg) {
    $opts, $rem, $msg
  }

  function regex_escape($str) {
    return [regex]::escape($str)
  }
  function  validate_argv([Object] $argv) {
    $argv_clone = $argv[$i + 1]
    if (($argv_clone -is [int]) -or ($argv_clone -is [decimal])) { 
      $argv_clone = $argv_clone.ToString()
    }
    if (($argv_clone.startswith('--')) -or ($argv_clone.startswith('-'))) {
      return $false
    }
    return $true

  } 
  # ensure these are arrays
  $argv = @($argv)
  $longopts = @($longopts)

  for ($i = 0; $i -lt $argv.length; $i++) {
    $arg = $argv[$i]
    if ($null -eq $arg) { continue }
    # don't try to parse array arguments
    if ($arg -is [array]) { $rem += , $arg; continue }
    if ($arg -is [int]) { $rem += $arg; continue }
    if ($arg -is [decimal]) { $rem += $arg; continue }
    if ($arg.startswith('--')) {
      $name = $arg.substring(2)
            
      $longopt = $longopts | Where-Object { $_ -match "^$name=?$" }

      if ($longopt) {


        if ($longopt.endswith('=')) {
          # requires arg
          if ($i -eq $argv.length - 1) {
            return err "Option --$name requires an argument."
          }
          if (-not(validate_argv ($argv))) {
            $faulty_arg = $argv[($i + 1)]
            return err "Option --$name got an invalid argument: [ $faulty_arg ]"
          }
          $opts.$name = $argv[++$i]
        } else {
          $opts.$name = $true
        }
      } else {
        return err "Option --$name not recognized."
      }
    } elseif ($arg.startswith('-') -and $arg -ne '-') {
      for ($j = 1; $j -lt $arg.length; $j++) {
        $letter = $arg[$j].tostring()

        if ($shortopts -match "$(regex_escape $letter)`:?") {
          $shortopt = $matches[0]
          if ($shortopt[1] -eq ':') {

            if ($j -ne $arg.length - 1 -or $i -eq $argv.length - 1) {
              return err "Option -$letter requires an argument."
            }
            if (-not(validate_argv ($argv))) {
              $faulty_arg = $argv[($i + 1)]
              return err "Option --$name got an invalid argument: [ $faulty_arg ]"
            }
            $opts.$letter = $argv[++$i]
          } else {
            $opts.$letter = $true
          }
        } else {
          return err "Option -$letter not recognized."
        }
      }
    } else {
      $rem += $arg
    }
  }

  $opts, $rem
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
function Test-Admin {
  return ([System.Security.Principal.WindowsIdentity]::GetCurrent().UserClaims | ? { $_.Value -eq 'S-1-5-32-544' })
}
Function Get-CoreCount() {
  Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty NumberOfLogicalProcessors
}
Function Get-Hostname() {
  return (Get-WmiObject -Class Win32_ComputerSystem -Property Name).Name
}
# [ NOTE ]
# https://github.com/wahidsaleemi/pwshprofile/blob/master/Microsoft.PowerShell_profile.ps1
function Get-Size {
  param (
    [Parameter(Mandatory = $false)][string]$Path = '.',
    [Parameter(Mandatory = $false)][string]$InType = "MB"
  )
  $colItems = (Get-ChildItem $Path -recurse | Measure-Object -property length -sum)
  switch ($InType) {
    "GB" { $ret = "{0:N2}" -f ($colItems.sum / 1GB) + " GB" }
    "MB" { $ret = "{0:N2}" -f ($colItems.sum / 1MB) + " MB" }
    "KB" { $ret = "{0:N2}" -f ($colItems.sum / 1KB) + " KB" }
    "B" { $ret = "{0:N2}" -f ($colItems.sum) + " B" }
    Default { $ret = "{0:N2}" -f ($colItems.sum) + " B" }
  }
  Return $ret
}
# # [ NOTE ] https://github.com/grigoryvp/dotfiles/blob/master/profile.ps1
# function grep() {
#   Select-String -Path $Args[1] -Pattern $Args[0]
# }

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
function Get-Content-Bat {
  param (
    [Parameter(Mandatory = $true)][string] $path
  )
  & bat -pp $path
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
function Set-Hyperv-Up { 
  param (
    [string] $name = $Env:VMName
  )
  $box = Get-VM -Name $name -ErrorAction SilentlyContinue
  while (-not($box)) {
    warn "$name not ready. Waiting"
    Start-Sleep -Seconds 3
    $box = Get-VM -Name $name -ErrorAction SilentlyContinue
  }
  if ($box.State -ne "Running" ) {
    Start-VM -Name $name
  }
  [int]$counter = 5
  # ssh config setup
  $addr = Get-Vm -Name $name  | `
    Select-Object -ExpandProperty Networkadapters | `
    Select-Object -ExpandProperty IPAddresses
  while (-not($addr)) {
    if ($counter -eq 0) {
      abort " $name network is not ready "
    }
    warn "[ $counter ] $name network is not ready. retrying"
    Start-Sleep -Seconds 3
    $addr = Get-Vm -Name $name  | `
      Select-Object -ExpandProperty Networkadapters | `
      Select-Object -ExpandProperty IPAddresses
    $counter -= 1;
  }
  $IPV4Pattern = '^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$'
  $addr = $addr | `
    Where-Object -FilterScript { $_ -match $IPV4Pattern } | `
    Select-Object -First 1
  # # [ NOTE ] : we are assuming that the box's username is
  # # the same as the host's logged in user
  Set-SSH-Config $name $Env:USERNAME $addr
}
function New-Hyperv-Session { 
  param (
    [string] $name = $Env:VMName
  )
  Set-Hyperv-Up $name
  $hostname = Get-Hostname ;
  VMConnect $hostname $name
}
# ─── UTILITY ────────────────────────────────────────────────────────────────────
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
Set-Alias vmc New-Hyperv-Session
Set-Alias lsvm Get-VM
# ─── NIX ALIASES ────────────────────────────────────────────────────────────────
Set-Alias nproc  Get-CoreCount
Set-Alias hostname  Get-Hostname
Set-Alias which  Get-Command
Set-Alias printenv Get-Environment-Variables
# Set-Location
If (Test-Path Alias:cd) { Remove-Item Alias:cd }
Set-Alias cd Push-Location
If (Test-Path Alias:pwd) { Remove-Item Alias:pwd }
Set-Alias pwd Get-WD
# Get-Content
If (Test-Path Alias:cat) { Remove-Item Alias:cat }
Set-Alias cat Get-Content-Bat
Set-Alias size Get-Size
# ─── DOCKER ALIASES ─────────────────────────────────────────────────────────────
Set-Alias drm  Remove-StoppedContainers
Set-Alias drmf  Remove-AllContainers
Set-Alias dip  Get-ContainerIPAddress
# ─── UTILITY ────────────────────────────────────────────────────────────────────
Set-Alias wsldns Set-WSL-DNS

#
# ────────────────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: E N V I R O N M E N T   V A R I A B L E S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────────────────────────────
#

# ─── MODULES ────────────────────────────────────────────────────────────────────
$modules = @()
$modules += 'oh-my-posh'
$modules += 'posh-git'
$modules += 'Terminal-Icons'
$modules += 'posh-docker'
# https://github.com/jdhitsolutions/PSScriptTools#General-Tools
$modules += 'PSScriptTools'
$modules += 'BitsTransfer'
# ─── VIRTUALIZATION ENVIRONMENT VARIABLES ───────────────────────────────────────
$Env:VMName = 'ArchLinux'
$Env:VAGRANT_DEFAULT_PROVIDER = "hyperv"
# ─── DOCKER ENVIRONMENT VARIABLES ───────────────────────────────────────────────
$Env:DOCKER_BUILDKIT = 1
$Env:COMPOSE_DOCKER_CLI_BUILD = 1
$Env:BUILDKIT_PROGRESS = "plain"
# ─── PYTHON ENVIRONMENT VARIABLES ───────────────────────────────────────────────
$Env:PATH = $Env:PATH + ";$HOME\.poetry\bin" + ";$HOME\AppData\Local\bin"
# ─── MISC ENVIRONMENT VARIABLES ─────────────────────────────────────────────────
$Env:DISPLAY = "localhost:0.0"
$Env:VAULT_SKIP_VERIFY = "true"
$Env:CONSUL_SCHEME = "https"
$Env:CONSUL_HTTP_SSL = "true"
$Env:CONSUL_HTTP_SSL_VERIFY = "false"

#
# ────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: E X E C U T I O N   S T A R T : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────────────────
#

# ─── BASHLIKE TAB COMPLETION ────────────────────────────────────────────────────
Set-PSReadlineKeyHandler -Key Tab -Function Complete
# ────────────────────────────────────────────────────────────────────────────────
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
# ─── FIX WSL DNS ────────────────────────────────────────────────────────────────
# Clear-Host
# ─── STARSHIP SETUP ─────────────────────────────────────────────────────────────
Invoke-Expression (&starship init powershell)
# ─── ASYNC TASKS ────────────────────────────────────────────────────────────────
$async_init_block = {
  $repository = Get-PSRepository | Where-Object InstallationPolicy -EQ Trusted -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $repository) {
    Set-PSRepository -name PSGallery -InstallationPolicy Trusted
  }

  foreach ($module in $modules) {
    if (-not(Get-Module -ListAvailable -Name $module)) {
      Install-Module -Scope CurrentUser -Name $module -Repository PSGallery -SkipPublisherCheck
    } 
    Import-Module $module
  }
  Set-WSL-DNS 
}
$null = Start-Job -ScriptBlock $async_init_block -Name "StartUp"
$timer = New-Object System.Timers.Timer
$timer.Interval = 1000
$timer.AutoReset = $true
$null = Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier "StartUp" -Action {
  $jobs = Get-Job -Name "StartUp*"
  if ($jobs.count -gt 1) {
    foreach ($job in $jobs) {
      if ($job.State -ne "Running") {
        Receive-Job $job.Name
        Remove-Job $job.Name
      }
    }
  } else {
    $timer.stop()
    Unregister-Event "StartUp"
    Remove-Job "StartUp"
    success  "Asynchronous profile load completed"
  }
}
info "Asynchronous profile load starting ..."
$timer.Start()