set shell := ["powershell.exe", "-Command"]
# ─── VARIABLES ──────────────────────────────────────────────────────────────────
user := "code"
# ─── DOCKER ─────────────────────────────────────────────────────────────────────
alias ds:=docker-stop
docker-stop:
  Invoke-Expression ("docker stop {0}" -f ([uri]"{{justfile_directory()}}").segments[-1].trim('/')) -ErrorAction SilentlyContinue  2>&1 | Out-Null
# ────────────────────────────────────────────────────────────────────────────────
alias db:=docker-build
docker-build:
  docker build --build-arg "user={{user}}" -t fjolsvin/pwsh-windows contrib\docker
# ────────────────────────────────────────────────────────────────────────────────
alias dp:=docker-push
docker-push:docker-build
  docker push fjolsvin/pwsh-windows:latest
# ────────────────────────────────────────────────────────────────────────────────
dr : docker-stop docker-build
  docker run \
  --mount type=bind,source='{{justfile_directory()}}',target='c:\Users\{{user}}\workspace' \
  --rm \
  -it \
  --name ([uri]"{{justfile_directory()}}").segments[-1].trim('/') \
  fjolsvin/pwsh-windows \
  pwsh;
alias d:=docker
docker: docker-stop docker-build
  docker run \
  --mount type=bind,source='{{justfile_directory()}}',target='c:\Users\{{user}}\workspace' \
  --rm \
  --name ([uri]"{{justfile_directory()}}").segments[-1].trim('/') \
  -d \
  fjolsvin/pwsh-windows ;

  (Get-Content -Raw $Env:UserProfile\.ssh\config) \
  -replace ('(?s)\r?\nHost {0}.*?MACs hmac-sha2-512\r?\n' \
  -f "psutils") \
  | Set-Content $Env:UserProfile\.ssh\config ;

  "`nHost {0} `n\
  `tHostName {1} `n\
  `tUser {{user}} `n\
  `tStrictHostKeyChecking no `n\
  `tCheckHostIP no `n\
  `tUserKnownHostsFile /dev/null `n\
  `tMACs hmac-sha2-512`n" \
  -f \
  ([uri]"{{justfile_directory()}}").segments[-1].trim('/') \
  ,(docker inspect -f '{{{{range.NetworkSettings.Networks}}{{{{.IPAddress}}{{{{end}}' ([uri]"{{justfile_directory()}}").segments[-1].trim('/') ) \
  | Out-File -Encoding ascii -Append $Env:UserProfile\.ssh\config ;

  ((Get-Content -Raw $Env:UserProfile\.ssh\config ) \
  -replace "(?m)^\s*`r`n",'').trim() \
  -replace "`t", "  " \
  -replace "^\s\s*", "  " \
  | Set-Content $Env:UserProfile\.ssh\config ;
vscode-server:
  & 'C:\Users\code\.vscode-server\bin\*\server.cmd' --start-server --host=127.0.0.1 --enable-remote-auto-s shutdown --port=0 --connection-secret "C:\Users\code\.vscode-server\.3c4e3df9e89829dce27b7b5c24508306b151f30d.token" *> 'C:\Users\code\.vscode-server\.3c4e3df9e89829dce27b7b5c24508306b151f30d.log'

# ─── BIN EXEC ───────────────────────────────────────────────────────────────────
go-toolchain: docker-build
	docker run \
	--mount type=bind,source='{{justfile_directory()}}',target='c:\Users\{{user}}\workspace' \
	--rm \
	-it \
	fjolsvin/pwsh-windows \
	bin\go-toolchain.ps1 --install -d; go --version