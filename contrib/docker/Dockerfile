# escape=`
#syntax=docker/dockerfile:1.2

# ─── EXAMPLE BUILD COMMAND ──────────────────────────────────────────────────────
# docker build -t fjolsvin/pwsh-windows contrib\docker
# ────────────────────────────────────────────────────────────────────────────────

# ─── EXAMPLE RUN COMMAND ────────────────────────────────────────────────────────
# docker run --mount type=bind,source="$(PWD)",target=$HOMEDRIVE\Users\ContainerUser\workspace  --rm -it fjolsvin/pwsh-windows
# ────────────────────────────────────────────────────────────────────────────────

ARG IMAGE=mcr.microsoft.com/windows/servercore
ARG TAG="20H2"
# [ NOTE ] => small size, lacking some core tools
# - VSCODE remote server doesn not work with nanoserver image
# ARG IMAGE=mcr.microsoft.com/windows/nanoserver:20H2
# [ NOTE ] => too large
# ARG IMAGE=mcr.microsoft.com/windows:20H2


FROM mcr.microsoft.com/powershell:nanoserver  AS powershell-installer
SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
# ─── ENVIRONMENT VARIABLES ──────────────────────────────────────────────────────
ENV ProgramFiles="$HOMEDRIVE\Program Files"
ENV ProgramData="$HOMEDRIVE\ProgramData"
ENV PATH="$HOMEDRIVE\Windows"
ENV PATH="$PATH;$HOMEDRIVE\Windows\system32"
ENV PATH="$PATH;$ProgramFiles\PowerShell"
ENV PATH="$PATH;$ProgramData\Bin"
ENV POWERSHELL_TELEMETRY_OPTOUT="1"
# ─── DOWNLOADING POWESHELL ──────────────────────────────────────────────────────
ARG PS_VERSION=7.0.0
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  Write-Output ('Verifying validity of given Powershell Version ' + $Env:PS_VERSION) ; `
  if (!($Env:PS_VERSION -match '^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$' )) { `
  throw ('PS_Version ({0}) must match the regex "^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$"' -f $Env:PS_VERSION) `
  } `
  Write-Output ('downloading powershell ' + $Env:PS_VERSION) ;`
  $start_time = Get-Date; `
  $NETWORK_IO_URL='https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1'; `
  Invoke-Expression (New-Object net.webclient).downloadstring($NETWORK_IO_URL); `
  set_tls_policies ; `
  $PS_PACKAGE_URL='https://github.com/PowerShell/PowerShell/releases/download/v{0}/PowerShell-{0}-win-x64.zip' -f $Env:PS_VERSION ;`
  download $PS_PACKAGE_URL '/installer/powershell.zip' | Out-Null ; `
  Expand-Archive '/installer/powershell.zip' -DestinationPath '\PowerShell' ; `
  Write-Output ('Time taken: ' + $(((Get-Date).Subtract($start_time)).Seconds) + ' second(s)'); `
  }
# ────────────────────────────────────────────────────────────────────────────────
FROM ${IMAGE}:${TAG}
# ─── ENVIRONMENT VARIABLES ──────────────────────────────────────────────────────
ENV ProgramFiles="$HOMEDRIVE\Program Files"
ENV ProgramData="$HOMEDRIVE\ProgramData"
ENV PATH="$HOMEDRIVE\Windows"
ENV PATH="$HOMEDRIVE\Windows\system32;$PATH"
ENV PATH="$ProgramFiles\PowerShell;$PATH"
ENV PATH="$ProgramData\Bin;$PATH"
#  [ TODO ]
# "$HOME\AppData\Local\bin";
USER ContainerAdministrator
RUN net localgroup administrators /add "User Manager\ContainerUser" && exit 0
RUN setx HOME "%USERPROFILE%" && exit 0
RUN setx TEMP "%USERPROFILE%\AppData\Local\Temp" && exit 0
RUN setx TMP "%USERPROFILE%\AppData\Local\Temp" && exit 0

USER ContainerUser
RUN `
  setx HOME "%USERPROFILE%" && `
  setx TEMP "%USERPROFILE%\AppData\Local\Temp" && `
  setx TMP "%USERPROFILE%\AppData\Local\Temp"
