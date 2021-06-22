#
# ────────────────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: E N V I R O N M E N T   V A R I A B L E S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────────────────────────────
#

# ─── FOR GIT TO CORRECTLY SHOW UNICODE FILES CONTENT ────────────────────────────
$Env:LANG = "en_US.UTF-8";
# ─── MODULES ────────────────────────────────────────────────────────────────────
$modules = @()
$modules += 'PowerShellGet'
$modules += 'BitsTransfer'
$modules += 'Terminal-Icons'
$modules += 'cd-extras'
$modules += 'powershell-yaml'
$modules += 'oh-my-posh'
$modules += 'posh-git'
$modules += 'posh-docker'
$modules += 'DockerCompletion'
# https://github.com/jdhitsolutions/PSScriptTools#General-Tools
$modules += 'PSScriptTools'
$modules += 'PSReadLine'


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
  Write-Host "[INFO] $msg" -f darkcyan
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
        }
        else {
          $opts.$name = $true
        }
      }
      else {
        return err "Option --$name not recognized."
      }
    }
    elseif ($arg.startswith('-') -and $arg -ne '-') {
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
          }
          else {
            $opts.$letter = $true
          }
        }
        else {
          return err "Option -$letter not recognized."
        }
      }
    }
    else {
      $rem += $arg
    }
  }

  $opts, $rem
}

# ─── PACKAGE MANAGEMENT ─────────────────────────────────────────────────────────
# https://github.com/SorenMaagaard/dotfiles/blob/master/powershell/profile.ps1

