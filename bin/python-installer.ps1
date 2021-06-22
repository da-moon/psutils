# https://github.com/xenron/sandbox-github-clone/blob/master/hmmlearn/hmmlearn/continuous_integration/appveyor/install.ps1
# https://github.com/tgckpg/Dockerhub/blob/master/python/3.9.0-embed-win-nano-2004.dockerfile
# https://github.com/rkttu/python-nanoserver/blob/master/Dockerfile
$PYTHON_PRERELEASE_REGEX = @"
(?x)
(?<major>\d+)
\.
(?<minor>\d+)
\.
(?<micro>\d+)
(?<prerelease>[a-z]{1,2}\d+)
"@
function ParsePythonVersion () {
  param (
    [string] $python_version = "3.9.2"
  )
  if ($python_version -match $PYTHON_PRERELEASE_REGEX) {
    return ([int]$matches.major, [int]$matches.minor, [int]$matches.micro,
      $matches.prerelease)
  }
  $version_obj = [version]$python_version
  return ($version_obj.major, $version_obj.minor, $version_obj.build, "")
}
param($cmd)
set-strictmode -off
if (($PSVersionTable.PSVersion.Major) -lt 5) {
  Write-Output "PowerShell 5 or later is required to run python-installer."
  Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
  break
}

# [ NOTE ] => show notification to change execution policy:
$allowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
if ((Get-ExecutionPolicy).ToString() -notin $allowedExecutionPolicy) {
  Write-Output "PowerShell requires an execution policy in [$($allowedExecutionPolicy -join ", ")] to run python-installer."
  Write-Output "For example, to set the execution policy to 'RemoteSigned' please run :"
  Write-Output "'Set-ExecutionPolicy RemsoteSigned -scope CurrentUser'"
  break
}
# [ NOTE ] => quit if anything goes wrong
$old_erroractionpreference = $erroractionpreference
$erroractionpreference = 'stop'

[string] $architecture = reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE | ForEach-Object { ($_ -split "\s+")[3] }
$architecture = $architecture.ToLower();
$architecture = $architecture.Trim();
if ($architecture -eq "arm64") {
  exit 1
}
if ($architecture -eq "amd64") {
  $platform_suffix = "$architecture"
}
$PYTHON_URL = "https://www.python.org/ftp/python"
[string] $python_version = "3.9.2"
$major, $minor, $micro, $prerelease = ParsePythonVersion $python_version
if (($major -le 2 -and $micro -eq 0) `
    -or ($major -eq 3 -and $minor -le 2 -and $micro -eq 0) `
) {
  $PYTHON_URL='{0}/{1}' -f $PYTHON_URL,"$major.$minor"
  $python_version = "$major.$minor$prerelease"
} else {
  $PYTHON_URL='{0}/{1}' -f $PYTHON_URL,"$major.$minor.$micro"
}
if ($prerelease) {
  if (($major -le 2) `
      -or ($major -eq 3 -and $minor -eq 1) `
      -or ($major -eq 3 -and $minor -eq 2) `
      -or ($major -eq 3 -and $minor -eq 3) `
  ) {
    $PYTHON_URL = '{0}/prev' -f $PYTHON_URL
  }
}
$PYTHON_URL = '{0}/{1}' -f $PYTHON_URL, "python-$python_version-embed-$platform_suffix.zip"
$NETWORK_IO_URL = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1';
Invoke-Expression (New-Object net.webclient).downloadstring($NETWORK_IO_URL);
$TMP_DIR = $Env:TEMP + '\python';
$ZIP_FILE = $TMP_DIR + '\python.zip';
$GET_PIP_URL = "https://bootstrap.pypa.io/get-pip.py"
download $PYTHON_URL $ZIP_FILE
$python_home = '{0}\python' -f $Env:ProgramFiles
if (!(Test-Path $python_home)) { New-Item -Force -Type Directory -Path $python_home | Out-Null } ;
Expand-Archive $ZIP_FILE -ErrorAction SilentlyContinue -DestinationPath $python_home -Force | Out-Null ;
Get-ChildItem -Path $python_home -Filter *._pth -File | ForEach-Object {
  Move-Item -Force -Path $_.FullName -Destination ($_.FullName + '.bak')
}
Add-Content -Path $Profile.CurrentUserAllHosts -Value ('$Env:PATH="$Env:PATH;{0}"' -f $python_home)
Add-Content -Path $Profile.CurrentUserAllHosts -Value ('$Env:PATH="$Env:PATH;{0}"' -f ($python_home + '\Scripts'))
.  $Profile.CurrentUserAllHosts
python --version | Out-Null
$Env:PYTHON_PIP_VERSION = "21.1.2"
# $PYTHON_PIP_VERSION = "20.2.4"
$PIP_SCRIPT = $TMP_DIR + '\get-pip.py';
download $GET_PIP_URL $PIP_SCRIPT
python $PIP_SCRIPT `
        --disable-pip-version-check `
        --no-cache-dir `
        ('pip=={0}' -f $Env:PYTHON_PIP_VERSION);
Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null;