# ─── COPY POWERSHELL CORE FROM THE INSTALLER CONTAINER ──────────────────────────
COPY --from=powershell-installer ["\\PowerShell\\", "$ProgramFiles\\PowerShell"]
# ─── SETTING SHELL ──────────────────────────────────────────────────────────────
SHELL ["pwsh","-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
# ─── INITIAL SETUP ──────────────────────────────────────────────────────────────
ARG user="code"
# ────────────────────────────────────────────────────────────────────────────────
# ARG PASSWORD="Password~1234"
# RUN & { `
#   New-LocalUser -Name $Env:user -Password (ConvertTo-SecureString -AsPlainText `
# $Env:PASSWORD -Force) -FullName $Env:user -Description "LocalAdministrator" ; `
#   Add-LocalGroupMember -Group administrators -Member $Env:user -Verbose ; `
#   Set-LocalUser -name $Env:user -Password ([securestring]::new()) ; `
#   }
# ────────────────────────────────────────────────────────────────────────────────
# [ NOTE ] removing min passwd requirements
RUN & { `
  # [ NOTE ] nano server does not have secedit so we skip errors
  $ErrorActionPreference = 'SilentlyContinue' ;`
  $cfg=$Env:TEMP + '\secpol.cfg' ; `
  secedit /export /cfg  $cfg ; `
  ((Get-Content -Raw $cfg ) -replace 'PasswordComplexity = 1', 'PasswordComplexity = 0').trim() | Set-Content  $cfg ; `
  secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY ; `
  Remove-Item -Path $cfg -Force | Out-Null; `
  }
RUN & { `
  New-Item -Itemtype SymbolicLink -Path ($Env:ProgramFiles + '\PowerShell') -name "powershell.exe" -Value (Get-Command pwsh).Source ;`
  cmd /C net accounts /minpwlen:0 ; `
  cmd /C net accounts ; `
  cmd /C net USER $Env:user "" /ADD ; `
  cmd /C net localgroup administrators /add ('{0}' -f $Env:user ) `
  # Set-ADAccountPassword -Identity 'ContainerAdministrator' -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "p@ssw0rd" -Force) ;`
  # Set-ADAccountPassword -Identity 'ContainerUser' -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "p@ssw0rd" -Force) ;`
  }
USER $user
RUN & { `
  cmd /C setx HOME $Env:USERPROFILE ; `
  cmd /C setx TEMP ($Env:USERPROFILE +'\AppData\Local\Temp') ; `
  cmd /C setx TMP ($Env:USERPROFILE +'\AppData\Local\Temp') ; `
  }
# ─── INTIALIZE POWERSHELL MODULE CACHE ──────────────────────────────────────────
ENV PSModuleAnalysisCachePath="$PUBLIC\AppData\Local\Microsoft\Windows\PowerShell\docker\ModuleAnalysisCache"
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  Write-Output ('initilizing powershell module cache') ;`
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  $start_time = Get-Date; `
  $stopTime = (get-date).AddMinutes(15); `
  while(!(Test-Path -Path $Env:PSModuleAnalysisCachePath)) {  `
  Write-Host "'Waiting for $Env:PSModuleAnalysisCachePath'" ; `
  if((get-date) -gt $stopTime) { throw 'timout expired'} `
  Start-Sleep -Seconds 6 ; `
  } `
  Write-Output ('Time taken: ' + $(((Get-Date).Subtract($start_time)).Seconds) + ' second(s)'); `
  }
# ─── INSTALLING MODULES ─────────────────────────────────────────────────────────
ENV PSModulePath="$USERPROFILE\Documents\WindowsPowerShell\Modules"
ENV PSModulePath="$PSModulePath;$ProgramFiles\PowerShell\Modules"
ENV PATH="$USERPROFILE\Documents\PowerShell\Scripts;$PATH"
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  Write-Output ('installing modules') ;`
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  $start_time = Get-Date; `
  Set-PSRepository -name PSGallery -InstallationPolicy Trusted ; `
  Install-Module -Name Pester -Repository PSGallery -SkipPublisherCheck | Out-Null ; `
  Install-Module -Name powershell-yaml -Repository PSGallery -SkipPublisherCheck | Out-Null ; `
  Write-Output ('Time taken: ' + $(((Get-Date).Subtract($start_time)).Seconds) + ' second(s)'); `
  };
# ─── ARIA2 ──────────────────────────────────────────────────────────────────────
ARG ARIA2_VERSION="1.35.0"
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  'installing aria2 {0}' -f $Env:ARIA2_VERSION ; `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  'Verifying validity of given Aria2 Version {0}' -f $Env:ARIA2_VERSION ;`
  if (!($Env:ARIA2_VERSION -match '^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$' )) { `
  throw ('ARIA2_VERSION ({0}) must match the regex "^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$"' -f $Env:ARIA2_VERSION); `
  } `
  $start_time = Get-Date; `
  if($Env:PROCESSOR_ARCHITECTURE.ToLower() -eq 'amd64' ){ `
  $NETWORK_IO_URL='https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1'; `
  Invoke-Expression (New-Object net.webclient).downloadstring($NETWORK_IO_URL); `
  $DOWNLOAD_URL='https://github.com/aria2/aria2/releases/download/release-{0}/aria2-{0}-win-64bit-build1.zip' -f $Env:ARIA2_VERSION; `
  $TMP_DIR=$Env:TEMP + '\aria2'; `
  $ZIP_FILE=$TMP_DIR + '\aria2.zip'; `
  download $DOWNLOAD_URL $ZIP_FILE ; `
  New-Item -Type Directory -Path ($Env:ProgramData+'\Bin') -Force -ErrorAction SilentlyContinue  | Out-Null ; `
  Expand-Archive $ZIP_FILE -DestinationPath $TMP_DIR -Force  | Out-Null ; `
  Remove-Item -Path $ZIP_FILE -Recurse -Force  | Out-Null ; `
  Copy-Item ($TMP_DIR + '\aria2*\aria2c.exe')  ($Env:ProgramData+ '\Bin') -Force | Out-Null ; `
  aria2c --version | Out-Null ; `
  Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null ;`
  } `
  Write-Output ('Time taken: ' + $(((Get-Date).Subtract($start_time)).Seconds) + ' second(s)'); `
  };
