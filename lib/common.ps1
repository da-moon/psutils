# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $common_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/common.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($common_url)
# ────────────────────────────────────────────────────────────────────────────────


# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

function env($name, $global, $val = '__get') {
  $target = 'User'; if ($global) { $target = 'Machine' }
  if ($val -eq '__get') { [environment]::getEnvironmentVariable($name, $target) }
  else { [environment]::setEnvironmentVariable($name, $val, $target) }
}
function wraptext($text, $width) {
  if(!$width) { $width = $host.ui.rawui.buffersize.width };
  # be conservative: doesn't seem to print the last char
  $width -= 1 
  $text -split '\r?\n' | ForEach-Object {
      $line = ''
      $_ -split ' ' | ForEach-Object {
          if($line.length -eq 0) { $line = $_ }
          elseif($line.length + $_.length + 1 -le $width) { $line += " $_" }
          else { $lines += ,$line; $line = $_ }
      }
      $lines += ,$line
  }

  $lines -join "`n"
}
  

# ────────────────────────────────────────────────────────────────────────────────
function Optimize-SecurityProtocol {
  $isNewerNetFramework = ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -contains 'SystemDefault')
  $isSystemDefault = ([System.Net.ServicePointManager]::SecurityProtocol.Equals([System.Net.SecurityProtocolType]::SystemDefault))
  if (!($isNewerNetFramework -and $isSystemDefault)) {
      [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192
  }
}
# ────────────────────────────────────────────────────────────────────────────────

function is_admin {
  $admin = [security.principal.windowsbuiltinrole]::administrator
  $id = [security.principal.windowsidentity]::getcurrent()
  ([security.principal.windowsprincipal]($id)).isinrole($admin)
}