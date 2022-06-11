# UnattendTool 简介

* 生成 Windows 系统自动安装应答文件 Unattend.xml
* 可搭配 Ventoy 一起使用：https://github.com/ventoy/Ventoy
* 只支持 Windows 10 或 Windows 11

# 下载

从如下链接下载最新的版本：`UnattendTool_版本号.zip`

> https://github.com/dsx42/UnattendTool/releases

# 使用

解压，鼠标左键双击运行解压后的 `UnattendTool.cmd` 文件，根据提示操作即可

# 支持的选项

`UnattendTool.ps1` 支持非交互式运行

```powershell
.\UnattendTool.ps1 -Version
```

```powershell
.\UnattendTool.ps1 -Interactive
```

```powershell
.\UnattendTool.ps1
    [-Language String]
    [-OsVersion int]
    [-WindowsProductName String]
    [-Architecture String]
    [-DiskId int]
    [-PartitionID int]
    [-FullName String]
    [-VentoyDriverLetter String]
    [-ISOPath String]
    [-NotFormat]
```

* `-Version`：返回当前工具的版本号
* `-Interactive`：交互模式运行，作用和鼠标左键双击运行 `UnattendTool.cmd` 文件一样的效果
* `-Language String`：要安装系统的语言，只支持如下两个值：
    * `'zh-CN'`：简体中文；默认值
    * `'en-US'`：英文
* `-OsVersion int`：要安装系统的版本，只支持如下两个值：
    * `11`：Windows 11；默认值
    * `10`：Windows 10
* `-WindowsProductName String`：要安装系统的产品，支持如下值：
    * `'Enterprise'`：企业版；默认值
    * `'Education'`：教育版
    * `'Pro'`：专业版
    * `'Pro Education'`：专业教育版
    * `'Pro For Workstations'`：专业工作站版
    * `''`：空字符串，表示非上述的其他版本
* `-Architecture String`：要安装系统的架构，只支持如下两个值：
    * `'x64'`：64 位系统；默认值
    * `'x86'`：32 位系统；注意，Windows 11 只有 64 位系统
* `-DiskId int`：要安装系统的硬盘编号，硬盘编号从 0 开始；默认为 -1，表示自动选择当前操作系统所在的硬盘
* `-PartitionID int`：要安装系统的分区编号，分区编号从 1 开始；默认为 -1，表示自动选择当前操作系统所在的分区
* `-FullName String`：系统安装后的登录账号名；推荐英文字母或数字的组合，尽量不使用中文或其他特殊字符；默认为 `'MyPC'`
* `-VentoyDriverLetter String`：已安装 Ventoy 的 U 盘驱动器；默认为当前用户的桌面
* `-ISOPath String`：使用应答文件的 ISO 镜像文件的路径；默认未指定
* `-NotFormat`：安装系统时不格式化所选硬盘分区；默认安装时会格式化所选硬盘分区
