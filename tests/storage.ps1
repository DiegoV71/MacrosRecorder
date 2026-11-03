$ErrorActionPreference = 'Stop'
$source = Get-Content -Raw (Join-Path $PSScriptRoot '../src/purchase-macros.ks')
if ($source -notmatch 'macroDir := A_ScriptDir "\\\.\.\\macros"') { throw 'Macro storage must stay at the project root.' }
git check-ignore -q macros/example/F1.txt
if ($LASTEXITCODE -ne 0) { throw 'Personal macros must be ignored.' }
'OK'
