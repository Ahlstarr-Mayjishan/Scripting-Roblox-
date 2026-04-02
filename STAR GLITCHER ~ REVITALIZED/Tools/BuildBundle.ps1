param()

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$mainPath = Join-Path $root "Core\Main.lua"
$bundlePath = Join-Path $root "Core\Bundle.lua"

$mainContent = Get-Content -Raw -Path $mainPath
$loaderPattern = "local GITHUB_CONFIG = \{.*?\r?\n\r?\n-- Services"

$bundleHeader = @"
local BUNDLED_SOURCES = {
__BUNDLED_SOURCES__
}

local function loadBundledModule(path)
    local source = BUNDLED_SOURCES[path]
    if not source then
        error("Missing bundled module: " .. tostring(path))
    end

    local chunk, compileErr = loadstring(source, "=" .. path)
    if not chunk then
        error("Bundled compile failed for " .. tostring(path) .. ": " .. tostring(compileErr))
    end

    return chunk()
end

local function loadModule(path)
    local ok, result = pcall(loadBundledModule, path)
    if ok then
        return result
    end

    warn("[Bundle] Failed: " .. tostring(path) .. " | Error: " .. tostring(result))
    return nil
end

local function requireModule(path)
    local module = loadModule(path)
    if module == nil then
        error("Required module failed to load: " .. tostring(path))
    end
    return module
end

-- Services
"@

$moduleFiles = Get-ChildItem -Path $root -Recurse -File -Filter "*.lua" |
    Where-Object {
        $_.FullName -ne (Join-Path $root "Main.lua") -and
        $_.FullName -ne $mainPath -and
        $_.FullName -ne $bundlePath
    } |
    Sort-Object FullName

$entries = foreach ($file in $moduleFiles) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace("\", "/")
    $content = Get-Content -Raw -Path $file.FullName
    "    [""$relative""] = [====[$content]====]"
}

$replacement = $bundleHeader.Replace("__BUNDLED_SOURCES__", ($entries -join ",`r`n"))
$bundleContent = [regex]::Replace(
    $mainContent,
    $loaderPattern,
    $replacement,
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$bundleContent = $bundleContent.TrimStart([char]0xFEFF)

[System.IO.File]::WriteAllText(
    $bundlePath,
    $bundleContent,
    (New-Object System.Text.UTF8Encoding($false))
)
Write-Host "Bundle rebuilt:" $bundlePath
