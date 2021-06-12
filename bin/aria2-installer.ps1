# ────────────────────────────────────────────────────────────────────────────────
# powershell -ExecutionPolicy Bypass -File bin\aria2-installer.ps1
# ────────────────────────────────────────────────────────────────────────────────
# run the following for execution over the internet:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   iwr -useb 'https://raw.githubusercontent.com/da-moon/psutils/master/bin/aria2-installer.ps1'| iex
# ────────────────────────────────────────────────────────────────────────────────

param($cmd)
set-strictmode -off
# ─── VARIABLES ──────────────────────────────────────────────────────────────────
# [ NOTE ] => quit if anything goes wrong
$old_erroractionpreference = $erroractionpreference
$erroractionpreference = 'stop'
[string] $ARIA2_VERSION = "1.35.0"


# ─── MESSAGE FUNCTIONS ──────────────────────────────────────────────────────────
function abort($msg, [int] $exit_code = 1) { Write-Host $msg -f red; exit $exit_code }
function error($msg) { Write-Host "[ ERROR ] $msg" -f darkred }
function warn($msg) { Write-Host "[ WARN ]  $msg" -f darkyellow }
function info($msg) { Write-Host "[ INFO ]  $msg" -f DarkBlue }
function debug($obj) {
  $prefix = "DEBUG[$(Get-Date -UFormat %s)]"
  $param = $MyInvocation.Line.Replace($MyInvocation.InvocationName, '').Trim()
  $msg = $obj | Out-String -Stream

  if ($null -eq $obj -or $null -eq $msg) {
    Write-Host "$prefix $param = " -f DarkCyan -NoNewline
    Write-Host '$null' -f DarkYellow -NoNewline
    Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
    return
  }

  if ($msg.GetType() -eq [System.Object[]]) {
    Write-Host "$prefix $param ($($obj.GetType()))" -f DarkCyan -NoNewline
    Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
    $msg | Where-Object { ![String]::IsNullOrWhiteSpace($_) } |
    Select-Object -Skip 2 | # Skip headers
    ForEach-Object {
      Write-Host "$prefix $param.$($_)" -f DarkCyan
    }
  } else {
    Write-Host "$prefix $param = $($msg.Trim())" -f DarkCyan -NoNewline
    Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
  }
}
function success($msg) { Write-Host $msg -f darkgreen }
# ─── CLI PARSER ─────────────────────────────────────────────────────────────────
function debug_opt([Hashtable]$opt) {
  $opt.GetEnumerator() | ForEach-Object {
    $message = '{0}=>{1}' -f $_.key, $_.value
    Write-Host $message -f darkgreen
  }

}
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
  
# ─── NETWORK IO ─────────────────────────────────────────────────────────────────
function set_tls_policies() {
  [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
}
function download([string]$url, [string] $targetFile) {
  set_tls_policies ;
  $dir = Split-Path -parent $targetFile
  if (-not(Test-Path -Path $dir -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
  }

  $uri = New-Object "System.Uri" "$url"
  $request = [System.Net.HttpWebRequest]::Create($uri)
  $request.set_Timeout(15000)
  $response = $request.GetResponse()
  $totalLength = [System.Math]::Floor($response.get_ContentLength() / 1024)
  $responseStream = $response.GetResponseStream()
  $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
  $buffer = New-Object byte[] 10KB
  $count = $responseStream.Read($buffer, 0, $buffer.length)
  $downloadedBytes = $count
  while ($count -gt 0) {
    $targetStream.Write($buffer, 0, $count)
    $count = $responseStream.Read($buffer, 0, $buffer.length)
    $downloadedBytes = $downloadedBytes + $count
    Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes / 1024)) / $totalLength) * 100)
  }
  Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
  $targetStream.Flush()
  $targetStream.Close()
  $targetStream.Dispose()
  $responseStream.Dispose()
}
# ─── UTIL FUNCTIONS ─────────────────────────────────────────────────────────────
function validate_semver {
  param (
    [string] $version = $ARIA2_VERSION
  )
  if (!($version -match '^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$' )) {
    throw ('version ({0}) must match the regex "^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$"' -f $version);
  }
}

