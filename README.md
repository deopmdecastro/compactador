# COMPACTADOR

Projeto de automacao industrial para uma linha de tapetes transportadores com compactador, desenvolvido no Siemens TIA Portal V21 e simulado no Factory IO.

O projeto inclui a logica PLC, a cena do Factory IO, o espelho da tabela de I/O, scripts de apoio para TIA Openness e documentacao operacional da sequencia.

## Componentes principais

- Projeto TIA Portal: `COMPACTADOR.ap21`
- Cena Factory IO: `COMPACTADOR.factoryio`
- Informacao do projeto TIA: `COMPACTADOR.info` e `ProjectInfo.txt`
- Espelho da tabela I/O: `UserFiles/IO/Lista_IO_Espelho.csv`
- Fonte executavel da logica: `tia-src/COMPACTADOR_LinhaCompactador.scl`
- OB principal: `tia-src/COMPACTADOR_Main.scl`
- Visualizacao LAD: `tia-xml/FC_LinhaCompactador_LAD.xml`
- Scripts TIA Openness: `tools/`

## Requisitos

- Siemens TIA Portal V21
- STEP 7 V21
- TIA Openness ativo para o utilizador Windows
- Factory IO
- PLCSIM ou CPU S7-1200/1500 compativel

Segundo `ProjectInfo.txt`, o projeto requer TIA Portal V21 e foi usado com TIA Portal V21 Hotfix 1.

## Blocos PLC

O projeto usa estes blocos principais:

- `Main [OB1]`: bloco de organizacao principal em LAD (Ladder). Contem apenas a chamada ao bloco de controlo da linha.
- `FC_LinhaCompactador_LAD [FC21]`: visualizacao em LAD da logica principal, incluindo a network do `TON` de inatividade. E chamado diretamente pelo `Main [OB1]`.
- `FB_LinhaCompactador [FB1]`: contem a logica executavel da linha.
- `DB_LinhaCompactador [DB1]`: instance DB do `FB_LinhaCompactador`.

O `Main [OB1]` e o ponto de entrada do PLC. Ele chama o `FC_LinhaCompactador_LAD [FC21]`, que representa a logica visual em Ladder da linha de compactador.

## Estrutura do programa

```text
Main [OB1] (LAD)
  └── FC_LinhaCompactador_LAD [FC21]
        └── (logica LAD da linha: GRAFCET, seguranca, sequencias, etc.)
```

O `Main [OB1]` foi recriado em linguagem LAD (Ladder). A sua Network 1 contem apenas a chamada ao bloco `FC_LinhaCompactador_LAD [FC21]`. Toda a logica executavel reside dentro desse FC, que pode ser monitorizada online com os óculos de monitorizacao (Ctrl + F7).

## Topologia da linha

A linha tem cinco grupos de tapetes e um compactador:

```text
M1 -> M3 -> M5 -> compactador/contentor
M2 -> M4 -> M5 -> compactador/contentor
```

O grupo `M5` aparece repetido fisicamente no Factory IO porque a esteira usada tem duas partes, mas logicamente continua a ser o mesmo motor/grupo da tabela I/O.

## Entradas principais

Seguranca e comando:

- `STOP7`: paragem geral local, contacto NF.
- `STOP6_GERAL`: paragem geral adicional, contacto NF.
- `START`: arranque automatico.
- `AVANCA`: comando manual de avanco do cilindro.
- `RECUA`: comando manual de recuo do cilindro.
- `SEL_AUTO`: seletor em automatico.
- `SEL_MANUAL`: seletor em manual.

Protecoes e diagnosticos:

- `FR1` a `FR6`: reles termicos dos motores M1 a M6.
- `SIN_Y7_COMP`: diagnostico de seguranca do compactador.
- `SIN_Y7_M1` a `SIN_Y7_M5`: diagnostico de seguranca dos motores.
- `NA_STOP_M1` a `NA_STOP_M5`: paragens locais dos tapetes.
- `NA_STOP_COMP`: paragem local do compactador.

Sensores de tapetes:

- `M1_S4`, `M1_S5`, `M1_S6`
- `M2_S7`, `M2_S8`, `M2_S9`
- `M3_S10`, `M3_S11`, `M3_S12`
- `M4_S13`, `M4_S14`, `M4_S15`
- `M5_S16`, `M5_S17`, `M5_S18`, `M5_S19`

