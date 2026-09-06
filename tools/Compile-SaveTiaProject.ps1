param(
    [string]$ProjectName = "COMPACTADOR.ap21"
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

$process = [Siemens.Engineering.TiaPortal]::GetProcesses() |
    Where-Object { $_.ProjectPath -and ([string]$_.ProjectPath).EndsWith($ProjectName, [System.StringComparison]::OrdinalIgnoreCase) } |
    Select-Object -First 1

if ($null -eq $process) {
    throw "Projeto $ProjectName nao encontrado aberto no TIA Portal."
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

    $compileService = Invoke-GenericGetService $plcSoftware ([Siemens.Engineering.Compiler.ICompilable])
    if ($null -eq $compileService) {
        throw "Servico ICompilable nao encontrado para o PLC."
    }

    $result = $compileService.Compile()

    Write-Host "TIA_PROCESS=$($process.Id)"
    Write-Host "TIA_PROJECT=$($process.ProjectPath)"
    Write-Host "COMPILE_STATE=$($result.State)"

    foreach ($message in $result.Messages) {
        Write-Host "COMPILE_MESSAGE=$($message.State);$($message.Description)"
    }

    $project.Save()
    Write-Host "PROJECT_SAVED=True"
} finally {
    $tiaPortal.Dispose()
}
