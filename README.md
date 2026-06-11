# O-C Codex 模式切换工具

O-C 是一个 Windows 桌面工具，用来在 **Codex 官方 ChatGPT/OAuth 模式** 和 **CPAMC/API 模式** 之间切换配置，并自动同步本地聊天记录的 provider 元数据，让你在切换额度来源后仍然能继续看到原来的项目和对话。

> 本项目只负责本机配置切换和本地记录同步，不提供 OpenAI 账号、CPAMC 账号、API Key 或任何第三方服务额度。

项目参考：[Dailin521/codex-provider-sync](https://github.com/Dailin521/codex-provider-sync)

## 遇到的问题

很多 Codex Desktop 用户会同时使用两种方式开发：

- 官方 ChatGPT/OpenAI 账号登录
- CPAMC/API provider 接入

在实际使用中，经常会遇到一个问题：官方账号额度用完后，切换到 CPAMC/API 继续开发；或者从 CPAMC/API 切回官方 OAuth 登录后，原来的项目和聊天记录突然不显示了。

这些对话通常并没有真正丢失。Codex Desktop 会把本地聊天记录、项目侧边栏、账号状态等数据保存在本机的 `.codex` 目录里，但不同登录方式使用的 provider 元数据不同，导致同一批本地聊天记录在切换模式后可能被隐藏。

O-C 就是为了解决这个切换痛点而做的工具。

它会把下面这些步骤自动化：

1. 切换前先备份当前 `%USERPROFILE%\.codex` 里的配置、账号缓存和聊天记录元数据。
2. 写入目标模式对应的 `config.toml`。
3. 处理 OAuth/API 两种登录方式之间不兼容的 auth 文件。
4. 把本地聊天记录的 provider 元数据同步到目标模式。
5. 切换完成后重新打开 Codex，就可以在新模式下继续开发原来的项目和对话。

## 功能特点

- 一键切换至 OAuth
- 一键切换至 CPAMC
- 支持导入两份 `config.toml`
- 支持自定义 Codex 数据目录
- 支持自定义备份目录
- 切换前自动备份当前状态
- 自动同步本地聊天记录 provider 元数据
- Windows 图形界面，适合不想手动改配置文件的用户

## 界面预览

### 模式切换

![O-C 模式切换界面](picture/1.png)

### 设置

![O-C 设置界面](picture/2.png)

## 使用前准备

你需要先准备两份可用的 Codex 配置文件。

### 1. 准备官方 OAuth 配置

1. 打开 Codex Desktop。
2. 使用官方 ChatGPT/OpenAI 账号登录。
3. 确认 Codex 可以正常聊天。
4. 找到本机配置文件：

```text
%USERPROFILE%\.codex\config.toml
```

5. 把这个文件复制出来保存，例如：

```text
D:\codex-configs\official-config.toml
```

这份文件就是你的官方 OAuth 配置。

### 2. 准备 CPAMC/API 配置

1. 按你的 CPAMC 面板教程，把 Codex 切换到 API 接入方式。
2. 在登录界面或配置流程中填入 CPAMC 面板提供的 API Key。
3. 确认 Codex 可以通过 CPAMC/API 正常聊天。
4. 再次保存当前配置文件：

```text
%USERPROFILE%\.codex\config.toml
```

5. 把它复制出来保存，例如：

```text
D:\codex-configs\cpamc-config.toml
```

这份文件就是你的 CPAMC/API 配置。配置文件可能包含账号或 API 信息，O-C 会在本机读取它来完成模式切换。

## 第一次使用 O-C

1. 下载 Release 压缩包并解压。
2. 双击 `O-C.exe` 启动 O-C。
3. 如果想创建桌面快捷方式，双击 `Create-O-C-Shortcut.bat`，脚本会在桌面生成 `O-C.lnk`。
4. 打开左侧的 `设置`。
5. 在 `OpenAI 配置` 中选择官方 OAuth 的 `config.toml`。
6. 在 `CPAMC 配置` 中选择 CPAMC/API 的 `config.toml`。
7. 确认 `Codex 数据` 路径，默认是：

```text
%USERPROFILE%\.codex
```

8. 设置 `备份目录`，推荐使用非系统盘，例如：

```text
D:\codex-back
```

9. 点击 `保存设置`。

设置文件会保存在：

```text
%APPDATA%\C-O\settings.json
```

## 如何切换模式

建议切换前先关闭 Codex Desktop。  
如果 Codex 正在运行，部分会话文件可能正在被占用，虽然 O-C 会尽量处理，但关闭后再切换更稳。

### 切换至 CPAMC

适合官方账号额度不够，需要调用 CPAMC 面板额度继续开发时使用。

1. 打开 O-C。
2. 点击 `切换至CPAMC`。
3. O-C 会先读取当前 `%USERPROFILE%\.codex` 数据并创建备份。
4. O-C 写入 CPAMC 的 `config.toml`。
5. O-C 处理当前 auth 状态。
6. O-C 将本地聊天记录 provider 同步到 CPAMC 对应 provider。
7. 打开 Codex Desktop，继续使用原来的项目和对话。

### 切换至 OAuth

适合从 CPAMC/API 模式切回官方 ChatGPT/OpenAI 账号时使用。

1. 打开 O-C。
2. 点击 `切换至OAuth`。
3. O-C 会先读取当前 `%USERPROFILE%\.codex` 数据并创建备份。
4. O-C 写入官方 OAuth 的 `config.toml`。
5. O-C 会移走 API 模式下不兼容的 auth 文件。
6. O-C 将本地聊天记录 provider 同步到 OAuth 对应 provider。
7. 打开 Codex Desktop。
8. 如果 Codex 要求登录，使用官方账号重新登录即可。

## 备份目录说明

默认备份根目录是：

```text
D:\codex-back
```

里面通常会有这些目录：

```text
D:\codex-back\codex-switch
D:\codex-back\history-sync
D:\codex-back\c-o-safety-backups
```

### `codex-switch`

保存模式切换相关的配置和账号缓存备份，例如官方模式、CPAMC 模式各自的 auth/config 状态。

```text
codex-switch/
  profiles/
    official/
    cpamc/
  backups/
```

### `history-sync`

保存聊天记录 provider 同步前的备份。  
例如你当前在 CPAMC 模式，点击 `切换至OAuth`，O-C 会先备份当前 CPAMC 模式下的聊天记录元数据，再执行 provider 同步。

```text
history-sync/
  yyyyMMdd-HHmmss-openai/
  yyyyMMdd-HHmmss-CPA/
```

### `c-o-safety-backups`

保存清理旧文件、迁移备份目录或升级工具时产生的安全备份。

## O-C 会修改哪些文件

O-C 主要会修改或备份 `%USERPROFILE%\.codex` 里的文件，例如：

```text
config.toml
auth.json
state_5.sqlite
sessions\rollout-*.jsonl
archived_sessions\rollout-*.jsonl
.codex-global-state.json
```

修改前会先创建备份。  

## 隐私与数据说明

O-C 只在本机工作，不会上传你的配置文件、账号缓存、API Key 或聊天记录。

切换时产生的备份会保存到你设置的备份目录中。备份内容可能包含 Codex 的本地配置、登录缓存和聊天记录元数据，因此建议把备份目录放在你自己可控的位置。

O-C 不是删除数据恢复工具。它的作用是让本机仍然存在的 Codex 聊天记录在不同 provider 模式下继续可见。

## 项目结构

```text
O-C/
  O-C.exe                 # Release 压缩包中的启动程序
  O-C.lnk                 # 运行 Create-O-C-Shortcut.bat 后生成
  Run-O-C.vbs
  Build-O-C-Release.bat
  Push-GitHub.bat
  Create-O-C-Shortcut.bat
  README.md
  picture/
    1.png
    2.png
  Source_Codes/
    build/
      Build-O-C-Release.ps1
    launcher/
      O-C.Launcher.csproj
      Program.cs
    tools/
      CodexUnifiedSwitcher.ps1
    tests/
      Test-CodexUnifiedSwitcher.ps1
      Test-CodexUnifiedSwitcher-CPAMCWithoutAuth.ps1
      Test-CodexUnifiedSwitcher-Ui.ps1
```

核心文件是：

```text
Source_Codes\tools\CodexUnifiedSwitcher.ps1
```

`O-C.exe` 是 Windows 启动器，负责隐藏命令框并启动上面的 PowerShell 图形界面。

## 开发者说明

推送源码到 GitHub：

```powershell
.\Push-GitHub.bat
```

脚本会自动检查变更、添加文件、使用默认提交说明提交，并推送到当前仓库的上游分支。

运行 UI 检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Source_Codes\tests\Test-CodexUnifiedSwitcher-Ui.ps1
```

运行切换逻辑检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Source_Codes\tests\Test-CodexUnifiedSwitcher.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Source_Codes\tests\Test-CodexUnifiedSwitcher-CPAMCWithoutAuth.ps1
```

运行打包检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Source_Codes\tests\Test-OCPackaging.ps1
```

生成 Release 压缩包：

```powershell
.\Build-O-C-Release.bat
```

打包完成后，产物会输出到：

```text
dist\O-C
dist\O-C-v0.1.0-win-x64.zip
```

## 常见问题

### 切换后聊天记录为什么会消失？

通常不是聊天记录真的被删除，而是 Codex 当前模式的 provider 和旧聊天记录的 provider 不一致，侧边栏没有显示出来。O-C 会在切换时同步这些 provider 元数据。

### 我必须关闭 Codex 再切换吗？

建议关闭。  
如果 Codex 正在运行，它可能正在写入会话文件，关闭后切换更稳定。

### 可以自定义备份目录吗？

可以。  
在 O-C 的 `设置` 页面修改 `备份目录` 即可。

### 备份可以删除吗？

确认切换稳定、聊天记录正常显示后，可以清理较旧的备份。  
建议至少保留最近一次成功切换前的备份，方便需要时回退。

### O-C 可以恢复已删除的聊天记录吗？

不可以。  
O-C 只处理本机仍然存在的 Codex 聊天记录元数据，不能恢复已经被删除的内容。

## License

以仓库中的 `LICENSE` 文件为准。
