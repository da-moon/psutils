set shell := ["powershell.exe", "-Command"]
user := "code"
docker-stop:
  Invoke-Expression ("docker stop {0}" -f ([uri]"{{justfile_directory()}}").segments[-1].trim('/')) -ErrorAction SilentlyContinue  2>&1 | Out-Null

alias db:=docker-build
docker-build:
  docker build --build-arg "user={{user}}" -t fjolsvin/pwsh-windows contrib\docker
docker-push:docker-build
  docker push fjolsvin/pwsh-windows:latest
#  docker-build
docker: docker-stop
  Invoke-Expression (New-Object net.webclient).downloadstring('https://raw.githubusercontent.com/da-moon/psutils/master/lib/string.ps1');
  docker run \
  --mount type=bind,source='{{justfile_directory()}}',target='c:\Users\code\workspace' \
  --rm \
  --name ([uri]"{{justfile_directory()}}").segments[-1].trim('/') \
  -d \
  fjolsvin/pwsh-windows ;
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
  | Expand-Tab 2 ;
# (Get-Content -Raw $Env:UserProfile\.ssh\config) | ? {$_.trim() -ne "" } 
# (Get-Content -Raw $Env:UserProfile\.ssh\config) -replace ('(?s)\r?\nHost {0}.*?MACs hmac-sha2-512\r?\n' -f "psutils")
# | Out-File -Encoding ascii -Append $Env:UserProfile\.ssh\config

go-toolchain: docker-build
	docker run \
	--mount type=bind,source='{{justfile_directory()}}',target='c:\Users\code\workspace' \
	--rm \
	-it \
	fjolsvin/pwsh-windows \
	bin\go-toolchain.ps1 --install -d; go --version


# | set-content file.txt