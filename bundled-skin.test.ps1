$ErrorActionPreference='Stop'
$code=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'install-user.ps1'))
$begin=$code.IndexOf('$mechaSource =')
$end=$code.IndexOf('$targetLiteral =',$begin)
if($begin -lt 0 -or $end -lt 0){throw 'Bundled skin install block missing'}
$installBlock=[scriptblock]::Create($code.Substring($begin,$end-$begin))
$fixture=Join-Path $env:TEMP ('bundled-skin-test-'+[guid]::NewGuid().ToString('N'))
$source=Join-Path $fixture 'source'; $target=Join-Path $fixture 'installed'
[void][IO.Directory]::CreateDirectory((Join-Path $source 'skins\机甲'))
[void][IO.Directory]::CreateDirectory((Join-Path $target 'skins'))
$inputFile=Join-Path $source 'skins\机甲\skin.json'
$outputFile=Join-Path $target 'skins\机甲\skin.json'
[IO.File]::WriteAllText($inputFile,'bundled')
& $installBlock
if([IO.File]::ReadAllText($outputFile) -ne 'bundled'){throw 'New skin not installed'}
[IO.File]::WriteAllText($outputFile,'customized')
& $installBlock
if([IO.File]::ReadAllText($outputFile) -ne 'customized'){throw 'Existing skin overwritten'}
'PASS: new bundled skin installed; existing user skin preserved.'
