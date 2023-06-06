# $parent=Split-Path -parent $PROFILE ; if (-not(Test-Path -Path $parent -PathType Container)) {$null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop}
$modules = @()
$modules += 'Fasdr'
$modules += 'PSEverything'
$modules += 'PSFzf'
$modules += 'powershell-yaml'
# $modules += 'ZLocation'
$modules += 'PSScriptTools'
if ($host.Name -eq "ConsoleHost") {
  $modules += 'Profile'
  $modules += 'PSReadLine'
}
if (Get-Command scoop -ErrorAction SilentlyContinue) {
  $modules += 'scoop-completion'
}
if ((Test-Path -PathType Container "$Env:USERPROFILE\bin" )) {
  $Env:PATH="$Env:PATH;$Env:USERPROFILE\bin"
}
if ((Test-Path -PathType Container "$Env:LOCALAPPDATA\Microsoft\WindowsApps" )) {
  $Env:PATH = $Env:PATH + ";$Env:LOCALAPPDATA\Microsoft\WindowsApps"
}
if ((Test-Path -PathType Container "$Env:LOCALAPPDATA\bin")) {
  $Env:PATH = $Env:PATH + ";$Env:LOCALAPPDATA\AppData\Local\bin"
}
if (Get-Command python -ErrorAction SilentlyContinue) {
  $Env:PATH="$Env:PATH;$(Split-Path -parent "$(python -c 'import site;print(site.USER_SITE)')")\Scripts"
}
# npm -g list --depth 0
if (Get-Command npm -ErrorAction SilentlyContinue) {
  $modules += 'npm-completion'
  $Env:PATH="$Env:PATH;$Env:APPDATA\npm"
}
if (Get-Command yarn -ErrorAction SilentlyContinue) {
  $modules += 'yarn-completion'
  $Env:PATH="$Env:PATH;$(yarn global dir)\bin"
}
if (Test-Path -Path "$Env:USERPROFILE\scoop\apps\go" -PathType Container) {
  $Env:Path=($Env:Path.Split(';') | Select-String -SimpleMatch -NotMatch "$Env:PROGRAMFILES\Go\bin") -join ';'
}
if (Get-Command vault -ErrorAction SilentlyContinue) {
  $Env:VAULT_SKIP_VERIFY = "true"
  $Env:VAULT_ADDR="http://localhost:8200"
  $ENV:VAULT_TOKEN="root"
}
if (Get-Command hx -ErrorAction SilentlyContinue) {
  $Env:EDITOR="hx";
  $Env:VISUAL="hx";
elseif (Get-Command nvim -ErrorAction SilentlyContinue)
  $Env:EDITOR="nvim";
  $Env:VISUAL="nvim";
}
#
# ──────────────────────────────────────────────────────────── I ──────────
#   :::::: C O M P L E T I O N : :  :   :    :     :        :          :
# ──────────────────────────────────────────────────────────────────────
#
Register-ArgumentCompleter -CommandName ssh,scp,sftp -Native -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  $sshConfig = Get-Content ${Env:HOMEPATH}\.ssh\config `
  | ForEach-Object { ([string]$_).Split(' ')[1] } `
  | Sort-Object -Unique

  # For now just assume it's a hostname.
  $textToComplete = $wordToComplete
  $generateCompletionText = {
      param($x)
      $x
  }
  if ($wordToComplete -match "^(?<user>[-\w/\\]+)@(?<host>[-.\w]+)$") {
      $textToComplete = $Matches["host"]
      $generateCompletionText = {
          param($hostname)
          $Matches["user"] + "@" + $hostname
      }
  }

  $sshConfig `
  | Where-Object { $_ -like "${textToComplete}*" } `
  | ForEach-Object { [System.Management.Automation.CompletionResult]::new((&$generateCompletionText($_)), $_, [System.Management.Automation.CompletionResultType]::ParameterValue, $_) }
}

