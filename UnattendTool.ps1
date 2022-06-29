param(
    $Language = 'zh-CN',
    $OsVersion = 11,
    $WindowsProductName = 'Enterprise',
    $Architecture = 'x64',
    $DiskId = -1,
    $PartitionId = -1,
    $PartitionStyle = 'GPT',
    $FullName = 'MyPC',
    $VentoyDriverLetter = '',
    $ISOPath = '',
    [switch]$Interactive,
    [switch]$NotFormat,
    [switch]$Version
)

function GetDefaultFolderPath {
    return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
}

function GetPartitionTypeName {
    param($GptType, $MbrType, $FileSystem)

    if ($GptType) {
        if ($GptType -ieq '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}') {
            return '微软恢复分区'
        }
        elseif ($GptType -ieq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}') {
            return 'EFI 系统分区'
        }
        elseif ($GptType -ieq '{e3c9e316-0b5c-4db8-817d-f92df00215ae}') {
            return '微软保留分区'
        }
        elseif ($GptType -ieq '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}') {
            return '基本数据分区'
        }
        elseif ($GptType -ieq '{af9b60a0-1431-4f62-bc68-3311714a69ad}') {
            return '逻辑磁盘管理器元数据分区'
        }
        elseif ($GptType -ieq '{af9b60a0-1431-4f62-bc68-3311714a69ad}') {
            return '逻辑磁盘管理器数据分区'
        }
    }

    if ($MbrType) {
        if ($MbrType -ieq '1') {
            return 'FAT12 分区'
        }
        elseif ($MbrType -ieq '4') {
            return 'FAT16 分区'
        }
        elseif ($MbrType -ieq '5') {
            return '扩展分区'
        }
        elseif ($MbrType -ieq '6') {
            return '逻辑分区'
        }
        elseif ($MbrType -ieq '7') {
            return "$FileSystem 分区"
        }
        elseif ($MbrType -ieq '12') {
            return 'FAT32 分区'
        }
    }

    return '未知分区'
}

