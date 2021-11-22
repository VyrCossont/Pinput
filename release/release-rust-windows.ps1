# If this doesn't execute, first run:
# Set-ExecutionPolicy -Scope CurrentUser Unrestricted

# Should be set to a MinGW bash.exe like the one that comes with Git for Windows.
$bashExe = "${env:ProgramFiles}\Git\bin\bash.exe"

$releaseDir = Split-Path $MyInvocation.MyCommand.Path -Parent

& $bashExe "$releaseDir\release-rust.sh"