#
# ────────────────────────────────────────────────────────── I ──────────
#   :::::: F U N C T I O N S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────────
#
Function Debug-String {
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    [string] $String
    ,
    [switch] $CaretNotation
  )

  begin {
    $re = [regex] '\p{C}'
  }
  process {
    $re.Replace($String, {
        param($match)
        $handled = $False
        if (-not $CaretNotation) {
          $handled = $True
          switch ([Int16] [char] $match.Value) {
            0 { '`0'; break }
            7 { '`a'; break }
            8 { '`b'; break }
            12 { '`f'; break }
            10 { '`n'; break }
            13 { '`r'; break }
            9 { '`t'; break }
            11 { '`v'; break }
            default { $handled = $false }
          }
        }
        if (-not $handled) {
          switch ([Int16] [char] $match.Value) {
            10 { '$'; break }
            { $_ -ge 0 -and $_ -le 31 -or $_ -eq 127 } {
              '^' + [char] (64 + $_)
              break
            }
            default { '`u{{{0}}}' -f ([int16] [char] $_).ToString('x') }
          }
        }
      })
  }
}
# ─── MESSAGE ────────────────────────────────────────────────────────────────────
function abort($msg, [int] $exit_code = 1) {
  Write-Host $msg -f red
  exit $exit_code
}
function error($msg) {
  Write-Host "[ERROR] $msg" -f darkred
}
function warn($msg) {
  Write-Host "[WARN]  $msg" -f darkyellow
}
function info($msg) {
  Write-Host "[INFO] $msg" -f darkcyan
}
function success($msg) {
  Write-Host  "[DONE] $msg" -f darkgreen
}
# ─── DEBUG ──────────────────────────────────────────────────────────────────────
function debug($msg) {
  Write-Host "[DEBUG]  $msg" -f darkgray
}

