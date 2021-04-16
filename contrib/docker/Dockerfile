# escape=`

# ─── EXAMPLE BUILD COMMAND ──────────────────────────────────────────────────────
# docker build -t fjolsvin/pwsh-windows contrib\docker
# ────────────────────────────────────────────────────────────────────────────────

# ─── EXAMPLE RUN COMMAND ────────────────────────────────────────────────────────
# docker run --mount type=bind,source="$(PWD)",target=c:\Users\ContainerUser\workspace  --rm -it fjolsvin/pwsh-windows
# ────────────────────────────────────────────────────────────────────────────────


FROM mcr.microsoft.com/powershell:nanoserver  AS installer-Env

SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

#
# ─── ENVIRONMENT VARIABLES ──────────────────────────────────────────────────────
#
ENV ProgramFiles="C:\Program Files"
ENV ProgramData="C:\ProgramData"
ENV PATH="C:\Windows"
ENV PATH="$PATH;C:\Windows\system32"
ENV PATH="$PATH;$ProgramFiles\PowerShell"
ENV PATH="$PATH;$ProgramData\Bin"
ENV POWERSHELL_TELEMETRY_OPTOUT="1"
# ────────────────────────────────────────────────────────────────────────────────
ARG NETWORK_IO_URL="https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1"
# ────────────────────────────────────────────────────────────────────────────────
#
# ─── DOWNLOADING POWESHELL ──────────────────────────────────────────────────────
#
ARG PS_VERSION=7.0.0
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v$PS_VERSION/PowerShell-$PS_VERSION-win-x64.zip
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  Write-Output ('Verifying validity of give Powershell Version ' + $Env:PS_VERSION) ; `
  if (!($Env:PS_VERSION -match '^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$' )) { `
  throw ('PS_Version ({0}) must match the regex "^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$"' -f $Env:PS_VERSION) `
  } `
  Write-Output ('downloading powershell ' + $Env:PS_VERSION) ;`
  $start_time = Get-Date; `
  Invoke-Expression (New-Object net.webclient).downloadstring($Env:NETWORK_IO_URL); `
  set_tls_policies ; `
  download $Env:PS_PACKAGE_URL '/installer/powershell.zip' | Out-Null ; `
  Expand-Archive '/installer/powershell.zip' -DestinationPath '\PowerShell' ; `
  Write-Output ('Time taken: ' + $((Get-Date).Subtract($start_time).Seconds) + ' second(s)'); `
  }

#
# ──────────────────────────────────────────────────────────────────────────────────────────────────────────── I ──────────
#   :::::: I N S T A L L   P O W E R S H E L L   I N T O   N A N O S E R V E R : :  :   :    :     :        :          :
# ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#
FROM mcr.microsoft.com/windows/nanoserver:20H2
# ────────────────────────────────────────────────────────────────────────────────
# USER ContainerAdministrator
USER "ContainerUser"
# ENV HOME="C:\Users\${USERNAME}"
# ENV TEMP="${HOME}\AppData\Local\Temp"
#
# ─── ENVIRONMENT VARIABLES ──────────────────────────────────────────────────────
#
ENV ProgramFiles="C:\Program Files"
ENV ProgramData="C:\ProgramData"
ENV PATH="C:\Windows"
ENV PATH="$PATH;C:\Windows\system32"
ENV PATH="$PATH;$ProgramFiles\PowerShell"
ENV PATH="$PATH;$ProgramData\Bin"
ENV PSCORE="$ProgramFiles\PowerShell\pwsh.exe"
ENV POWERSHELL_TELEMETRY_OPTOUT="1"
ENV TEMP="C:\Users\ContainerUser\AppData\Local\Temp"

#
# ─── COPY POWERSHELL CORE FROM THE INSTALLER CONTAINER ──────────────────────────
#
COPY --from=installer-Env ["\\PowerShell\\", "$ProgramFiles\\PowerShell"]
# SHELL ["pwsh", "-NoLogo", "-NoProfile","-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
SHELL ["pwsh","-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

#
#
# ─── INTIALIZE POWERSHELL MODULE CACHE ──────────────────────────────────────────
#
ENV PSModuleAnalysisCachePath="C:\Users\Public\AppData\Local\Microsoft\Windows\PowerShell\docker\ModuleAnalysisCache"

RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  Write-Output ('initilizing powershell module cache') ;`
  $start_time = Get-Date; `
  $stopTime = (get-date).AddMinutes(15); `
  while(!(Test-Path -Path $Env:PSModuleAnalysisCachePath)) {  `
  Write-Host "'Waiting for $Env:PSModuleAnalysisCachePath'" ; `
  if((get-date) -gt $stopTime) { throw 'timout expired'} `
  Start-Sleep -Seconds 6 ; `
  } `
  Write-Output ('Time taken: ' + $((Get-Date).Subtract($start_time).Seconds) + ' second(s)'); `
  }

