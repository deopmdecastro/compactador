param(
    [string]$MirrorPath = "UserFiles\IO\Lista_IO_Espelho.csv",
    [string]$ExportRoot = "outputs\tia-export"
)

$ErrorActionPreference = "Stop"

$ApiPath = "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48"
$BaseDll = Join-Path $ApiPath "Siemens.Engineering.Base.dll"
$Step7Dll = Join-Path $ApiPath "Siemens.Engineering.Step7.dll"

if (-not (Test-Path -LiteralPath $BaseDll)) {
    throw "TIA Openness Base DLL nao encontrada em: $BaseDll"
}

$env:Path = "$ApiPath;$env:Path"

try { Add-Type -Path $BaseDll } catch {}
try { Add-Type -Path $Step7Dll } catch {}

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

function Get-CommentText {
    param($Comment)

    if ($null -eq $Comment) {
        return ""
    }

    foreach ($item in $Comment.Items) {
        if (-not [string]::IsNullOrWhiteSpace($item.Text)) {
            return [string]$item.Text
        }
    }

    return ""
}

function Convert-ToCsvField {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return ""
    }

    $text = [string]$Value
    if ($text -match '[;"\r\n]') {
        return '"' + ($text -replace '"', '""') + '"'
    }

    return $text
}

function ConvertTo-MirrorCsv {
    param([array]$Rows)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Path;Name;Data Type;Logical Address;Comment")

    foreach ($row in $Rows) {
        $fields = @(
            (Convert-ToCsvField $row.Path),
            (Convert-ToCsvField $row.Name),
            (Convert-ToCsvField $row.'Data Type'),
            (Convert-ToCsvField $row.'Logical Address'),
            (Convert-ToCsvField $row.Comment)
        )
        $lines.Add(($fields -join ";"))
    }

    return $lines
}

function Convert-AddressToSortKey {
    param([string]$Address)

    if ($Address -match '^%?([IQM])([WD]?)(\d+)(?:\.(\d+))?$') {
        $areaOrder = @{ I = 0; Q = 1; M = 2 }
        $area = $Matches[1]
        $byte = [int]$Matches[3]
        $bit = if ($Matches[4]) { [int]$Matches[4] } else { -1 }
        return "{0:D2}-{1:D6}-{2:D3}-{3}" -f $areaOrder[$area], $byte, $bit, $Address
    }

    return "99-999999-999-$Address"
}

function Read-MirrorRows {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    return @(Import-Csv -LiteralPath $Path -Delimiter ";")
}

