# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

`webview_cef` is a Flutter plugin that embeds CEF (Chromium Embedded Framework) to provide WebView capabilities on macOS, Windows, Linux, and eLinux.

## Guidelines

### 1. Documentation Language

All documentation under the `docs/` directory must be written in **Chinese**. This includes new files and updates to existing files.

### 2. Git Commit Policy

**Never auto-commit code.** Only commit when the user explicitly commands it (e.g., "提交代码", "commit", "提交暂存区"). Do not commit proactively after completing a task.

### 3. Code Comments

All code comments (in Dart, C++, ObjC, etc.) must be written in **English**. Maintain consistency with the existing codebase style.

### 4. Commit Workflow

When the user asks to commit code:
1. **First**, review the staged changes and synchronize the `docs/` directory accordingly — update existing documentation or add new files to reflect the changes being committed.
2. **Then**, stage the documentation updates together with the code changes and commit them as a single unit.
