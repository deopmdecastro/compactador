param(
    [string]$SourcePath = "tia-src\COMPACTADOR_LinhaCompactador.scl",
    [string]$SourceName = "COMPACTADOR_LinhaCompactador",
    [string[]]$DeleteBlock = @()
)

$ErrorActionPreference = "Stop"

$ApiPath = "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48"
$env:Path = "$ApiPath;$env:Path"

try { Add-Type -Path (Join-Path $ApiPath "Siemens.Engineering.Base.dll") } catch {}
try { Add-Type -Path (Join-Path $ApiPath "Siemens.Engineering.Step7.dll") } catch {}

function Invoke-GenericGetService {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][Type]$ServiceType
    )

    $method = $Object.GetType().GetMethod("GetService")
    if ($null -eq $method) {
        return $null
    }

    return $method.MakeGenericMethod($ServiceType).Invoke($Object, @())
}

function Find-PlcSoftware {
    param($DeviceItems)

    foreach ($deviceItem in $DeviceItems) {
        $softwareContainer = Invoke-GenericGetService $deviceItem ([Siemens.Engineering.HW.Features.SoftwareContainer])
        if ($null -ne $softwareContainer -and $softwareContainer.Software -is [Siemens.Engineering.SW.PlcSoftware]) {
            return $softwareContainer.Software
        }

        try {
            $nested = Find-PlcSoftware $deviceItem.DeviceItems
            if ($null -ne $nested) {
                return $nested
            }
        } catch {}
    }

    return $null
}

$sourceFullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $SourcePath))
if (-not (Test-Path -LiteralPath $sourceFullPath)) {
    throw "Fonte SCL nao encontrada: $sourceFullPath"
}

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.ProjectPath -and ([string]$_.ProjectPath).EndsWith("COMPACTADOR.ap21", [System.StringComparison]::OrdinalIgnoreCase) } |
    Select-Object -First 1

if ($null -eq $process) {
    throw "Projeto COMPACTADOR.ap21 nao encontrado aberto no TIA Portal."
}

$tiaPortal = $process.Attach()
try {
    $project = $tiaPortal.Projects | Select-Object -First 1
    $plcSoftware = $null

    foreach ($device in $project.Devices) {
        $plcSoftware = Find-PlcSoftware $device.DeviceItems
        if ($null -ne $plcSoftware) {
            break
        }
    }

    if ($null -eq $plcSoftware) {
        throw "PlcSoftware nao encontrado no projeto TIA."
    }

    $existingSource = $plcSoftware.ExternalSourceGroup.ExternalSources.Find($SourceName)
    if ($null -ne $existingSource) {
        $existingSource.Delete()
    }

    if ($DeleteBlock.Count -gt 0) {
        foreach ($blockName in $DeleteBlock) {
            $existingBlock = $plcSoftware.BlockGroup.Blocks.Find($blockName)
            if ($null -ne $existingBlock) {
                $existingBlock.Delete()
            }
        }
    }

    $source = $plcSoftware.ExternalSourceGroup.ExternalSources.CreateFromFile($SourceName, $sourceFullPath)
    $generated = @($source.GenerateBlocksFromSource([Siemens.Engineering.SW.ExternalSources.GenerateBlockOption]::KeepOnError))

    Write-Host "TIA_PROCESS=$($process.Id)"
    Write-Host "TIA_PROJECT=$($process.ProjectPath)"
    Write-Host "SOURCE=$sourceFullPath"
    Write-Host "GENERATED_COUNT=$($generated.Count)"

    foreach ($block in $generated) {
        Write-Host "BLOCK=$($block.Name);TYPE=$($block.GetType().Name);LANG=$($block.ProgrammingLanguage);CONSISTENT=$($block.IsConsistent)"
    }
} finally {
    $tiaPortal.Dispose()
}
