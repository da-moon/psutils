DISTRO := 'arch'
set shell := ["powershell.exe", "-Command"]
docker-build:
	docker build -t fjolsvin/pwsh-windows contrib\docker
docker-push:docker-build
	docker push fjolsvin/pwsh-windows:latest
docker:docker-build
	docker run \
	--mount type=bind,source='{{justfile_directory()}}',target='c:\Users\ContainerUser\workspace' \
	--rm \
	-it \
	fjolsvin/pwsh-windows
go-toolchain: docker-build
	docker run \
	--mount type=bind,source='{{justfile_directory()}}',target='c:\Users\ContainerUser\workspace' \
	--rm \
	-it \
	fjolsvin/pwsh-windows \
	bin\go-toolchain.ps1 --install -d; go --version
