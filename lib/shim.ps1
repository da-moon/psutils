# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $shim_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/shim.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($shim_url)
# ────────────────────────────────────────────────────────────────────────────────

#
# ─── SHIM ───────────────────────────────────────────────────────────────────────
#
# [ NOTE ] =>
# https://github.com/lukesampson/psutils/blob/master/shim.ps1


$libraries = @("messages","common","path")
foreach ($library in $libraries) {
  if (Test-Path "$psscriptroot\$library.ps1" -PathType leaf){
    . "$psscriptroot\$library.ps1"
  }else{
    $library_repo_root_url = "https://raw.githubusercontent.com/da-moon/psutils/master"
    $target = $library_repo_root_url + '/' + "$library" + ".ps1"
    Invoke-Expression (New-Object net.webclient).downloadstring($target)
  }
}

function create_shim($path) {
  
  if (!(Test-Path $path)) { abort "shim: couldn't find $path"; }
  $path = Resolve-Path $path
  $shimdir = "~/appdata/local/shims"
  if (-not(Test-Path $shimdir)) { 
    $null=New-Item -ItemType Directory -Path $shimdir -Force -ErrorAction Stop
  }
  $shimdir = Resolve-Path $shimdir
  ensure_in_path $shimdir

  $fname_stem = [io.path]::getfilenamewithoutextension($path).tolower()

  $shim = "$shimdir\$fname_stem.ps1"

  Write-Output "`$path = '$path'" > $shim
  Write-Output 'if($myinvocation.expectingInput) { $input | & $path @args } else { & $path @args }' >> $shim

  if ($path -match '\.((exe)|(bat)|(cmd))$') {
    info "shim .exe, .bat, .cmd so they can be used by programs with no awareness of PSH"
    "@`"$path`" %*" | Out-File "$shimdir\$fname_stem.cmd" -encoding oem
  }
  elseif ($path -match '\.ps1$') {
    info "make ps1 accessible from cmd.exe"
    "@powershell -noprofile -ex unrestricted `"& '$path' %*;exit `$lastexitcode`"" | Out-File "$shimdir\$fname_stem.cmd" -encoding oem
  }
}