Compactador, moega e contentor:

- `NA_S1_COMP`: fim de curso/seguranca 1 do compactador.
- `NA_S2_COMP`: fim de curso/seguranca 2 do compactador.
- `NA_S3_COMP`: fim de curso/seguranca 3 do compactador.
- `SENSOR_75_PERCENT`: nivel da moega a 75%.
- `SENSOR_100_PERCENT`: nivel da moega a 100%.
- `S20_COMP`: sensor de contentor.
- `S21_COMP`: sensor de contentor.

## Saidas principais

Motores e atuadores:

- `KM1`: motor/tapete M1.
- `KM2`: motor/tapete M2.
- `KM3`: motor/tapete M3.
- `KM4`: motor/tapete M4.
- `KM5`: motor/tapete M5.
- `START_SS_M6`: habilitacao da soft starter/bomba M6.
- `Y1_AVANCA`: eletrovalvula de avanco do cilindro.
- `Y2_RECUA`: eletrovalvula de recuo do cilindro.

Sinalizacao:

- `H1_VERDE`: linha automatica em funcionamento.
- `H2_AMARELO`: standby/pronto ou contentor bloqueado.
- `H3_AZUL`: nivel da moega a 75%.
- `H4_VERMELHO`: nivel da moega a 100%.
- `H5_VERMELHO`: paragem ou avaria geral.
- `H6_VERMELHO`: avaria/paragem do compactador.
- `H7_VERMELHO` a `H11_VERMELHO`: avarias dos motores M1 a M5.
- `H12_VERMELHO`: avaria da bomba M6.
- `H13_AUTO`: modo automatico selecionado.
- `H14_MANUAL`: modo manual selecionado.

## Marcadores internos

- `%M0.0` `OK_SISTEMA`: permissivo geral de seguranca.
- `%M0.1` `AUT_LINHA_LIGADA`: selo da linha em automatico.
- `%M0.2` `MODO_MANUAL`: modo manual validado.
- `%M0.3` `CICLO_RECUO`: estado do ciclo de recuo do cilindro.
- `%M0.4` `EMERGENCIA`: falta de permissivo geral.
- `%M0.5` `INATIVIDADE_ATIVA`: `Q` do timer de inatividade.
- `%MW2` `ETAPA_GRAFCET`: etapa atual da sequencia.

## Logica de seguranca

`OK_SISTEMA` fica ativo apenas quando todas as condicoes de seguranca estao boas:

```text
STOP7
STOP6_GERAL
FR1..FR6
SIN_Y7_COMP
SIN_Y7_M1..SIN_Y7_M5
NA_STOP_M1..NA_STOP_M5
NA_STOP_COMP
```

Se qualquer uma destas condicoes falhar:

- `OK_SISTEMA` desliga.
- `EMERGENCIA` liga.
- `KM1` a `KM5` desligam.
- `START_SS_M6` desliga.
- `Y1_AVANCA` e `Y2_RECUA` desligam.
- `AUT_LINHA_LIGADA` desliga.
- `CICLO_RECUO` desliga.
- `ETAPA_GRAFCET` volta para `0`.

Tambem existe protecao contra modo invalido: se `SEL_AUTO` e `SEL_MANUAL` estiverem ativos ao mesmo tempo, a linha e desligada.

## Modos de operacao

Modo automatico:

```text
AutoOk = SEL_AUTO AND NOT SEL_MANUAL AND OK_SISTEMA
```

Modo manual:

```text
MODO_MANUAL = SEL_MANUAL AND NOT SEL_AUTO AND OK_SISTEMA
```

As lampadas de modo seguem diretamente o seletor validado:

- `H13_AUTO`: automatico selecionado.
- `H14_MANUAL`: manual selecionado.

## Sequencia automatica

O arranque automatico so comeca se:

- `AutoOk` estiver ativo.
- `START` for pressionado.
- `SENSOR_100_PERCENT` estiver livre.
- `S20_COMP` e `S21_COMP` estiverem livres.
- `ETAPA_GRAFCET` estiver em `0`.

Etapas de arranque:

```text
0x0000: parado / standby
0x000A: arranca M6
0x0014: depois de 3 s, habilita M5
0x001E: depois de 2 s, habilita M3 e M4
0x0028: depois de 2 s, linha ligada e habilita M1 e M2
```

Temporizadores de arranque:

