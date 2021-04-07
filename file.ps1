# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $file_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/file.ps1'
#   Invoke-Expression (new-object net.webclient).downloadstring($file_url)
# ────────────────────────────────────────────────────────────────────────────────
#
# ─── IMPORTING LIBRARIES ────────────────────────────────────────────────────────
#
$messages_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/messages.ps1'
Invoke-Expression (new-object net.webclient).downloadstring($messages_url)
# ────────────────────────────────────────────────────────────────────────────────
function add_line_to_file([string] $line,[string] $path){
  $parent=Split-Path -parent $path 
  if (-not(Test-Path -Path $parent -PathType Container)) {
    warn "The directory [$parent] does not exist.trying to create it."
    try {
      $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
      info "The directory [$parent] has been created."
    }
    catch {
      throw $_.Exception.Message
    }
  }
  if (-not(Test-Path -Path $path -PathType Leaf)) {
    try {
      $null = New-Item -ItemType File -Path $path -Force -ErrorAction Stop
      info "The file [$path] has been created."
    }
    catch {
      throw $_.Exception.Message
    }
  }
	If (!(Select-String -Path $path -pattern $line)){
		$line | Out-File "$path"  -Encoding ascii -Append
	}
}
