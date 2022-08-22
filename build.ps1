Clear-Host

Set-Location -Path $PSScriptRoot

$ProductJsonPath = "$PSScriptRoot\product.json"

if (!(Test-Path -Path $ProductJsonPath -PathType Leaf)) {
    Write-Warning -Message ("$ProductJsonPath 不存在")
    [System.Environment]::Exit(0)
}

$ProductInfo = $null
try {
    $ProductInfo = Get-Content -Path $ProductJsonPath | ConvertFrom-Json
}
catch {
    Write-Warning -Message ("$ProductJsonPath 解析失败")
    [System.Environment]::Exit(0)
}
if (!$ProductInfo -or $ProductInfo -isNot [PSCustomObject]) {
    Write-Warning -Message ("$ProductJsonPath 解析失败")
    [System.Environment]::Exit(0)
}

$Version = $ProductInfo.'version'
if (!$Version) {
    Write-Warning -Message ("$ProductJsonPath 不存在 version 信息")
    [System.Environment]::Exit(0)
}

$ProjectName = $ProductInfo.'name'
if (!$ProjectName) {
    Write-Warning -Message ("$ProductJsonPath 不存在 name 信息")
    [System.Environment]::Exit(0)
}

$Files = $ProductInfo.'files'
if (!$Files -or $Files -isNot [System.Array] -or $Files.Count -le 0) {
    Write-Warning -Message ("$ProductJsonPath 不存在 files 信息")
    [System.Environment]::Exit(0)
}

$CopyFiles = @()
foreach ($File in $Files) {
    $CopyFiles += "$PSScriptRoot\$File"
}

$Output = 'target'
$OutputPath = "$PSScriptRoot\$Output"
$OutputProjectPath = "$OutputPath\${ProjectName}"
$OutputFileName = "${ProjectName}_v$Version"
$ZipFilePath = "$OutputPath\$OutputFileName.zip"
$Sha256FilePath = "$OutputPath\$OutputFileName.sha256"

if (Test-Path -Path $OutputPath -PathType Container) {
    Remove-Item -Path $OutputPath -Recurse -Force
}

New-Item -Path $OutputProjectPath -ItemType Directory -Force | Out-Null

Copy-Item -Path $CopyFiles -Destination $OutputProjectPath -Force -Recurse

Compress-Archive -Path $OutputProjectPath -DestinationPath $ZipFilePath -Force

$Hash = Get-FileHash -Path $ZipFilePath -Algorithm SHA256

$Checksum = $Hash.Hash + " $OutputFileName.zip"

Add-Content -Path $Sha256FilePath -Value $Checksum

Write-Host -Object ''
Write-Host -Object ('Path: ' + $Hash.Path)
Write-Host -Object ''
Write-Host -Object ('SHA256: ' + $Hash.Hash)
Write-Host -Object ''
Read-Host -Prompt '按回车键关闭此窗口'