# ─── PACKAGE MANAGEMENT ─────────────────────────────────────────────────────────
function Update-Repo {
  Begin {
    info "Updating Repo ..."
  }
  Process {
    $packageProviders = PackageManagement\Get-PackageProvider -ListAvailable
    $checkPowerShellGet = $packageProviders | Where-Object name -eq "PowerShellGet"
    $checkNuget = $packageProviders | Where-Object name -eq "NuGet"
    $checkPSGallery = Get-PSRepository PSGallery
    if (!$checkPSGallery -or $checkPSGallery.InstallationPolicy -ne 'Trusted') {
      Set-PSRepository PSGallery -InstallationPolicy trusted -SourceLocation "https://www.powershellgallery.com/api/v2"
    }
    if (!$checkPowerShellGet) {
      PackageManagement\Get-PackageProvider -Name PowerShellGet -Force
    }
    if (!$checkNuget) {
      PackageManagement\Get-PackageProvider -Name NuGet -Force
    } 
  }
  End {
    success "Updating Repo ..."
  }
}
function Install-Modules {
  param(
    [parameter(Mandatory, ValueFromPipeline)]
    [string[]] $modulesNames
  )
  Begin {
    info "Installing Modules..."
    Import-Module PowerShellGet -ErrorAction SilentlyContinue
    Update-Repo
  }
  Process {
    $installedModules = Get-InstalledModule
    foreach ($moduleName in $modulesNames) {
      if (!(Get-Module -Name $moduleName)) {
        Try {
          info "Checking $($moduleName)"
          $online = Find-Module $moduleName
        }
        Catch {
          warn "Module $($module.name) was not found in the PSGallery"
          continue
        }
        if ($online) {
          if ($installedModules.Name -notcontains $moduleName) {
            info "installing $($moduleName) module"
            Install-Module $moduleName `-Force -AllowClobber -SkipPublisherCheck `
              -Scope CurrentUser `
              -ErrorAction SilentlyContinue
            success "installing $($moduleName) module"
          }
        }
      }
    }
  }
  End {
    success "Installing Modules..."
  }
}
# [ NOTE ] Modules should be installed on User scope
function Get-EnsureModule {
  param(
    [parameter(Mandatory, ValueFromPipeline)]
    [string[]] $modulesNames
  )
  Begin {
    info "Ensuring Modules..."
    Update-Repo
  }
  Process {
    foreach ($moduleName in $modulesNames) {
      if (!(Get-Module -Name $moduleName)) {
        try {
          info "importing $($moduleName)"
          Import-Module $moduleName -ErrorAction Stop
          success "importing $($moduleName) module"
        }
        catch {
          info "installing $($moduleName) module"
          Install-Module $moduleName `-Force -AllowClobber -SkipPublisherCheck -Scope CurrentUser `
            success "installing $($moduleName) module"
          info "importing $($moduleName) module"
          Import-Module $moduleName
          success "importing $($moduleName) module"
        }
      }
    }
  }
  End {
    success "Ensuring Modules..."
  }
}
function Update-Modules {
  Begin {
    info "updating Modules..."
    Update-Repo
    Import-Module PowerShellGet -ErrorAction SilentlyContinue
  }
  Process {
    $installedModules = Get-InstalledModule
    foreach ($module in $installedModules) {
      Try {
        info "Checking $($module.name)"
        $online = Find-Module $module.name
        success "Checking $($module.name)"
      }
      Catch {
        warn "Module $($module.name) was not found in the PSGallery"
      }
      if ($online.version -gt $module.version) {
        info "Updating $($module.name) module"
        Update-Module -SkipPublisherCheck `
          -Name $module.name `
          -ErrorAction SilentlyContinue
        success "Updating $($module.name) module"
      }
    }
  }
  End {
    success "updating Modules..."
  }
}

function Remove-CR() {
  param (
    [Parameter(Mandatory = $true)][string] $path
  )
  $content = ((Get-Content $path) -join "`n") + "`n" 
  ($content -replace "(?m)^\s*`r`n", '').trim() `
    -replace "`t", "  " `
    -replace "^\s\s*", "  " | Set-Content -NoNewline $path
}
function Remove-LF() {
  param (
    [Parameter(Mandatory = $true)][string] $path
  )
  $content = (Get-Content $path) -join "`n" 
  ($content -replace "(?m)^\s*`n", '').trim() `
    -replace "`t", "  " `
    -replace "^\s\s*", "  " | Set-Content -NoNewline $path
}

Function Get-Environment-Variables {
  param (
    [Parameter(Mandatory = $false)][string] $Variable
  )
  if ($Variable) {
    Get-ChildItem Env:* | `
      Where-Object -FilterScript { $_.Name -match $Variable } | Select-Object -ExpandProperty Value
    return
  }
  Get-ChildItem Env:*
}
function Get-Content-Bat {
  param (
    [Parameter(Mandatory = $true)][string] $path
  )
  & bat -pp $path
}
function Remove-With-Recurse($path) { Remove-Item $path -Recurse -Force }
Function Get-LineCount {
  Param( [Parameter(ValueFromPipeline)][String[]] $str = "" )
  Process { $i += 1 } End { return $i }
}

# ─── STARSHIP SETUP ─────────────────────────────────────────────────────────────
# starship
if (Get-Command starship -ErrorAction SilentlyContinue) {
  # function prompt { [char]8203 }
  # function Invoke-Starship-TransientFunction { [char]8203 }
  
  Invoke-Expression (starship init powershell)
  # Enable-TransientPrompt
  # Set-PSReadLineOption -ExtraPromptLineCount 2 
}

#
# ────────────────────────────────────────────────────── I ──────────
#   :::::: A L I A S E S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────
#

# ─── TERRAFORM ALIASES ──────────────────────────────────────────────────────────
function tf([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform $params }
function tfi([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform init $params }
function tfa([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform apply -auto-approve $params }
function tfd([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform destroy -auto-approve $params }
function tfp([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform plan $params }
function tfw([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform workspace $params }
function tfwl([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform workspace list $params }
function tfws([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform workspace select $params }
function tfo([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform output $params }
function tfv([Parameter(ValueFromRemainingArguments = $true)]$params) { & terraform validate $params }
# ─── GIT ALIASES ────────────────────────────────────────────────────────────────
if (Get-Command git -ErrorAction SilentlyContinue) {
  $modules += 'posh-git'
  # ─── FOR GIT TO CORRECTLY SHOW UNICODE FILES CONTENT ────────────────────────────
  $Env:LANG = "en_US.UTF-8";
  function ga($path) { git add $path }
  function gaa { git add . }
  function gct($comment) { git commit -m "$comment" }
  function gd { git diff }
  function gdf { git diff }
  function glg { git log }
  function gs { git status -sb }  
  Set-Alias g git
}
# ─── MARKDOWN ALIASES ─────────────────────────────────────────────────────────
# npm i -g prettier
if (Get-Command prettier -ErrorAction SilentlyContinue) {
  function prettier-md([Parameter(ValueFromRemainingArguments = $true)]$params) { prettier --print-width=79 --prose-wrap=always --parser markdown $params }
}
# npm i -g remark remark-cli remark-frontmatter remark-reference-links remark-toc 
if (Get-Command remark -ErrorAction SilentlyContinue) {
  function remark-fmt([Parameter(ValueFromRemainingArguments = $true)]$params) { remark --use remark-toc='\"heading\": \"Table of contents\",\"tight\" : true' --use remark-frontmatter --use remark-reference-links --use remark-stringify='bullet: \"-\",listItemIndent: \"one\"' $params }
}
if ((Get-Command remark -ErrorAction SilentlyContinue) -and (Get-Command prettier -ErrorAction SilentlyContinue)) {
  function md-fmt([Parameter(ValueFromRemainingArguments = $true)]$params) { 
    remark `
      --use remark-toc='\"heading\": \"Table of contents\",\"tight\" : true' `
      --use remark-stringify='bullet: \"-\",listItemIndent: \"one\"' `
      --use remark-frontmatter `
      --use remark-reference-links `
      $params | prettier --print-width=79 --prose-wrap=always --parser markdown
  }
}
if (Get-Command pandoc -ErrorAction SilentlyContinue) {
  function md2jira([Parameter(ValueFromRemainingArguments = $true)]$params) { & pandoc --from gfm --to jira $params } ;
  function md2pdf([Parameter(ValueFromRemainingArguments = $true)]$params) { & pandoc --from markdown --pdf-engine=xelatex $params } ;
  function md2word([Parameter(ValueFromRemainingArguments = $true)]$params) { & pandoc --from markdown --to docx $params } ;
  function md2ppt([Parameter(ValueFromRemainingArguments = $true)]$params) { & pandoc --from markdown --to pptx $params } ;
}
# ─── NIX FUNCTION ALIAS ─────────────────────────────────────────────────────────
function l { Get-ChildItem $args }
function la { Get-ChildItem -Force $args }

Set-Alias printenv Get-Environment-Variables
If (Test-Path Alias:cd) { Remove-Item Alias:cd }
Set-Alias cd Push-Location
if (Get-Command bat -ErrorAction SilentlyContinue) {
  If (Test-Path Alias:cat) { Remove-Item Alias:cat }
  Set-Alias cat Get-Content-Bat
}
Set-Alias d Remove-With-Recurse
# ─── MISC ALIASES ─────────────────────────────────────────────────────────────
if (Get-Command aria2c -ErrorAction SilentlyContinue) {
  function dl([Parameter(ValueFromRemainingArguments = $true)]$params) { & aria2c --optimize-concurrent-downloads -k 1M -j16 -x 16 -c $params } ;
}
if (Get-Command zoxide -ErrorAction SilentlyContinue){
  if (Test-Path Alias:z) {Remove-Item Alias:z}
  Invoke-Expression (& {
      $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
      (zoxide init --hook $hook powershell | Out-String)
  })      
}
# ─── FZF ──────────────────────────────────────────────────────────────────────
if (Get-Command fzf -ErrorAction SilentlyContinue) {
  # $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
  $env:_PSFZF_FZF_DEFAULT_OPTS="--multi --height=40% --reverse --tabstop=4 -0"
  $env:_PSFZF_FZF_DEFAULT_OPTS+=" --prompt=' | ' --color=prompt:0,hl:178,hl+:178"
  $env:_PSFZF_FZF_DEFAULT_OPTS+=" --bind='ctrl-t:toggle-all,ctrl-g:select-all+accept'"
  $env:_PSFZF_FZF_DEFAULT_OPTS+=" --bind='tab:down,shift-tab:up'"
  $env:_PSFZF_FZF_DEFAULT_OPTS+=" --bind='?:toggle-preview,ctrl-space:toggle'"
  # This brings PSFzf more in line with how search works in zsh, and it seems to
  # provide more relevant results.
  $env:FZF_CTRL_R_OPTS = "'-n2..,..' --bind=ctrl-r:toggle-sort,ctrl-z:ignore"
  $env:FZF_CTRL_R_OPTS += " --preview='echo {}' --preview-window=down:3:wrap"
  $env:FZF_CTRL_T_OPTS = "--reverse --bind=ctrl-z:ignore"
  $env:FZF_ALT_C_OPTS = "--reverse --bind=ctrl-z:ignore"
  # Use fd for faster search through all the directories, though.
  if (Get-Command fd -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_COMMAND = "fd -tf . `"{0}`""
    $env:FZF_CTRL_T_COMMAND = "fd -L . --min-depth 1 -tf -td -tl"
    $env:FZF_ALT_C_COMMAND = "fd -L . --min-depth 1 -td"
  }
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' ;
  Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r' ;
  Set-PsFzfOption -PSReadlineChordSetLocation 'Alt+c' ;
  Set-PsFzfOption -GitKeyBindings ;
  # Set-PsFzfOption -TabExpansion ;
  # Set-PSReadlineKeyHandler -Key 'Ctrl+r' -ScriptBlock { Invoke-FuzzyHistory }
  # Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {  Invoke-FzfTabCompletion   }
}else{
  Set-PSReadlineKeyHandler -Key Tab -Function Complete
}
Set-PSReadLineKeyHandler -Key 'Ctrl+a' -Function BeginningOfLine
Set-PSReadlineKeyHandler -Key 'Alt+Backspace' -Function BackwardKillWord
if ($host.Name -eq "ConsoleHost") {
  Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
  Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
}
if (Get-Command aws -ErrorAction SilentlyContinue) {
  $Env:AWS_DEFAULT_PROFILE="saml" ;
  $Env:AWS_PAGER="";
}
# ─── ASYNC TASKS ────────────────────────────────────────────────────────────────
# [ NOTE ] -> only run async tasks out of VSCode shell.
$async_lock = '{0}\{1}.lock' -f $Env:TMP, (Get-Date -UFormat "%m-%d-%Y")
if (-not(Test-Path $async_lock)) {
  
  if ($Env:TERM_PROGRAM -ne 'vscode') {
      $function_ctx = [scriptblock]::create(@"
  function info {${function:info}}
  function warn {${function:warn}}
  function success {${function:success}}
  function Get-EnsureModule {${function:Get-EnsureModule}}
  function Update-Modules {${function:Update-Modules}}
"@)
      $null = Start-Job -InitializationScript $function_ctx -Name "async_module_init" -ScriptBlock { $Using:modules | Get-EnsureModule }
      # ────────────────────────────────────────────────────────────────────────────────
      $null = Start-Job -InitializationScript $function_ctx -Name "async_update_modules" { Update-Modules }
      # ────────────────────────────────────────────────────────────────────────────────
      $null = Start-Job -InitializationScript $function_ctx -Name "async_clean_tmp" {Remove-Item -Force -Recurse -Path ($Env:Tmp+'\*') -ErrorAction SilentlyContinue}
      # ────────────────────────────────────────────────────────────────────────────────
      $timer = New-Object System.Timers.Timer
      $timer.Interval = 1000
      $timer.AutoReset = $true
      Get-EventSubscriber -SourceIdentifier "async" -ErrorAction SilentlyContinue | Unregister-Event
      $null = Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier "async" -Action {
        $jobs = Get-Job -Name "async*"
        if ($jobs.count -gt 1) {
          foreach ($job in $jobs) {
            if ($job.State -ne "Running") {
              $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0 , $host.UI.RawUI.CursorPosition.Y
              $null = Receive-Job $job.Name
              $null = Remove-Job $job.Name
              $null = Unregister-Event $job.Name
            }
          }
          return
        }
        [void]$timer.stop()
        # [ NOTE ] => ensuring cursor position starts at the begining of
        # the line.
        $null = Unregister-Event "async"
        $null = Remove-Job "async"
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0 , $host.UI.RawUI.CursorPosition.Y
        success "Asynchronous profile load was completed"
        Get-ChildItem -Path $Env:USERPROFILE *.lock | ForEach-Object { Remove-Item -Force -Path $_.FullName }
        New-Item -ItemType file $async_lock
      }
      info "Asynchronous profile load starting ..."
      $timer.Start()
    }
  }
Remove-Variable modules
# Configure git
# 
# git config --global 'core.autocrlf'                                   'false'
# git config --global 'push.recursesubmodules'                          'on-demand'
# git config --global 'pull.rebase'                                     'true'
# git config --global 'rebase.autostash'                                'true'
# git config --global 'status.submodulesummary'                         'true'
# git config --global 'commit.gpgsign'                                  'true'
# git config --global 'interactive.difffilter'                          'delta --color-only --features'
# git config --global 'pager.diff'                                      'delta'
# git config --global 'pager.grep'                                      'delta'
# git config --global 'pager.blame'                                     'delta'
# git config --global 'pager.log'                                       'delta'
# git config --global 'pager.reflog'                                    'delta'
# git config --global 'pager.show'                                      'delta'
# git config --global 'diff.submodule'                                  'log'
# git config --global 'diff.tool'                                       'difftastic'
# git config --global 'diff.difftastic.command'                         'difft'
# git config --global 'diff.difftastic.binary'                          'true'
# git config --global 'difftool.prompt'                                 'false'
# git config --global 'difftool.difftastic.cmd'                         'difft --color always $LOCAL $REMOTE'
# git config --global 'difftool.delta.cmd'                              'diff -u --unified=3 --ignore-case -w $LOCAL $REMOTE | delta'
# git config --global 'delta.features'                                  'side-by-side line-numbers decorations'
# git config --global 'delta.whitespace-error-style'                    '22 reverse'
# git config --global 'delta.decorations.commit-decoration-style'       'bold yellow box ul'
# git config --global 'delta.decorations.file-style'                    'bold yellow ul'
# git config --global 'delta.decorations.file-decoration-style'         'none'
# git config --global 'delta.decorations.commit-style'                  'raw'
# git config --global 'delta.decorations.hunk-header-decoration-style'  'blue box'
# git config --global 'delta.decorations.hunk-header-file-style'        'red'
# git config --global 'delta.decorations.hunk-header-line-number-style' '#067a00'
# git config --global 'delta.decorations.hunk-header-style'             'file line-number syntax'
# git config --global 'delta.interactive.keep-plus-minus-markers'       'false'
# git config --global 'gui.editor'                                      'code -w'
# git config --global 'fetch.prune'                                     'true'
# git config --global 'merge.log'                                       'true'
# git config --global 'merge.tool'                                      'code'
# git config --global 'mergetool.code.cmd'                              'code --wait --merge $REMOTE $LOCAL $BASE $MERGED'
# git config --global 'alias.view-contributors'                         'shortlog -e -s -n'
# git config --global 'alias.upstream'                                  'remote get-url origin'
# git config --global 'alias.root'                                      'rev-parse --show-toplevel'
# git config --global 'alias.scope'                                     'rev-parse --show-prefix'
# git config --global 'alias.url'                                       'ls-remote --get-url'
# git config --global 'alias.aliases'                                   'config --get-regexp alias'
# git config --global 'alias.spush'                                     'push --recurse-submodules=on-demand'
# git config --global 'alias.sfetch'                                    'submodule foreach --recursive git fetch'
# git config --global 'alias.supdate'                                   'submodule update --remote --merge'
# git config --global 'alias.default-branch'                            'rev-parse --abbrev-ref HEAD'
# git config --global 'alias.current-branch'                            '!git for-each-ref --format="%(upstream:short)" $(git symbolic-ref -q HEAD)'
# git config --global 'alias.ca'                                        'commit --signoff --gpg-sign --amend --reuse-message=HEAD'
# git config --global 'alias.c'                                         'commit --signoff --gpg-sign'
# git config --global 'alias.commit-summary'                            'log --color --graph --pretty=format:"%C(red)%h%C(reset) %s %C(bold blue)[%an](mailto:%ae)%C(reset) %C(green)%C(bold)%cr" --abbrev-commit'
# git config --global 'alias.head-hash'                                 'rev-parse HEAD'
# git config --global 'alias.latest-commit'                             'log -1 HEAD --stat'
# git config --global 'alias.untracked'                                 'ls-files --others --exclude-standard'
# git config --global 'alias.tags'                                      'for-each-ref --format="%(refname:short) (%(committerdate:relative))" --sort=committerdate refs/tags'
# git config --global 'alias.latest-tag'                                '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null'
# git config --global 'alias.release-notes'                             'log --color --pretty=format:"* %C(red)%h%C(reset) %s %C(bold blue)[%an](mailto:%ae)%C(reset)" --abbrev-commit --dense --no-merges'
# git config --global 'alias.staged'                                    'diff --name-only --staged'
# git config --global 'alias.difft'                                     'difftool --tool difftastic'
# git config --global 'alias.diffd'                                     'difftool --tool delta'
# git config --global 'alias.not-staged'                                'diff-files --name-only -B -R -M'
# git config --global 'alias.all-changes'                               'diff --name-only HEAD'
# git config --global 'alias.conflicts'                                 '! $EDITOR $(git diff --name-only --diff-filter=U)'
# git config --global 'alias.issues'                                    '! gh issue list --assignee "@me"'
# git config --global 'alias.changes'                                   'diff-index --name-only -B -R -M -C HEAD'
# git config --global 'alias.rel-changes'                               'ls-files -m -o --exclude-standard'
# git config --global 'alias.ignored'                                   'ls-files --others --ignored --exclude-standard'
# git config --global 'alias.modified-files'                            'diff --name-only'
# git config --global 'alias.restage'                                   '!git add $(git diff --name-only)'
# git config --global 'alias.stage-all'                                 '!git add $(git diff --name-only HEAD)'
# git config --global 'alias.ui'                                        '!f() { cd "$(git rev-parse --show-toplevel)" && gitui; }; f'
# git config --global 'alias.zipball'                                   '!git archive --format=zip --output=$(basename -s.git $(git remote get-url origin))-$(git describe --abbrev=0).zip $(git describe --abbrev=0)'
# git config --global 'alias.tarball'                                   '!git archive --format=tar.gz --output=$(basename -s.git $(git remote get-url origin))-$(git describe --abbrev=0).tar.gz $(git describe --abbrev=0)'
# # git config --global 'alias.tracked'                                   '!git ls-tree -r $(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD) --name-only'
# # git config --global 'alias.branch-prune'                              '!git fetch -p ; for b in $(git for-each-ref --format="%(if:equals=[gone])%(upstream:track)%(then)%(refname:short)%(end)" refs/heads); do git branch -d $b; done'
# # git config --global "alias.next-patch-release"                        '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null'"| awk -F. '{gsub(\"v\",\"\",\$1);printf \"%s.%s.%s\", \$1,\$2,\$3+1}END {if (NR==0){print \"0.0.1\"}}'"
# # git config --global "alias.next-minor-release"                        '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null'"| awk -F. '{gsub(\"v\",\"\",\$1);printf \"%s.%s.0\", \$1,\$2+1}END {if (NR==0){print \"0.0.1\"}}'"
# # git config --global "alias.next-major-release"                        '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null'"| awk -F. '{gsub(\"v\",\"\",\$1);printf \"%s.0.0\", \$1+1}END {if (NR==0){print \"0.0.1\"}}'"

# ──────────────────────────────────────────────────────────────────────────────
# https://lazyadmin.nl/powershell/powershell-grep-select-string/
# ──────────────────────────────────────────────────────────────────────────────
