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

function Invoke-GoOfflineForDeviceItems {
    param($DeviceItems)

    $changed = 0

    foreach ($deviceItem in $DeviceItems) {
        $onlineProvider = Invoke-GenericGetService $deviceItem ([Siemens.Engineering.Online.OnlineProvider])
        if ($null -ne $onlineProvider) {
            Write-Host "ONLINE_TARGET=$($deviceItem.Name);STATE_BEFORE=$($onlineProvider.State)"

            if ($onlineProvider.State -ne [Siemens.Engineering.Online.OnlineState]::Offline) {
                $stateAfter = $onlineProvider.GoOffline()
                Write-Host "ONLINE_TARGET=$($deviceItem.Name);STATE_AFTER=$stateAfter"
                $changed++
            }
        }

        try {
            $changed += Invoke-GoOfflineForDeviceItems $deviceItem.DeviceItems
        } catch {}
    }

    return $changed
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
    $changed = 0

    foreach ($device in $project.Devices) {
        $changed += Invoke-GoOfflineForDeviceItems $device.DeviceItems
    }

    Write-Host "TIA_PROCESS=$($process.Id)"
    Write-Host "TIA_PROJECT=$($process.ProjectPath)"
    Write-Host "GO_OFFLINE_COUNT=$changed"
} finally {
    $tiaPortal.Dispose()
}
