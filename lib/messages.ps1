# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $messages_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/messages.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($messages_url)
# ────────────────────────────────────────────────────────────────────────────────


# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/core.ps1

function abort($msg, [int] $exit_code=1) { Write-Host $msg -f red; exit $exit_code }
function error($msg) { Write-Host "[ ERROR ] $msg" -f darkred }
function warn($msg) {  Write-Host "[ WARN ]  $msg" -f darkyellow }
function info($msg) {  Write-Host "[ INFO ]  $msg" -f DarkBlue }
function debug($obj) {
    $prefix = "DEBUG[$(Get-Date -UFormat %s)]"
    $param = $MyInvocation.Line.Replace($MyInvocation.InvocationName, '').Trim()
    $msg = $obj | Out-String -Stream

    if($null -eq $obj -or $null -eq $msg) {
        Write-Host "$prefix $param = " -f DarkCyan -NoNewline
        Write-Host '$null' -f DarkYellow -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
        return
    }

    if($msg.GetType() -eq [System.Object[]]) {
        Write-Host "$prefix $param ($($obj.GetType()))" -f DarkCyan -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
        $msg | Where-Object { ![String]::IsNullOrWhiteSpace($_) } |
            Select-Object -Skip 2 | # Skip headers
            ForEach-Object {
                Write-Host "$prefix $param.$($_)" -f DarkCyan
            }
    } else {
        Write-Host "$prefix $param = $($msg.Trim())" -f DarkCyan -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
    }
}
function success($msg) { Write-Host $msg -f darkgreen }
