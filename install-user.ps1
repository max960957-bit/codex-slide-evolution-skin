[CmdletBinding()]
param([string]$SourceRoot = $PSScriptRoot, [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexSlideEvolutionSkin'))
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath($SourceRoot); $target = [IO.Path]::GetFullPath($InstallRoot)
if ($target -eq $source -or $target.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Install target must be outside source.' }
$required = @('启动换肤.cmd','启动自定义皮肤.cmd','导入皮肤.cmd','管理皮肤.cmd','glass-lab.ps1','glass.js','sequence-host.js','ex-video-loop.js','build-sequence.js','skin-pack.js','select-skin.ps1','import-skin.ps1','manage-skins.ps1','使用说明.md','皮肤制作说明.md','visual-core','vendor\node','skins\example')
foreach ($item in $required) { if (-not (Test-Path -LiteralPath (Join-Path $source $item))) { throw "Missing package item: $item" } }
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($item in $required) {
  $from = Join-Path $source $item; $to = Join-Path $target $item
  if ((Get-Item -LiteralPath $from).PSIsContainer) { New-Item -ItemType Directory -Path $to -Force | Out-Null; Get-ChildItem -LiteralPath $from -Force | Copy-Item -Destination $to -Recurse -Force }
  else { New-Item -ItemType Directory -Path (Split-Path $to) -Force | Out-Null; Copy-Item -LiteralPath $from -Destination $to -Force }
}
$userSkins = Join-Path $target 'skins'; $sourceExample = Join-Path $source 'skins\example'
if (Test-Path -LiteralPath $userSkins) {
  $example = Join-Path $userSkins 'example'; $backup = Join-Path $target 'skins.__upgrade_backup'
  if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
  Move-Item -LiteralPath $userSkins -Destination $backup
  New-Item -ItemType Directory -Path $userSkins -Force | Out-Null
  Copy-Item -LiteralPath $sourceExample -Destination $userSkins -Recurse -Force
  Get-ChildItem -LiteralPath $backup -Directory | Where-Object Name -ne 'example' | ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination $userSkins -Force }
  Remove-Item -LiteralPath $backup -Recurse -Force
}
$targetLiteral = $target.Replace("'", "''")
Set-Content -LiteralPath (Join-Path $target 'uninstall.ps1') -Encoding UTF8 -Value "`$ErrorActionPreference='Stop'; `$root='$targetLiteral'; if(Test-Path -LiteralPath `$root){Remove-Item -LiteralPath `$root -Recurse -Force}"
$start = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'; New-Item -ItemType Directory -Path $start -Force | Out-Null
$shell = New-Object -ComObject WScript.Shell; $shortcut = $shell.CreateShortcut((Join-Path $start 'Codex 滑动变富器.lnk'))
$shortcut.TargetPath = Join-Path $target '启动换肤.cmd'; $shortcut.WorkingDirectory = $target; $shortcut.Description = '启动 Codex 滑动变富器'; $shortcut.Save()
Write-Output "Installed to $target"
