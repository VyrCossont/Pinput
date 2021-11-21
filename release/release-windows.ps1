# If this doesn't execute, first run:
# Set-ExecutionPolicy -Scope CurrentUser Unrestricted

# Guaranteed to exist at this path if VS2017 or higher is installed.
$vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

# https://github.com/microsoft/vswhere/wiki/Find-MSBuild
$msbuildPath = & $vswherePath -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | select-object -first 1
if (!$msbuildPath) {
    throw "Couldn't find MSBuild.exe!"
}

$releaseDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$pinputCliDir = "$releaseDir\..\windows\PinputCli"
$version = Get-Content -Path "$releaseDir\version.txt" -TotalCount 1

foreach ($platform in "x64", "x86")
{
    & $msbuildPath "$pinputCliDir\PinputCli.sln" -p:Configuration=Release -p:Platform=$platform

    if ($platform -eq "x86") {
        $exePath = "$pinputCliDir\Release\PinputCli.exe"
    } else {
        $exePath = "$pinputCliDir\$platform\Release\PinputCli.exe"
    }
    # TODO: check executable with `dumpbin.exe /pdbpath`:
    #   https://docs.microsoft.com/en-us/cpp/build/reference/pdbpath
    $zipPath = "$releaseDir\artifacts\pinput-windows-$platform-$version.zip"
    Compress-Archive -Force -Path $exePath -DestinationPath $zipPath
}