function Update-Repo {
  Begin {
    info "Updating Repo ..."
  }
  Process {
    $packageProviders = PackageManagement\Get-PackageProvider -ListAvailable
    $checkPowerShellGet = $packageProviders | Where-Object name -eq "PowerShellGet"
    $checkNuget = $packageProviders | Where-Object name -eq "NuGet"
    $checkPSGallery = Get-PSRepository PSGallery
    if (!$checkPSGallery -or $checkPSGallery.InstallationPolicy -ne 'Trusted') {
      Set-PSRepository PSGallery -InstallationPolicy trusted -SourceLocation "https://www.powershellgallery.com/api/v2"
    }
    if (!$checkPowerShellGet) {
      PackageManagement\Get-PackageProvider -Name PowerShellGet -Force
    }
    if (!$checkNuget) {
      PackageManagement\Get-PackageProvider -Name NuGet -Force
    } 
  }
  End {
    success "Updating Repo ..."
  }
}
function Install-Modules {
  param(
    [parameter(Mandatory, ValueFromPipeline)]
    [string[]] $modulesNames
  )
  Begin {
    info "Installing Modules..."
    Import-Module PowerShellGet -ErrorAction SilentlyContinue
    Update-Repo
  }
  Process {
    $installedModules = Get-InstalledModule
    foreach ($moduleName in $modulesNames) {
      if (!(Get-Module -Name $moduleName)) {
        Try {
          info "Checking $($moduleName)"
          $online = Find-Module $moduleName
        }
        Catch {
          warn "Module $($module.name) was not found in the PSGallery"
          continue
        }
        if ($online) {
          if ($installedModules.Name -notcontains $moduleName) {
            info "installing $($moduleName) module"
            Install-Module $moduleName `-Force -AllowClobber -SkipPublisherCheck `
              -Scope CurrentUser `
              -ErrorAction SilentlyContinue
            success "installing $($moduleName) module"
          }
        }
      }
    }
  }
  End {
    success "Installing Modules..."
  }
}
# [ NOTE ] Modules should be installed on User scope
function Get-EnsureModule {
  param(
    [parameter(Mandatory, ValueFromPipeline)]
    [string[]] $modulesNames
  )
  Begin {
    info "Ensuring Modules..."
    Update-Repo
  }
  Process {
    foreach ($moduleName in $modulesNames) {
      if (!(Get-Module -Name $moduleName)) {
        try {
          info "importing $($moduleName)"
          Import-Module $moduleName -ErrorAction Stop
          success "importing $($moduleName) module"
        }
        catch {
          info "installing $($moduleName) module"
          Install-Module $moduleName `-Force -AllowClobber -SkipPublisherCheck -Scope CurrentUser `
            success "installing $($moduleName) module"
          info "importing $($moduleName) module"
          Import-Module $moduleName
          success "importing $($moduleName) module"
        }
      }
    }
  }
  End {
    success "Ensuring Modules..."
  }
}
function Update-Modules {
  Begin {
    info "updating Modules..."
    Update-Repo
    Import-Module PowerShellGet -ErrorAction SilentlyContinue
  }
  Process {
    $installedModules = Get-InstalledModule
    foreach ($module in $installedModules) {
      Try {
        info "Checking $($module.name)"
        $online = Find-Module $module.name
        success "Checking $($module.name)"
      }
      Catch {
        warn "Module $($module.name) was not found in the PSGallery"
      }
      if ($online.version -gt $module.version) {
        info "Updating $($module.name) module"
        Update-Module -SkipPublisherCheck `
          -Name $module.name `
          -ErrorAction SilentlyContinue
        success "Updating $($module.name) module"
      }
    }
  }
  End {
    success "updating Modules..."
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
function Get-DriveInfo {
  Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used } | Where-Object { $_.Name -ne "Temp" } | Sort-Object Name
}

function Get-DriveInfoView {
  Get-DriveInfo | Format-Table -AutoSize
}

# # [ NOTE ] https://github.com/grigoryvp/dotfiles/blob/master/profile.ps1
function Search-Input() {
  [OutputType([String])]
  param (
    [Parameter(Mandatory = $true)][string] $pattern,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, parametersetname = "nopipeline")][String]$source

  )
  Begin {
    $is_file = $false
    if ($PSCmdlet.ParameterSetName -eq "nopipeline") {
      $is_file = $true
    }
  }
  Process {
    if ($is_file) {
      return Select-String -Path $source -Pattern $pattern
    }
    return $source | Select-String -Pattern $pattern
  }
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
function Get-Content-Bat {
  param (
    [Parameter(Mandatory = $true)][string] $path
  )
  & bat -pp $path
}
function Watch-File {
  param (
    [Parameter(Mandatory = $true)][string] $path
  )

  Get-Content $path -Wait
}
Function Get-WD() {
  param (
    [string] $path
  )
  Get-Location | Select-Object -ExpandProperty Path
}
function Remove-With-Recurse($path) { Remove-Item $path -Recurse -Force }

# ─── DOCKER ─────────────────────────────────────────────────────────────────────
function Remove-StoppedContainers {
  & docker container rm $(docker container ls -q)
}
function Remove-AllContainers {
  & docker container rm -f $(docker container ls -aq)
}
function Get-ContainerIPAddress {
  param (
    [string] $id
  )
  & docker inspect --format '{{ .NetworkSettings.Networks.nat.IPAddress }}' $id
}
function Get-Containers {
  return (& docker ps -a)
}
function Get-Images {
  return (& docker images -a)
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
  $addr = Get-Vm -Name $name  `
  | Select-Object -ExpandProperty Networkadapters `
  | Select-Object -ExpandProperty IPAddresses `
  | Where-Object -FilterScript { $_ -match $IPV4Pattern } `
  Select-Object -First 1
  while (-not($addr) -or ($addr.Length == 0) ) {
    if ($counter -eq 0) {
      abort " $name network is not ready "
    }
    warn "[ $counter ] $name network is not ready. retrying"
    Start-Sleep -Seconds 3
    $IPV4Pattern = '^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$'
    $addr = Get-Vm -Name $name  `
    | Select-Object -ExpandProperty Networkadapters `
    | Select-Object -ExpandProperty IPAddresses `
    | Where-Object -FilterScript { $_ -match $IPV4Pattern } `
    Select-Object -First 1
    $counter -= 1;
  }
  # [ NOTE ] : we are assuming that the box's username is
  # the same as the host's logged in user
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
function Set-WSL-DNS {
  # 
  Begin {
    info "Fixing WSL dns nameservers ..."
  }
  Process {
    Get-DnsClientServerAddress -AddressFamily ipv4 | `
      Select-Object -ExpandProperty ServerAddresses | `
      Get-Unique | `
      Select-Object -First 3 | `
      ForEach-Object { `
        info ('adding nameserver "{0}"' -f $_) ;
      wsl -u root -- `
        /bin/bash -c ('
            set -ex;
            sed -i \"/nameserver {0}/d\" /etc/resolv.conf && \
            echo \"nameserver {0}\" >> /etc/resolv.conf
            ' -f $_) ;
      success ('adding nameserver "{0}"' -f $_) ;
    }
  }
  End {
    success "Fixing WSL dns nameservers ..."
  }
}
function Is-Windows {
  ($PSVersionTable.PSVersion.Major -eq 5) -or ($PSVersionTable.Platform -eq "Win32NT")
}
# https://github.com/codaamok/PoSH/blob/master/profile.ps1
function Get-Username {
  param (
    [String]$OS
  )
  if ($OS -eq "Windows") {
    $env:USERNAME
  }
  else {
    $env:USER
  }
}
function RemoveTo-Trash {
  # https://qiita.com/Zuishin/items/1fa77bccd111b55f7bf6
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Path')]
  Param (
    [SupportsWildCards()]
    [Parameter(
      Mandatory = $true,
      Position = 0,
      ParameterSetName = 'Path',
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true
    )]
    [string[]]$Path,

    [Alias('LP')]
    [Alias('PSPath')]
    [Parameter(
      Mandatory = $true,
      Position = 0,
      ParameterSetName = 'LiteralPath',
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $true
    )]
    [string[]]$LiteralPath
  )
  Begin {
    $shell = New-Object -ComObject Shell.Application
    $trash = $shell.NameSpace(10)
  }
  Process {
    if ($PSBoundParameters.ContainsKey('Path')) {
      $Path | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Set-Variable Path
      $targets = Convert-Path $Path
    }
    else {
      $targets = Convert-Path -LiteralPath $LiteralPath
    }
    $targets | ForEach-Object {
      if ($PSCmdlet.ShouldProcess($_)) {
        $trash.MoveHere($_)
      }
    }
  }
}
# https://github.com/grigoryvp/dotfiles/blob/master/profile.ps1
function Update-VscodeExt() {
  $cfgFileName = "package.json";
  if (-not (Test-Path $cfgFileName)) {
    Write-Error "$cfgFileName not found";
    return;
  }
  $cfg = Get-Content $cfgFileName | ConvertFrom-Json;

  $name = $cfg.name;
  if (-not $name) {
    Write-Error "'name' property not found in the $cfgFileName";
    return;
  }
  $publisher = $cfg.publisher;
  if (-not $publisher) {
    Write-Error "'publisher' property not found in the $cfgFileName";
    return;
  }
  $version = $cfg.version;
  if (-not $version) {
    Write-Error "'version' property not found in the $cfgFileName";
    return;
  }

  $verPartList = $version.split(".");

  $extRoot = "$env:USERPROFILE\.vscode\extensions"
  $extDir = "";
  # Try current version and all older build semver since installed
  # extension is often older than the development one.
  for ($i = [int]$verPartList[-1]; $i -ge 0; $i --) {
    $verPartList[-1] = $i
    $curVer = [System.String]::Join(".", $verPartList);
    $extDir = "$extRoot\$publisher.$name-$curVer";
    if (Test-Path $extDir) {
      break;
    }
  }
  if (-not (Test-Path $extDir)) {
    Write-Error "'$extRoot\$publisher.$name-$version...0' dir not found";
    return;
  }

  if (-not (Test-Path -Path $extDir/src)) {
    New-Item -Path $extDir/src -ItemType Directory | Out-Null;
  }
  Copy-Item *.js $extDir;
  Copy-Item *.json $extDir;
  Write-Output "Copied into $extDir";
  if (Test-Path -Path src) {
    Copy-Item src/*.js $extDir/src;
    Copy-Item src/*.json $extDir/src;
    Write-Output "Copied ./src into $extDir/src";
  }
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
# ─── GIT ALIASES ────────────────────────────────────────────────────────────────
# IntegratedDevelopmentEnvironment::ResourceManagement::Git
function ga($path) { git add $path }
function gaa { git add . }
function gct($comment) { git commit -m "$comment" }
function gd { git diff }
function gdf { git diff }
function glg { git log }
function gs { git status -sb }
# ─── NIX FUNCTION ALIAS ─────────────────────────────────────────────────────────
if (Is-Windows) {
  function l { Get-ChildItem $args }
  function la { Get-ChildItem -Force $args }
}
else {
  function l { Get-ChildItem -l $args }
  function la { Get-ChildItem -a $args }
}


#
# ────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: E X E C U T I O N   S T A R T : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────────────────
#
# Use utf-8
chcp 65001
$OutputEncoding = [Console]::OutputEncoding
# [ NOTE ] Establishing Cmdlet Default Parameters
# https://github.com/jkavanagh58/slackgroup/blob/master/ProfilesCollection/sample-profile.ps1
$PSDefaultParameterValues = @{
  "install-module:Confirm" = $False
  "install-module:Verbose" = $False
  "install-module:Force"   = $True
  "install-module:Scope"   = "CurrentUser"
  "update-module:Confirm"  = $False
  "update-module:Verbose"  = $False
  "update-module:Force"    = $True
}

# ─── WINDOWS PACKAGE MANAGEMENT ─────────────────────────────────────────────────
Set-Alias gpkg Get-Package
Set-Alias fpkg Find-Package
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
If (Test-Path Alias:cd) { Remove-Item Alias:cd }
Set-Alias cd Push-Location
If (Test-Path Alias:pwd) { Remove-Item Alias:pwd }
Set-Alias pwd Get-WD
If (Test-Path Alias:cat) { Remove-Item Alias:cat }
Set-Alias cat Get-Content-Bat
Set-Alias size Get-Size
Set-Alias tail Watch-File
Set-Alias grep Search-Input
Set-Alias df Get-DriveInfoView
# ─── DOCKER ALIASES ─────────────────────────────────────────────────────────────
Set-Alias drm  Remove-StoppedContainers
Set-Alias drmf  Remove-AllContainers
Set-Alias dip  Get-ContainerIPAddress
Set-Alias dc  Get-Containers
Set-Alias di  Get-Images
# ─── UTILITY ────────────────────────────────────────────────────────────────────
if (Get-Command fzf -ErrorAction SilentlyContinue) {
  Set-Alias __FILTER fzf
}
if (Is-Windows) {
  If (Test-Path Alias:ls) { Remove-Item Alias:ls }
  Set-Alias ls Get-ChildItem
}
else {
  Set-Alias ls lsd
}
Set-Alias wsldns Set-WSL-DNS
Set-Alias gna Get-NetAdapter
Set-Alias rna Restart-NetAdapter
Set-Alias g git
Set-Alias d Remove-With-Recurse
# ─── READLINE SETTING ───────────────────────────────────────────────────────────
# https://github.com/yukimemi/dotfiles/blob/main/win/Microsoft.PowerShell_profile.ps1
Set-PSReadlineKeyHandler -Key Tab -Function Complete
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key 'Ctrl+a' -Function BeginningOfLine
# ─── STARSHIP SETUP ─────────────────────────────────────────────────────────────
# starship
if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (&starship init powershell)
}
# ─── ASYNC TASKS ────────────────────────────────────────────────────────────────
$function_ctx = [scriptblock]::create(@"
  function info {${function:info}}
  function warn {${function:warn}}
  function success {${function:success}}
  function Set-WSL-DNS {${function:Set-WSL-DNS}}
  function Update-Repo {${function:Update-Repo}}
  function Get-EnsureModule {${function:Get-EnsureModule}}
  function Update-Modules {${function:Update-Modules}}
"@)
$null = Start-Job -InitializationScript $function_ctx -Name "async_module_init" -ScriptBlock { $Using:modules | Get-EnsureModule }
# ────────────────────────────────────────────────────────────────────────────────
$null = Start-Job -InitializationScript $function_ctx -Name "async_update_modules" { Update-Modules }
# ────────────────────────────────────────────────────────────────────────────────
$null = Start-Job -InitializationScript $function_ctx -Name "async_wsl_dns" { Set-WSL-DNS }
# ────────────────────────────────────────────────────────────────────────────────
$timer = New-Object System.Timers.Timer
$timer.Interval = 1000
$timer.AutoReset = $true
Get-EventSubscriber -SourceIdentifier "async" -ErrorAction SilentlyContinue | Unregister-Event
$null = Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier "async" -Action {
  $jobs = Get-Job -Name "async*"
  if ($jobs.count -gt 1) {
    foreach ($job in $jobs) {
      if ($job.State -ne "Running") {
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0 , $host.UI.RawUI.CursorPosition.Y
        $null = Receive-Job $job.Name
        $null = Remove-Job $job.Name
        $null = Unregister-Event $job.Name
      }
    }
    return
  }
  [void]$timer.stop()
  # [ NOTE ] => ensuring cursor position starts at the begining of
  # the line.
  $null = Unregister-Event "async"
  $null = Remove-Job "async"
  $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0 , $host.UI.RawUI.CursorPosition.Y
  success "Asynchronous profile load was completed"
}
info "Asynchronous profile load starting ..."
$timer.Start()
Remove-Variable modules