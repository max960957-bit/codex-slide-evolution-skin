$ErrorActionPreference='Stop'
$fixture=Join-Path $env:TEMP ('skin-entry-test-'+[guid]::NewGuid().ToString('N'))
$source=Join-Path $fixture 'source'; $target=Join-Path $fixture 'installed'
New-Item -ItemType Directory -Path $source,$target | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'start-skin.ps1') $source
@'
param($SourceRoot,$InstallRoot)
Copy-Item (Join-Path $SourceRoot 'start-skin.ps1') $InstallRoot
Set-Content (Join-Path $InstallRoot 'manage-skins.ps1') 'param($InstallRoot); Add-Content (Join-Path $InstallRoot "opened.txt") "opened"'
Add-Content (Join-Path $InstallRoot 'installed.txt') 'installed'
'@ | Set-Content (Join-Path $source 'install-user.ps1')
& (Join-Path $source 'start-skin.ps1') -InstallRoot $target
& (Join-Path $target 'start-skin.ps1') -InstallRoot $target
if (@(Get-Content (Join-Path $target 'installed.txt')).Count -ne 1) { throw 'Unexpected reinstall' }
if (@(Get-Content (Join-Path $target 'opened.txt')).Count -ne 2) { throw 'Manager missing' }
'PASS: first launch installs and opens; installed launch opens without reinstall.'