# ─── GIT ────────────────────────────────────────────────────────────────────────
ENV PATH="$ProgramFiles\mingit\cmd;$PATH"
ARG GIT_VERSION="2.31.1"
ARG GIT_PATCH_VERSION="1"
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  'installing git {0}' -f $Env:GIT_VERSION ; `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  'Verifying validity of given Git Version {0}' -f $Env:GIT_VERSION ;`
  if (!($Env:GIT_VERSION -match '^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$' )) { `
  throw ('GIT_VERSION ({0}) must match the regex "^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$"' -f $Env:GIT_VERSION); `
  } `
  $libraries=@('common','network-io'); `
  foreach ($library in $libraries) { `
  $library_url = 'https://raw.githubusercontent.com/da-moon/psutils/master/lib/{0}.ps1' -f $library; `
  Invoke-Expression (New-Object net.webclient).downloadstring($library_url); `
  } `
  $TMP_DIR=$Env:TEMP + '\git'; `
  $DOWNLOAD_URL='https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}-busybox-64-bit.zip' -f $Env:GIT_VERSION,$Env:GIT_PATCH_VERSION; `
  $ZIP_FILE = $TMP_DIR + '\git.zip' ; `
  $start_time = Get-Date; `
  download $DOWNLOAD_URL $ZIP_FILE | Out-Null ; `
  if(!(Test-Path ($Env:ProgramFiles + '\mingit'))) { New-Item -Force -Type Directory -Path ($Env:ProgramFiles + '\mingit') | Out-Null } ; `
  Expand-Archive $ZIP_FILE -ErrorAction SilentlyContinue -DestinationPath ($Env:ProgramFiles + '\mingit') -Force | Out-Null ; `
  git --version | Out-Null ; `
  Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null; `
  Write-Output ('Time taken: ' + $(((Get-Date).Subtract($start_time)).Seconds) + ' second(s)'); `
  };
