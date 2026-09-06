param(
    [string]$ProjectName = "COMPACTADOR.ap21"
)

$ErrorActionPreference = "Stop"

$ApiPath = "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48"
$env:Path = "$ApiPath;$env:Path"

try { Add-Type -Path (Join-Path $ApiPath "Siemens.Engineering.Base.dll") } catch {}

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.ProjectPath -and ([string]$_.ProjectPath).EndsWith($ProjectName, [System.StringComparison]::OrdinalIgnoreCase) } |
    Select-Object -First 1

if ($null -eq $process) {
    throw "Projeto $ProjectName nao encontrado aberto no TIA Portal."
}

$tiaPortal = $process.Attach()
try {
    $project = $tiaPortal.Projects | Select-Object -First 1
    $project.Save()

    Write-Host "TIA_PROCESS=$($process.Id)"
    Write-Host "TIA_PROJECT=$($process.ProjectPath)"
    Write-Host "PROJECT_SAVED=True"
} finally {
    $tiaPortal.Dispose()
}
