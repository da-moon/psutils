# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $common_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/common.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($common_url)
# ────────────────────────────────────────────────────────────────────────────────


# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1


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