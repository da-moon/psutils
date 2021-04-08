# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $alias_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/alias.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($alias_url)
# ────────────────────────────────────────────────────────────────────────────────


#
# ─── ALIASES ────────────────────────────────────────────────────────────────────
#
# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

function reset_alias($name, $value) {
  if($existing = Get-Alias $name -ea ignore | Where-Object { $_.options -match 'readonly' }) {
      if($existing.definition -ne $value) {
          Write-Host "Alias $name is read-only; can't reset it." -f darkyellow
      }
      return # already set
  }
  if($value -is [scriptblock]) {
      if(!(Test-Path -path "function:script:$name")) {
          New-Item -path function: -name "script:$name" -value $value | out-null
      }
      return
  }

  Set-Alias $name $value -scope script -option allscope
}

function reset_aliases() {
  # for aliases where there's a local function, re-alias so the function takes precedence
  $aliases = Get-Alias | Where-Object { $_.options -notmatch 'readonly|allscope' } | ForEach-Object { $_.name }
  Get-ChildItem function: | ForEach-Object {
      $fn = $_.name
      if($aliases -contains $fn) {
          Set-Alias $fn local:$fn -scope script
      }
  }

  # for dealing with user aliases
  $default_aliases = @{
      'cp' = 'copy-item'
      'echo' = 'Write-Output'
      'gc' = 'get-content'
      'gci' = 'Get-ChildItem'
      'gcm' = 'get-command'
      'gm' = 'get-member'
      'iex' = 'invoke-expression'
      'ls' = 'Get-ChildItem'
      'mkdir' = { New-Item -type directory @args }
      'mv' = 'move-item'
      'rm' = 'remove-item'
      'sc' = 'set-content'
      'select' = 'select-object'
      'sls' = 'select-string'
  }
  # [ NOTE ] => set default aliases
  $default_aliases.keys | ForEach-Object { reset_alias $_ $default_aliases[$_] }
}
