$ErrorActionPreference = 'Stop'
$source = Get-Content -Raw (Join-Path $PSScriptRoot '../src/purchase-macros.ks')
if ($source -notmatch 'SplitPath\(A_ScriptDir, &scriptDirName, &scriptParent\)' -or $source -notmatch 'scriptDirName = "src" \? scriptParent : A_ScriptDir') { throw 'Macro storage must support source and standalone release layouts.' }
git check-ignore -q macros/example/F1.txt
if ($LASTEXITCODE -ne 0) { throw 'Personal macros must be ignored.' }
'OK'
