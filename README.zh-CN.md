# Codex Runtime Repair（Windows 版）

> **非官方社区工具。** 与 OpenAI 无隶属关系，也未获得其背书或支持。使用风险自负。

[English](README.md)

一个用于修复 **Windows 版 Codex Desktop** 启动问题的小型 PowerShell 脚本：程序看似启动了，`ChatGPT.exe` 一直在后台运行，但主窗口始终不出现。

## 症状

- 启动 Codex Desktop 后没有窗口。
- 任务管理器里有一个或多个 `ChatGPT.exe` 进程。
- 重启应用或重启 Windows 都没有效果。
- 问题通常出现在一次更新、更新中断或 runtime staging 失败之后。

## 修复内容

Codex 自带一个 `cua_node` runtime，启动时会经过 staging 并移动到：

```
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\<runtime-id>
```

如果 staging 过程被中断，可能留下一个 `.staging-<runtime-id>-*` 目录，而最终的 `<runtime-id>` 目录缺失或不完整。Codex 会一直等待，因此永远不显示窗口。

本脚本会从已安装的软件包中提取 runtime 文件，重建正式目录，验证复制结果，确认无误后才清理 staging 残留。

## 环境要求

- Windows 10 或 Windows 11
- 以 AppX/MSIX 包（`OpenAI.Codex`）安装的 Codex Desktop
- Windows PowerShell 5.1（系统自带）
- 普通用户会话 —— **不要使用「以管理员身份运行」**

## 快速开始

1. 下载本仓库（Code → Download ZIP）或最新 Release。
2. 解压到任意目录，不要在 ZIP 压缩包内直接运行。
3. 双击 `Run-Repair.bat`。
4. 查看输出结果，然后正常启动 Codex。

脚本会自动定位安装包和 runtime 目录，**不需要手动修改任何路径**。

## 手动运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Repair-CodexRuntime.ps1
```

查看内置帮助：

```powershell
Get-Help .\Repair-CodexRuntime.ps1 -Full
```

## 脚本做了什么

1. 找到已安装的 `OpenAI.Codex` 包并读取版本。
2. 定位包内的官方 `cua_node` 源目录。
3. 找到最新的 `.staging-*` 目录并解析 runtime ID。
4. 只终止从 Codex 安装目录启动的 `ChatGPT.exe` 进程。
5. 使用 `xcopy /E /I /H /Y /G` 复制 runtime。
6. 验证 `bin\node.exe` 和 `bin\node_repl.exe`。
7. 比较源目录和目标目录的文件数量。
8. 只有第 6、7 步都通过后才删除 `.staging-*` 目录。

`/G` 用于保留 MSIX 文件的特殊 ACL，使复制后的文件在非管理员权限下仍可正常使用。

## 安全性

- 不需要管理员权限；如果窗口已提权会给出警告。
- 不会修改已安装的软件包，只从中读取文件。
- 不会删除已有的正式 runtime 目录。
- 只终止 Codex 自己的 `ChatGPT.exe`（按安装路径匹配），不会误杀其他同名程序。
- 只有验证全部通过后才删除 staging 目录。
- 不修改注册表、服务或任何系统配置。

重复运行脚本是安全的，它只会重新执行检查。

## 退出码

| 代码 | 含义 |
|---|---|
| `0` | 修复完成，或无需修复。 |
| `1` | 必要检查失败，staging 文件已保留。 |
| `2` | 复制完成，但目标文件数少于源目录，staging 文件已保留。 |

## 常见问题

| 问题 | 处理方法 |
|---|---|
| `Package 'OpenAI.Codex' was not found` | 当前 Windows 用户没有安装 Codex。请安装，或用安装 Codex 的那个用户运行脚本。 |
| `No .staging-* directory found` | 先启动一次 Codex 让故障复现，然后重新运行脚本。如果 Codex 能正常打开，则无需修复。 |
| `xcopy failed` | 关闭 Codex 后重试，并检查磁盘空间和 runtime 目录的写入权限。 |
| `Destination has fewer files` | 再次运行脚本；如果仍然出现，请手动检查复制结果或重装 Codex。 |
| 核心文件缺失 | 安装包内的 runtime 源可能已损坏，请修复或重装 Codex Desktop。 |
| 修复后仍无窗口 | 确认是以普通方式启动 Codex，而不是管理员方式，然后检查 Codex 应用日志。 |

## 需要你自己修改的地方

### 普通用户

一般**不需要修改任何内容**。只有 OpenAI 更改了包名或目录结构时，才需要编辑 `Repair-CodexRuntime.ps1` 顶部的配置：

```powershell
$PackageName         = "OpenAI.Codex"
$InstallRelativePath = "app\resources\cua_node"
$AppDataFolder       = "OpenAI\Codex"
$RuntimeName         = "cua_node"
$ProcessName         = "ChatGPT"
```

### 发布者 / 二次发布

本仓库故意**不包含任何硬编码的仓库地址、用户名或本地绝对路径**。发布前请自行处理：

- [ ] 将 `LICENSE` 中的 `<YOUR NAME OR ORGANIZATION>` 替换为版权所有者。
- [ ] 如有需要，自行在两个 README 中添加你的仓库地址、徽章或联系方式（目前均未填写）。
- [ ] `Run-Repair.bat` 和 `Repair-CodexRuntime.ps1` 必须放在同一目录；启动器使用 `%~dp0` 定位，整个文件夹可以放在任意位置。
- [ ] 发布 Release 时，将以下文件打包为 ZIP：
  - `Run-Repair.bat`
  - `Repair-CodexRuntime.ps1`
  - `README.md`
  - `README.zh-CN.md`
  - `LICENSE`
- [ ] 如果重命名了仓库或脚本文件，请同步修改本 README 中的手动运行命令。
- [ ] 发布前在一个干净目录（最好再用一个干净的 Windows 用户配置）测试 ZIP。

## 参与贡献

欢迎提交 Issue 和 Pull Request。请附上：

- 你的 Windows 版本和脚本输出中的 Codex 版本；
- 完整的控制台输出；
- 复现问题的步骤。

请不要粘贴个人文件路径、令牌或其他隐私信息。

## 许可证

[MIT](LICENSE)
