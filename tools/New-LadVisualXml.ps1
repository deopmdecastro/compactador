param(
    [string]$OutPath = "tia-xml\FC_LinhaCompactador_LAD.xml"
)

$ErrorActionPreference = "Stop"

$script:docId = 1
$script:uid = 20

function New-Id {
    $value = $script:docId
    $script:docId++
    return $value.ToString("X")
}

function New-UId {
    $script:uid++
    return $script:uid
}

function Escape-Xml {
    param([string]$Text)
    return [System.Security.SecurityElement]::Escape($Text)
}

function New-AccessXml {
    param(
        [int]$UId,
        [string]$Name
    )

    $escaped = Escape-Xml $Name
    return @"
                <Access Scope="GlobalVariable" UId="$UId">
                  <Symbol>
                    <Component Name="$escaped" />
                  </Symbol>
                </Access>
"@
}

function New-ContactXml {
    param(
        [int]$UId,
        [bool]$Negated
    )

    if ($Negated) {
        return @"
                <Part Name="Contact" UId="$UId">
                  <Negated Name="operand" />
                </Part>
"@
    }

    return "                <Part Name=`"Contact`" UId=`"$UId`" />"
}

function New-SeriesNetwork {
    param(
        [string]$Title,
        [array]$Contacts,
        [string]$Coil
    )

    $compileId = New-Id
    $commentId = New-Id
    $commentItemId = New-Id
    $titleId = New-Id
    $titleItemId = New-Id

    $parts = New-Object System.Collections.Generic.List[string]
    $wires = New-Object System.Collections.Generic.List[string]

    $contactParts = @()
    foreach ($contact in $Contacts) {
        $accessId = New-UId
        $partId = New-UId
        $contactParts += [pscustomobject]@{
            AccessId = $accessId
            PartId = $partId
            Name = $contact.Name
            Negated = [bool]$contact.Negated
        }
        $parts.Add((New-AccessXml $accessId $contact.Name))
        $parts.Add((New-ContactXml $partId ([bool]$contact.Negated)))
    }

    $coilAccessId = New-UId
    $coilPartId = New-UId
    $parts.Add((New-AccessXml $coilAccessId $Coil))
    $parts.Add("                <Part Name=`"Coil`" UId=`"$coilPartId`" />")

    for ($i = 0; $i -lt $contactParts.Count; $i++) {
        $contact = $contactParts[$i]
        $operandWireId = New-UId
        $wires.Add(@"
                <Wire UId="$operandWireId">
                  <IdentCon UId="$($contact.AccessId)" />
                  <NameCon UId="$($contact.PartId)" Name="operand" />
                </Wire>
"@)

        if ($i -eq 0) {
            $powerWireId = New-UId
            $wires.Add(@"
                <Wire UId="$powerWireId">
                  <Powerrail />
                  <NameCon UId="$($contact.PartId)" Name="in" />
                </Wire>
"@)
        }

        $logicWireId = New-UId
        if ($i -lt ($contactParts.Count - 1)) {
            $next = $contactParts[$i + 1]
            $wires.Add(@"
                <Wire UId="$logicWireId">
                  <NameCon UId="$($contact.PartId)" Name="out" />
                  <NameCon UId="$($next.PartId)" Name="in" />
                </Wire>
"@)
        } else {
            $wires.Add(@"
                <Wire UId="$logicWireId">
                  <NameCon UId="$($contact.PartId)" Name="out" />
                  <NameCon UId="$coilPartId" Name="in" />
                </Wire>
"@)
        }
    }

    $coilWireId = New-UId
    $wires.Add(@"
                <Wire UId="$coilWireId">
                  <IdentCon UId="$coilAccessId" />
                  <NameCon UId="$coilPartId" Name="operand" />
                </Wire>
"@)

    $partsText = $parts -join "`r`n"
    $wiresText = $wires -join "`r`n"
    $escapedTitle = Escape-Xml $Title

    return @"
      <SW.Blocks.CompileUnit ID="$compileId" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource>
            <FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v4">
              <Parts>
$partsText
              </Parts>
              <Wires>
$wiresText
              </Wires>
            </FlgNet>
          </NetworkSource>
          <ProgrammingLanguage>LAD</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="$commentId" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="$commentItemId" CompositionName="Items">
                <AttributeList>
                  <Culture>en-US</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
          <MultilingualText ID="$titleId" CompositionName="Title">
            <ObjectList>
              <MultilingualTextItem ID="$titleItemId" CompositionName="Items">
                <AttributeList>
                  <Culture>en-US</Culture>
                  <Text>$escapedTitle</Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
"@
}

function New-TonNetwork {
    param(
        [string]$Title,
        [array]$Contacts,
        [string]$TimerInstance,
        [string]$PresetTime,
        [string]$DoneCoil
    )

    $compileId = New-Id
    $commentId = New-Id
    $commentItemId = New-Id
    $titleId = New-Id
    $titleItemId = New-Id

    $parts = New-Object System.Collections.Generic.List[string]
    $wires = New-Object System.Collections.Generic.List[string]

    $contactParts = @()
    foreach ($contact in $Contacts) {
        $accessId = New-UId
        $partId = New-UId
        $contactParts += [pscustomobject]@{
            AccessId = $accessId
            PartId = $partId
            Name = $contact.Name
            Negated = [bool]$contact.Negated
        }
        $parts.Add((New-AccessXml $accessId $contact.Name))
        $parts.Add((New-ContactXml $partId ([bool]$contact.Negated)))
    }

    $presetAccessId = New-UId
    $parts.Add(@"
                <Access Scope="TypedConstant" UId="$presetAccessId">
                  <Constant>
                    <ConstantValue>$PresetTime</ConstantValue>
                  </Constant>
                </Access>
"@)

    $tonPartId = New-UId
    $tonInstanceId = New-UId
    $parts.Add(@"
                <Part Name="TON" Version="1.0" UId="$tonPartId">
                  <Instance Scope="GlobalVariable" UId="$tonInstanceId">
                    <Component Name="DB_LinhaCompactador" />
                    <Component Name="$TimerInstance" />
                  </Instance>
                  <TemplateValue Name="time_type" Type="Type">Time</TemplateValue>
                </Part>
"@)

    $coilAccessId = New-UId
    $coilPartId = New-UId
    $parts.Add((New-AccessXml $coilAccessId $DoneCoil))
    $parts.Add("                <Part Name=`"Coil`" UId=`"$coilPartId`" />")

    for ($i = 0; $i -lt $contactParts.Count; $i++) {
        $contact = $contactParts[$i]
        $operandWireId = New-UId
        $wires.Add(@"
                <Wire UId="$operandWireId">
                  <IdentCon UId="$($contact.AccessId)" />
                  <NameCon UId="$($contact.PartId)" Name="operand" />
                </Wire>
"@)

        if ($i -eq 0) {
            $powerWireId = New-UId
            $wires.Add(@"
                <Wire UId="$powerWireId">
                  <Powerrail />
                  <NameCon UId="$($contact.PartId)" Name="in" />
                </Wire>
"@)
        }

        $logicWireId = New-UId
        if ($i -lt ($contactParts.Count - 1)) {
            $next = $contactParts[$i + 1]
            $wires.Add(@"
                <Wire UId="$logicWireId">
                  <NameCon UId="$($contact.PartId)" Name="out" />
                  <NameCon UId="$($next.PartId)" Name="in" />
                </Wire>
"@)
        } else {
            $wires.Add(@"
                <Wire UId="$logicWireId">
                  <NameCon UId="$($contact.PartId)" Name="out" />
                  <NameCon UId="$tonPartId" Name="IN" />
                </Wire>
"@)
        }
    }

    $presetWireId = New-UId
    $wires.Add(@"
                <Wire UId="$presetWireId">
                  <IdentCon UId="$presetAccessId" />
                  <NameCon UId="$tonPartId" Name="PT" />
                </Wire>
"@)

    $qWireId = New-UId
    $wires.Add(@"
                <Wire UId="$qWireId">
                  <NameCon UId="$tonPartId" Name="Q" />
                  <NameCon UId="$coilPartId" Name="in" />
                </Wire>
"@)

    $etWireId = New-UId
    $openConId = New-UId
    $wires.Add(@"
                <Wire UId="$etWireId">
                  <NameCon UId="$tonPartId" Name="ET" />
                  <OpenCon UId="$openConId" />
                </Wire>
"@)

    $coilWireId = New-UId
    $wires.Add(@"
                <Wire UId="$coilWireId">
                  <IdentCon UId="$coilAccessId" />
                  <NameCon UId="$coilPartId" Name="operand" />
                </Wire>
"@)

    $partsText = $parts -join "`r`n"
    $wiresText = $wires -join "`r`n"
    $escapedTitle = Escape-Xml $Title

    return @"
      <SW.Blocks.CompileUnit ID="$compileId" CompositionName="CompileUnits">
        <AttributeList>
          <NetworkSource>
            <FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v4">
              <Parts>
$partsText
              </Parts>
              <Wires>
$wiresText
              </Wires>
            </FlgNet>
          </NetworkSource>
          <ProgrammingLanguage>LAD</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="$commentId" CompositionName="Comment">
            <ObjectList>
              <MultilingualTextItem ID="$commentItemId" CompositionName="Items">
                <AttributeList>
                  <Culture>en-US</Culture>
                  <Text />
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
          <MultilingualText ID="$titleId" CompositionName="Title">
            <ObjectList>
              <MultilingualTextItem ID="$titleItemId" CompositionName="Items">
                <AttributeList>
                  <Culture>en-US</Culture>
                  <Text>$escapedTitle</Text>
                </AttributeList>
              </MultilingualTextItem>
            </ObjectList>
          </MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
"@
}

function Contact {
    param(
        [string]$Name,
        [switch]$Negated
    )

    return [pscustomobject]@{
        Name = $Name
        Negated = [bool]$Negated
    }
}

$networks = @()

$networks += New-SeriesNetwork "FC1 - OK_SISTEMA: cadeia geral de seguranca" @(
    Contact "STOP7"
    Contact "STOP6_GERAL"
    Contact "FR1"
    Contact "FR2"
    Contact "FR3"
    Contact "FR4"
    Contact "FR5"
    Contact "FR6"
    Contact "SIN_Y7_COMP"
    Contact "SIN_Y7_M1"
    Contact "SIN_Y7_M2"
    Contact "SIN_Y7_M3"
    Contact "SIN_Y7_M4"
    Contact "SIN_Y7_M5"
    Contact "NA_STOP_M1"
    Contact "NA_STOP_M2"
    Contact "NA_STOP_M3"
    Contact "NA_STOP_M4"
    Contact "NA_STOP_M5"
    Contact "NA_STOP_COMP"
) "OK_SISTEMA"

$networks += New-SeriesNetwork "FC1 - EMERGENCIA: falta de OK_SISTEMA" @(
    Contact "OK_SISTEMA" -Negated
) "EMERGENCIA"

$networks += New-SeriesNetwork "FC2 - MODO_MANUAL validado" @(
    Contact "SEL_MANUAL"
    Contact "SEL_AUTO" -Negated
    Contact "OK_SISTEMA"
) "MODO_MANUAL"

$networks += New-SeriesNetwork "FC2 - H13 modo automatico" @(
    Contact "SEL_AUTO"
    Contact "SEL_MANUAL" -Negated
) "H13_AUTO"

$networks += New-SeriesNetwork "FC2 - H14 modo manual" @(
    Contact "SEL_MANUAL"
    Contact "SEL_AUTO" -Negated
) "H14_MANUAL"

$networks += New-SeriesNetwork "FC6 - H3 nivel 75 porcento" @(
    Contact "SENSOR_75_PERCENT"
) "H3_AZUL"

$networks += New-SeriesNetwork "FC6 - H4 nivel 100 porcento" @(
    Contact "SENSOR_100_PERCENT"
) "H4_VERMELHO"

$networks += New-SeriesNetwork "FC7 - H1 linha auto ligada" @(
    Contact "SEL_AUTO"
    Contact "AUT_LINHA_LIGADA"
) "H1_VERDE"

$networks += New-SeriesNetwork "FC7 - H2 pronto/standby" @(
    Contact "OK_SISTEMA"
    Contact "AUT_LINHA_LIGADA" -Negated
) "H2_AMARELO"

$networks += New-SeriesNetwork "Inatividade - linha sem material" @(
    Contact "AUT_LINHA_LIGADA"
    Contact "M1_S4" -Negated
    Contact "M1_S5" -Negated
    Contact "M1_S6" -Negated
    Contact "M2_S7" -Negated
    Contact "M2_S8" -Negated
    Contact "M2_S9" -Negated
    Contact "M3_S10" -Negated
    Contact "M3_S11" -Negated
    Contact "M3_S12" -Negated
    Contact "M4_S13" -Negated
    Contact "M4_S14" -Negated
    Contact "M4_S15" -Negated
    Contact "M5_S16" -Negated
    Contact "M5_S17" -Negated
    Contact "M5_S18" -Negated
    Contact "M5_S19" -Negated
    Contact "S20_COMP" -Negated
    Contact "S21_COMP" -Negated
    Contact "SENSOR_75_PERCENT" -Negated
    Contact "SENSOR_100_PERCENT" -Negated
) "H2_AMARELO"

$networks += New-TonNetwork "TON - Inatividade 30s" @(
    Contact "SEL_AUTO"
    Contact "OK_SISTEMA"
    Contact "AUT_LINHA_LIGADA"
    Contact "M1_S4" -Negated
    Contact "M1_S5" -Negated
    Contact "M1_S6" -Negated
    Contact "M2_S7" -Negated
    Contact "M2_S8" -Negated
    Contact "M2_S9" -Negated
    Contact "M3_S10" -Negated
    Contact "M3_S11" -Negated
    Contact "M3_S12" -Negated
    Contact "M4_S13" -Negated
    Contact "M4_S14" -Negated
    Contact "M4_S15" -Negated
    Contact "M5_S16" -Negated
    Contact "M5_S17" -Negated
    Contact "M5_S18" -Negated
    Contact "M5_S19" -Negated
    Contact "S20_COMP" -Negated
    Contact "S21_COMP" -Negated
    Contact "SENSOR_75_PERCENT" -Negated
    Contact "SENSOR_100_PERCENT" -Negated
) "T_Inatividade" "T#30s" "INATIVIDADE_ATIVA"

$networks += New-SeriesNetwork "Manual - avanco cilindro" @(
    Contact "MODO_MANUAL"
    Contact "AVANCA"
    Contact "RECUA" -Negated
    Contact "OK_SISTEMA"
) "Y1_AVANCA"

$networks += New-SeriesNetwork "Manual - recuo cilindro" @(
    Contact "MODO_MANUAL"
    Contact "RECUA"
    Contact "AVANCA" -Negated
    Contact "OK_SISTEMA"
) "Y2_RECUA"

$networks += New-SeriesNetwork "Manual - bomba M6 sob procura" @(
    Contact "MODO_MANUAL"
    Contact "AVANCA"
    Contact "RECUA" -Negated
) "START_SS_M6"

$networks += New-SeriesNetwork "Auto - permissivo KM1 simplificado" @(
    Contact "AUT_LINHA_LIGADA"
    Contact "S20_COMP" -Negated
    Contact "S21_COMP" -Negated
    Contact "SENSOR_100_PERCENT" -Negated
    Contact "M3_S10" -Negated
    Contact "M3_S11" -Negated
    Contact "M3_S12" -Negated
    Contact "FR1"
    Contact "NA_STOP_M1"
    Contact "SIN_Y7_M1"
    Contact "FR3"
    Contact "NA_STOP_M3"
    Contact "SIN_Y7_M3"
    Contact "FR5"
    Contact "NA_STOP_M5"
    Contact "SIN_Y7_M5"
) "KM1"

$networks += New-SeriesNetwork "Auto - permissivo KM2 simplificado" @(
    Contact "AUT_LINHA_LIGADA"
    Contact "S20_COMP" -Negated
    Contact "S21_COMP" -Negated
    Contact "SENSOR_100_PERCENT" -Negated
    Contact "M4_S13" -Negated
    Contact "M4_S14" -Negated
    Contact "M4_S15" -Negated
    Contact "FR2"
    Contact "NA_STOP_M2"
    Contact "SIN_Y7_M2"
    Contact "FR4"
    Contact "NA_STOP_M4"
    Contact "SIN_Y7_M4"
    Contact "FR5"
    Contact "NA_STOP_M5"
    Contact "SIN_Y7_M5"
) "KM2"

$networks += New-SeriesNetwork "Auto - permissivo KM3 simplificado" @(
    Contact "AUT_LINHA_LIGADA"
    Contact "S20_COMP" -Negated
    Contact "S21_COMP" -Negated
    Contact "M5_S16" -Negated
    Contact "M5_S17" -Negated
    Contact "FR3"
    Contact "NA_STOP_M3"
    Contact "SIN_Y7_M3"
    Contact "FR5"
    Contact "NA_STOP_M5"
    Contact "SIN_Y7_M5"
) "KM3"

$networks += New-SeriesNetwork "Auto - permissivo KM4 simplificado" @(
    Contact "AUT_LINHA_LIGADA"
    Contact "S20_COMP" -Negated
    Contact "S21_COMP" -Negated
    Contact "M5_S18" -Negated
    Contact "M5_S19" -Negated
    Contact "FR4"
    Contact "NA_STOP_M4"
    Contact "SIN_Y7_M4"
    Contact "FR5"
    Contact "NA_STOP_M5"
    Contact "SIN_Y7_M5"
) "KM4"

$networks += New-SeriesNetwork "Auto - permissivo KM5 simplificado" @(
    Contact "AUT_LINHA_LIGADA"
    Contact "S20_COMP" -Negated
    Contact "S21_COMP" -Negated
    Contact "SENSOR_100_PERCENT" -Negated
    Contact "FR5"
    Contact "NA_STOP_M5"
    Contact "SIN_Y7_M5"
) "KM5"

$networks += New-SeriesNetwork "FC7 - avaria compactador" @(
    Contact "NA_STOP_COMP" -Negated
) "H6_VERMELHO"

$networks += New-SeriesNetwork "FC7 - avaria M1 por termico" @(
    Contact "FR1" -Negated
) "H7_VERMELHO"

$networks += New-SeriesNetwork "FC7 - avaria M2 por termico" @(
    Contact "FR2" -Negated
) "H8_VERMELHO"

$networks += New-SeriesNetwork "FC7 - avaria M3 por termico" @(
    Contact "FR3" -Negated
) "H9_VERMELHO"

$networks += New-SeriesNetwork "FC7 - avaria M4 por termico" @(
    Contact "FR4" -Negated
) "H10_VERMELHO"

$networks += New-SeriesNetwork "FC7 - avaria M5 por termico" @(
    Contact "FR5" -Negated
) "H11_VERMELHO"

$networks += New-SeriesNetwork "FC7 - avaria M6 por termico" @(
    Contact "FR6" -Negated
) "H12_VERMELHO"

$networkText = $networks -join "`r`n"
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Document>
  <Engineering version="V21" />
  <DocumentInfo>
    <Created>2026-09-06T16:35:00Z</Created>
    <ExportSetting>WithDefaults</ExportSetting>
  </DocumentInfo>
  <SW.Blocks.FC ID="0">
    <AttributeList>
      <AutoNumber>true</AutoNumber>
      <HeaderAuthor />
      <HeaderFamily />
      <HeaderName />
      <HeaderVersion>0.1</HeaderVersion>
      <Interface>
        <Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">
          <Section Name="Input" />
          <Section Name="Output" />
          <Section Name="InOut" />
          <Section Name="Temp" />
          <Section Name="Constant" />
        </Sections>
      </Interface>
      <MemoryLayout>Optimized</MemoryLayout>
      <Name>FC_LinhaCompactador_LAD</Name>
      <Namespace />
      <Number>21</Number>
      <ProgrammingLanguage>LAD</ProgrammingLanguage>
      <SetENOAutomatically>false</SetENOAutomatically>
    </AttributeList>
    <ObjectList>
      <MultilingualText ID="1000" CompositionName="Comment">
        <ObjectList>
          <MultilingualTextItem ID="1001" CompositionName="Items">
            <AttributeList>
              <Culture>en-US</Culture>
              <Text>Visualizacao LAD da logica principal. A sequencia temporizada executavel continua em FB_LinhaCompactador.</Text>
            </AttributeList>
          </MultilingualTextItem>
        </ObjectList>
      </MultilingualText>
$networkText
    </ObjectList>
  </SW.Blocks.FC>
</Document>
"@

$fullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutPath))
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fullPath) | Out-Null
[System.IO.File]::WriteAllText($fullPath, $xml, (New-Object System.Text.UTF8Encoding $false))
Write-Host "WROTE=$fullPath"
