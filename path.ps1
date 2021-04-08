# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#  $path_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/path.ps1'
#  Invoke-Expression (New-Object net.webclient).downloadstring($path_url)
# ────────────────────────────────────────────────────────────────────────────────

#
# ─── PATH UTILS ─────────────────────────────────────────────────────────────────
#
# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

$library="common"
if (Test-Path "$psscriptroot\$library.ps1" -PathType leaf){
  . "$psscriptroot\$library.ps1"
}else{
  $library_url = "https://raw.githubusercontent.com/da-moon/psutils/master/$library.ps1"
  Invoke-Expression (New-Object net.webclient).downloadstring($library_url)
}
function ensure($dir) { 
  if(-not(Test-Path $dir)) { 
    $null=New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
  }
  Resolve-Path $dir
}
function fullpath($path) {
  $executionContext.sessionState.path.getUnresolvedProviderPathFromPSPath($path)
}
function relpath($path) { 
  Resolve-Path -Path "$($myinvocation.psscriptroot)\$path" 
}
function friendly_path($path) {
    $h = (Get-PsProvider 'FileSystem').home; if(!$h.endswith('\')) { $h += '\' }
    if($h -eq '\') { return $path }
    return "$path" -replace ([regex]::escape($h)), "~\"
}

function strip_path($orig_path, $dir) {
    if($null -eq $orig_path) { 
      $orig_path = '' 
    }
    $stripped = [string]::join(';', @( $orig_path.split(';') | Where-Object { $_ -and $_ -ne $dir } ))
    return ($stripped -ne $orig_path), $stripped
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
    if($was_in_path) {
        Write-Output "Removing $(friendly_path $dir) from your path."
        env 'path' $global $newpath
    }

    # current session
    $was_in_path, $newpath = strip_path $env:PATH $dir
    if($was_in_path) { $env:PATH = $newpath }
}
function ensure_in_path($dir, $global) {
    $path = env 'PATH' $global
    $dir = fullpath $dir
    if($path -notmatch [regex]::escape($dir)) {
        Write-Output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path."

        env 'PATH' $global "$dir;$path"
        $env:PATH = "$dir;$env:PATH"
    }
}

function search_in_path($target) {
    $path = (env 'PATH' $false) + ";" + (env 'PATH' $true)
    foreach($dir in $path.split(';')) {
        if(Test-Path "$dir\$target" -pathType leaf) {
            return "$dir\$target"
        }
    }
}