# ─── OPENSSH ────────────────────────────────────────────────────────────────────
ARG OPENSSH_VERSION=v8.1.0.0p1-Beta
ENV PATH="$ProgramFiles\OpenSSH-Win64;$PATH"
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  'installing openssh {0}' -f $Env:OPENSSH_VERSION ; `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  $NETWORK_IO_URL='https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1'; `
  Invoke-Expression (New-Object net.webclient).downloadstring($NETWORK_IO_URL); `
  $TMP_DIR=$Env:TEMP + '\openssh'; `
  $ZIP_FILE=$TMP_DIR + '\openssh.zip'; `
  $DOWNLOAD_URL = 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/{0}/OpenSSH-Win64.zip' -f $Env:OPENSSH_VERSION ; `
  $start_time = Get-Date; `
  download $DOWNLOAD_URL $ZIP_FILE | Out-Null ; `
  Expand-Archive $ZIP_FILE $Env:ProgramFiles | Out-Null; `
  &  ($Env:ProgramFiles + '\OpenSSH-Win64\Install-SSHd.ps1') ; `
  if(!(Test-Path ($Env:ProgramData + '\ssh'))) { New-Item -Type Directory -Path ($Env:ProgramData + '\ssh') | Out-Null } ; `
  Copy-Item ($Env:ProgramFiles + '\OpenSSH-Win64\sshd_config_default') ($Env:ProgramData + '\ssh\sshd_config') ; `
  $content = Get-Content -Path ( $Env:ProgramData + '\ssh\sshd_config' ) ; `
  $content | ForEach-Object { $_ `
  -replace '#PermitRootLogin.*','PermitRootLogin yes' `
  -replace '#AllowTcpForwarding.*','AllowTcpForwarding yes' `
  -replace '#PasswordAuthentication.*','PasswordAuthentication yes' `
  -replace '#PermitEmptyPasswords.*','PermitEmptyPasswords yes' `
  -replace '#PubkeyAuthentication.*','PubkeyAuthentication yes' `
  -replace '#SyslogFacility.*','SyslogFacility LOCAL0' `
  -replace '#LogLevel.*','LogLevel INFO' `
  -replace 'Match Group administrators','' `
  } | `
  Set-Content -Path ( $Env:ProgramData + '\ssh\sshd_config') ; `
  Add-Content -Path ( $Env:ProgramData + '\ssh\sshd_config') -Value 'ChallengeResponseAuthentication no' ; `
  Add-Content -Path ( $Env:ProgramData + '\ssh\sshd_config') -Value 'HostKeyAgent \\.\pipe\openssh-ssh-agent' ; `
  Add-Content -Path ( $Env:ProgramData + '\ssh\sshd_config') -Value ('Match User {0}' -f $Env:USERNAME) ; `
  New-Item -Path HKLM:\SOFTWARE -Name OpenSSH -Force | Out-Null ; `
  Set-ItemProperty HKLM:\SOFTWARE\OpenSSH\ -Name DefaultShell -Value (Get-Command powershell).Source -Type String -Force | Out-Null; `
  Get-Service ssh* | Set-Service -StartupType Automatic; `
  Remove-Item -Path $TMP_DIR -Recurse -Force | Out-Null; `
  Write-Output ('Time taken: ' + $(((Get-Date).Subtract($start_time)).Seconds) + ' second(s)'); `
  };
EXPOSE 22
EXPOSE 49000-52000
WORKDIR "$HOMEDRIVE\Users\$user\workspace"
# ─── ALIASES ────────────────────────────────────────────────────────────────────
RUN & { `
  New-Item -Path $profile -ItemType File -Force; `
  Add-Content -Path $profile -Value 'New-Alias "gcim" "Get-CimInstance"' ; `
  }
ENTRYPOINT ["powershell","-NoExit", "-Command"]
CMD ["Get-Content","-Wait", "-Path", "$Env:ProgramData\\ssh\\logs\\sshd.log"]
# ─── ACKNOWLEDGEMENTS ───────────────────────────────────────────────────────────
# - https://github.com/janegilring/PSCommunity/blob/master/Containers/PowerShell%20Universal%20Dashboard/NanoDemoWebsite/Dockerfile
# - https://github.com/PowerShell/PowerShell-Docker/tree/master
# - https://github.com/SilkyFowl/MyWindowsContainer/blob/main/ssh/NanoServer/Dockerfile
# - https://github.com/informatique-cdc/ansible-role-win_netroute/blob/master/molecule/default/Dockerfile
# - https://github.com/jenkinsci/docker-ssh-agent/blob/master/11/windows/nanoserver-1809/Dockerfile
# ────────────────────────────────────────────────────────────────────────────────