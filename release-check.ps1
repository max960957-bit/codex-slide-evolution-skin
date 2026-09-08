[CmdletBinding()]
param([string]$PackageRoot)
$ErrorActionPreference='Stop'
if(-not $PackageRoot){throw 'PackageRoot required'}
$required=@('product.json','LICENSE','发布说明.md','install-user.cmd','uninstall-user.cmd','管理皮肤.cmd','导入皮肤.cmd','vendor\node\node.exe','visual-core\baseline.json','skins\example\skin.json')
foreach($p in $required){if(-not(Test-Path -LiteralPath (Join-Path $PackageRoot $p))){throw "Missing release file: $p"}}
$product=Get-Content (Join-Path $PackageRoot 'product.json') -Raw|ConvertFrom-Json
if($product.status -ne 'preview' -or $product.codexVersion -ne '26.901.6511.0'){throw 'Product metadata mismatch'}
$tok=$null;$err=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PackageRoot 'manage-skins.ps1'),[ref]$tok,[ref]$err);if($err.Count){throw 'Manager parse failure'}
Write-Output 'PASS: release manifest, license, manager, runtime and example skin present.'
