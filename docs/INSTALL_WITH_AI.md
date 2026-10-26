# Install Dayline with an AI agent

Give the prompt below to Cursor, Codex, or another coding agent on the Mac where you want Dayline installed. The agent should build from this repository. It should not ask for an Apple ID password, a private key, or a paid developer membership.

Review the plan before the agent replaces an app you already use.

## English prompt

```text
Install Dayline from https://github.com/dushiye/Dayline on this Mac.

Read README.md, README_CN.md, and AGENTS.md before you change anything.

Do this:
1. Check macOS 14 or newer, Swift, and either Xcode or the Command Line Tools. Run scripts/check-environment.sh and stop if it fails. Explain the error in plain language.
2. Clone or update the repository. Open Dayline.xcodeproj when you use Xcode. Do not open the repository folder as the project.
3. Build with scripts/build-macos.sh. Do not use sudo. If Xcode or the Command Line Tools are missing, explain that and ask before running xcode-select --install.
4. If ~/Applications/Dayline.app does not exist, install with:
   scripts/install-macos.sh "$HOME/Applications/Dayline.app"
   If that app already exists, stop and ask me before setting DAYLINE_REPLACE_INSTALLED=yes. The script moves the previous app aside. It must not delete it.
   install-macos.sh compiles the current checkout before copying, so an update is:
   git pull
   DAYLINE_REPLACE_INSTALLED=yes scripts/install-macos.sh "$HOME/Applications/Dayline.app"
5. Verify the installed bundle with codesign --verify --deep --strict.
6. Ask me before launching the app. If you launch it for a test, use a temporary database with --qa-store. Never launch it without that flag against my real library.
7. Run the Mac tests if I ask for them:
   xcodebuild -project Dayline.xcodeproj -scheme Dayline -destination 'platform=macOS,arch=arm64' -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" ONLY_ACTIVE_ARCH=YES test
   Also run: swift test --package-path Packages/DaylineCore --scratch-path "$HOME/Library/Caches/DaylineSwiftBuild/DaylineCore"
   Tests must keep DAYLINE_XCTEST_MODE=1 and must use a temporary store.

Never do this:
- Do not open, copy, move, replace, or delete ~/Library/Application Support/Dayline or any Dayline.store, WAL, SHM, or backup there.
- Do not disable Gatekeeper, SIP, or any other system security setting.
- Do not ask me for an Apple ID password, a certificate, a private key, or a provisioning profile.
- Do not commit, push, change repository visibility, rewrite history, or force-push.
- Do not change the MIT `LICENSE`.

When you finish, tell me the installed path, how to open it, and how to update with git pull followed by install-macos.sh. Also tell me that 导出备份… in the sidebar menu writes a JSON copy.
```

## 中文提示词

```text
请在这台 Mac 上从 https://github.com/dushiye/Dayline 安装 Dayline。

动手之前先阅读 README.md、README_CN.md 和 AGENTS.md。

按这个顺序做：
1. 确认系统是 macOS 14 或更新版本，并且有 Swift，以及 Xcode 或 Command Line Tools。运行 scripts/check-environment.sh。失败就停下来，用普通人能看懂的话说明原因。
2. 克隆或更新仓库。使用 Xcode 时打开 Dayline.xcodeproj，不要把仓库文件夹本身当成工程打开。
3. 用 scripts/build-macos.sh 构建。不要使用 sudo。如果缺少 Xcode 或 Command Line Tools，先说明，并等我同意后再运行 xcode-select --install。
4. 如果 ~/Applications/Dayline.app 还不存在，执行：
   scripts/install-macos.sh "$HOME/Applications/Dayline.app"
   如果这个应用已经存在，先停下来问我，得到同意后再设置 DAYLINE_REPLACE_INSTALLED=yes。脚本只会把旧应用改名留在一旁，不能删除它。
   install-macos.sh 会先按当前源码重新编译再复制。以后更新用：
   git pull
   DAYLINE_REPLACE_INSTALLED=yes scripts/install-macos.sh "$HOME/Applications/Dayline.app"
5. 用 codesign --verify --deep --strict 检查装好的应用包。
6. 启动应用之前先问我。如果只是测试能否启动，必须加上 --qa-store 并指向临时数据库。禁止在没有这个参数时启动，以免打开我的正式资料库。
7. 只有我要求时才运行 Mac 测试：
   xcodebuild -project Dayline.xcodeproj -scheme Dayline -destination 'platform=macOS,arch=arm64' -derivedDataPath "$HOME/Library/Caches/DaylineXcodeDerivedData" ONLY_ACTIVE_ARCH=YES test
   以及：swift test --package-path Packages/DaylineCore --scratch-path "$HOME/Library/Caches/DaylineSwiftBuild/DaylineCore"
   测试必须保留 DAYLINE_XCTEST_MODE=1，并且使用临时数据库。

这些事情不要做：
- 不要打开、复制、移动、替换或删除 ~/Library/Application Support/Dayline，也不要碰其中的 Dayline.store、WAL、SHM 和备份。
- 不要关闭 Gatekeeper、SIP 或其他系统安全设置。
- 不要向我索取 Apple ID 密码、证书、私钥或描述文件。
- 不要提交、推送、修改仓库可见性、改写历史或强制推送。
- 不要修改 MIT `LICENSE`。

完成后告诉我安装路径、怎么打开，以及以后怎样用 git pull 再运行 install-macos.sh 更新。也告诉我侧边栏菜单里的「导出备份…」会写出一份 JSON。
```
