param(
    [string]$ProjectName = "COMPACTADOR.ap21",
    [string]$TableName,
    [string]$Name,
    [string]$DataTypeName = "Bool",
    [string]$LogicalAddress,
    [string]$Comment = ""
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

if ([string]::IsNullOrWhiteSpace($TableName) -or [string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($LogicalAddress)) {
    throw "Informe TableName, Name e LogicalAddress."
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

    $table = $plcSoftware.TagTableGroup.TagTables.Find($TableName)
    if ($null -eq $table) {
        $table = $plcSoftware.TagTableGroup.TagTables.Create($TableName)
    }

    $existing = $table.Tags.Find($Name)
    if ($null -eq $existing) {
        $tag = $table.Tags.Create($Name, $DataTypeName, $LogicalAddress)
        Write-Host "TAG_CREATED=True"
    } else {
        $tag = $existing
        if ([string]$tag.LogicalAddress -ne $LogicalAddress) {
            $tag.LogicalAddress = $LogicalAddress
        }
        if ([string]$tag.DataTypeName -ne $DataTypeName) {
            $tag.DataTypeName = $DataTypeName
        }
        Write-Host "TAG_CREATED=False"
    }

    if (-not [string]::IsNullOrWhiteSpace($Comment)) {
        $item = $tag.Comment.Items | Select-Object -First 1
        if ($null -eq $item) {
            $item = $tag.Comment.Items.Create("en-US")
        }
        $item.Text = $Comment
    }

    Write-Host "TIA_PROCESS=$($process.Id)"
    Write-Host "TIA_PROJECT=$($process.ProjectPath)"
    Write-Host "TABLE=$($table.Name)"
    Write-Host "TAG=$($tag.Name);TYPE=$($tag.DataTypeName);ADDRESS=$($tag.LogicalAddress)"
} finally {
    $tiaPortal.Dispose()
}
