param (
  [Parameter(Mandatory = $true)][string] $ssh_host
)
$ErrorActionPreference = 'SilentlyContinue' ;
$kill_payload='
Invoke-Expression (""Get-Process node | Where-Object Path -match ''.*\.vscode-server.*\\bin\.*''  | ForEach-Object { write-host (''killing {0}'' -f `$_.Id) ; Stop-Process -Id `$_.Id; }"")
'.replace("`n", " ")
$start_payload='
Invoke-Expression ((""{0}\bin\*\server.cmd
--start-server
--host=127.0.0.1
--enable-remote-auto-s shutdown
--port=0
--connection-secret {1}.token *> {1}.log"" -f ( $Env:USERPROFILE + ''\.vscode-server'' ) , ((Get-ChildItem ( $Env:USERPROFILE + ''\.vscode-server'' ) -Filter ''*.token'' ` -Recurse `
    | ForEach-Object { $_.FullName }) -replace ''\.[^\.]+$'' )))'.replace("`n", " ");
ssh $ssh_host -- $kill_payload;
Invoke-Expression (  ssh -f $ssh_host -- ('{0}' -f $start_payload)  ) ;