- `T_Start_M6`: 3 s.
- `T_Start_M5`: 2 s.
- `T_Start_M34`: 2 s.

## Paragem automatica em cascata

A linha entra em paragem quando esta em funcionamento e acontece uma destas condicoes:

- sai do modo automatico;
- `SENSOR_100_PERCENT` fica ativo;
- `INATIVIDADE_ATIVA` fica ativo apos 30 s sem material.

Etapas de paragem:

```text
0x0064: desliga alimentacao inicial / M1 e M2
0x006E: desliga M3 e M4
0x0078: desliga M5
0x0000: volta a standby
```

Temporizadores de paragem:

- `T_Stop_M12`: 2 s.
- `T_Stop_M34`: 2 s.
- `T_Stop_M5`: 2 s.

A transicao para a etapa seguinte tambem pode acontecer antes do tempo se os sensores da zona seguinte indicarem que ja nao ha material.

## Logica anti-acumulacao

A regra principal e: o motor de tras so alimenta se a zona da frente estiver livre.

Permissivos por motor:

- `KM1` so anda se `M3_S10`, `M3_S11` e `M3_S12` estiverem livres.
- `KM2` so anda se `M4_S13`, `M4_S14` e `M4_S15` estiverem livres.
- `KM3` so anda se `M5_S16` e `M5_S17` estiverem livres.
- `KM4` so anda se `M5_S18` e `M5_S19` estiverem livres.
- `KM5` so anda se `SENSOR_100_PERCENT` estiver livre.

Todos os motores tambem dependem de:

- contentor livre (`S20_COMP` e `S21_COMP` livres);
- protecoes do proprio grupo;
- protecoes dos grupos a jusante quando aplicavel.

Esta logica evita empurrar material para uma zona ocupada e reduz o risco de derrubar objetos transportados.

## Logica do contentor

`S20_COMP` e `S21_COMP` monitoram o contentor.

Se qualquer um ficar obstruido:

- `ContentorLivre` fica falso.
- `KM1` a `KM5` deixam de receber permissivo.
- `H1_VERDE` desliga.
- `H2_AMARELO` liga como standby/bloqueio.

Quando `S20_COMP` e `S21_COMP` voltam a ficar livres, a linha volta a ter permissivo, desde que as restantes condicoes de seguranca e modo estejam corretas.

## Logica de inatividade

A linha nao fica a trabalhar indefinidamente sem material.

Foi criado o timer:

```text
T_Inatividade : TON
PT = T#30s
Q  = INATIVIDADE_ATIVA (%M0.5)
```

O timer so conta quando:

- a linha esta em automatico;
- `AUT_LINHA_LIGADA` esta ativo;
- todos os sensores de passagem estao livres;
- `S20_COMP` e `S21_COMP` estao livres;
- `SENSOR_75_PERCENT` e `SENSOR_100_PERCENT` estao livres.

Condicao de linha sem material:

```text
NOT M1_S4 AND NOT M1_S5 AND NOT M1_S6
AND NOT M2_S7 AND NOT M2_S8 AND NOT M2_S9
AND NOT M3_S10 AND NOT M3_S11 AND NOT M3_S12
AND NOT M4_S13 AND NOT M4_S14 AND NOT M4_S15
AND NOT M5_S16 AND NOT M5_S17 AND NOT M5_S18 AND NOT M5_S19
AND NOT S20_COMP AND NOT S21_COMP
AND NOT SENSOR_75_PERCENT AND NOT SENSOR_100_PERCENT
```

Quando esta condicao permanece verdadeira por 30 s:

- `INATIVIDADE_ATIVA` liga.
- A etapa `0x0028` passa para `0x0064`.
- A linha executa a paragem em cascata.
- No fim, `AUT_LINHA_LIGADA` desliga e a linha volta para `0x0000`.

No LAD visual existe a network:

```text
TON - Inatividade 30s
```

Ela mostra o mesmo timer com `DB_LinhaCompactador.T_Inatividade`, `PT = T#30s` e `Q -> INATIVIDADE_ATIVA`.

## Modo manual

Em modo manual:

- A linha automatica e desligada.
- `ETAPA_GRAFCET` volta para `0`.
- `KM1` a `KM5` ficam desligados.
- O compactador pode ser comandado por `AVANCA` ou `RECUA`.

Intertravamentos:

