# ────────────────────────────────────────────────────────────────────────────────
# snippet to source this script:
#
#   $string_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/string.ps1'
#   Invoke-Expression (New-Object net.webclient).downloadstring($string_url)
# ────────────────────────────────────────────────────────────────────────────────

function Expand-Tab {
  param([UInt32] $TabWidth = 8)
  process {
    $line = $_
    while ( $TRUE ) {
      $i = $line.IndexOf([Char] 9)
      if ( $i -eq -1 ) { break }
      if ( $TabWidth -gt 0 ) {
        $pad = " " * ($TabWidth - ($i % $TabWidth))
      } else {
        $pad = ""
      }
      $line = $line -replace "^([^\t]{$i})\t(.*)$",
      "`$1$pad`$2"
    }
    $line
  }
}
function wraptext($text, $width) {
  if (!$width) { $width = $host.ui.rawui.buffersize.width };
  # be conservative: doesn't seem to print the last char
  $width -= 1 
  $text -split '\r?\n' | ForEach-Object {
    $line = ''
    $_ -split ' ' | ForEach-Object {
      if ($line.length -eq 0) { $line = $_ }
      elseif ($line.length + $_.length + 1 -le $width) { $line += " $_" }
      else { $lines += , $line; $line = $_ }
    }
    $lines += , $line
  }

  $lines -join "`n"
}