function GetCurrentDisk {

    $CurrentDisks = [ordered]@{}

    Get-Disk | ForEach-Object {

        $Partitions = [ordered]@{}
        $PhydicalDisk = Get-PhysicalDisk -FriendlyName $_.FriendlyName

        Get-Partition -DiskNumber $_.DiskNumber | ForEach-Object {

            $Volume = Get-Volume -Partition $_
            $PartitionTypeName = GetPartitionTypeName -GptType $_.GptType -MbrType $_.MbrType `
                -FileSystem $Volume.FileSystem

            $Partition = @{
                'Guid'            = $_.Guid; # 分区 ID
                'PartitionNumber' = $_.PartitionNumber; # 分区编号，值从 1 开始
                'DiskNumber'      = $_.DiskNumber; # 所属硬盘编号，值从 0 开始
                'GptType'         = $_.GptType; # 分区类型的 ID
                'DriveLetter'     = $_.DriveLetter; # 驱动器号，如 C
                'FileSystem'      = $Volume.FileSystem; # 分区文件系统类型
                'FileSystemType'  = $Volume.FileSystemType; # 分区文件系统类型
                'SizeRemaining'   = $Volume.SizeRemaining; # 分区可用空间大小，单位为 Byte
                'Size'            = $_.Size; # 分区容量，单位为 Byte
                'Type'            = $_.Type; # GPT 分区类型，System 表示 EFI 分区，Basic 表示基本数据分区，Reserved 表示 MSR 保留分区
                'TypeName'        = $PartitionTypeName;
                'MbrType'         = $_.MbrType; # MBR 分区类型的 ID
                'IsHidden'        = $_.IsHidden; # 是否隐藏分区
                'IsBoot'          = $_.IsBoot; # 是否启动分区
                'IsSystem'        = $_.IsSystem; # 是否 EFI 系统分区
                'IsActive'        = $_.IsActive # 是否活动分区，MBR 才有意义，GPT 无意义
            }
            $Partitions.Add($_.PartitionNumber, $Partition)
        }

        $Disk = @{
            'DiskNumber'         = $_.DiskNumber; # 硬盘编号，值从 0 开始
            'PartitionStyle'     = $_.PartitionStyle; # 分区类型，如 GPT 或 MBR
            'MediaType'          = $PhydicalDisk.MediaType; # 硬盘类型，如 SSD 或 HDD
            'OperationalStatus'  = $_.OperationalStatus; # 硬盘状态，如 Online
            'HealthStatus'       = $_.HealthStatus; # 硬盘健康状态，如 Healthy
            'BusType'            = $_.BusType; # 硬盘接口类型，如 RAID 或 USB
            'BootFromDisk'       = $_.BootFromDisk; # 是否从该硬盘启动
            'FirmwareVersion'    = $_.FirmwareVersion; # 硬盘固件版本
            'FriendlyName'       = $_.FriendlyName; # 硬盘名称
            'IsBoot'             = $_.IsBoot; # 是否从该硬盘启动
            'IsSystem'           = $_.IsSystem; # 是否系统盘
            'Manufacturer'       = $_.Manufacturer; # 硬盘制造商
            'Model'              = $_.Model; # 硬盘型号
            'NumberOfPartitions' = $_.NumberOfPartitions; # 硬盘分区数量
            'Size'               = $_.Size; # 硬盘容量，单位为 Byte
            'AllocatedSize'      = $PhydicalDisk.AllocatedSize; # 已分配容量，单位为 Byte
            'Partitions'         = $Partitions
        }
        $CurrentDisks.Add($_.DiskNumber, $Disk)
    }

    return $CurrentDisks
}

function GetSystemDiskId {

    $CurrentDisks = GetCurrentDisk

    foreach ($_ in $CurrentDisks.GetEnumerator()) {
        if ($_.Value['IsBoot']) {
            return $_.Value['DiskNumber']
        }
    }

    return 0
}

function GetSystemPartitionId {

    $CurrentDisks = GetCurrentDisk

    foreach ($_ in $CurrentDisks.GetEnumerator()) {
        foreach ($__ in $_.Value['Partitions'].GetEnumerator()) {
            if ($__.Value['IsBoot']) {
                return $__.Value['PartitionNumber']
            }
        }
    }

    return 1
}

function FormatSize {
    param($Size)

    $Tb = [Math]::Round($Size * 1.0 / 1024 / 1024 / 1024 / 1024, 2)
    if ($Tb -gt 1) {
        return "$Tb" + ' TB'
    }

    $Gb = [Math]::Round($Size * 1.0 / 1024 / 1024 / 1024, 2)
    if ($Gb -gt 1) {
        return "$Gb" + ' GB'
    }

    $Mb = [Math]::Round($Size * 1.0 / 1024 / 1024, 2)
    if ($Mb -gt 1) {
        return "$Mb" + ' MB'
    }

    $Kb = [Math]::Round($Size * 1.0 / 1024, 2)
    if ($Kb -gt 1) {
        return "$Kb" + ' KB'
    }

    if ($Size -le 0) {
        return '0 Byte'
    }

    return "$Size" + ' Byte'
}

function ShowLanguageSelect {

    Write-Host -Object '============================'
    Write-Host -Object '选择要安装系统的语言，推荐 1'
    Write-Host -Object '============================'
    Write-Host -Object ''
    Write-Host -Object '1: 简体中文 zh-CN'
    Write-Host -Object ''
    Write-Host -Object '2: 英文 en-US'

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt '请输入选择的序号(默认为 1)，按回车键确认'
        if ($InputOption -ieq '' -or $InputOption -ieq '1') {
            Write-Host -Object ''
            return 'zh-CN'
        }
        elseif ($InputOption -ieq '2') {
            Write-Host -Object ''
            return 'en-US'
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
    }
}

function ShowOsVersionSelect {

    Write-Host -Object '============================'
    Write-Host -Object '选择要安装系统的版本，推荐 1'
    Write-Host -Object '============================'
    Write-Host -Object ''
    Write-Host -Object '1: Windows 11'
    Write-Host -Object ''
    Write-Host -Object '2: Windows 10'

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt '请输入选择的序号(默认为 1)，按回车键确认'
        if ($InputOption -ieq '' -or $InputOption -ieq '1') {
            Write-Host -Object ''
            return 11
        }
        elseif ($InputOption -ieq '2') {
            Write-Host -Object ''
            return 10
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
    }
}

function ShowWindowsProductNameSelect {

    Write-Host -Object '============================'
    Write-Host -Object '选择要安装系统的产品，推荐 1'
    Write-Host -Object '============================'
    Write-Host -Object ''
    Write-Host -Object '1: 企业版 Enterprise'
    Write-Host -Object ''
    Write-Host -Object '2: 教育版 Education'
    Write-Host -Object ''
    Write-Host -Object '3: 专业版 Pro'
    Write-Host -Object ''
    Write-Host -Object '4: 专业教育版 Pro Education'
    Write-Host -Object ''
    Write-Host -Object '5: 专业工作站版 Pro For Workstations'
    Write-Host -Object ''
    Write-Host -Object '6: 其他'

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt '请输入选择的序号(默认为 1)，按回车键确认'
        if ($InputOption -ieq '' -or $InputOption -ieq '1') {
            Write-Host -Object ''
            return 'Enterprise'
        }
        elseif ($InputOption -ieq '2') {
            Write-Host -Object ''
            return 'Education'
        }
        elseif ($InputOption -ieq '3') {
            Write-Host -Object ''
            return 'Pro'
        }
        elseif ($InputOption -ieq '4') {
            Write-Host -Object ''
            return 'Pro Education'
        }
        elseif ($InputOption -ieq '5') {
            Write-Host -Object ''
            return 'Pro For Workstations'
        }
        elseif ($InputOption -ieq '6') {
            Write-Host -Object ''
            return ''
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
    }
}

function ShowArchitectureSelect {
    param($OsVersion)

    if ($OsVersion -eq 11) {
        return 'x64'
    }

    Write-Host -Object '============================'
    Write-Host -Object '选择要安装系统的架构，推荐 1'
    Write-Host -Object '============================'
    Write-Host -Object ''
    Write-Host -Object '1: 64 位系统 x64'
    Write-Host -Object ''
    Write-Host -Object '2: 32 位系统 x86'

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt '请输入选择的序号(默认为 1)，按回车键确认'
        if ($InputOption -ieq '' -or $InputOption -ieq '1') {
            Write-Host -Object ''
            return 'x64'
        }
        elseif ($InputOption -ieq '2') {
            Write-Host -Object ''
            return 'x86'
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
    }
}

function ShowDiskIdSelect {

    $SystemDiskId = GetSystemDiskId
    $CurrentDisks = GetCurrentDisk

    Write-Host -Object '================================================'
    Write-Host -Object "选择要安装系统的硬盘编号，推荐当前系统所在硬盘 $SystemDiskId"
    Write-Host -Object '================================================'
    Write-Host -Object ''
    Write-Host -Object '当前系统识别到的硬盘如下：红色字体的硬盘为当前系统所在硬盘，红色字体的分区为当前系统所在分区'

    $CurrentDisks.GetEnumerator() | ForEach-Object {

        $msg = '硬盘编号: ' + $_.Value['DiskNumber'] + ', 硬盘类型: ' + $_.Value['MediaType'] + ', 接口类型: ' `
            + $_.Value['BusType'] + ', 分区类型: ' + $_.Value['PartitionStyle'] + ', 硬盘容量: ' `
            + (FormatSize -Size $_.Value['Size']) + ', 硬盘名称: ' + $_.Value['FriendlyName']

        Write-Host -Object ''
        if ($_.Value['IsBoot']) {
            Write-Host -Object $msg -ForegroundColor Red
        }
        else {
            Write-Host -Object $msg
        }

        $_.Value['Partitions'].GetEnumerator() | ForEach-Object {

            $msg = '  |- 分区编号: ' + $_.Value['PartitionNumber'] + ', 驱动器: ' + $_.Value['DriveLetter'] `
                + ', 是否隐藏: ' + $_.Value['IsHidden'] + ', 文件系统: ' + $_.Value['FileSystem'] + ', 类型: ' `
                + $_.Value['TypeName'] + ', 可用空间: ' + (FormatSize -Size $_.Value['SizeRemaining']) + ', 容量: ' `
                + ( FormatSize -Size $_.Value['Size'])

            Write-Host -Object '  |'
            if ($_.Value['IsBoot']) {
                Write-Host -Object $msg -ForegroundColor Red
            }
            else {
                Write-Host -Object $msg
            }
        }
    }

    while ($true) {
        Write-Host -Object ''
        try {
            [System.Int32]$InputOption = Read-Host `
                -Prompt "请输入选择的硬盘编号(硬盘编号从 0 开始，默认为 $SystemDiskId)，按回车键确认"
            if ($InputOption -ge 0) {
                Write-Host -Object ''
                return $InputOption
            }
            else {
                Write-Host -Object ''
                Write-Warning -Message '输入无效，请重新输入'
            }
        }
        catch {
            Write-Host -Object ''
            Write-Warning -Message '输入无效，请重新输入'
        }
    }
}

function ShowWipeDiskSelect {
    param($DiskId)

    $CurrentDisks = GetCurrentDisk
    $SelectDisk = $CurrentDisks[$DiskId]
    $DefalultSelect = 0

    if ($SelectDisk -and $SelectDisk['PartitionStyle'] -ine 'GPT') {
        Write-Host -Object '=================================='
        Write-Host -Object '选择是否对所选硬盘进行分区，推荐 1'
        Write-Host -Object '=================================='
        $DefalultSelect = 1
    }
    else {
        Write-Host -Object '=================================='
        Write-Host -Object '选择是否对所选硬盘进行分区，推荐 0'
        Write-Host -Object '=================================='
        $DefalultSelect = 0
    }

    Write-Host -Object ''
    Write-Host -Object '0: 否'
    Write-Host -Object ''
    Write-Host -Object '1: GPT 分区，注意：安装系统时会清除所选硬盘的数据，请及时备份所选硬盘的数据' -ForegroundColor Red
    Write-Host -Object ''
    Write-Host -Object '2: MBR 分区，注意：安装系统时会清除所选硬盘的数据，请及时备份所选硬盘的数据' -ForegroundColor Red

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt "请输入选择的序号(默认为 $DefalultSelect)，按回车键确认"
        if ($InputOption -ieq '') {
            Write-Host -Object ''
            return $DefalultSelect
        }
        elseif ('0' -ieq $InputOption) {
            Write-Host -Object ''
            return 0
        }
        elseif ($InputOption -ieq '1') {
            Write-Host -Object ''
            return 1
        }
        elseif ($InputOption -ieq '2') {
            Write-Host -Object ''
            return 2
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
    }
}

function ShowNewPartition {
    param($CreatePartitionInfo)

    Write-Host -Object '所选硬盘重新分区如下：红色字体的分区为系统安装分区'
    Write-Host -Object ''

    $CreatePartitionInfo.GetEnumerator() | ForEach-Object {

        $VolumeSize = '硬盘剩余所有空间'
        if (!$_.Value['Extend']) {
            $VolumeSize = FormatSize -Size $($_.Value['Size'] * 1024 * 1024)
        }

        $msg = '分区编号: ' + $_.Value['Order'] + ', 是否隐藏: ' + $_.Value['IsHidden'] + ', 文件系统: ' `
            + $_.Value['FileSystem'] + ', 类型: ' + $_.Value['TypeName'] + ', 容量: ' + $VolumeSize

        if ($_.Value['IsBoot']) {
            Write-Host -Object $msg -ForegroundColor Red
        }
        else {
            Write-Host -Object $msg
        }
        Write-Host -Object ''
    }
}

function ShowAddNewPartition {

    while ($true) {
        $InputOption = Read-Host -Prompt '是否增加新分区(0: 否, 1: 是)，按回车键确认'
        Write-Host -Object ''
        if ($InputOption -ieq '0') {
            return $false
        }
        elseif ($InputOption -ieq '1') {
            return $true
        }
        else {
            Write-Warning -Message '输入无效，请重新输入'
            Write-Host -Object ''
        }
    }
}

function ShowIsBoot {
    param($CreatePartitionInfo)

    Write-Host -Object '================================================'
    Write-Host -Object '选择要安装系统的分区编号，类型必须为基本数据分区'
    Write-Host -Object '================================================'
    Write-Host -Object ''

    ShowNewPartition -CreatePartitionInfo $CreatePartitionInfo

    while ($true) {
        $InputOption = Read-Host -Prompt '请输入选择的分区编号(分区编号从 1 开始，类型必须为基本数据分区)，按回车键确认'
        $SelectPartition = $CreatePartitionInfo[$InputOption]
        if ($SelectPartition) {
            if ($SelectPartition['Type'] -ieq 'Primary') {
                Write-Host -Object ''
                $SelectPartition['IsBoot'] = $true
                $Script:PartitionId = $SelectPartition['Order']
                return
            }
            else {
                Write-Host -Object ''
                Write-Warning -Message '所选分区非基本数据分区，只能选择基本数据分区，请重新输入'
                Write-Host -Object ''
            }
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '所选分区不存在，请重新输入'
            Write-Host -Object ''
        }
    }
}

function ShowCreatePartition {

    if (1 -eq $script:WipeDisk) {
        $CreatePartitionInfo = [ordered]@{
            '1' = @{
                'Order'      = 1;
                'Size'       = 100;
                'Type'       = 'EFI';
                'TypeName'   = 'EFI 分区';
                'FileSystem' = 'FAT32';
                'Extend'     = $false;
                'IsHidden'   = $true;
                'IsBoot'     = $false
            };
            '2' = @{
                'Order'      = 2;
                'Size'       = 128;
                'Type'       = 'MSR';
                'TypeName'   = '微软保留分区';
                'FileSystem' = '';
                'Extend'     = $false;
                'IsHidden'   = $true;
                'IsBoot'     = $false
            }
        }
        $PartitionNumber = 2
        Write-Host -Object '==============='
        Write-Host -Object '创建新 GPT 分区'
        Write-Host -Object '==============='
        Write-Host -Object ''
    }
    else {
        $CreatePartitionInfo = [ordered]@{}
        $PartitionNumber = 0
        Write-Host -Object '======================================'
        Write-Host -Object '创建新 MBR 分区，最多支持创建 4 个分区'
        Write-Host -Object '======================================'
        Write-Host -Object ''
    }

    ShowNewPartition -CreatePartitionInfo $CreatePartitionInfo

    while ($true) {
        try {
            $PartitionNumber = $PartitionNumber + 1
            [System.Int32]$InputOption = Read-Host `
                -Prompt "输入第 $PartitionNumber 个分区的大小，0 表示占用硬盘所有剩余空间(默认为 0)，单位为 MB，按回车键确认"
            if ($InputOption -eq 0) {
                Write-Host -Object ''
                $CreatePartitionInfo.Add([System.String]$PartitionNumber, @{
                        'Order'      = $PartitionNumber;
                        'Size'       = 0;
                        'Type'       = 'Primary';
                        'TypeName'   = '基本数据分区';
                        'FileSystem' = 'NTFS';
                        'Extend'     = $true;
                        'IsHidden'   = $false;
                        'IsBoot'     = $false
                    })
                ShowNewPartition -CreatePartitionInfo $CreatePartitionInfo
                break
            }
            elseif ($InputOption -gt 0) {
                Write-Host -Object ''
                $CreatePartitionInfo.Add([System.String]$PartitionNumber, @{
                        'Order'      = $PartitionNumber;
                        'Size'       = $InputOption;
                        'Type'       = 'Primary';
                        'TypeName'   = '基本数据分区';
                        'FileSystem' = 'NTFS';
                        'Extend'     = $false;
                        'IsHidden'   = $false;
                        'IsBoot'     = $false
                    })
                ShowNewPartition -CreatePartitionInfo $CreatePartitionInfo
            }
            else {
                $PartitionNumber = $PartitionNumber - 1
                Write-Host -Object ''
                Write-Warning -Message '输入无效，请重新输入'
                Write-Host -Object ''
                continue
            }
            if (2 -eq $script:WipeDisk -and $PartitionNumber -ge 4) {
                $ShowAddNewPartition = $false
            }
            else {
                $ShowAddNewPartition = ShowAddNewPartition
            }
            if (!$ShowAddNewPartition) {
                $CreatePartitionInfo["$PartitionNumber"]['Extend'] = $true
                break
            }
        }
        catch {
            $PartitionNumber = $PartitionNumber - 1
            Write-Host -Object ''
            Write-Warning -Message '输入无效，请重新输入'
            Write-Host -Object ''
        }
    }

    ShowIsBoot -CreatePartitionInfo $CreatePartitionInfo
    ShowNewPartition -CreatePartitionInfo $CreatePartitionInfo
    return $CreatePartitionInfo
}

function ShowPartitionIdSelect {
    param($DiskId)

    $DefalultSelect = GetSystemPartitionId
    $CurrentDisks = GetCurrentDisk
    $SelectDisk = $CurrentDisks[$DiskId]

    if ($SelectDisk) {
        Write-Host -Object '================================================'
        Write-Host -Object "选择要安装系统的分区编号，推荐当前系统所在分区 $DefalultSelect"
        Write-Host -Object '================================================'
        Write-Host -Object ''
        Write-Host -Object '所选硬盘的分区如下：红色字体的分区为当前系统所在分区'

        $SelectDisk['Partitions'].GetEnumerator() | ForEach-Object {

            $msg = '分区编号: ' + $_.Value['PartitionNumber'] + ', 驱动器: ' + $_.Value['DriveLetter'] + ', 是否隐藏: ' `
                + $_.Value['IsHidden'] + ', 文件系统: ' + $_.Value['FileSystem'] + ', 类型: ' + $_.Value['TypeName'] `
                + ', 可用空间: ' + (FormatSize -Size $_.Value['SizeRemaining']) + ', 容量: ' `
                + (FormatSize -Size $_.Value['Size'])

            Write-Host -Object ''
            if ($_.Value['IsBoot']) {
                Write-Host -Object $msg -ForegroundColor Red
            }
            else {
                Write-Host -Object $msg
            }
        }
    }
    else {
        Write-Host -Object '================================'
        Write-Host -Object "选择要安装系统的分区编号，推荐 $DefalultSelect"
        Write-Host -Object '================================'
    }

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt "请输入选择的分区编号(分区编号从 1 开始，默认为 $DefalultSelect)，按回车键确认"
        if ($InputOption -ieq '') {
            Write-Host -Object ''
            return $DefalultSelect
        }
        try {
            [System.Int32]$InputOption1 = [System.Int32]$InputOption
            if ($InputOption1 -eq 0) {
                Write-Host -Object ''
                Write-Warning -Message '输入无效，请重新输入'
                continue
            }
            if ($InputOption1 -ge 1) {
                Write-Host -Object ''
                return $InputOption1
            }
            else {
                Write-Host -Object ''
                Write-Warning -Message '输入无效，请重新输入'
            }
        }
        catch {
            Write-Host -Object ''
            Write-Warning -Message '输入无效，请重新输入'
        }
    }
}

