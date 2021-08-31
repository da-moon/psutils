#Requires -Version 5
# vim: ft=powershell tabstop=2 shiftwidth=2 softtabstop=2 expandtab
# Set-ExecutionPolicy Bypass -Scope Process -Force
# iwr -useb 'https://raw.githubusercontent.com/da-moon/psutils/master/bin/system-init.ps1' | iex
if (-not(Test-Path -Path (Split-Path -parent $PROFILE.CurrentUserAllHosts) -PathType Container)) {
  $null = New-Item -ItemType Directory -Path (Split-Path -parent $PROFILE.CurrentUserAllHosts) -Force -ErrorAction Stop
}
if (-not(Test-Path -Path $PROFILE.CurrentUserAllHosts -PathType Leaf)) {
  $uri='https://raw.githubusercontent.com/da-moon/psutils/master/lib/profile.ps1'
  Invoke-WebRequest -Uri $uri -OutFile $PROFILE.CurrentUserAllHosts -ErrorAction Stop -Verbose
}
if (-not(Get-Command scoop -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy Bypass -Scope Process -Force
  iwr -useb get.scoop.sh | iex
  scoop install git
  $(scoop bucket known).split() | ForEach-Object{ scoop bucket add $_.trim()}
  scoop alias add 'S'     'scoop install $args'
  scoop alias add 'Sc'    'scoop cleanup $args'
  scoop alias add 'Si'    'scoop info $args'
  scoop alias add 'Ss'    'scoop search $args'
  scoop alias add 'Sy'    "scoop update '*'"
  scoop alias add 'Syyu'  'scoop update * ; if ($args){scoop install $args}'
  scoop alias add 'R'     'scoop uninstall $args'
  scoop alias add 'B'     'scoop bucket $args'
  scoop alias add 'Ba'    'scoop bucket add $args'
  scoop alias add 'Bk'    'scoop bucket known $args'
  scoop alias add 'Bl'    'scoop bucket list $args'
  scoop alias add 'Br'    'scoop bucket rm $args'
  scoop alias add allin 'gci "~/scoop/buckets/$($args[0])/bucket" |% { echo "$($_.BaseName)" }' 'List all apps in a bucket'
}
scoop install `
  7zip `
  aria2 `
  bulk-crap-uninstaller `
  cacert `
  chisel `
  cmake `
  Dark `
  fzf `
  gcc `
  gh `
  git `
  glow `
  go `
  gsudo `
  Innounp `
  Lessmsi `
  make `
  marp `
  memreduct `
  msys2 `
  neovim-nightly `
  nodejs `
  nodejs-lts-np `
  notable `
  openssl `
  python `
  rufus `
  rust-analyzer `
  rustup-msvc `
  syncthing `
  synctrayzor `
  vcredist2017 `
  vcredist2019 `
  vlc `
  gsudo `
  vscode `
  win32-openssh `
  wire `
  yarn
sudo scoop install `
  Open-Sans `
  Cascadia-Code
