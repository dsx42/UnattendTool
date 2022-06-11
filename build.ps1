Set-Location -Path $PSScriptRoot

$Version = .\UnattendTool.ps1 -Version
$Output = 'target'
$ProjectName = 'UnattendTool'

$DestinationPath = ".\$Output\${ProjectName}_$Version.zip"

$Files = @(
    '.\UnattendTool.cmd',
    '.\UnattendTool.ps1',
    '.\LICENSE',
    '.\README.md'
)

if (Test-Path -Path ".\$Output" -PathType Container) {
    Remove-Item -Path ".\$Output" -Recurse -Force
}

New-Item -Path ".\$Output\$ProjectName" -ItemType Directory -Force

Copy-Item -Path $Files -Destination ".\$Output\$ProjectName" -Force -Recurse

Compress-Archive -Path ".\$Output\$ProjectName" -DestinationPath $DestinationPath -Force

$Hash = Get-FileHash -Path $DestinationPath -Algorithm SHA256

$Checksum = $Hash.Hash + " ${ProjectName}_$Version.zip"

Add-Content -Path ".\$Output\${ProjectName}_$Version.sha256" -Value $Checksum

Write-Host -Object ''
Write-Host -Object ('Path: ' + $Hash.Path)
Write-Host -Object ''
Write-Host -Object ('SHA256: ' + $Hash.Hash)
Write-Host -Object ''
Read-Host -Prompt '按回车键关闭此窗口'
