<p align="center">
  <img src="Documentation/Brand/dayline-icon.png" width="96" alt="Dayline icon">
</p>

<h1 align="center">Dayline</h1>

<p align="center">
  <strong>Draw a line from today to the place you want to reach.</strong>
</p>

<p align="center">
  A to-do list can tell you what is in front of you.<br>
  It cannot tell you whether any of it leads where you meant to go.
</p>

<p align="center">
  Free · Open source · Native macOS · On this Mac · No account
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="README_CN.md">中文</a> ·
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

Dayline is a native Mac app. The day you choose, the outcome you want, and the thought that is not ready yet share one window. It does not ask you to do more. It helps you spend a limited day on what is worth doing.

The interface is in Chinese.

> **Unreleased work:** the `feat/daily-review` branch adds Daily Review, a quiet place to put one day's learning into your own words, notice real progress, and carry one thought into tomorrow. It autosaves one review per civil day, keeps its date stable across time zones, links from Today, and exports one or several reviews through the existing export center. This branch is under review and is not part of the installed stable release yet.

<p align="center">
  <img src="Documentation/Screenshots/02-today-light-final.png" width="720" alt="Today: plans for the day, grouped by area, with earlier unfinished plans waiting to be rescheduled">
</p>

<p align="center">
  <a href="#install"><strong>Install without writing code</strong></a>
</p>