- `Y1_AVANCA` so liga com `AVANCA`, sem `RECUA`, e com `OK_SISTEMA`.
- `Y2_RECUA` so liga com `RECUA`, sem `AVANCA`, e com `OK_SISTEMA`.
- `START_SS_M6` liga quando existe comando manual valido.

## Ciclo do compactador

Em automatico, o compactador usa um ciclo simples por fins de curso:

- Se `NA_S2_COMP` estiver ativo, `CICLO_RECUO` liga.
- Se `NA_S1_COMP` estiver ativo, `CICLO_RECUO` desliga.
- `Y1_AVANCA` liga quando `START_SS_M6` esta ativo, `CICLO_RECUO` esta falso e `NA_S2_COMP` ainda nao foi atingido.
- `Y2_RECUA` liga quando `START_SS_M6` esta ativo, `CICLO_RECUO` esta verdadeiro e `NA_S1_COMP` ainda nao foi atingido.

`S20_COMP` e `S21_COMP` nao sao fins de curso do compactador; eles monitoram o contentor.

## Factory IO

A cena `COMPACTADOR.factoryio` esta preparada para comunicacao Siemens S7-1200/1500.

Mapeamento de sensores principais no Factory IO:

- `M1_S4` a `M5_S19`: entradas digitais `%I4.0` a `%I5.7`.
- `S20_COMP` e `S21_COMP`: sensores do contentor.
- As saidas `KM1` a `KM5`, `START_SS_M6`, `Y1_AVANCA` e `Y2_RECUA` devem comandar os motores/atuadores correspondentes.

Os sensores opticos dos tapetes foram ajustados em altura, orientacao e espacamento para atravessar o tapete corretamente.

## Fluxo de trabalho com TIA Openness

Scripts principais:

- `tools/Export-TiaTagsToMirror.ps1`: exporta as tabelas reais do TIA e atualiza `UserFiles/IO/Lista_IO_Espelho.csv`.
- `tools/Import-SclSourceToTia.ps1`: importa fontes SCL e gera blocos no TIA.
- `tools/Import-BlockXmlToTia.ps1`: importa blocos XML, como o LAD visual.
- `tools/New-LadVisualXml.ps1`: regenera `tia-xml/FC_LinhaCompactador_LAD.xml`.
- `tools/GoOffline-TiaProject.ps1`: coloca o PLC offline pela API antes de editar blocos.
- `tools/Compile-SaveTiaProject.ps1`: compila e salva o projeto aberto.
- `tools/Get-TiaBlockStatus.ps1`: mostra linguagem e consistencia dos blocos.
- `tools/Ensure-TiaTag.ps1`: cria/garante uma tag PLC no TIA.

Fluxo recomendado apos alterar logica:

```powershell
& .\tools\GoOffline-TiaProject.ps1
& .\tools\New-LadVisualXml.ps1
& .\tools\Import-SclSourceToTia.ps1 -DeleteBlock DB_LinhaCompactador,FB_LinhaCompactador
& .\tools\Import-BlockXmlToTia.ps1 -XmlPath tia-xml\FC_LinhaCompactador_LAD.xml -DeleteBlock FC_LinhaCompactador_LAD
& .\tools\Compile-SaveTiaProject.ps1
& .\tools\Export-TiaTagsToMirror.ps1
```

## Estado de compilacao

Ultima validacao feita no TIA Portal:

```text
Main                    LAD CONSISTENT=True
FB_LinhaCompactador     CONSISTENT=True
DB_LinhaCompactador     CONSISTENT=True
FC_LinhaCompactador_LAD CONSISTENT=True
```

Compilacao final:

```text
errors: 0
warnings: 1
PROJECT_SAVED=True
```

O projeto foi salvo no TIA. O download para PLC/PLCSIM deve ser feito depois de confirmar a ligacao correta com Factory IO.

## Boas praticas

- Fazer backup antes de migrar para outra versao do TIA Portal.
- Usar as tabelas reais do TIA como fonte de verdade para I/O.
- Atualizar o espelho com `Export-TiaTagsToMirror.ps1` apos alterar tags.
- Nao editar manualmente ficheiros internos como `XRef.db`, `Vci.db`, `PEData.*` ou conteudos de `IM/SearchIndex`.
- Manter alteracoes de logica, Factory IO e documentacao em commits claros.

## Autor

- Projeto: Deogracia de Castro
- Ambiente: TIA Portal V21 / STEP 7 V21 / Factory IO
