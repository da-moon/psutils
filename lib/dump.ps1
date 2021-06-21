# collection of scripts I had no use for at the moment but can be used in the future.
# [ NOTE ] => Not useful. Just kept for reference purposes
# https://stackoverflow.com/a/57635570
function Get-ScriptFunctionNamesWithRegex {
  param (
    [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [AllowEmptyString()]
    [AllowNull()]
    [System.String]
    $Path
  )
  Process {
    [System.Collections.Generic.List[String]]$FX_NAMES = New-Object System.Collections.Generic.List[String]
    if (!([System.String]::IsNullOrWhiteSpace($Path))) {
      Select-String -NotMatch -Path "$Path" -Pattern "^\s*#" | Select-String -Pattern "^\s*function" |
      ForEach-Object {
        # [ NOTE ]
        # https://stackoverflow.com/a/52336328
        [System.Text.RegularExpressions.Regex] $regexp = New-Object Regex("(function)( +)([\w-]+)")
        [Text.RegularExpressions.RegexOptions] $regex_options = [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'
        $match = [regex]::Match("$_", $regexp, $regex_options)
        if ($match.Success) {
          $FX_NAMES.Add("$($match.Groups[3])")
        }
      }
    }
    return , $FX_NAMES.ToArray()
  }
}
# [ NOTE ] =>
# https://stackoverflow.com/a/57343076
Function Get-MyCommands {
  Get-Content -Path $PSCommandPath | Select-String -Pattern "^function.+" | ForEach-Object {
    [Regex]::Matches($_, "^function ([a-z0-9.-]+)", "IgnoreCase").Groups[1].Value
  } | Where-Object { $_ -ine "prompt" } | Sort-Object | Unique
}

function add_line_to_file([string] $line, [string] $path) {
  $parent = Split-Path -parent $path
  if (-not(Test-Path -Path $parent -PathType Container)) {
    warn "The directory [$parent] does not exist.trying to create it."
    try {
      $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
      info "The directory [$parent] has been created."
    } catch {
      throw $_.Exception.Message
    }
  }
  if (-not(Test-Path -Path $path -PathType Leaf)) {
    try {
      $null = New-Item -ItemType File -Path $path -Force -ErrorAction Stop
      info "The file [$path] has been created."
    } catch {
      throw $_.Exception.Message
    }
  }
  If (!(Select-String -Path $path -pattern $line)) {
    $line | Out-File "$path"  -Encoding ascii -Append
  }
}
function add_line_to_profile([string] $line) {
  add_line_to_file "$line" $PROFILE.CurrentUserAllHosts
}
# https://github.com/nabinno/dotfiles/blob/master/.win32/MyDocuments/WindowsPowerShell/Microsoft.PowerShell_profile.ps1
function Connect-VM {
  [CmdletBinding(DefaultParameterSetName = 'name')]
  param(
    [Parameter(ParameterSetName = 'name')] [Alias('cn')] [System.String[]]$ComputerName = $env:COMPUTERNAME,
    [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'name')] [Alias('VMName')]      [System.String]$Name,
    [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'id')]   [Alias('VMId', 'Guid')] [System.Guid]$Id,
    # [Parameter(Position=0, Mandatory, ValueFromPipeline,                                  ParameterSetName='inputObject')] [Microsoft.HyperV.PowerShell.VirtualMachine]$InputObject,
    [switch]$StartVM
  )
  begin {
    Write-Verbose "Initializing InstanceCount, InstanceCount = 0"
    $InstanceCount = 0
  } process {
    try {
      foreach ($computer in $ComputerName) {
        Write-Verbose "ParameterSetName is '$($PSCmdlet.ParameterSetName)'"
        if ($PSCmdlet.ParameterSetName -eq 'name') {
          # Get the VM by Id if Name can convert to a guid
          if ($Name -as [guid]) {
            Write-Verbose "Incoming value can cast to guid"
            $vm = Get-VM -Id $Name -ErrorAction SilentlyContinue
          } else {
            $vm = Get-VM -Name $Name -ErrorAction SilentlyContinue
          }
        } elseif ($PSCmdlet.ParameterSetName -eq 'id') {
          $vm = Get-VM -Id $Id -ErrorAction SilentlyContinue
        } else {
          $vm = $InputObject
        } if ($vm) {
          Write-Verbose "Executing 'vmconnect.exe $computer $($vm.Name) -G $($vm.Id) -C $InstanceCount'"
          vmconnect.exe $computer $vm.Name -G $vm.Id -C $InstanceCount
        } else {
          Write-Verbose "Cannot find vm: '$Name'"
        } if ($StartVM -and $vm) {
          if ($vm.State -eq 'off') {
            Write-Verbose "StartVM was specified and VM state is 'off'. Starting VM '$($vm.Name)'"
            Start-VM -VM $vm
          } else {
            Write-Verbose "Starting VM '$($vm.Name)'. Skipping, VM is not not in 'off' state."
          }
        }
        $InstanceCount += 1
        Write-Verbose "InstanceCount = $InstanceCount"
      }
    } catch {
      Write-Error $_
    }
  }
}
Set-Alias gvm Get-VM
Set-Alias gvmn Get-VMNetworkAdapter

# [ TODO ] => md5hash alias
function Get-FileAndHash {
  Get-ChildItem . | ForEach-Object { [PSCustomObject]@{ path = $_.Name; hash = (Get-FileHash -a md5 $_.FullName).Hash } }
}
