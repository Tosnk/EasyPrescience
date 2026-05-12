param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion
)

$ErrorActionPreference = "Stop"

$tocPath = Join-Path $PSScriptRoot "..\\EasyPrescience.toc"
$changelogPath = Join-Path $PSScriptRoot "..\\CHANGELOG.md"

$tocContent = Get-Content -LiteralPath $tocPath
$versionLine = $tocContent | Where-Object { $_ -match '^## Version:' } | Select-Object -First 1
if (-not $versionLine) {
    throw "Missing version line in TOC."
}

$tocVersion = ($versionLine -replace '^## Version:\s*', '').Trim()
if ($tocVersion -ne $ExpectedVersion) {
    throw "TOC version '$tocVersion' does not match expected version '$ExpectedVersion'."
}

$changelogContent = Get-Content -LiteralPath $changelogPath
$expectedHeader = "## $ExpectedVersion"
if (-not ($changelogContent -contains $expectedHeader)) {
    throw "CHANGELOG.md does not contain release header '$expectedHeader'."
}

$headCommit = (git rev-parse HEAD).Trim()
Write-Output "Release check passed."
Write-Output "VERSION=$ExpectedVersion"
Write-Output "HEAD=$headCommit"