[Why Dayline](#why) · [Three ideas](#philosophy) · [See it](#see) · [A day](#day) · [Install](#install) · [Your data](#privacy) · [Questions](#faq)

<a id="why"></a>

## Why Dayline

Three things that belong together get split apart.

The work of a day drifts away from the direction of a year. You are busy, and you still cannot say what the week was moving toward.

A thought arrives and has nowhere to wait. By the time you remember it, the reason it mattered is gone.

Every box is checked, and the thing itself may not have moved. Finishing tasks and reaching an outcome are different events.

Dayline does not try to make you more productive. It makes those three breaks visible in one window.

<a id="philosophy"></a>

## Three ideas

### Today is a choice

Yesterday's unfinished work should not become the whole of today.

Today shows what you planned for today, or what is due today, grouped into Learning, Research, and Health. Anything still open from an earlier day waits under 待重新安排. The line there reads: the earlier plan is still here. Choose today, or give it another date.

The day you see is a choice, not a pile of debt.

A daily or weekly task continues with the next occurrence when you complete one. Missed days are not filled in all at once.

### Progress is an outcome

A goal can be a long direction, or a nearer result underneath it.

You set the outcome yourself. The editor says so: update it from the result you actually see. Completing a task does not move that percentage. Next to it, Dayline also shows how many linked actions are done. Both numbers stay. Neither pretends to be the other.

### Ideas need room

Not every thought should become a task on the spot.

In 灵感 you can write a question that does not have an answer yet, attach it to an area or a goal, or leave it alone. It saves as you write.

When it is ready, 转为任务 keeps the original idea and creates a task with no date yet. You choose the day. Deleting the idea leaves a task that was already created.

<a id="see"></a>

## See Dayline

<p align="center">
  <img src="Documentation/Screenshots/02-today-light-final.png" width="720" alt="Today">
</p>

<p align="center">Today holds what you placed in the day.</p>

<p align="center">
  <img src="Documentation/Screenshots/03-goals-dark.png" width="720" alt="A long-term goal and a shorter result beneath it">
</p>

<p align="center">A nearer result can sit under a longer direction. You judge the progress.</p>

<p align="center">
  <img src="Documentation/Screenshots/v11-ideas-light.png" width="720" alt="An idea that can stay a note">
</p>

<p align="center">A thought can stay here until it is ready to become work.</p>

The screenshots use the app's sample content, not a person's real plans.

<a id="day"></a>

## A day with Dayline

You are in a course that will take months. You write a long goal: finish the course properly. Under it, a shorter result: read the four assigned chapters this month. The outcome slider stays where you believe the result actually is.

In the morning you open Today. The chapter you did not finish yesterday is waiting to be rescheduled. You move one chapter onto today and give the others a later date. A name with nowhere to go yet can sit in the inbox.

While reading, a question shows up that you cannot phrase cleanly. You keep it in Ideas, attached to the course goal, with no date.

A few days later the question is clear. You turn it into a task. The idea remains. The new task has no date until you choose one.

To keep a copy of the week, press `⇧⌘E` and export PDF, PNG, or Markdown.

Further down Today, 计划记录 shows what was planned, what was finished, what was added that day, and what you moved on purpose. It does not edit your tasks. Before seven real planning days, there is no capacity note. After that, Today may offer one, and you can dismiss it.

The sidebar ends with a small line: 每一天，都算数。

<a id="install"></a>

## Install

Dayline is built from source on your Mac. There is no Developer ID download and no notarized disk image. You do not need to write code, and you do not need a paid Apple Developer membership.

You need macOS 14 or later, and Git. Building uses Xcode or the Xcode Command Line Tools. The app is copied to `~/Applications/Dayline.app`.

<a id="install-ai"></a>

### With an assistant

This is the short path. On your Mac, open Cursor, Codex, or another assistant that can run commands on that Mac, and paste this.

The assistant needs permission to run commands locally. If developer tools are missing, it should explain that and wait for you before installing them. If Dayline is already installed, it must ask before replacing the app. It must not change or delete your real library, turn off macOS security, or ask for an Apple ID password.

```text
Install Dayline on this Mac.

Repository: https://github.com/dushiye/Dayline

Read README.md, docs/INSTALL_WITH_AI.md, and AGENTS.md, then follow them.
I do not write code. Explain each step in plain language.
If developer tools are missing, tell me and wait before installing them.
If Dayline is already installed, ask me before replacing it.
Do not open, modify, or delete anything in ~/Library/Application Support/Dayline.
Do not turn off system security, and do not ask for an Apple ID password or a paid developer account.
Do not run tests against my real library.
When you finish, tell me where the app is, how to open it, and how to update it.
```

The full instructions for the assistant are in [docs/INSTALL_WITH_AI.md](docs/INSTALL_WITH_AI.md).

<a id="install-manual"></a>

### In Terminal

```bash
git clone https://github.com/dushiye/Dayline.git
cd Dayline
scripts/check-environment.sh
scripts/build-macos.sh
scripts/install-macos.sh "$HOME/Applications/Dayline.app"
open "$HOME/Applications/Dayline.app"
```

`scripts/check-environment.sh` checks the macOS version, Swift, and the developer tools. `scripts/build-macos.sh` only builds. `scripts/install-macos.sh` builds the current checkout again, then copies the app to the path you give it.

You can also double-click `安装 Dayline.command` in Finder. If an app is already there, Terminal asks, then rebuilds from the current source.

### Update

From the cloned directory:

```bash
git pull
DAYLINE_REPLACE_INSTALLED=yes scripts/install-macos.sh "$HOME/Applications/Dayline.app"
```

The installer compiles the source you just pulled, then renames the previous `Dayline.app` and leaves it beside the new one. Your plans, goals, and ideas stay in their database. The installer does not read or write that database.

<a id="privacy"></a>

## Your data

The database is:

```text
~/Library/Application Support/Dayline/Dayline.store
```

There is no account and no subscription. Dayline does not use CloudKit. A Mac and an iPhone do not sync with each other.

For another copy, use 导出备份… in the … menu at the bottom of the sidebar. The file is readable JSON. Keep it where you trust it. 从备份恢复… asks you first, because it replaces the whole library. Before that replacement, the app saves a copy of what you have now.

<a id="faq"></a>

## Questions

### Is Dayline free?

Yes. There are no ads and no in-app purchases. The code is [MIT](LICENSE).

### Can I install it if I do not write code?

Yes. Paste the prompt above into an assistant that can run commands on your Mac. It checks the machine, fetches the source, builds, and installs.

### Do I need a paid Apple Developer account?

Not for building and installing on your own Mac. You need Xcode or the Command Line Tools.

### Which versions of macOS?

macOS 14 and later.

### Does it run on Windows?

No. Dayline is a Mac app.

### Where is my data?

`~/Library/Application Support/Dayline/Dayline.store`

### Will an update erase my plans?

No. An update replaces the app. The previous app is renamed and kept. The installer does not read or write the database. For anything you cannot lose, also use 导出备份….

### Is there an iPhone app?

The repository contains an experimental iPhone app. Installing it on a device takes Xcode and your own signing. The Mac app is the one meant for every day.

### Do Mac and iPhone sync?

No. Each keeps its own data. Nothing is synced automatically.

### How do I back up or uninstall?

Back up with 导出备份…. To uninstall, move `Dayline.app` to the Trash. The folder `~/Library/Application Support/Dayline/` remains until you delete it yourself, after you are sure you no longer want what is in it.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). Please do not include real plans, database files, or signing credentials.

## License

[MIT](LICENSE). You can use, change, and share it. Keep the copyright notice and the license with the code.

## Author

[dushiye](https://github.com/dushiye) · [github.com/dushiye/Dayline](https://github.com/dushiye/Dayline)