function ShowFomatSelect {

    Write-Host -Object '================================'
    Write-Host -Object '选择是否对所选分区格式化，推荐 2'
    Write-Host -Object '================================'
    Write-Host -Object ''
    Write-Host -Object '1: 否'
    Write-Host -Object ''
    Write-Host -Object '2: 是，注意：安装系统时会清除所选分区的数据，请及时备份所选分区的数据' -ForegroundColor Red

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt '请输入选择的序号(默认为 2)，按回车键确认'
        if ($InputOption -ieq '' -or $InputOption -ieq '2') {
            Write-Host -Object ''
            return $true
        }
        elseif ($InputOption -ieq '1') {
            Write-Host -Object ''
            return $false
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
    }
}

function ShowPartitionStyleSelect {
    param($DiskId)

    $CurrentDisks = GetCurrentDisk
    $SelectDisk = $CurrentDisks[$DiskId]
    $DefalultSelect = 1
    $DefaultPartitionStyle = 'GPT'
    if ($SelectDisk -and $SelectDisk['PartitionStyle'] -ine 'GPT') {
        $DefalultSelect = 2
        $DefaultPartitionStyle = 'MBR'
    }

    Write-Host -Object '===================================='
    Write-Host -Object "请确认所选硬盘分区的分区类型，推荐 $DefalultSelect"
    Write-Host -Object '===================================='
    Write-Host -Object ''
    Write-Host -Object '1: GPT 分区'
    Write-Host -Object ''
    Write-Host -Object '2: MBR 分区'

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host -Prompt "请输入选择的序号(默认为 $DefalultSelect)，按回车键确认"
        if ($InputOption -ieq '') {
            Write-Host -Object ''
            return $DefaultPartitionStyle
        }
        if ($InputOption -ieq '1') {
            Write-Host -Object ''
            return 'GPT'
        }
        elseif ($InputOption -ieq '2') {
            Write-Host -Object ''
            return 'MBR'
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
    }
}

