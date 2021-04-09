# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $getopt_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/getopt.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($getopt_url)
# ────────────────────────────────────────────────────────────────────────────────

# [ NOTE ] =>
# https://github.com/lukesampson/psutils/blob/master/getopt.ps1

function getopt($argv, $shortopts, $longopts) {
    $opts = @{}; $rem = @()

    function err($msg) {
        $opts, $rem, $msg
    }

    function regex_escape($str) {
        return [regex]::escape($str)
    }
    function  validate_argv([Object] $argv) {
        $argv_clone = $argv[$i + 1]
        if (($argv_clone -is [int]) -or ($argv_clone -is [decimal])) { 
            $argv_clone = $argv_clone.ToString()
        }
        if (($argv_clone.startswith('--')) -or ($argv_clone.startswith('-'))) {
            return $false
        }
        return $true

    } 
    # ensure these are arrays
    $argv = @($argv)
    $longopts = @($longopts)

    for ($i = 0; $i -lt $argv.length; $i++) {
        $arg = $argv[$i]
        if ($null -eq $arg) { continue }

        # don't try to parse array arguments
        if ($arg -is [array]) { $rem += , $arg; continue }
        if ($arg -is [int]) { $rem += $arg; continue }
        if ($arg -is [decimal]) { $rem += $arg; continue }

        if ($arg.startswith('--')) {
            $name = $arg.substring(2)
            
            $longopt = $longopts | Where-Object { $_ -match "^$name=?$" }

            if ($longopt) {


                if ($longopt.endswith('=')) {
                    # requires arg
                    if ($i -eq $argv.length - 1) {
                        return err "Option --$name requires an argument."
                    }
                    if (-not(validate_argv ($argv))) {
                        $faulty_arg = $argv[($i + 1)]
                        return err "Option --$name got an invalid argument: [ $faulty_arg ]"
                    }
                    $opts.$name = $argv[++$i]
                }
                else {
                    $opts.$name = $true
                }
            }
            else {
                return err "Option --$name not recognized."
            }
        }
        elseif ($arg.startswith('-') -and $arg -ne '-') {
            for ($j = 1; $j -lt $arg.length; $j++) {
                $letter = $arg[$j].tostring()

                if ($shortopts -match "$(regex_escape $letter)`:?") {
                    $shortopt = $matches[0]
                    if ($shortopt[1] -eq ':') {

                        if ($j -ne $arg.length - 1 -or $i -eq $argv.length - 1) {
                            return err "Option -$letter requires an argument."
                        }
                        if (-not(validate_argv ($argv))) {
                            $faulty_arg = $argv[($i + 1)]
                            return err "Option --$name got an invalid argument: [ $faulty_arg ]"
                        }
                        $opts.$letter = $argv[++$i]
                    }
                    else {
                        $opts.$letter = $true
                    }
                }
                else {
                    return err "Option -$letter not recognized."
                }
            }
        }
        else {
            $rem += $arg
        }
    }

    $opts, $rem
}
