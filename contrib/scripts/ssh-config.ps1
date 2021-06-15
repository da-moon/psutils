
param (
  [Parameter(Mandatory = $true)][string] $container,
  [Parameter(Mandatory = $true)][string] $user
)

  (Get-Content -Raw $Env:UserProfile\.ssh\config) `
  -replace ('(?s)\r?\nHost {0}.*?MACs hmac-sha2-512\r?\n' `
  -f "$container") `
  | Set-Content $Env:UserProfile\.ssh\config ;

  "`nHost {0}
  `tHostName {1}
  `tUser {2}
  `tStrictHostKeyChecking no
  `tCheckHostIP no
  `tUserKnownHostsFile /dev/null
  `tMACs hmac-sha2-512`n" -f `
  $container, `
  (docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container), `
  $user `
  | Out-File -Encoding ascii -Append $Env:UserProfile\.ssh\config ;

  ((Get-Content -Raw $Env:UserProfile\.ssh\config ) `
  -replace "(?m)^\s*`r`n",'').trim() `
  -replace "`t", "  " `
  -replace "^\s\s*", "  " `
  | Set-Content $Env:UserProfile\.ssh\config ;
