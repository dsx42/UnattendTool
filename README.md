# UnattendTool 简介

* 生成 Windows 系统自动安装应答文件 Unattend.xml
* 支持 Ventoy
* 只支持 Windows 10 或 Windows 11

# 下载

从如下链接下载最新的版本：`UnattendTool_版本号.zip`

> https://github.com/dsx42/UnattendTool/releases

# 如何使用本工具？

有如下两种使用场景：

## 当前电脑要安装系统

* 在当前电脑安装系统前，把下载的文件解压到当前电脑
* 鼠标左键双击运行解压后的 `UnattendTool.cmd` 文件，根据提示操作
    * 提示包含当前电脑的信息，可以直接参考

## 其他电脑要安装系统

* 把下载的文件解压到当前电脑
* 鼠标左键双击运行解压后的 `UnattendTool.cmd` 文件，根据提示操作
    * 提示包含当前电脑的信息，不是将要安装系统的电脑信息，不可以作为参考
    * 必须了解要安装系统的电脑信息，并合理设置

# 生成的应答文件在哪里？

* 默认情况下，在 `%userprofile%\Desktop\ventoy\script\` 目录下
* 若指定了应答文件目录，则在指定目录下的 `ventoy\script\` 目录下

# 生成的应答文件如何使用？

## 和 Venoty 一起使用

* 准备一个 U 盘，用 Ventoy 处理，详见：https://www.ventoy.net/cn/doc_start.html
* 把应答文件复制到 U 盘
* 修改 U 盘下的 Ventoy 配置文件 `ventoy\ventoy.json`，详见：https://www.ventoy.net/cn/plugin_autoinstall.html
* U 盘插入要安装系统的电脑，该电脑关机，进入 BIOS，修改为启动进入 U 盘
* 进入 Ventoy 选择镜像的页面，选择要安装的镜像，选择要使用的应答文件

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
    [-PartitionStyle String]
    [-FullName String]
    [-Password String]
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
* `-PartitionStyle String`：未指定 `-NotFormat` 时，需要指定该参数，表示要安装系统的硬盘的分区类型，只支持如下两个值：
    * `GPT`：GPT 分区；默认值
    * `MBR`：MBR 分区
* `-FullName String`：系统安装后的登录账号名；推荐英文字母或数字的组合，尽量不使用中文或其他特殊字符；默认为 `'MyPC'`
* `-Password String`：系统安装后的登录账号密码；推荐不设置密码，系统安装后再自行设置密码；默认无密码
* `-VentoyDriverLetter String`：已安装 Ventoy 的 U 盘驱动器；默认为当前用户的桌面
* `-ISOPath String`：使用应答文件的 ISO 镜像文件的路径；默认未指定
* `-NotFormat`：安装系统时不格式化所选硬盘分区；默认安装时会格式化所选硬盘分区

# 参考资料

* Windonws 11 应答文件必须的内容：https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/automate-windows-setup?view=windows-11
* 应答文件组件介绍：https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/components-b-unattend
* 在线应答文件生成器：https://www.windowsafg.com/index.html
* Ventoy 使用：https://www.ventoy.net/cn/doc_start.html
* Ventoy 自动安装：https://www.ventoy.net/cn/plugin_autoinstall.html
