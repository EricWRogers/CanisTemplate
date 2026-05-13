$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Usage:
  .\scripts\create-game-script.bat [--root PATH] [--force] <Namespace/ScriptName> [required_component ...]

Examples:
  .\scripts\create-game-script.bat RollABall/EnemySpawner
  .\scripts\create-game-script.bat RollABall/EnemySpawner Canis::Transform Canis::Rigidbody
  .\scripts\create-game-script.bat --force SpaceGold::MiningLaser

Notes:
  - The target can use either /, \, or :: separators.
  - Required components are inserted into DEFAULT_CONFIG_AND_REQUIRED(...) exactly as provided.
'@ | Write-Host
}

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Validate-Identifier([string]$Value, [string]$Kind) {
    if ($Value -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Fail "'$Value' is not a valid C++ $Kind."
    }
}

function Add-Namespace-Open {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [int]$IndentLevel,
        [string]$NamespaceName
    )

    $indent = ' ' * $IndentLevel
    $Lines.Add("${indent}namespace $NamespaceName")
    $Lines.Add("${indent}{")
}

function Add-Namespace-Close {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [int]$IndentLevel
    )

    $indent = ' ' * $IndentLevel
    $Lines.Add("${indent}}")
}

function Write-LinesToFile {
    param(
        [string]$Path,
        [System.Collections.Generic.List[string]]$Lines
    )

    [System.IO.File]::WriteAllText($Path, (($Lines -join "`r`n") + "`r`n"))
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..'))
$outputRoot = $repoRoot
$forceOverwrite = $false

$argIndex = 0
$rawTarget = $null
$requiredComponents = [System.Collections.Generic.List[string]]::new()

while ($argIndex -lt $args.Count) {
    $current = $args[$argIndex]

    switch -Regex ($current) {
        '^--root$' {
            if ($argIndex + 1 -ge $args.Count) {
                Show-Usage
                Fail 'error: --root requires a path.'
            }
            $outputRoot = $args[$argIndex + 1]
            $argIndex += 2
            continue
        }
        '^--force$' {
            $forceOverwrite = $true
            $argIndex += 1
            continue
        }
        '^(-h|--help)$' {
            Show-Usage
            exit 0
        }
        '^--$' {
            $argIndex += 1
            break
        }
        '^-.*$' {
            Show-Usage
            Fail "error: unknown option '$current'."
        }
        default {
            break
        }
    }

    break
}

if ($argIndex -ge $args.Count) {
    Show-Usage
    Fail 'error: missing script name.'
}

$rawTarget = $args[$argIndex]
$argIndex += 1

while ($argIndex -lt $args.Count) {
    $requiredComponents.Add($args[$argIndex])
    $argIndex += 1
}

$normalizedTarget = $rawTarget.Replace('::', '/').Replace('\', '/').Trim('/')
if ([string]::IsNullOrWhiteSpace($normalizedTarget)) {
    Fail 'error: script name cannot be empty.'
}

$pathParts = $normalizedTarget.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
if ($pathParts.Count -eq 0) {
    Fail "error: invalid script name '$rawTarget'."
}

$className = $pathParts[$pathParts.Count - 1]
$namespaceParts = @()
if ($pathParts.Count -gt 1) {
    $namespaceParts = $pathParts[0..($pathParts.Count - 2)]
}

Validate-Identifier $className 'type name'
foreach ($namespacePart in $namespaceParts) {
    Validate-Identifier $namespacePart 'namespace segment'
}

$relativeDir = if ($namespaceParts.Count -gt 0) { [string]::Join('/', $namespaceParts) } else { '' }
$relativeHeader = if ($relativeDir) { "$relativeDir/$className.hpp" } else { "$className.hpp" }
$relativeSource = if ($relativeDir) { "$relativeDir/$className.cpp" } else { "$className.cpp" }
$scriptSymbolName = if ($namespaceParts.Count -gt 0) { ([string]::Join('::', $namespaceParts) + "::$className") } else { $className }

$headerPath = Join-Path $outputRoot "game/include/$relativeHeader"
$sourcePath = Join-Path $outputRoot "game/src/$relativeSource"

if (((Test-Path $headerPath) -or (Test-Path $sourcePath)) -and -not $forceOverwrite) {
    Write-Error 'error: target file already exists.'
    Write-Error "  header: $headerPath"
    Write-Error "  source: $sourcePath"
    Write-Error 'Use --force to overwrite both files.'
    exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $headerPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourcePath) | Out-Null

$configMacro = "DEFAULT_CONFIG(scriptConf, $scriptSymbolName);"
if ($requiredComponents.Count -gt 0) {
    $requiredComponentList = [string]::Join(', ', $requiredComponents)
    $configMacro = "DEFAULT_CONFIG_AND_REQUIRED(scriptConf, $scriptSymbolName, $requiredComponentList);"
}

$headerLines = [System.Collections.Generic.List[string]]::new()
$headerLines.Add('#pragma once')
$headerLines.Add('')
$headerLines.Add('#include <Canis/Entity.hpp>')
$headerLines.Add('')
$headerLines.Add('namespace Canis')
$headerLines.Add('{')
$headerLines.Add('    class App;')
$headerLines.Add('}')
$headerLines.Add('')

$indentLevel = 0
foreach ($namespacePart in $namespaceParts) {
    Add-Namespace-Open -Lines $headerLines -IndentLevel $indentLevel -NamespaceName $namespacePart
    $indentLevel += 4
}

$classIndent = ' ' * ($namespaceParts.Count * 4)
$bodyIndent = ' ' * (($namespaceParts.Count + 1) * 4)

$headerLines.Add("${classIndent}class $className : public Canis::ScriptableEntity")
$headerLines.Add("${classIndent}{")
$headerLines.Add("${classIndent}public:")
$headerLines.Add("${bodyIndent}static constexpr const char* ScriptName = `"$scriptSymbolName`";")
$headerLines.Add('')
$headerLines.Add("${bodyIndent}explicit $className(Canis::Entity& _entity) : Canis::ScriptableEntity(_entity) {}")
$headerLines.Add('')
$headerLines.Add("${bodyIndent}void Create() override;")
$headerLines.Add("${bodyIndent}void Ready() override;")
$headerLines.Add("${bodyIndent}void Destroy() override;")
$headerLines.Add("${bodyIndent}void Update(float _dt) override;")
$headerLines.Add("${classIndent}};")
$headerLines.Add('')
$headerLines.Add("${classIndent}void Register${className}Script(Canis::App& _app);")
$headerLines.Add("${classIndent}void UnRegister${className}Script(Canis::App& _app);")

for ($index = $namespaceParts.Count - 1; $index -ge 0; $index--) {
    $indentLevel -= 4
    Add-Namespace-Close -Lines $headerLines -IndentLevel $indentLevel
}

$sourceLines = [System.Collections.Generic.List[string]]::new()
$sourceLines.Add("#include <$relativeHeader>")
$sourceLines.Add('')
$sourceLines.Add('#include <Canis/App.hpp>')
$sourceLines.Add('#include <Canis/ConfigHelper.hpp>')
$sourceLines.Add('')

$indentLevel = 0
foreach ($namespacePart in $namespaceParts) {
    Add-Namespace-Open -Lines $sourceLines -IndentLevel $indentLevel -NamespaceName $namespacePart
    $indentLevel += 4
}

$sourceIndent = ' ' * ($namespaceParts.Count * 4)
$blockIndent = ' ' * (($namespaceParts.Count + 1) * 4)

$sourceLines.Add("${sourceIndent}namespace")
$sourceLines.Add("${sourceIndent}{")
$sourceLines.Add("${blockIndent}Canis::ScriptConf scriptConf = {};")
$sourceLines.Add("${sourceIndent}}")
$sourceLines.Add('')
$sourceLines.Add("${sourceIndent}void Register${className}Script(Canis::App& _app)")
$sourceLines.Add("${sourceIndent}{")
$sourceLines.Add("${blockIndent}// REGISTER_PROPERTY(scriptConf, $scriptSymbolName, exampleProperty);")
$sourceLines.Add('')
$sourceLines.Add("${blockIndent}$configMacro")
$sourceLines.Add('')
$sourceLines.Add("${blockIndent}scriptConf.DEFAULT_DRAW_INSPECTOR($scriptSymbolName);")
$sourceLines.Add('')
$sourceLines.Add("${blockIndent}_app.RegisterScript(scriptConf);")
$sourceLines.Add("${sourceIndent}}")
$sourceLines.Add('')
$sourceLines.Add("${sourceIndent}DEFAULT_UNREGISTER_SCRIPT(scriptConf, $className)")
$sourceLines.Add('')
$sourceLines.Add("${sourceIndent}void ${className}::Create() {}")
$sourceLines.Add('')
$sourceLines.Add("${sourceIndent}void ${className}::Ready() {}")
$sourceLines.Add('')
$sourceLines.Add("${sourceIndent}void ${className}::Destroy() {}")
$sourceLines.Add('')
$sourceLines.Add("${sourceIndent}void ${className}::Update(float) {}")

for ($index = $namespaceParts.Count - 1; $index -ge 0; $index--) {
    $indentLevel -= 4
    Add-Namespace-Close -Lines $sourceLines -IndentLevel $indentLevel
}

Write-LinesToFile -Path $headerPath -Lines $headerLines
Write-LinesToFile -Path $sourcePath -Lines $sourceLines

Write-Host "Created $headerPath"
Write-Host "Created $sourcePath"