function ShowNameInput {

    Write-Host -Object '=================================================='
    Write-Host -Object '输入系统安装后的登录账号名，账号名建议符合如下要求'
    Write-Host -Object '=================================================='
    Write-Host -Object ''
    Write-Host -Object '1: 推荐英文字母或数字的组合，尽量不使用特殊字符'
    Write-Host -Object ''
    Write-Host -Object '2: 尽量不使用中文，防止某些应用软件不支持中文而无法使用'
    Write-Host -Object ''

    $InputOption = Read-Host -Prompt '请输入登录账号名(默认为 MyPC)，按回车键确认'
    if ($InputOption -ieq '') {
        Write-Host -Object ''
        return 'MyPC'
    }
    else {
        Write-Host -Object ''
        return $InputOption
    }
}

function ShowVentoyDriverLetterSelect {

    $CurrentDisks = GetCurrentDisk

    Write-Host -Object '==============================='
    Write-Host -Object '输入已安装 Ventoy 的 U 盘驱动器'
    Write-Host -Object '==============================='
    Write-Host -Object ''
    Write-Host -Object '当前系统识别到的驱动器如下：'

    $CurrentDisks.GetEnumerator() | ForEach-Object {

        $msg = '硬盘类型: ' + $_.Value['MediaType'] + ', 接口类型: ' + $_.Value['BusType'] + ', 分区类型: ' `
            + $_.Value['PartitionStyle'] + ', 硬盘容量: ' + (FormatSize -Size $_.Value['Size']) + ', 硬盘名称: ' `
            + $_.Value['FriendlyName']

        Write-Host -Object ''
        Write-Host -Object $msg
        $_.Value['Partitions'].GetEnumerator() | ForEach-Object {
            if ($_.Value['DriveLetter']) {
                $msg = '  |- 驱动器: ' + $_.Value['DriveLetter'] + ', 文件系统: ' + $_.Value['FileSystem'] `
                    + ', 可用空间: ' + (FormatSize -Size $_.Value['SizeRemaining']) + ', 容量: ' `
                    + (FormatSize -Size $_.Value['Size'])
                Write-Host -Object '  |'
                Write-Host -Object $msg
            }
        }
    }

    while ($true) {
        Write-Host -Object ''
        $InputOption = Read-Host `
            -Prompt '请输入已安装 Ventoy 的 U 盘驱动器(0 表示将应答文件保存到当前用户的桌面上)，按回车键确认'
        if ($InputOption -ieq '') {
            Write-Host -Object ''
            Write-Warning -Message '选择无效，请重新输入'
        }
        elseif ($InputOption -ieq '0') {
            Write-Host -Object ''
            return ''
        }
        elseif (Test-Path -Path $InputOption -PathType Container) {
            Write-Host -Object ''
            return $InputOption
        }
        elseif (Test-Path -Path $($InputOption + ':\') -PathType Container) {
            Write-Host -Object ''
            return $($InputOption + ':\')
        }
        else {
            Write-Host -Object ''
            Write-Warning -Message '驱动器不存在，请重新输入'
        }
    }
}

function ShowGetISOPath {
    param($Path)

    Write-Host -Object '==============================='
    Write-Host -Object '选择使用应答文件的 ISO 镜像文件'
    Write-Host -Object '==============================='
    Write-Host -Object ''
    Write-Host -Object '搜索 ISO 镜像文件中......'

    $ISOFiles = [ordered]@{}
    $Index = 0;
    try {
        Get-ChildItem -Path $Path -Include '*.iso' -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $Index = $Index + 1
            $ISOFiles.Add([System.String]$Index, $_.FullName)
        }
    }
    catch {
        $msg = $Path + ' 无权限'
        Write-Warning -Message $msg
    }

    if ($ISOFiles.Count -gt 0) {
        Write-Host -Object ''
        Write-Host -Object '搜索到的镜像文件如下：'
        $ISOFiles.GetEnumerator() | ForEach-Object {
            Write-Host -Object ''
            $msg = '镜像文件序号: ' + $_.Key + ', 镜像文件路径: ' + $_.Value
            Write-Host -Object $msg
        }
        while ($true) {
            Write-Host -Object ''
            $InputOption = Read-Host -Prompt '请输入使用应答文件的 ISO 镜像文件序号，按回车键确认'
            $ISOFile = $ISOFiles[$InputOption]
            if ($ISOFile) {
                Write-Host -Object ''
                return $ISOFile
            }
            else {
                Write-Host -Object ''
                Write-Warning -Message '镜像文件序号不存在，请重新输入'
            }
        }
    }
    else {
        Write-Host -Object ''
        Write-Host -Object '未搜索到 ISO 镜像文件'
        Write-Host -Object ''
        return ''
    }
}

function UpdateVentoyConfig {
    param(
        $ISOPath,
        $UnattendPath,
        $VentoyConfigParentPath
    )

    if (!$ISOPath) {
        return
    }
    if (!$UnattendPath) {
        return
    }
    if (!$VentoyConfigParentPath) {
        return
    }

    $ISOPath = Split-Path -Path $ISOPath -NoQualifier
    $ISOPath = $ISOPath.Replace('\', '/')

    $UnattendPath = Split-Path -Path $UnattendPath -NoQualifier
    $UnattendPath = $UnattendPath.Replace('\', '/')

    $VentoyConfigJsonPath = Join-Path -Path $VentoyConfigParentPath -ChildPath 'ventoy.json'

    $JSONContent = $null
    if (Test-Path -Path $VentoyConfigJsonPath -PathType Leaf) {
        try {
            $JSONContent = Get-Content -Path $VentoyConfigJsonPath | ConvertFrom-Json
        }
        catch {
            $msg = $VentoyConfigJsonPath + ' 解析失败'
            Write-Warning -Message $msg
        }
    }

    if (!$JSONContent -or !($JSONContent -is [PSCustomObject])) {
        $JSONContent = [PSCustomObject]@{
            'control'      = @(@{
                    'VTOY_WIN11_BYPASS_CHECK' = '1'
                });
            'auto_install' = @(@{
                    'image'    = $ISOPath;
                    'template' = $UnattendPath
                })
        }

        $JSONString = $JSONContent | ConvertTo-Json
        $Utf8NoBomEncoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllLines($VentoyConfigJsonPath, $JSONString, $Utf8NoBomEncoding)
        return
    }

    $Controls = $JSONContent.'control'
    if ($null -eq $Controls -or !($Controls -is [System.Array])) {
        Add-Member -InputObject $JSONContent -Force `
            -NotePropertyMembers @{ 'control' = @(@{ 'VTOY_WIN11_BYPASS_CHECK' = '1' }) }
    }
    else {
        $AddFlag = $false
        foreach ($Control in $Controls) {
            if ($null -eq $Control) {
                $AddFlag = $true
                Add-Member -InputObject $Control -Force -NotePropertyMembers @{ 'VTOY_WIN11_BYPASS_CHECK' = '1' }
                break
            }
            $Check = $Control.'VTOY_WIN11_BYPASS_CHECK'
            if ($null -eq $Check) {
                continue
            }
            $AddFlag = $true
            Add-Member -InputObject $Control -Force -NotePropertyMembers @{ 'VTOY_WIN11_BYPASS_CHECK' = '1' }
            break
        }
        if (!$AddFlag) {
            $Controls += [PSCustomObject]@{ 'VTOY_WIN11_BYPASS_CHECK' = '1' }
            $JSONContent.'control' = $Controls
        }
    }

    $Installs = $JSONContent.'auto_install'
    if ($null -eq $Installs -or !($Installs -is [System.Array])) {
        Add-Member -InputObject $JSONContent -Force `
            -NotePropertyMembers @{ 'auto_install' = @(@{ 'image' = $ISOPath; 'template' = $UnattendPath }) }
    }
    else {
        $AddFlag = $false
        foreach ($Install in $Installs) {
            if ($null -eq $Install) {
                Add-Member -InputObject $Install -Force `
                    -NotePropertyMembers @{ 'image' = $ISOPath; 'template' = $UnattendPath }
                $AddFlag = $true
                break
            }
            $Image = $Install.'image'
            if ($null -eq $Image) {
                Add-Member -InputObject $Install -Force `
                    -NotePropertyMembers @{ 'image' = $ISOPath; 'template' = $UnattendPath }
                $AddFlag = $true
                break
            }
            if ($Image -ne $ISOPath) {
                continue
            }
            Add-Member -InputObject $Install -Force `
                -NotePropertyMembers @{ 'image' = $ISOPath; 'template' = $UnattendPath }
            $AddFlag = $true
            break
        }
        if (!$AddFlag) {
            $Installs += [PSCustomObject]@{ 'image' = $ISOPath; 'template' = $UnattendPath }
            $JSONContent.'auto_install' = $Installs
        }
    }

    $JSONString = $JSONContent | ConvertTo-Json
    $Utf8NoBomEncoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllLines($VentoyConfigJsonPath, $JSONString, $Utf8NoBomEncoding)
}

