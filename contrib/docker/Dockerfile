# escape=`


# Args used by from statements must be defined here:
ARG InstallerVersion=nanoserver
ARG InstallerRepo=mcr.microsoft.com/powershell
ARG NanoServerRepo=mcr.microsoft.com/windows/nanoserver

# Use server core as an installer container to extract PowerShell,
# As this is a multi-stage build, this stage will eventually be thrown away
FROM ${InstallerRepo}:$InstallerVersion  AS installer-env

#
# ─── ARGUMENTS FOR INSTALLING POWERSHELL ────────────────────────────────────────
#

ARG PS_VERSION=6.0.0
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v$PS_VERSION/PowerShell-$PS_VERSION-win-x64.zip
SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# disable telemetry
ENV POWERSHELL_TELEMETRY_OPTOUT="1"

ARG PS_PACKAGE_URL_BASE64

RUN Write-host "Verifying valid Version..."; `
  if (!($env:PS_VERSION -match '^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$' )) { `
  throw ('PS_Version ({0}) must match the regex "^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$"' -f $env:PS_VERSION) `
  }
ARG NETWORK_IO_URL="https://raw.githubusercontent.com/da-moon/psutils/master/lib/network-io.ps1"

RUN $start_time = Get-Date; `
  $ProgressPreference = 'SilentlyContinue'; `
  Write-host "using url: $env:PS_PACKAGE_URL" ;`
  $url = $env:PS_PACKAGE_URL; `
  Write-host "downloading: $url"; `
  Invoke-Expression (New-Object net.webclient).downloadstring($Env:NETWORK_IO_URL); `
  set_tls_policies ; `
  download "$url" "/installer/powershell.zip"; `
  Expand-Archive /installer/powershell.zip -DestinationPath \PowerShell ;
# Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)";

# Install PowerShell into NanoServer
FROM ${NanoServerRepo}:20H2

#
# ─── ENVIRONMENT VARIABLES ──────────────────────────────────────────────────────
#
# Copy PowerShell Core from the installer container
ENV ProgramFiles="C:\Program Files"
# set a fixed location for the Module analysis cache
ENV PSModuleAnalysisCachePath="C:\Users\Public\AppData\Local\Microsoft\Windows\PowerShell\docker\ModuleAnalysisCache"
# Persist %PSCORE% ENV variable for user convenience
ENV PSCORE="$ProgramFiles\PowerShell\pwsh.exe"
# Set the default windows path so we can use it
ENV WindowsPATH="C:\Windows\system32;C:\Windows"
ENV POWERSHELL_DISTRIBUTION_CHANNEL="PSDocker-NanoServer-20H2"

### Begin workaround ###
# Note that changing user on nanoserver is not recommended
# See, https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/container-base-images#base-image-differences
# But we are working around a bug introduced in the nanoserver image introduced in 1809
# Without this, PowerShell Direct will fail
# this command sholud be like this: https://github.com/PowerShell/PowerShell-Docker/blob/f81009c42c96af46aef81eb1515efae0ef29ad5f/release/preview/nanoserver/docker/Dockerfile#L76
USER ContainerAdministrator

# This is basically the correct code except for the /M
RUN setx PATH "%PATH%;%ProgramFiles%\PowerShell;" /M

USER ContainerUser
### End workaround ###

COPY --from=installer-env ["\\PowerShell\\", "$ProgramFiles\\PowerShell"]
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

#
# ─── INTIALIZE POWERSHELL MODULE CACHE ──────────────────────────────────────────
#


RUN $start_time = Get-Date; `
  $stopTime = (get-date).AddMinutes(15); `
  $ErrorActionPreference = 'Stop' ; `
  $ProgressPreference = 'SilentlyContinue' ; `
  while(!(Test-Path -Path $env:PSModuleAnalysisCachePath)) {  `
  Write-Host "'Waiting for $env:PSModuleAnalysisCachePath'" ; `
  if((get-date) -gt $stopTime) { throw 'timout expired'} `
  Start-Sleep -Seconds 6 ; `
  }
# Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)";
#
# ─── INSTALLING MODULES ─────────────────────────────────────────────────────────
#
RUN $start_time = Get-Date; `
  Install-Module -Name PowerShellGet -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber; `
  Install-Module -Name powershell-yaml -Scope CurrentUser -Force -SkipPublisherCheck; `
  Install-Module -Name Pester -Scope CurrentUser -Force -MaximumVersion 4.99 -SkipPublisherCheck;
ENTRYPOINT ["pwsh.exe"]
# ─── ACKNOWLEDGEMENTS ───────────────────────────────────────────────────────────
# - https://github.com/janegilring/PSCommunity/blob/master/Containers/PowerShell%20Universal%20Dashboard/NanoDemoWebsite/Dockerfile
# - https://github.com/PowerShell/PowerShell-Docker/tree/master
# ────────────────────────────────────────────────────────────────────────────────