function New-DiffReport {
    param(
        [array]$Before,
        [array]$After,
        [array]$Skipped
    )

    $beforeByAddress = @{}
    foreach ($row in $Before) {
        $beforeByAddress[[string]$row.'Logical Address'] = $row
    }

    $afterByAddress = @{}
    foreach ($row in $After) {
        $afterByAddress[[string]$row.'Logical Address'] = $row
    }

    $report = New-Object System.Collections.Generic.List[string]
    $report.Add("Atualizacao do espelho a partir das PLC tag tables reais do TIA Portal")
    $report.Add("Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $report.Add("")
    $report.Add("Resumo:")
    $report.Add("- Antes: $($Before.Count) tags")
    $report.Add("- Depois: $($After.Count) tags")
    $report.Add("")

    $changes = New-Object System.Collections.Generic.List[string]
    foreach ($address in ($afterByAddress.Keys | Sort-Object { Convert-AddressToSortKey $_ })) {
        if (-not $beforeByAddress.ContainsKey($address)) {
            $row = $afterByAddress[$address]
            $changes.Add("ADICIONADO $address -> $($row.Path);$($row.Name);$($row.'Data Type');$($row.Comment)")
            continue
        }

        $old = $beforeByAddress[$address]
        $new = $afterByAddress[$address]
        $fieldChanges = @()
        foreach ($field in @("Path", "Name", "Data Type", "Comment")) {
            if ([string]$old.$field -ne [string]$new.$field) {
                $fieldChanges += "${field}: '$($old.$field)' -> '$($new.$field)'"
            }
        }

        if ($fieldChanges.Count -gt 0) {
            $changes.Add("ALTERADO $address -> " + ($fieldChanges -join "; "))
        }
    }

    foreach ($address in ($beforeByAddress.Keys | Sort-Object { Convert-AddressToSortKey $_ })) {
        if (-not $afterByAddress.ContainsKey($address)) {
            $row = $beforeByAddress[$address]
            $changes.Add("REMOVIDO $address -> $($row.Path);$($row.Name);$($row.'Data Type');$($row.Comment)")
        }
    }

    if ($changes.Count -eq 0) {
        $report.Add("Alteracoes:")
        $report.Add("- Nenhuma diferenca no espelho.")
    } else {
        $report.Add("Alteracoes:")
        foreach ($change in $changes) {
            $report.Add("- $change")
        }
    }

    if ($Skipped.Count -gt 0) {
        $report.Add("")
        $report.Add("Ignorados por endereco PLC invalido:")
        foreach ($row in $Skipped) {
            $report.Add("- $($row.Path);$($row.Name);$($row.'Data Type');$($row.'Logical Address');$($row.Comment)")
        }
    }

    return $report
}

function Export-TagTables {
    param(
        $Group,
        [string]$PathPrefix,
        [string]$XmlDir,
        [System.Collections.Generic.List[object]]$Rows
    )

    foreach ($table in $Group.TagTables) {
        $tablePath = if ([string]::IsNullOrWhiteSpace($PathPrefix)) { $table.Name } else { "$PathPrefix\$($table.Name)" }
        $safeName = ($tablePath -replace '[\\/:*?"<>|]', "_")
        $xmlPath = [System.IO.Path]::GetFullPath((Join-Path $XmlDir "$safeName.xml"))
        $table.Export([System.IO.FileInfo]$xmlPath, [Siemens.Engineering.ExportOptions]::WithDefaults)

        foreach ($tag in $table.Tags) {
            $row = [pscustomobject]@{
                Path              = $tablePath
                Name              = $tag.Name
                "Data Type"       = $tag.DataTypeName
                "Logical Address" = $tag.LogicalAddress
                Comment           = Get-CommentText $tag.Comment
            }

            if ($row."Logical Address" -notmatch '^%[IQM]') {
                $script:SkippedRows.Add($row)
                continue
            }

            $Rows.Add([pscustomobject]@{
                Path              = $row.Path
                Name              = $row.Name
                "Data Type"       = $row."Data Type"
                "Logical Address" = $row."Logical Address"
                Comment           = $row.Comment
            })
        }
    }

    foreach ($childGroup in $Group.Groups) {
        $childPath = if ([string]::IsNullOrWhiteSpace($PathPrefix)) { $childGroup.Name } else { "$PathPrefix\$($childGroup.Name)" }
        Export-TagTables $childGroup $childPath $XmlDir $Rows
    }
}

$processes = @([Siemens.Engineering.TiaPortal]::GetProcesses())
if ($processes.Count -eq 0) {
    throw "Nenhum processo do TIA Portal esta aberto."
}

$targetProcess = $processes |
    Where-Object { $_.ProjectPath -and ([string]$_.ProjectPath).EndsWith("COMPACTADOR.ap21", [System.StringComparison]::OrdinalIgnoreCase) } |
    Select-Object -First 1

if ($null -eq $targetProcess) {
    $targetProcess = $processes | Select-Object -First 1
}

$exportDir = Join-Path $ExportRoot ("tia-tags-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$xmlDir = Join-Path $exportDir "xml"
New-Item -ItemType Directory -Force -Path $xmlDir | Out-Null

$beforeRows = Read-MirrorRows $MirrorPath
$rows = New-Object System.Collections.Generic.List[object]
$script:SkippedRows = New-Object System.Collections.Generic.List[object]

$tiaPortal = $targetProcess.Attach()
try {
    foreach ($project in $tiaPortal.Projects) {
        foreach ($device in $project.Devices) {
            $plcSoftware = Find-PlcSoftware $device.DeviceItems
            if ($null -eq $plcSoftware) {
                continue
            }

            Export-TagTables $plcSoftware.TagTableGroup "" $xmlDir $rows
        }
    }
} finally {
    $tiaPortal.Dispose()
}

if ($rows.Count -eq 0) {
    throw "Nenhuma PLC tag table foi encontrada no TIA Portal."
}

$sortedRows = @($rows | Sort-Object Path, { Convert-AddressToSortKey $_.'Logical Address' }, Name)
$mirrorLines = ConvertTo-MirrorCsv $sortedRows
$mirrorFullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $MirrorPath))
$mirrorDir = Split-Path -Parent $mirrorFullPath
New-Item -ItemType Directory -Force -Path $mirrorDir | Out-Null
[System.IO.File]::WriteAllLines($mirrorFullPath, [string[]]$mirrorLines, (New-Object System.Text.UTF8Encoding $false))

$reportPath = Join-Path $exportDir "diff-report.txt"
$report = New-DiffReport $beforeRows $sortedRows $script:SkippedRows
[System.IO.File]::WriteAllLines([System.IO.Path]::GetFullPath($reportPath), [string[]]$report, (New-Object System.Text.UTF8Encoding $false))

Write-Host "TIA_PROCESS=$($targetProcess.Id)"
Write-Host "TIA_PROJECT=$($targetProcess.ProjectPath)"
Write-Host "TAGS=$($sortedRows.Count)"
Write-Host "SKIPPED=$($script:SkippedRows.Count)"
Write-Host "MIRROR=$mirrorFullPath"
Write-Host "EXPORT_DIR=$([System.IO.Path]::GetFullPath($exportDir))"
Write-Host "DIFF_REPORT=$([System.IO.Path]::GetFullPath($reportPath))"