function GetVertion {
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

    return $Version
}

$VersionInfo = GetVertion

if ($Version) {
    return $VersionInfo
}

Clear-Host
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$Host.UI.RawUI.WindowTitle = 'Windows 应答文件生成'
Set-Location -Path $PSScriptRoot
Write-Host -Object "=====> Windows 系统自动安装应答文件生成 v$VersionInfo <====="
Write-Host -Object ''

$WipeDisk = 0
$Token = '31bf3856ad364e35'
$WindowsProduct = [ordered]@{
    'Enterprise'           = @{
        'CN'          = '企业版';
        'US'          = 'Enterprise';
        'NoSpaceName' = 'Enterprise';
        'gvlk'        = 'NPPR9-FWDCX-D2C8J-H872K-2YT43'
    };
    'Education'            = @{
        'CN'          = '教育版';
        'US'          = 'Education';
        'NoSpaceName' = 'Education';
        'gvlk'        = '6TP4R-GNPTD-KYYHQ-7B7DP-J447Y'
    };
    'Pro'                  = @{
        'CN'          = '专业版';
        'US'          = 'Pro';
        'NoSpaceName' = 'Pro';
        'gvlk'        = 'W269N-WFGWX-YVC9B-4J6C9-T83GX'
    };
    'Pro Education'        = @{
        'CN'          = '专业教育版';
        'US'          = 'Pro Education';
        'NoSpaceName' = 'Pro_Education';
        'gvlk'        = '6TP4R-GNPTD-KYYHQ-7B7DP-J447Y'
    };
    'Pro For Workstations' = @{
        'CN'          = '专业工作站版';
        'US'          = 'Pro For Workstations';
        'NoSpaceName' = 'Pro_For_Workstations';
        'gvlk'        = 'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J'
    }
}

