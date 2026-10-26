<p align="center">
  <img src="Documentation/Brand/dayline-icon.png" width="96" alt="Dayline icon">
</p>

<h1 align="center">Dayline</h1>

<p align="center">
  Plans, goals, and ideas. One native Mac app.<br>
  Free. No ads. No account.
</p>

<p align="center">
  <a href="README_CN.md">中文</a> ·
  <a href="#install">Install</a> ·
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

Dayline is where the day you are going to live, the result you care about, and the thought you are not ready to schedule all stay in one window. It is a native macOS app, built with SwiftUI. The interface is Chinese.

A task list forgets why the task exists. A goal tracker forgets what to do today. A notes app forgets to become action. Dayline keeps that line intact.

**The plan belongs to today.** Today shows what you scheduled for today or what comes due today, grouped into Learning, Research, and Health. Work left over from an earlier day waits under Reschedule. The list you open in the morning is the day you chose.

**The goal is about the outcome.** A long goal can hold shorter ones. You decide how far the result has come. Finishing a task shows the work. The goal moves when you say it has moved.

**The idea can wait.** Pin a note, keep it with an area or a goal, and turn it into a task when it is ready to be done. The original idea stays, so the reason for the task is still there.

Daily and weekly tasks carry themselves forward when you complete one. Export turns a stretch of plans, or the ideas you choose, into PDF, PNG, or Markdown. History shows how those days actually went.

<p align="center">
  <img src="Documentation/Screenshots/02-today-light-final.png" width="720" alt="Today, with plans grouped by area">
</p>

<p align="center">
  <img src="Documentation/Screenshots/03-goals-dark.png" width="720" alt="Goals, with a long-term direction and a shorter goal beneath it">
</p>

<p align="center">
  <img src="Documentation/Screenshots/v11-ideas-light.png" width="720" alt="Ideas, ready to stay a note or become a task">
</p>

## Install

macOS 14 or later, with Xcode or the Command Line Tools.

### With AI

This is the shortest path. Copy the prompt into Cursor, Codex, or another coding agent on your Mac.

```text
Install Dayline on this Mac from https://github.com/dushiye/Dayline.

Read README.md and docs/INSTALL_WITH_AI.md. Check the environment, clone the source, build it, and install it to ~/Applications/Dayline.app. Then tell me how to open it.
```

The full prompt is in [docs/INSTALL_WITH_AI.md](docs/INSTALL_WITH_AI.md).

### On your own

```bash
git clone https://github.com/dushiye/Dayline.git
cd Dayline
scripts/check-environment.sh
scripts/build-macos.sh
scripts/install-macos.sh "$HOME/Applications/Dayline.app"
open "$HOME/Applications/Dayline.app"
```

You can also double-click `安装 Dayline.command` in Finder.

To update an app that is already installed:

```bash
git pull
DAYLINE_REPLACE_INSTALLED=yes scripts/install-macos.sh "$HOME/Applications/Dayline.app"
```

Your plans, goals, and ideas stay where they are. For development, open `Dayline.xcodeproj`, then choose the **Dayline** scheme and **My Mac**.

## A day with Dayline

- **Capture:** `⌘N` or **+**. A title is enough.
- **Place it:** a planned date is the day you mean to do it. A due date is the latest day. Both use the same calendar.
- **Find it:** search across tasks, goals, and ideas.
- **Keep the spark:** sidebar **灵感**. Turning an idea into a task leaves the idea in place.
- **Share a slice of time:** `⇧⌘E` exports PDF, PNG, or Markdown.
- **Make it yours:** follow the system appearance, or choose light or dark. Sample content is in the sidebar menu, **添加示例内容**.

## Your work

Everything you write stays on this Mac. When you want a copy, use **导出备份…** in the sidebar menu.

## License

[MIT](LICENSE). Free to use, change, and share.

## Author

[dushiye](https://github.com/dushiye) · [github.com/dushiye/Dayline](https://github.com/dushiye/Dayline)
