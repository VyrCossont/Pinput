# If this doesn't execute, first run:
# Set-ExecutionPolicy -Scope CurrentUser Unrestricted

# Guaranteed to exist at this path if VS2017 or higher is installed.
$vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

# TODO: figure out which parts of VS Build Tools need to be installed, and install them on the build box.
$allowBuildTools = $false
if ($allowBuildTools) {
    $productsFlags = @("-products", "*")
} else {
    $productsFlags = @()
}

# https://github.com/microsoft/vswhere/wiki/Find-MSBuild
$msbuildPath = & $vswherePath -latest @productsFlags -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | select-object -first 1
if (!$msbuildPath) {
    throw "Couldn't find MSBuild.exe!"
}

$releaseDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$pinputCliDir = "$releaseDir\..\windows\PinputCli"
$version = Get-Content -Path "$releaseDir\version.txt" -TotalCount 1
if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
    $hostArch = "x64"
} elseif ($env:PROCESSOR_ARCHITECTURE -eq "X86") {
    $hostArch = "x86"
} else {
    throw "Unsupported host PROCESSOR_ARCHITECTURE: ${env:PROCESSOR_ARCHITECTURE}!"
}

# Remove build directories and output archives.
Remove-Item -Recurse -Force -ErrorAction Ignore "$pinputCliDir\Release"
Remove-Item -Recurse -Force -ErrorAction Ignore "$pinputCliDir\x64\Release"
Remove-Item -Recurse -Force "$releaseDir\artifacts\pinput-windows-*"

foreach ($targetArch in "x64", "x86")
{
    & $msbuildPath "$pinputCliDir\PinputCli.sln" -p:Configuration=Release -p:Platform=$targetArch

    if ($targetArch -eq "x86") {
        $exePath = "$pinputCliDir\Release\PinputCli.exe"
        $artifactArch = "x86"
    } else {
        $exePath = "$pinputCliDir\$targetArch\Release\PinputCli.exe"
        $artifactArch = "x86_64"
    }

    # Check for unwanted strings in output.
    # Requires SysInternals version of `strings`:
    # - https://docs.microsoft.com/en-us/sysinternals/downloads/strings added to path manually, or
    # - https://www.microsoft.com/store/productId/9P7KNL5RWT25
    $stringsFound = & strings.exe -accepteula -nobanner $exePath | Select-String -Quiet -Pattern @($env:COMPUTERNAME, $env:USERNAME)
    if ($stringsFound) {
        throw "Unwanted strings found in ${exePath}!"
    }

    $zipPath = "$releaseDir\artifacts\pinput-windows-$artifactArch-$version.zip"
    Compress-Archive -Force -Path $exePath -DestinationPath $zipPath

    $stringsFound = & strings.exe -accepteula -nobanner $zipPath | Select-String -Quiet -Pattern @($env:COMPUTERNAME, $env:USERNAME)
    if ($stringsFound) {
        throw "Unwanted strings found in ${zipPath}!"
    }
}