$CurrentDisks = GetCurrentDisk

if ($Interactive) {
    $Language = ShowLanguageSelect
    $OsVersion = ShowOsVersionSelect
    $WindowsProductName = ShowWindowsProductNameSelect
    $Architecture = ShowArchitectureSelect -OsVersion $OsVersion
    $DiskId = ShowDiskIdSelect
    $WipeDisk = ShowWipeDiskSelect -DiskId $DiskId
    if (1 -eq $WipeDisk -or 2 -eq $WipeDisk) {
        $CreatePartitionInfo = ShowCreatePartition
    }
    else {
        $PartitionId = ShowPartitionIdSelect -DiskId $DiskId
        $NotFormat = !$(ShowFomatSelect)
        if (!$NotFormat) {
            $PartitionStyle = ShowPartitionStyleSelect -DiskId $DiskId
        }
    }
    $FullName = ShowNameInput
    $VentoyDriverLetter = ShowVentoyDriverLetterSelect
    if ($VentoyDriverLetter) {
        $ISOPath = ShowGetISOPath -Path $VentoyDriverLetter
    }
}

if ($Language -ine 'zh-CN' -and $Language -ine 'en-US') {
    Write-Warning -Message '参数 Language 只支持 zh-CN (简体中文), en-US (英文)'
    [System.Environment]::Exit(0)
}
if ($Language -ieq 'zh-CN') {
    $Language = 'zh-CN'
}
elseif ($Language -ieq 'en-US') {
    $Language = 'en-US'
}

if ($OsVersion -ne 10 -and $OsVersion -ne 11) {
    Write-Warning -Message '参数 OsVersion 只支持 10 (Windows 10), 11 (Windows 11)'
    [System.Environment]::Exit(0)
}

if ($WindowsProductName -and !$WindowsProduct.Contains($WindowsProductName)) {
    $WindowsProductNameArray = @($WindowsProduct.GetEnumerator() | ForEach-Object {
            $_.Value['US'] + ' (' + $_.Value['CN'] + ')'
        })
    $AllSupportProductName = [string]::join(', ', $WindowsProductNameArray)
    Write-Warning -Message "参数 WindowsProductName 只支持 $AllSupportProductName"
    [System.Environment]::Exit(0)
}

if ($OsVersion -eq 10) {
    if ($Architecture -ne 'x64' -and $Architecture -ne 'x86') {
        Write-Warning -Message '参数 OsVersion 为 Windows 10 时，参数 Architecture 只支持 x64 (64 位系统), x86 (32 位系统)'
        [System.Environment]::Exit(0)
    }
}
if ($OsVersion -eq 11) {
    if ($Architecture -ine 'x64') {
        Write-Warning -Message '参数 OsVersion 为 Windows 11 时，参数 Architecture 只支持 x64 (64 位系统)'
        [System.Environment]::Exit(0)
    }
}

$ArchitectureName = 'amd64'
if ($Architecture -eq 'x86') {
    $ArchitectureName = 'x86'
}

if ($DiskId -eq -1) {
    $DiskId = GetSystemDiskId
}

if ($PartitionId -eq -1) {
    $PartitionId = GetSystemPartitionId
}

if ($PartitionStyle -ine 'GPT' -and $PartitionStyle -ine 'MBR') {
    Write-Warning -Message '参数 PartitionStyle 只支持 GPT, MBR'
    [System.Environment]::Exit(0)
}
if ($PartitionStyle -ieq 'GPT') {
    $PartitionStyle = 'GPT'
}
elseif ($PartitionStyle -ieq 'MBR') {
    $PartitionStyle = 'MBR'
}

if ('' -ieq $VentoyDriverLetter) {
    $ParentPath = GetDefaultFolderPath
}
else {
    $ParentPath = $VentoyDriverLetter
    if ($ISOPath) {
        $Letter1 = Split-Path -Path $ISOPath -Qualifier
        $Letter2 = Split-Path -Path $ISOPath -Qualifier
        if ($Letter1 -ine $Letter2) {
            Write-Warning -Message '参数 ISOPath 指定的路径必须和参数 VentoyDriverLetter 指定的驱动器属于同一个驱动器'
            [System.Environment]::Exit(0)
        }
    }
}

$VentoyConfigParentPath = Join-Path -Path $ParentPath -ChildPath 'ventoy'
if (!$(Test-Path -Path $VentoyConfigParentPath -PathType Container)) {
    New-Item -Path $VentoyConfigParentPath -ItemType Directory -Force | Out-Null
}
$VentoyConfigScriptPath = Join-Path -Path $VentoyConfigParentPath -ChildPath 'script'
if (!$(Test-Path -Path $VentoyConfigScriptPath -PathType Container)) {
    New-Item -Path $VentoyConfigScriptPath -ItemType Directory -Force | Out-Null
}

$DiskTypeStr = ''
if ($WipeDisk -eq 1) {
    $DiskTypeStr = '_CreateGPT'
}
elseif ($WipeDisk -eq 2) {
    $DiskTypeStr = '_CreateMBR'
}
elseif (!$NotFormat) {
    $DiskTypeStr = "_Format$PartitionStyle"
}
$ProductInfo = @{}
if ('' -ieq $WindowsProductName) {
    $UnattendPath = $VentoyConfigScriptPath + '\Unattend_Windows_' + $OsVersion + '_' + $Architecture + '_' `
        + $Language + $DiskTypeStr + '_' + $FullName + '.xml'
}
else {
    $ProductInfo = $WindowsProduct[$WindowsProductName]
    $NoSpaceName = $ProductInfo['NoSpaceName']
    $UnattendPath = $VentoyConfigScriptPath + '\Unattend_Windows_' + $OsVersion + '_' + $NoSpaceName + '_' `
        + $Architecture + '_' + $Language + $DiskTypeStr + '_' + $FullName + '.xml'
}

UpdateVentoyConfig -ISOPath $ISOPath -UnattendPath $UnattendPath -VentoyConfigParentPath $VentoyConfigParentPath