# ─── CLI HELP ───────────────────────────────────────────────────────────────────
function usage() {
  Write-Host "Usage: aria2-installer [options]" -f darkgreen
}
function summary() {
  Write-Host "Summary: script to install aria2" -f darkyellow
}
function help() {
  usage
  Write-Host ""
  summary
  Write-Host " 
Help: installs aria2
  this script can be used inside Windows based Docker images; e.g:
  NanoServer Image
Options:
  -v, --version                 aria2 version
                                Default : $ARIA2_VERSION
  -h, --help                    shows help message
" -f darkgray
}

#
# ────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: E X E C U T I O N   S T A R T : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────────────────
#
if (($PSVersionTable.PSVersion.Major) -lt 5) {
  Write-Output "PowerShell 5 or later is required to run aria2-installer."
  Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
  $erroractionpreference = $old_erroractionpreference
  break
}

# [ NOTE ] => show notification to change execution policy:
$allowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
if ((Get-ExecutionPolicy).ToString() -notin $allowedExecutionPolicy) {
  Write-Output "PowerShell requires an execution policy in [$($allowedExecutionPolicy -join ", ")] to run aria2-installer."
  Write-Output "For example, to set the execution policy to 'RemoteSigned' please run :"
  Write-Output "'Set-ExecutionPolicy RemsoteSigned -scope CurrentUser'"
  $erroractionpreference = $old_erroractionpreference
  break
}
if ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -notcontains 'Tls12') {
  Write-Output "aria2-installer requires at least .NET Framework 4.5"
  Write-Output "Please download and install it first:"
  Write-Output "https://www.microsoft.com/net/download"
  $erroractionpreference = $old_erroractionpreference
  break
}


if ($Env:PROCESSOR_ARCHITECTURE.ToLower() -ne 'amd64' ) {
  $erroractionpreference = $old_erroractionpreference
  abort 'processor architecture {0} is not supported' -f $Env:PROCESSOR_ARCHITECTURE.ToLower() 
}

Clear-Host
if (-not ( $cmd -or $args)) {
  help
  exit 0
}
if ((!$cmd -or !$args) -and @('--help', '-h') -contains ($cmd + $args)) {
  help
  exit 0
}
$long_flags = @(
  'version'
)
$opt, $args , $err = getopt $args 'v:' $long_flags

if ($err) { "aria2-installer : $err"; exit 1 }
if (($cmd) -and ($cmd.startswith('--'))) {
  $opt_cmd, $args_cmd , $err = getopt $cmd '' $long_flags
  if ($err) { "aria2-installer : $err"; exit 1 }
  $opt_cmd.GetEnumerator() | ForEach-Object {
    $opt[$_.key.ToString()] = $_.value
    if (($_.key.ToString() -eq 'install') -and ($args_cmd)) {
      $args = $args_cmd
    }
  }
}
$start_time = Get-Date
if ($opt['version']) { $ARIA2_VERSION = $opt['version'] }
elseif ($opt['v']) { $ARIA2_VERSION = $opt['v'] }
info 'Verifying validity of given Aria2 Version {0}' -f $ARIA2_VERSION ;
validate_semver $ARIA2_VERSION
$DOWNLOAD_URL='https://github.com/aria2/aria2/releases/download/release-{0}/aria2-{0}-win-64bit-build1.zip' -f $ARIA2_VERSION;
info 'downloading aria2 {0} from {1}' -f $ARIA2_VERSION,$DOWNLOAD_URL;
$TMP_DIR = $Env:TEMP + '\aria2';
$ZIP_FILE=$TMP_DIR + '\aria2.zip';
Remove-Item -Path $TMP_DIR -Recurse -Force  | Out-Null ;
download $DOWNLOAD_URL $ZIP_FILE ;
New-Item -Type Directory -Path ($Env:ProgramData+'\Bin') -Force -ErrorAction SilentlyContinue  | Out-Null ;
Expand-Archive $ZIP_FILE -DestinationPath $TMP_DIR -Force  | Out-Null ;
Remove-Item -Path $ZIP_FILE -Recurse -Force  | Out-Null ;
Remove-Item -Path ($Env:ProgramData+ '\Bin') -Force  | Out-Null ;
Copy-Item ($TMP_DIR + '\aria2*\aria2c.exe')  ($Env:ProgramData+ '\Bin') -Force | Out-Null ;
aria2c --version | Out-Null ;
Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null ;
# [ NOTE ] => Reset $erroractionpreference to original value
$erroractionpreference = $old_erroractionpreference
success "Time taken: $(((Get-Date).Subtract($start_time)).Seconds) second(s)"
exit 0