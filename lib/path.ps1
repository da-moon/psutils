# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#  $path_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/path.ps1'
#  Invoke-Expression (New-Object net.webclient).downloadstring($path_url)
# ────────────────────────────────────────────────────────────────────────────────

#
# ─── PATH UTILS ─────────────────────────────────────────────────────────────────
#
# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

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

