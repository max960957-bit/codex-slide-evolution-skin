$ErrorActionPreference='Stop'
$fixture=Join-Path $env:TEMP ('skin-panel-check-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$child=Join-Path $fixture 'child.ps1'
@'
param($Folder)
[IO.File]::WriteAllText((Join-Path $Folder 'ready'),'ready')
$deadline=(Get-Date).AddSeconds(15)
while(-not(Test-Path (Join-Path $Folder 'finish')) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 50}
exit 7
'@ | Set-Content -LiteralPath $child
$wrapper=Join-Path $PSScriptRoot 'run-hidden.vbs'
$arguments=@($wrapper,$child,$fixture) | ForEach-Object {'"'+$_+'"'}
$process=Start-Process wscript.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
try {
  $deadline=(Get-Date).AddSeconds(10)
  while(-not(Test-Path (Join-Path $fixture 'ready')) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 50}
  if(-not(Test-Path (Join-Path $fixture 'ready'))){throw 'Hidden child did not start'}
  $process.Refresh()
  if($process.HasExited){throw 'Wrapper exited before child; panel cannot stop the session'}
} finally { [IO.File]::WriteAllText((Join-Path $fixture 'finish'),'finish') }
if(-not $process.WaitForExit(5000)){throw 'Wrapper did not exit after child'}
if($process.ExitCode -ne 7){throw 'Child exit code lost'}
$process.Dispose()
$js=@'
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(process.argv[1],'utf8');
const line=source.split('\n').find(s=>s.includes('if (!realWindow.__codexSequenceTransfer?.externalStop)'));
assert(line,'Missing managed-overlay gate');
for(const externalStop of [true,false]){
  let attached=0;
  vm.runInNewContext(line,{realWindow:{__codexSequenceTransfer:{externalStop}},controls:{},document:{body:{appendChild(){attached++}}}});
  assert.equal(attached,externalStop?0:1);
}
'@ 
& (Join-Path $PSScriptRoot 'vendor\node\node.exe') -e $js (Join-Path $PSScriptRoot 'sequence-host.js')
if($LASTEXITCODE){throw 'Overlay gate failed'}
'PASS: hidden wrapper tracks child lifetime/exit code; panel overlay hidden; legacy stop retained.'
