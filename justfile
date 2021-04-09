DISTRO := 'arch'
set shell := ["powershell.exe", "-Command"]
go-toolchain:
	powershell \
	-ExecutionPolicy Bypass \
	-File bin\go-toolchain.ps1 -- new \
	--minimal \
	--distro {{DISTRO}} \
	example
go-tools:
	powershell \
	-ExecutionPolicy Bypass \
	-File bin\go-toolchain.ps1 -- new \
	--minimal \
	--distro {{DISTRO}} \
	example