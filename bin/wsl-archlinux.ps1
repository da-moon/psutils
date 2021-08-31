#Requires -Version 5
# vim: ft=powershell tabstop=2 shiftwidth=2 softtabstop=2 expandtab
# Set-ExecutionPolicy Bypass -Scope Process -Force
# iwr -useb 'https://raw.githubusercontent.com/da-moon/psutils/master/bin/wsl-archlinux.ps1' | iex
$name="archlinux"
# ────────────────────────────────────────────────────────────────────────────────
[string] $architecture = reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE | ForEach-Object { ($_ -split "\s+")[3] }
$architecture = $architecture.ToLower();
$architecture = $architecture.Trim();
$installed_distros=wsl -l | where {$_ -ne ""}
if ( -not ($installed_distros.Contains($name)) ){
  $distro_path=('{0}\wsl\{1}' -f $Env:AppData,$name);
  $rootfs_path=("{0}\Downloads\vm-image\wsl\{1}.tar.gz" `
    -f $Env:USERPROFILE,'arch') ;
  if (-not(Test-Path $rootfs_path)) {
    $parent=Split-Path -parent $rootfs_path ;
    if (-not(Test-Path -Path $parent -PathType Container)) {
      try {
        $null = New-Item `
          -Force `
          -ItemType Directory `
          -Path $parent `
          -ErrorAction Stop
      }
      catch {
        throw $_.Exception.Message
      }
    }
    if (-not(Test-Path $rootfs_path)) {
      $path=$env:TMP + '\arch'
      if (Test-Path $path) {
        $null=Remove-Item `
        -Force `
        -Recurse `
        -Path $path `
        -ErrorAction Stop ;
      }
      $null = New-Item `
        -Force `
        -ItemType Directory `
        -Path $path `
        -ErrorAction Stop ;
      Write-Host "Getting Latest ArchLinux Filesytem Download URL" ;
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ;
      if ($architecture -eq 'arm64' ){
        $rootfs_uri="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
        if (Get-Command aria2c -ErrorAction SilentlyContinue) {
          aria2c `
          --continue `
          --optimize-concurrent-downloads `
          --min-split-size=1M `
          --max-concurrent-downloads=16 `
          --max-connection-per-server=16 `
          --file-allocation=falloc `
          --dir="$path" `
          --out="rootfs.tar.gz" `
          "$rootfs_uri";
        }else{
        Invoke-WebRequest `
          -Uri $rootfs_uri `
          -OutFile ('{0}\arch.tar.gz' -f $path) ;
        }
      }else{
        $repo="yuk7/ArchWSL" ;
        $uri="https://api.github.com/repos/$($repo)/releases" ;
        $latest = (Invoke-RestMethod `
          -Uri $uri `
          -UseBasicParsing)[0] ;
        $assets = $latest.assets ;
        $rootfs_uri=$assets `
        | Where-Object {$_.name -Like ('*.{0}' -f 'zip'  )} `
        | Select-Object -ExpandProperty browser_download_url ;
        if (Get-Command aria2c -ErrorAction SilentlyContinue) {
          aria2c `
          --continue `
          --optimize-concurrent-downloads `
          --min-split-size=1M `
          --max-concurrent-downloads=16 `
          --max-connection-per-server=16 `
          --file-allocation=falloc `
          --dir="$path" `
          --out="arch.zip" `
          "$rootfs_uri";
        }else{
          Invoke-WebRequest `
            -Uri $rootfs_uri `
            -OutFile ('{0}\arch.zip' -f $path) ;
        }
        Expand-Archive `
          -Force `
          -Path ('{0}\arch.zip' -f $path) `
          -DestinationPath $path `
          -ErrorAction Stop ;
        }
      Move-Item -Force `
        -Path ('{0}\rootfs.tar.gz' -f $path) `
        -Destination $rootfs_path `
        -ErrorAction Stop ;
      $null=Remove-Item `
      -Force `
      -Recurse `
      -Path $path `
      -ErrorAction Stop ;
    }
  }
  if (Test-Path $distro_path) {
    $null=Remove-Item `
    -Force `
    -Recurse `
    -Path $distro_path `
    -ErrorAction Stop ;
  }
  $null = New-Item `
    -Force `
    -ItemType Directory `
    -Path $distro_path `
    -ErrorAction Stop ;
  wsl.exe `
    --import "$name" "$distro_path" "$rootfs_path"
}
Write-Host 'initial setup'
wsl -d $name -u root -- `
    /bin/bash -c (@'
set -ex;
pacman-key --init
[[ $(uname --m) == "aarch64" ]] && pacman-key --populate archlinuxarm || pacman-key --populate archlinux
pacman -Syyu --noconfirm
'@ ) ;
Write-Host ('Configuring Pacman')
wsl -d $name -u root -- `
    /bin/bash -c (@'
set -ex;
sed -i -e "/ParallelDownloads/d" -e  '/\[options\]/a ParallelDownloads = 16' /etc/pacman.conf ;
sed -i -e "/Color/d" -e "/ILoveCandy/d" -e '/\[options\]/a Color'  -e '/\[options\]/a ILoveCandy' /etc/pacman.conf ;
'@ ) ;
if ($architecture -ne 'arm64' ){
  Write-Host ('finding fastest sources')
  wsl -d $name -u root -- `
    /bin/bash -c (@'
set -ex;
pacman -Sy --noconfirm reflector ;
reflector -p https --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist ;
'@ ) ;
}
Write-Host 'ensuring users belonging to sudo group can become root without password'
wsl -d $name -u root -- `
    /bin/bash -c (@'
set -ex;
pacman -S --noconfirm sudo
getent group sudo > /dev/null || groupadd sudo
sed -i -e '/%wheel.*NOPASSWD:\s*ALL/d' -e '/%wheel\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/d'  /etc/sudoers;
cat << EOF >> /etc/sudoers
%wheel ALL=(ALL) ALL
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
'@ ) ;
Write-Host ('Creating user : {0}' -f $Env:USERNAME)
wsl -d $name -u root -- /bin/bash -c (@'
set -ex;
userdel alarm || true
if getent passwd alarm > /dev/null ; then
  userdel -r -f alarm
fi
if ! getent passwd '${0}' > /dev/null ; then
  useradd -U -md '/home/{0}' -G 'wheel,storage,power' -s /bin/bash -p '{0}' '{0}'
  echo '{0}:{0}' | chpasswd
fi
'@ -f $Env:USERNAME ) ;

if ($architecture -eq 'arm64' ){
  wsl -d $name -u root -- /bin/bash -c (@'
set -ex;
if [ "$(id -u {0})" != "1000" ] ; then
  usermod --uid 1000 {0}
fi
if [ "$(id -g {0})" != "1000" ] ; then
  groupmod --gid 1000 {0}
fi
chown "$(id -u {0}):$(id -g {0})" /home/{0} -R
'@ -f $Env:USERNAME ) ;
}
Write-Host ('Setting up wsl conf for user : {0}' -f $Env:USERNAME)
wsl -d $name -u root -- /bin/bash -c (@'
set -ex;
cat << EOF |  tee /etc/wsl.conf > /dev/null
[user]
default={0}
[interop]
enabled=false
appendWindowsPath=false
[wsl2]
localhostForwarding=true
EOF
'@ -f $Env:USERNAME ) ;
Write-Host ('installing core packages')
wsl -d $name -u $Env:USERNAME -- /bin/bash -c (@'
set -ex;
sudo pacman -Sy --noconfirm --needed \
  pacman-contrib \
  expac \
  base-devel \
  git \
  bash-completion \
  sshpass \
  wget \
  curl \
  unzip
'@ ) ;
# ────────────────────────────────────────────────────────────────────────────────
Write-Host ('ensuring paru is installed')
wsl -d $name -u $Env:USERNAME --  /bin/bash -c (@'
set -ex;
if ! command -- paru -h > /dev/null 2>&1 ; then
  rm -rf /tmp/paru
  git clone https://aur.archlinux.org/paru.git /tmp/paru
  pushd /tmp/paru
  for i in {1..5}; do
  makepkg -sicr --noconfirm && break || sleep 15
  done ;
  popd
  sudo rm -rf /tmp/paru
  sudo pacman -Rcns --noconfirm rust > /dev/null 2>&1 || true
fi
'@ ) ;
# ─── PACMAN PACKAGES ────────────────────────────────────────────────────────────
Write-Host ('installing devel packages')
wsl -d $name -u $Env:USERNAME -- `
    /bin/bash -c (@'
set -ex;
sudo pacman -Sy --noconfirm --needed \
  cmake \
  go \
  perl \
  python \
  python2 \
  nodejs \
  ruby \
  yarn
'@ ) ;
Write-Host ('installing common cli tools')
wsl -d $name -u $Env:USERNAME -- /bin/bash -c (@'
set -ex;
sudo pacman -Sy --noconfirm --needed \
  fzf \
  aria2 \
  jq \
  github-cli \
  rsync \
  rclone \
  parallel \
  tmux \
  htop \
  progress \
  unrar \
  dialog \
  psutils
'@ ) ;
Write-Host ('installing fonts')
wsl -d $name -u $Env:USERNAME -- `
    /bin/bash -c (@'
set -ex;
sudo pacman -Sy --noconfirm --needed \
  noto-fonts \
  ttf-ubuntu-font-family \
  ttf-dejavu \
  ttf-freefont \
  ttf-liberation \
  ttf-droid \
  ttf-inconsolata \
  ttf-roboto \
  terminus-font \
  ttf-font-awesome
'@ ) ;

Write-Host ('installing common aur packages')
wsl -d $name -u $Env:USERNAME -- `
    /bin/bash -c (@'
set -ex;
paru --needed --removemake --cleanafter --noconfirm -Sy \
  glow \
  rcm \
  shell-color-scripts \
  fastfetch-git \
  xorg-font-utils \
  git-completion \
  yarn-completion-git \
  fzf-extras
'@ ) ;
# ────────────────────────────────────────────────────────────────────────────────
Write-Host ('setting up dotfiles')
wsl -d $name -u $Env:USERNAME -- /bin/bash -c (@"
set -ex;
git clone https://github.com/da-moon/.dotfiles ~/.dotfiles
git clone https://github.com/da-moon/SpaceVim.d ~/.SpaceVim.d
rcup -f
"@ ) ;
# ─── DOCKER ─────────────────────────────────────────────────────────────────────
Write-Host ('installing docker')
wsl -d $name -u $Env:USERNAME -- /bin/bash -c (@"
set -ex;
sudo pacman -Sy --noconfirm --needed docker docker-compose
sudo usermod -aG docker \`"`$(whoami)\`"
"@ ) ;
# ─── RUST TOOLCHAIN ─────────────────────────────────────────────────────────────
Write-Host ('setting up rust toolchain')
wsl -d $name -u $Env:USERNAME -- `
    /bin/bash -c (@"
set -ex;
sudo pacman -Rcns --noconfirm rust || true ;
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain stable --profile default ;
. ~/.cargo/env
rustup --version
cargo --version
rustc --version
rustup toolchain install stable-`$(uname -m)-pc-windows-msvc
rustup toolchain install nightly-`$(uname -m)-unknown-linux-gnu
rustup default stable-`$(uname -m)-unknown-linux-gnu
rustup component add rust-src
rustup component add rustfmt
rustup component add rls
rustup component add clippy
"@ ) ;
# ────────────────────────────────────────────────────────────────────────────────
Write-Host ('installing rust cli utilities')
wsl -d $name -u $Env:USERNAME -- /bin/bash -c (@"
set -ex;
. ~/.environment
rustup run --install stable cargo install --all-features \
  cargo-update \
  subsystemctl \
  convco \
  just \
  starship \
  exa \
  bat \
  tokei \
  sd \
  fd-find \
  hyperfine \
  skim \
  git-delta \
  jen \
  releez \
  procs ;
rustup run --install stable cargo install --all-features --git https://github.com/ms-jpq/sad
rustup run --install nightly cargo install --all-features ripgrep nu
rustup run --install nightly cargo install --all-features --git https://github.com/K4rakara/freshfetch
rustup default stable-`$(uname -m)-unknown-linux-gnu
find ~/.cargo/bin/ -type f -exec basename {} \; | sudo xargs -r -I {} sudo ln -sf ~/.cargo/bin/{} /usr/local/bin/{}
"@ ) ;

Write-Host ('Subsystemctl setup')
$sh = New-Object -ComObject ("WScript.Shell")
$Path = '{0}\{1}.lnk' -f ($Env:APPDATA+"\Microsoft\Windows\Start Menu\Programs\Startup"),$name
Remove-Item -Force -Path $Path -ErrorAction SilentlyContinue
$Shortcut = $sh.CreateShortcut($Path)
$Shortcut.WorkingDirectory="C:\WINDOWS\system32"
$Shortcut.TargetPath = "wsl.exe"
$Shortcut.Arguments="-u root --exec subsystemctl start"
$Shortcut.Save()
[Runtime.InteropServices.Marshal]::ReleaseComObject($sh) | Out-Null
wsl -d $name -u root -- subsystemctl start
wsl -d $name -u root -- subsystemctl exec systemctl disable systemd-networkd.socket
wsl -d $name -u root -- subsystemctl exec systemctl disable systemd-networkd.service
wsl -d $name -u root -- subsystemctl exec systemctl disable systemd-resolved
wsl -d $name -u root -- subsystemctl exec systemctl enable docker.socket
wsl -d $name -u root -- subsystemctl exec systemctl enable docker.service
wsl --set-default $name
wsl --shutdown
# ─── LOGIN COMMAND ──────────────────────────────────────────────────────────────
# wsl -d archlinux -u root -- subsystemctl shell --start ('--uid=$(id -u {0})' -f $Env:USERNAME)
# wsl -d archlinux -u root -- subsystemctl shell --uid=1001
# https://gist.github.com/nosada/d62def4e6ec1fcfe998f1b8abbf4e0a1
# ─── WINDOWS TERMINAL SETUP ─────────────────────────────────────────────────────
# $win_terminal_path = ('{0}\Packages\{1}\LocalState\settings.json' `
  # -f $env:LOCALAPPDATA,(Get-ChildItem -Path $env:LOCALAPPDATA\Packages -Filter *Microsoft.WindowsTerminal*))
# cargo install --all-features
# IFS=':' read -r -a array <<< "$PATH"
# cat /usr/share/xsessions/regolith.desktop
