# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $json_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/json.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($json_url)
# ────────────────────────────────────────────────────────────────────────────────


# [ NOTE ] => taken from
# - https://github.com/lukesampson/scoop/blob/master/lib/json.ps1
function ConvertToPrettyJson {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $data
    )

    Process {
        $data = normalize_values $data

        # convert to string
        [String]$json = $data | ConvertTo-Json -Depth 8 -Compress
        [String]$output = ''

        # state
        [String]$buffer = ''
        [Int]$depth = 0
        [Bool]$inString = $false

        # configuration
        [String]$indent = ' ' * 4
        [Bool]$unescapeString = $true
        [String]$eol = "`r`n"

        for ($i = 0; $i -lt $json.Length; $i++) {
            # read current char
            $buffer = $json.Substring($i, 1)

            $objectStart = !$inString -and $buffer.Equals('{')
            $objectEnd = !$inString -and $buffer.Equals('}')
            $arrayStart = !$inString -and $buffer.Equals('[')
            $arrayEnd = !$inString -and $buffer.Equals(']')
            $colon = !$inString -and $buffer.Equals(':')
            $comma = !$inString -and $buffer.Equals(',')
            $quote = $buffer.Equals('"')
            $escape = $buffer.Equals('\')

            if ($quote) {
                $inString = !$inString
            }

            # skip escape sequences
            if ($escape) {
                $buffer = $json.Substring($i, 2)
                ++$i

                # Unescape unicode
                if ($inString -and $unescapeString) {
                    if ($buffer.Equals('\n')) {
                        $buffer = "`n"
                    } elseif ($buffer.Equals('\r')) {
                        $buffer = "`r"
                    } elseif ($buffer.Equals('\t')) {
                        $buffer = "`t"
                    } elseif ($buffer.Equals('\u')) {
                        $buffer = [regex]::Unescape($json.Substring($i - 1, 6))
                        $i += 4
                    }
                }

                $output += $buffer
                continue
            }

            # indent / outdent
            if ($objectStart -or $arrayStart) {
                ++$depth
            } elseif ($objectEnd -or $arrayEnd) {
                --$depth
                $output += $eol + ($indent * $depth)
            }

            # add content
            $output += $buffer

            # add whitespace and newlines after the content
            if ($colon) {
                $output += ' '
            } elseif ($comma -or $arrayStart -or $objectStart) {
                $output += $eol
                $output += $indent * $depth
            }
        }

        return $output
    }
}

function normalize_values([psobject] $json) {
    # Iterate Through Manifest Properties
    $json.PSObject.Properties | ForEach-Object {
        # Recursively edit psobjects
        # If the values is psobjects, its not normalized
        # For example if manifest have architecture and it's architecture have array with single value it's not formatted.
        if ($_.Value -is [System.Management.Automation.PSCustomObject]) {
            $_.Value = normalize_values $_.Value
        }

        # Process String Values
        if ($_.Value -is [String]) {

            # Split on new lines
            [Array] $parts = ($_.Value -split '\r?\n').Trim()

            # Replace with string array if result is multiple lines
            if ($parts.Count -gt 1) {
                $_.Value = $parts
            }
        }

        # Convert single value array into string
        if ($_.Value -is [Array]) {
            # Array contains only 1 element String or Array
            if ($_.Value.Count -eq 1) {
                # Array
                if ($_.Value[0] -is [Array]) {
                    $_.Value = $_.Value
                } else {
                    # String
                    $_.Value = $_.Value[0]
                }
            } else {
                # Array of Arrays
                $resulted_arrs = @()
                foreach ($element in $_.Value) {
                    if ($element.Count -eq 1) {
                        $resulted_arrs += $element
                    } else {
                        $resulted_arrs += , $element
                    }
                }

                $_.Value = $resulted_arrs
            }
        }

        # Process other values as needed...
    }

    return $json
}
