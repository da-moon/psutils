set shell := [
  "powershell.exe",
   "-Command",
   "$Env:DOCKER_BUILDKIT = '0';"]
# ─── VARIABLES ──────────────────────────────────────────────────────────────────
user := "code"
# ─── DOCKER ─────────────────────────────────────────────────────────────────────
alias ds:=docker-stop
docker-stop:
  Invoke-Expression ("docker stop {0}" -f ([uri]"{{justfile_directory()}}").segments[-1].trim('/')) -ErrorAction SilentlyContinue  2>&1 | Out-Null
# ────────────────────────────────────────────────────────────────────────────────
alias dbn:=docker-build-nanoserver
docker-build-nanoserver:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' build --build-arg "user={{user}}" pwsh-nanoserver ;
alias dbs:=docker-build-servercore
docker-build-servercore:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' build --build-arg "user={{user}}" pwsh-servercore
alias dbw:=docker-build-windows
docker-build-windows:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' build --build-arg "user={{user}}" pwsh-windows
# docker build --build-arg "user={{user}}" -t fjolsvin/pwsh-windows contrib\docker
alias db:=docker-build
docker-build:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' build --build-arg "user={{user}}" --parallel
# ────────────────────────────────────────────────────────────────────────────────
# docker push fjolsvin/pwsh-windows:latest
alias dpn:=docker-push-nanoserver
docker-push-nanoserver:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' push pwsh-servercore-nanoserver

alias dps:=docker-push-servercore
docker-push-servercore:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' push pwsh-servercore

alias dpw:=docker-push-windows
docker-push-windows:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' push pwsh-windows

alias dp:=docker-push
docker-push:
  docker-compose -f '{{justfile_directory()}}\.github\docker-compose.yml' push
# ────────────────────────────────────────────────────────────────────────────────
alias d:=docker
docker : docker-stop
  docker run \
  --mount type=bind,source='{{justfile_directory()}}',target='c:\Users\{{user}}\workspace' \
  --rm \
  -it \
  --name ([uri]"{{justfile_directory()}}").segments[-1].trim('/') \
  fjolsvin/pwsh-servercore \
  pwsh;
# ────────────────────────────────────────────────────────────────────────────────
sshd: docker-stop
  docker run \
  --mount type=bind,source='{{justfile_directory()}}',target='c:\Users\{{user}}\workspace' \
  --rm \
  --name ([uri]"{{justfile_directory()}}").segments[-1].trim('/') \
  -d \
  fjolsvin/pwsh-servercore ;

  & '{{justfile_directory()}}\contrib\scripts\ssh-config.ps1' \
  ([uri]"{{justfile_directory()}}").segments[-1].trim('/') \
  '{{user}}';
# ────────────────────────────────────────────────────────────────────────────────
alias code:=vscode-server
alias up:=vscode-server
# & 'C:\Users\code\.vscode-server\bin\*\server.cmd' --start-server --host=127.0.0.1 --enable-remote-auto-s shutdown --port=0 --connection-secret "C:\Users\code\.vscode-server\.3c4e3df9e89829dce27b7b5c24508306b151f30d.token" *> 'C:\Users\code\.vscode-server\.3c4e3df9e89829dce27b7b5c24508306b151f30d.log'
# sshd
vscode-server:
  {{justfile_directory()}}\contrib\scripts\vscode-server.ps1 ([uri]"{{justfile_directory()}}").segments[-1].trim('/') 
# ─── BIN EXEC ───────────────────────────────────────────────────────────────────
go-toolchain: docker-build
	docker run \
	--mount type=bind,source='{{justfile_directory()}}',target='c:\Users\{{user}}\workspace' \
	--rm \
	-it \
	fjolsvin/pwsh-nanoserver \
	bin\go-toolchain.ps1 --install -d; go --version