<#
全量把 lib/ 下的 `Text(...)` 替换成 `AppText(...)`，并自动加 import。
- AppText 在 style 不是 PingFang SC 时与 Text 行为完全一致；
- `Text.rich(`、`RichText(`、`EditableText(`、`SelectableText(` 均不会被匹配到（regex 用了 `(?<![\w])Text\(` 且要求 `(` 紧跟 Text）；
- 跳过 app_text.dart 自身。

参数：
  -DryRun           仅打印将要改动的文件与每文件替换次数，不实际写盘。
  -VerboseDetail    打印每个文件的详细改动。
#>
param(
    [switch]$DryRun,
    [switch]$VerboseDetail
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$libRoot = (Resolve-Path (Join-Path $scriptDir '..\lib')).Path
$appTextPath = (Resolve-Path (Join-Path $libRoot 'core\widgets\app_text.dart')).Path

Write-Host "Lib root: $libRoot"
Write-Host "AppText file: $appTextPath"
Write-Host ""

$pattern = '(?<![\w])Text\('
$replacement = 'AppText('

$files = Get-ChildItem -Path $libRoot -Recurse -Filter '*.dart' | Where-Object { $_.FullName -ne $appTextPath }

$totalFiles = 0
$totalReplacements = 0
$totalImportsAdded = 0

function Get-RelativeImport {
    param([string]$FromFileFullPath, [string]$ToFileFullPath)
    $fromDir = Split-Path -Parent $FromFileFullPath
    $fromParts = $fromDir -split '[\\/]+' | Where-Object { $_ -ne '' }
    $toParts = $ToFileFullPath -split '[\\/]+' | Where-Object { $_ -ne '' }
    $common = 0
    $maxCommon = [Math]::Min($fromParts.Count, $toParts.Count - 1)
    while ($common -lt $maxCommon -and $fromParts[$common] -ieq $toParts[$common]) {
        $common += 1
    }
    $upCount = $fromParts.Count - $common
    $upSegment = ('../' * $upCount)
    $downSegments = ($toParts[$common..($toParts.Count - 1)] -join '/')
    if ($upCount -gt 0) { return "$upSegment$downSegments" }
    return "./$downSegments"
}

foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.UTF8Encoding]::new($false))
    if ([string]::IsNullOrEmpty($content)) { continue }

    $matchCount = ([regex]::Matches($content, $pattern)).Count
    if ($matchCount -eq 0) { continue }

    $totalFiles += 1
    $totalReplacements += $matchCount

    $rel = Get-RelativeImport -FromFileFullPath $f.FullName -ToFileFullPath $appTextPath
    $importLine = "import '$rel';"

    # ── 添加 import（如未存在） ──
    $importAdded = $false
    $hasAppTextImport = [regex]::IsMatch($content, "import\s+'[^']*app_text\.dart';")
    if (-not $hasAppTextImport) {
        # 找最后一行以 `import ` 开头的语句的结束位置（紧跟其后的换行符之后），插入新 import + 换行
        $importMatches = [regex]::Matches($content, "(?m)^import\s+'[^']+';\s*\r?\n")
        if ($importMatches.Count -gt 0) {
            $lastMatch = $importMatches[$importMatches.Count - 1]
            $insertPos = $lastMatch.Index + $lastMatch.Length
            $newImport = "$importLine`r`n"
            $content = $content.Substring(0, $insertPos) + $newImport + $content.Substring($insertPos)
            $importAdded = $true
            $totalImportsAdded += 1
        }
    }

    # ── 实际替换 Text( 为 AppText( ──
    $newContent = [regex]::Replace($content, $pattern, $replacement)

    if ($VerboseDetail) {
        $name = $f.FullName.Substring($libRoot.Length + 1)
        Write-Host ("  - {0,-72} replacements={1,-5} importAdded={2}" -f $name, $matchCount, $importAdded)
    }

    if (-not $DryRun) {
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($f.FullName, $newContent, $utf8)
    }
}

Write-Host ""
Write-Host ("Files touched   : {0}" -f $totalFiles)
Write-Host ("Replacements    : {0}" -f $totalReplacements)
Write-Host ("Imports added   : {0}" -f $totalImportsAdded)
if ($DryRun) {
    Write-Host ""
    Write-Host "(Dry run - no files were modified.)"
}
