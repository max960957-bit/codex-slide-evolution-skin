[CmdletBinding()]
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexSlideEvolutionSkin'))
$ErrorActionPreference = 'Stop'
try {
  if ([IO.Path]::GetFullPath($PSScriptRoot) -ne [IO.Path]::GetFullPath($InstallRoot)) {
    & (Join-Path $PSScriptRoot 'install-user.ps1') -SourceRoot $PSScriptRoot -InstallRoot $InstallRoot
  }
  & (Join-Path $InstallRoot 'manage-skins.ps1') -InstallRoot $InstallRoot
} catch {
  Add-Type -AssemblyName System.Windows.Forms
  [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, '启动失败')
  exit 1
}