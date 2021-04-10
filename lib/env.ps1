# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#  $env_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/env.ps1'
#  Invoke-Expression (New-Object net.webclient).downloadstring($env_url)
# ────────────────────────────────────────────────────────────────────────────────

#
# ─── PATH UTILS ─────────────────────────────────────────────────────────────────
#
# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

$library = "path"
if (($psscriptroot) -and (Test-Path "$psscriptroot\$library.ps1" -PathType leaf)) {
  . "$psscriptroot\$library.ps1"
}
else {
  $library_url = "https://raw.githubusercontent.com/da-moon/psutils/master/lib/$library.ps1"
  Invoke-Expression (New-Object net.webclient).downloadstring($library_url)
}
function env($name, $global, $val = '__get') {
  $target = 'User'; if ($global) { $target = 'Machine' }
  if ($val -eq '__get') { [environment]::getEnvironmentVariable($name, $target) }
  else { [environment]::setEnvironmentVariable($name, $val, $target) }
}

function add_first_in_path($dir, $global) {
  $dir = fullpath $dir

  # future sessions
  $null, $currpath = strip_path (env 'path' $global) $dir
  env 'path' $global "$dir;$currpath"

  # this session
  $null, $env:PATH = strip_path $env:PATH $dir
  $env:PATH = "$dir;$env:PATH"
}

function remove_from_path($dir, $global) {
  $dir = fullpath $dir

  # future sessions
  $was_in_path, $newpath = strip_path (env 'path' $global) $dir
  if ($was_in_path) {
    Write-Output "Removing $(friendly_path $dir) from your path."
    env 'path' $global $newpath
  }

  # current session
  $was_in_path, $newpath = strip_path $env:PATH $dir
  if ($was_in_path) { $env:PATH = $newpath }
}
function ensure_in_path($dir, $global) {
  $path = env 'PATH' $global
  $dir = fullpath $dir
  if ($path -notmatch [regex]::escape($dir)) {
    Write-Output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path."

    env 'PATH' $global "$dir;$path"
    $env:PATH = "$dir;$env:PATH"
  }
}

function search_in_path($target) {
  $path = (env 'PATH' $false) + ";" + (env 'PATH' $true)
  foreach ($dir in $path.split(';')) {
    if (Test-Path "$dir\$target" -pathType leaf) {
      return "$dir\$target"
    }
  }
}

# [ NOTE ] => ensures user profile file exists
function ensure_user_profile() {
  $parent = Split-Path -parent $PROFILE.CurrentUserAllHosts
  if (-not(Test-Path -Path $parent -PathType Container)) {
    warn "The directory [$parent] does not exist.trying to create it."
    $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
    info "The directory [$parent] has been created."
  }
  if (-not(Test-Path -Path $PROFILE.CurrentUserAllHosts -PathType Leaf)) {
    $null = New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force -ErrorAction Stop
    info "The file [$PROFILE.CurrentUserAllHosts] has been created."
  }
}