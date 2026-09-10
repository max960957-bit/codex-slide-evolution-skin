[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$packageRoot = Join-Path $PSScriptRoot ('dist\portable-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[void][System.IO.Directory]::CreateDirectory($packageRoot)
# Explicit allowlist: never include runs, runtime caches, private screenshots or developer tests.
$files = @('run-hidden.vbs','web-panel.ps1','start-skin.ps1','run-d6-sequence.cmd','glass-lab.ps1','glass.js','sequence-host.js','ex-video-loop.js','build-sequence.js','skin-pack.js','select-skin.ps1','import-skin.ps1','manage-skins.ps1','install-user.ps1','install-user.cmd','uninstall-user.cmd','release-check.ps1','product.json','LICENSE','发布说明.md','傻瓜式教程.md')
$files += @('启动换肤.cmd','启动自定义皮肤.cmd','导入皮肤.cmd','管理皮肤.cmd','使用说明.md','产品说明.md','皮肤制作说明.md')
foreach ($name in $files) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $packageRoot }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'visual-core') -Destination $packageRoot -Recurse
[void][System.IO.Directory]::CreateDirectory((Join-Path $packageRoot 'vendor\node'))
foreach ($name in @('node.exe','LICENSE','runtime.json')) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('vendor\node\' + $name)) -Destination (Join-Path $packageRoot 'vendor\node')
}
[void][System.IO.Directory]::CreateDirectory((Join-Path $packageRoot 'skins'))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skins\example') -Destination (Join-Path $packageRoot 'skins') -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skins\机甲') -Destination (Join-Path $packageRoot 'skins') -Recurse
foreach($folder in @('panel','vendor\webview2')){[void][IO.Directory]::CreateDirectory((Join-Path $packageRoot $folder))}
foreach($file in @('index.html','app.js','panel.css','LIQUID-LICENSE.txt','REACT-LICENSE.txt','REACT-DOM-LICENSE.txt')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('panel\'+$file)) -Destination (Join-Path $packageRoot 'panel')}
foreach($file in @('Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll','WebView2Loader.dll','LICENSE.txt','NOTICE.txt')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('vendor\webview2\'+$file)) -Destination (Join-Path $packageRoot 'vendor\webview2')}
$hashes = Get-ChildItem -LiteralPath $packageRoot -File -Recurse | ForEach-Object {
  [pscustomobject]@{path=$_.FullName.Substring($packageRoot.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
}
$hashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageRoot 'package-hashes.json') -Encoding UTF8
$zipPath = $packageRoot + '.zip'
& tar.exe -a -c -f $zipPath -C (Split-Path -Parent $packageRoot) (Split-Path -Leaf $packageRoot)
if ($LASTEXITCODE) { throw "Could not create package archive: $LASTEXITCODE" }
Write-Output ($packageRoot + '.zip')