#
# ─── INSTALLING MODULES ─────────────────────────────────────────────────────────
#
ENV PSModulePath="C:\Users\ContainerUser\Documents\WindowsPowerShell\Modules"
ENV PSModulePath="$PSModulePath;$ProgramFiles\PowerShell\Modules"
ENV PATH="$PATH;C:\Users\ContainerUser\Documents\PowerShell\Scripts"
RUN & { `
  Write-Output '─────────────────────────────────────────────────────────────────' ; `
  Write-Output ('installing modules') ;`
  $start_time = Get-Date; `
  Set-PSRepository -name PSGallery -InstallationPolicy Trusted ; `
  Install-Module -Name Pester -Repository PSGallery -SkipPublisherCheck ; `
  Install-Module -Name powershell-yaml -Repository PSGallery -SkipPublisherCheck | Out-Null ; `
  Write-Output ('Time taken: ' + $((Get-Date).Subtract($start_time).Seconds) + ' second(s)'); `
  };
#
# ─── INSTALLING ARIA2 ───────────────────────────────────────────────────────────
#
ARG ARIA2_RELEASE="1.35.0"
RUN & { `
  $script = iwr -useb 'https://raw.githubusercontent.com/da-moon/psutils/master/bin/install-aria2.ps1'; `
  Invoke-Command -ScriptBlock ([scriptblock]::Create("$script")) -ArgumentList $Env:ARIA2_RELEASE ; `
  };
#
# ─── INSTALL GIT ────────────────────────────────────────────────────────────────
#

# ARG GIT_RELEASE="2.31.1"
# RUN & { `
#   Write-Output '─────────────────────────────────────────────────────────────────' ; `
#   Write-Output ('installing git ' + $Env:GIT_RELEASE) ;`
#   $start_time = Get-Date; `
#   if($Env:PROCESSOR_ARCHITECTURE.ToLower() -eq 'amd64' ){ `
#   $url='https://github.com/git-for-windows/git/releases/download/v'+$Env:GIT_RELEASE+'.windows.1/MinGit-'+$Env:GIT_RELEASE+'-64-bit.zip';`
#   $dir=$Env:TEMP + '\git'; `
#   Invoke-Expression (New-Object net.webclient).downloadstring($Env:NETWORK_IO_URL); `
#   set_tls_policies ; `
#   download $url ($dir+'\git.zip') ; `
#   New-Item -Type Directory -Path ($Env:ProgramData+'\Bin') -Force -ErrorAction SilentlyContinue  | Out-Null ; `
#   Expand-Archive ($dir+'\git.zip') -DestinationPath ($Env:ProgramData+'\Bin') -Force  | Out-Null ; `
#   Remove-Item -Path ($dir+'\git.zip') -Recurse -Force  | Out-Null ; `
#   Remove-Item -Path $dir -Recurse -Force | Out-Null`
#   } `
#   Write-Output ('Time taken: ' + $((Get-Date).Subtract($start_time).Seconds) + ' second(s)'); `
#   };

# ────────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────────────────────────────────────────────────────

#
# ─── INSTALLING CHOCOLATEY ──────────────────────────────────────────────────────
#
USER "ContainerAdministrator"
# ENV HOME="C:\Users\ContainerAdministrator"
# ENV TEMP="${HOME}\AppData\Local\Temp"

USER "ContainerUser"
WORKDIR "c:\Users\ContainerUser"
ENTRYPOINT ["pwsh"]

# ─── ACKNOWLEDGEMENTS ───────────────────────────────────────────────────────────
# - https://github.com/janegilring/PSCommunity/blob/master/Containers/PowerShell%20Universal%20Dashboard/NanoDemoWebsite/Dockerfile
# - https://github.com/PowerShell/PowerShell-Docker/tree/master
# ────────────────────────────────────────────────────────────────────────────────