if (Test-Path -Path $UnattendPath -PathType Leaf) {
    Remove-Item -Path $UnattendPath -Force
}
Add-Content -Path $UnattendPath -Value '<?xml version="1.0" encoding="utf-8"?>'
Add-Content -Path $UnattendPath -Value '<unattend xmlns="urn:schemas-microsoft-com:unattend">'
Add-Content -Path $UnattendPath -Value '    <settings pass="windowsPE">'
Add-Content -Path $UnattendPath -Value ("        <component name=`"Microsoft-Windows-International-Core-WinPE`"" `
        + " processorArchitecture=`"$ArchitectureName`" publicKeyToken=`"$Token`" language=`"neutral`"" `
        + " versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`"" `
        + " xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">")
Add-Content -Path $UnattendPath -Value '            <SetupUILanguage>'
Add-Content -Path $UnattendPath -Value "                <UILanguage>$Language</UILanguage>"
Add-Content -Path $UnattendPath -Value '            </SetupUILanguage>'
Add-Content -Path $UnattendPath -Value "            <InputLocale>$Language</InputLocale>"
Add-Content -Path $UnattendPath -Value "            <UILanguage>$Language</UILanguage>"
Add-Content -Path $UnattendPath -Value "            <SystemLocale>$Language</SystemLocale>"
Add-Content -Path $UnattendPath -Value "            <UserLocale>$Language</UserLocale>"
Add-Content -Path $UnattendPath -Value "            <UILanguageFallback>$Language</UILanguageFallback>"
Add-Content -Path $UnattendPath -Value '        </component>'
Add-Content -Path $UnattendPath -Value ''
Add-Content -Path $UnattendPath -Value ("        <component name=`"Microsoft-Windows-Setup`"" `
        + " processorArchitecture=`"$ArchitectureName`" publicKeyToken=`"$Token`" language=`"neutral`"" `
        + " versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`"" `
        + " xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">")
Add-Content -Path $UnattendPath -Value '            <EnableNetwork>false</EnableNetwork>'
Add-Content -Path $UnattendPath -Value ''
Add-Content -Path $UnattendPath -Value '            <UserData>'
Add-Content -Path $UnattendPath -Value '                <AcceptEula>true</AcceptEula>'
if ($FullName) {
    Add-Content -Path $UnattendPath -Value "                <FullName>$FullName</FullName>"
}
if ($WindowsProductName) {
    $key = $ProductInfo['gvlk']
    Add-Content -Path $UnattendPath -Value '                <ProductKey>'
    Add-Content -Path $UnattendPath -Value "                    <Key>$key</Key>"
    Add-Content -Path $UnattendPath -Value '                </ProductKey>'
}
Add-Content -Path $UnattendPath -Value '            </UserData>'
Add-Content -Path $UnattendPath -Value ''
if ($WipeDisk -ne 0) {
    Add-Content -Path $UnattendPath -Value '            <DiskConfiguration>'
    Add-Content -Path $UnattendPath -Value '                <Disk wcm:action="add">'
    Add-Content -Path $UnattendPath -Value "                    <DiskID>$DiskId</DiskID>"
    Add-Content -Path $UnattendPath -Value ''
    Add-Content -Path $UnattendPath -Value '                    <WillWipeDisk>true</WillWipeDisk>'
    Add-Content -Path $UnattendPath -Value ''
    Add-Content -Path $UnattendPath -Value '                    <CreatePartitions>'
    $CreatePartitionInfo.GetEnumerator() | ForEach-Object {
        Add-Content -Path $UnattendPath -Value '                        <CreatePartition wcm:action="add">'
        if ($_.Value['Extend']) {
            Add-Content -Path $UnattendPath -Value '                            <Extend>true</Extend>'
        }
        else {
            $Size = $_.Value['Size']
            Add-Content -Path $UnattendPath -Value "                            <Size>$Size</Size>"
        }
        $Order = $_.Value['Order']
        Add-Content -Path $UnattendPath -Value "                            <Order>$Order</Order>"
        $Type = $_.Value['Type']
        Add-Content -Path $UnattendPath -Value "                            <Type>$Type</Type>"
        Add-Content -Path $UnattendPath -Value '                        </CreatePartition>'
    }
    Add-Content -Path $UnattendPath -Value '                    </CreatePartitions>'
    Add-Content -Path $UnattendPath -Value ''
    Add-Content -Path $UnattendPath -Value '                    <ModifyPartitions>'
    $CreatePartitionInfo.GetEnumerator() | ForEach-Object {
        Add-Content -Path $UnattendPath -Value '                        <ModifyPartition wcm:action="add">'
        if ($WipeDisk -eq 2 -and $_.Value['IsBoot']) {
            Add-Content -Path $UnattendPath -Value '                            <Active>true</Active>'
        }
        $Format = $_.Value['FileSystem']
        if ($Format) {
            Add-Content -Path $UnattendPath -Value "                            <Format>$Format</Format>"
        }
        $Order = $_.Value['Order']
        Add-Content -Path $UnattendPath -Value "                            <Order>$Order</Order>"
        Add-Content -Path $UnattendPath -Value "                            <PartitionID>$Order</PartitionID>"
        Add-Content -Path $UnattendPath -Value '                        </ModifyPartition>'
    }
    Add-Content -Path $UnattendPath -Value '                    </ModifyPartitions>'
    Add-Content -Path $UnattendPath -Value '                </Disk>'
    Add-Content -Path $UnattendPath -Value '            </DiskConfiguration>'
    Add-Content -Path $UnattendPath -Value ''
}
elseif (!$NotFormat) {
    Add-Content -Path $UnattendPath -Value '            <DiskConfiguration>'
    Add-Content -Path $UnattendPath -Value '                <Disk wcm:action="add">'
    Add-Content -Path $UnattendPath -Value "                    <DiskID>$DiskId</DiskID>"
    Add-Content -Path $UnattendPath -Value ''
    Add-Content -Path $UnattendPath -Value '                    <ModifyPartitions>'
    Add-Content -Path $UnattendPath -Value '                        <ModifyPartition wcm:action="add">'
    if ($PartitionStyle -ieq 'MBR') {
        Add-Content -Path $UnattendPath -Value '                            <Active>true</Active>'
    }
    Add-Content -Path $UnattendPath -Value '                            <Format>NTFS</Format>'
    Add-Content -Path $UnattendPath -Value '                            <Order>1</Order>'
    Add-Content -Path $UnattendPath -Value "                            <PartitionID>$PartitionId</PartitionID>"
    Add-Content -Path $UnattendPath -Value '                        </ModifyPartition>'
    Add-Content -Path $UnattendPath -Value '                    </ModifyPartitions>'
    Add-Content -Path $UnattendPath -Value '                </Disk>'
    Add-Content -Path $UnattendPath -Value '            </DiskConfiguration>'
    Add-Content -Path $UnattendPath -Value ''
}
Add-Content -Path $UnattendPath -Value '            <ImageInstall>'
Add-Content -Path $UnattendPath -Value '                <OSImage>'
if ($WindowsProductName) {
    $ImageName = 'Windows ' + $OsVersion + ' ' + $ProductInfo['US']
    Add-Content -Path $UnattendPath -Value '                    <InstallFrom>'
    Add-Content -Path $UnattendPath -Value '                        <MetaData wcm:action="add">'
    Add-Content -Path $UnattendPath -Value '                            <Key>/IMAGE/NAME</Key>'
    Add-Content -Path $UnattendPath -Value "                            <Value>$ImageName</Value>"
    Add-Content -Path $UnattendPath -Value '                        </MetaData>'
    Add-Content -Path $UnattendPath -Value '                    </InstallFrom>'
    Add-Content -Path $UnattendPath -Value ''
}

Add-Content -Path $UnattendPath -Value '                    <InstallTo>'
Add-Content -Path $UnattendPath -Value "                        <DiskID>$DiskId</DiskID>"
Add-Content -Path $UnattendPath -Value "                        <PartitionID>$PartitionId</PartitionID>"
Add-Content -Path $UnattendPath -Value '                    </InstallTo>'
Add-Content -Path $UnattendPath -Value '                </OSImage>'
Add-Content -Path $UnattendPath -Value '            </ImageInstall>'
Add-Content -Path $UnattendPath -Value '        </component>'
Add-Content -Path $UnattendPath -Value '    </settings>'
Add-Content -Path $UnattendPath -Value ''
Add-Content -Path $UnattendPath -Value '    <settings pass="specialize">'
Add-Content -Path $UnattendPath -Value ("        <component name=`"Microsoft-Windows-Security-SPP-UX`"" `
        + " processorArchitecture=`"$ArchitectureName`" publicKeyToken=`"$Token`" language=`"neutral`"" `
        + " versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`"" `
        + " xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">")
Add-Content -Path $UnattendPath -Value '            <SkipAutoActivation>true</SkipAutoActivation>'
Add-Content -Path $UnattendPath -Value '        </component>'
Add-Content -Path $UnattendPath -Value ''
Add-Content -Path $UnattendPath -Value ("        <component name=`"Microsoft-Windows-SQMApi`"" `
        + " processorArchitecture=`"$ArchitectureName`" publicKeyToken=`"$Token`" language=`"neutral`"" `
        + " versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`"" `
        + " xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">")
Add-Content -Path $UnattendPath -Value '            <CEIPEnabled>0</CEIPEnabled>'
Add-Content -Path $UnattendPath -Value '        </component>'
if ($WindowsProductName) {
    $key = $ProductInfo['gvlk']
    Add-Content -Path $UnattendPath -Value ''
    Add-Content -Path $UnattendPath -Value ("        <component name=`"Microsoft-Windows-Shell-Setup`"" `
            + " processorArchitecture=`"$ArchitectureName`" publicKeyToken=`"$Token`" language=`"neutral`"" `
            + " versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`"" `
            + " xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">")
    Add-Content -Path $UnattendPath -Value "            <ProductKey>$key</ProductKey>"
    Add-Content -Path $UnattendPath -Value '        </component>'
}
Add-Content -Path $UnattendPath -Value '    </settings>'
Add-Content -Path $UnattendPath -Value ''
Add-Content -Path $UnattendPath -Value '    <settings pass="oobeSystem">'
Add-Content -Path $UnattendPath -Value ("        <component name=`"Microsoft-Windows-International-Core`"" `
        + " processorArchitecture=`"$ArchitectureName`" publicKeyToken=`"$Token`" language=`"neutral`"" `
        + " versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`"" `
        + " xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">")
Add-Content -Path $UnattendPath -Value "            <InputLocale>$Language</InputLocale>"
Add-Content -Path $UnattendPath -Value "            <UILanguage>$Language</UILanguage>"
Add-Content -Path $UnattendPath -Value "            <SystemLocale>$Language</SystemLocale>"
Add-Content -Path $UnattendPath -Value "            <UserLocale>$Language</UserLocale>"
Add-Content -Path $UnattendPath -Value "            <UILanguageFallback>$Language</UILanguageFallback>"
Add-Content -Path $UnattendPath -Value '        </component>'
Add-Content -Path $UnattendPath -Value ''
Add-Content -Path $UnattendPath -Value ("        <component name=`"Microsoft-Windows-Shell-Setup`"" `
        + " processorArchitecture=`"$ArchitectureName`" publicKeyToken=`"$Token`" language=`"neutral`"" `
        + " versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`"" `
        + " xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">")
if ($FullName) {
    Add-Content -Path $UnattendPath -Value '            <AutoLogon>'
    Add-Content -Path $UnattendPath -Value '                <Password>'
    Add-Content -Path $UnattendPath -Value '                    <Value/>'
    Add-Content -Path $UnattendPath -Value '                    <PlainText>true</PlainText>'
    Add-Content -Path $UnattendPath -Value '                </Password>'
    Add-Content -Path $UnattendPath -Value '                <Enabled>true</Enabled>'
    Add-Content -Path $UnattendPath -Value "                <Username>$FullName</Username>"
    Add-Content -Path $UnattendPath -Value '            </AutoLogon>'
    Add-Content -Path $UnattendPath -Value ''
    Add-Content -Path $UnattendPath -Value '            <UserAccounts>'
    Add-Content -Path $UnattendPath -Value '                <LocalAccounts>'
    Add-Content -Path $UnattendPath -Value '                    <LocalAccount wcm:action="add">'
    Add-Content -Path $UnattendPath -Value '                        <Password>'
    Add-Content -Path $UnattendPath -Value '                            <Value/>'
    Add-Content -Path $UnattendPath -Value '                            <PlainText>true</PlainText>'
    Add-Content -Path $UnattendPath -Value '                        </Password>'
    Add-Content -Path $UnattendPath -Value "                        <DisplayName>$FullName</DisplayName>"
    Add-Content -Path $UnattendPath -Value '                        <Group>Administrators</Group>'
    Add-Content -Path $UnattendPath -Value "                        <Name>$FullName</Name>"
    Add-Content -Path $UnattendPath -Value '                    </LocalAccount>'
    Add-Content -Path $UnattendPath -Value '                </LocalAccounts>'
    Add-Content -Path $UnattendPath -Value '            </UserAccounts>'
    Add-Content -Path $UnattendPath -Value ''
    Add-Content -Path $UnattendPath -Value "            <RegisteredOwner>$FullName</RegisteredOwner>"
    Add-Content -Path $UnattendPath -Value ''
}
Add-Content -Path $UnattendPath -Value '            <OOBE>'
Add-Content -Path $UnattendPath -Value '                <HideEULAPage>true</HideEULAPage>'
Add-Content -Path $UnattendPath -Value '                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>'
Add-Content -Path $UnattendPath -Value '                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>'
Add-Content -Path $UnattendPath -Value '                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>'
Add-Content -Path $UnattendPath -Value '                <HideLocalAccountScreen>true</HideLocalAccountScreen>'
Add-Content -Path $UnattendPath -Value '                <ProtectYourPC>3</ProtectYourPC>'
Add-Content -Path $UnattendPath -Value '            </OOBE>'
Add-Content -Path $UnattendPath -Value '        </component>'
Add-Content -Path $UnattendPath -Value '    </settings>'
Add-Content -Path $UnattendPath -Value '</unattend>'

Write-Host -Object ('生成的应答文件位置: ' + $UnattendPath)
Write-Host -Object ''
Read-Host -Prompt '按回车键关闭此窗口'

