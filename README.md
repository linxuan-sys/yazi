# Yazi 汉化增强配置

> 一套基于 [Yazi](https://github.com/sxyazi/yazi) 的**中文增强配置**：界面提示全部汉化，内置 14 个实用插件，开箱即用。

- 适用版本：**Yazi 26.9.1**
- 面向用户：中文用户
- 特点：快捷键说明全中文、插件齐全、修复了默认配置里的键位冲突

---

## 一、插件与功能

| 插件 | 功能 | 快捷键 / 说明 |
| :--- | :--- | :--- |
| `mediainfo` | 音视频、图片的缩略图与媒体信息预览 | 光标停留即可预览；依赖 `ffmpeg`、`mediainfo` |
| `duckdb` | 预览 CSV / TSV / JSON / Parquet / XLSX / DB 表格数据 | 光标停留即可预览；依赖 `duckdb` |
| `docx-preview` | `.docx` 文档转纯文本预览（支持中文） | 依赖 `pandoc` |
| `preview-typst` | `.typ` 排版文档预览 | 依赖 `typst` |
| `gvfs` | 挂载 MTP / SMB / SFTP / WebDAV 等设备与远程存储 | `M` 系列、`G m`；依赖 `gvfs`、`glib` |
| `mount` | 本地磁盘分区挂载 / 卸载 / 弹出 | `M p`；依赖 `udisks2`、`util-linux` |
| `ouch` | 压缩 / 解压（自动适配格式） | `c z`；依赖 `ouch` |
| `yamb` | 书签管理：持久化保存、按键跳转、fzf 搜索、重命名 | `[` 存、`]` 跳、`\g` 跳、`\r` 改名、`\d` 删、`\G`/`\D`/`\R` 走 fzf、`\a` 存、`\A` 清空；fzf 功能依赖 `fzf` |
| `bypass` | 自动穿透「只有一个子目录」的目录链 | 配合 `→` 使用 |
| `smart-enter` | 目录则进入、文件则打开的「二合一」动作 | 通过 `bypass` 调用 |
| `open-with-cmd` | 用自定义命令打开文件 | `o c` |
| `full-border` | 给三栏界面加完整圆角边框 | 启动即生效 |
| `starship` | 顶部渲染 starship 提示符 | 依赖 `starship` |
| `simple-status` | 精简底部状态栏 | 启动即生效 |

> `package.toml` 锁定 14 个插件与 2 个现成主题（`dracula`、`catppuccin-mocha`），
> 全部由 `ya pkg install` 自动安装，无需任何手动步骤。

---

## 二、相对默认配置的改动

1. **符号链接键位避让（重点）**
   Yazi 默认把 `-`（绝对链接）和 `_`（相对链接）留给符号链接，而这两个键的位置很适合放标签页操作。
   本配置把标签页固定在 `-` `=` `_` `+`，链接功能改绑到右侧符号键：
   - `(` 相对符号链接
   - `)` 绝对符号链接
   - `*` 硬链接
   （用法：`y` 选中文件 → 跳到目标目录 → 按对应符号）

2. **`g t` 为回收站**
   进入 Yazi 内置回收站视图（`plugin trash`）；Templates 没用删了。
   回收站里按 `O`（`open --interactive`）弹出菜单，可选 `Restore selected files`
   恢复条目或 `Empty trash bin` 清空；按 `D` 永久删除选中条目。

3. **标签页操作**
   - `-` / `=`：上一个 / 下一个标签页（默认是 `[` / `]`，这两个键已让给书签插件）
   - `_` / `+`：与上一个 / 下一个标签交换位置（默认是 `{` / `}`）
   - `1`~`9`：直接切换到第 N 个标签
   - `t q`：关闭当前标签（默认是 `<C-c>`，改绑以免与终端「中断」习惯冲突；最后一个标签时退出）
   - `t t` 新建标签、`t r` 重命名标签
   - `}` 因此空置，不再占用

4. **书签改用 `yamb` 插件**（原 `bookmarks` 插件因 `ya.mgr_emit` 被 Yazi 移除而失效）
   - `[` / `\a`：保存当前位置为书签（依次填 tag、key，key 留空会自动分配一个未占用的键）
   - `]` / `\g`：按键跳转（目录直接 `cd`，文件则 `reveal` 定位）
   - `\r`：按键重命名（改 tag，或改绑到别的键）
   - `\d`：按键删除单条；`\A`：清空全部（需输入 `y` 确认）
   - `\G` / `\D` / `\R`：跳转 / 删除 / 重命名的 fzf 版本，书签多了记不住键时用
   - 持久化为纯文本 `~/.config/yazi/bookmark`（每行 `tag<TAB>路径<TAB>键`，路径以 `/`
     结尾表示目录），每次保存或删除立刻写入，不再依赖 Yazi DDS

5. **键位表改为「覆盖式」**：`[mgr]` 段使用 `keymap` 而非默认的 `prepend_keymap`，
   即**不再加载 Yazi 内置默认键位**，所有按键都在配置里显式列出（更方便汉化，也避免出现
   「帮助里有一条英文默认键、实际又按不出来」的幽灵条目）。代价是 Yazi 升级后新增的默认键
   不会自动出现，需要手动补充。

6. **输入框**
   保留 vim 风格编辑与历史翻页（`Ctrl+P` / `Ctrl+N`、`↑` / `↓`、普通模式下的 `k` / `j`）；
   默认的 `Alt+B` / `Alt+F` / `Ctrl+←` / `Ctrl+→` 的 "lean" 变体改为普通单词移动。

7. **其他小调整**
   - `<Space>` 选中后自动下移且不循环（原生 `toggle` + `arrow 1`；`arrow 1` 按偏移量移动，到末行即停不回绕）
   - `→` 使用 `bypass smart-enter`（目录进、文件开）
   - `PageUp/PageDown` 与 `Shift+PageUp/PageDown` 的半页/整页对调
   - `<C-Up>` / `<C-Down>` 预览上下滚动 5 行（与 `K` / `J` 等价）
   - `<S-Left>` / `<S-Right>` 目录历史后退 / 前进
   - 支持 `o o` / `p p` 双键前缀写法，`p f` 强制粘贴
   - 重命名提供多种光标位置：`r r`（扩展名前）、`r f`（清空）、`r i`（开头）、`r a`（末尾）、`r c`（清空）
   - 复制路径改用新语法（`c c` / `c d` / `c f` / `c n`），另有 `c m` 清空主名重命名、`c r` 创建
   - `U` 一键从 Git 强制更新本配置（`scripts/update_config.sh`，详见第六节）
   - `yazi.toml`：按扩展名排序、行模式显示创建时间、显示隐藏文件、预览自动换行、
     图像缩放用 `lanczos3`、图片任务内存上限 1 GiB，并为 mediainfo / duckdb /
     docx-preview / preview-typst 注册了 preloader 与 previewer 规则
   - `theme.toml` 只保留 `[flavor]` 段引用上游主题包（见第三节），图标依赖 Nerd Font

---

## 三、主题换肤

配置里备了两个上游主题包（flavor），都在 `package.toml` 的 `[[flavor.deps]]` 中，
`ya pkg install` 时自动下载到 `flavors/`：

| flavor | 风格 |
| :--- | :--- |
| `catppuccin-mocha` | Catppuccin 深色版，柔和粉紫、低饱和，长时间看不刺眼 |
| `dracula` | Dracula 经典配色，紫底 + 青/粉/黄高对比，辨识度高 |

### 怎么切换

主题的指定只能写在 `theme.toml` 里，并且**必须把原来的配色内容整段删掉**，只留 `[flavor]`：

```toml
[flavor]
dark = "dracula"
light = "dracula"
```

换另一个就把名字改成 `catppuccin-mocha`，然后重开 Yazi 生效。

> 关键点：`theme.toml` 的优先级**高于** flavor。只要文件里还留着 `[mgr]`、`[status]`、
> `[filetype]` 之类的配色段，它们就会把主题包的颜色盖回去，等于换肤没生效。
> 所以切主题时不是「加一段 flavor」，而是「清空旧配色 + 只写 flavor」。

### 恢复手写主题

仓库历史里保存着完整的手写 Material 风格深色主题（282 行），执行：

```bash
git checkout theme.toml
```

临时试主题的话，建议先把现有文件挪走（`mv theme.toml theme.toml.bak`）再写新的，
试完换回来即可。

---

## 四、汉化说明

- `keymap.toml` 中**所有快捷键的说明（`desc`）均已翻译为中文**，包括原本是英文的默认键
  （`G`、`Home`/`End`、`H`/`J`/`K`/`L`、`o`/`p`/`P`、`Ctrl+-`、`r`、`<F1>` 等）。
- 因此按 `~` 打开帮助面板、或按前缀键（如 `\`、`g`、`M`、`c`）弹出的按键提示，显示的都是中文。
- 插件自身的少数运行提示仍为英文（由上游插件决定），例如 `yamb` 保存时弹出的
  `Tag (alias name)` / `Key (1 character, optional)` 输入框标题，以及 `"xxx" saved` 提示。

---

## 五、安装

```bash
# 1. 备份原配置
mv ~/.config/yazi ~/.config/yazi.bak

# 2. 克隆本仓库
git clone https://github.com/linxuan-sys/yazi.git ~/.config/yazi

# 3. 安装 package.toml 里的插件与主题
cd ~/.config/yazi
ya pkg install

# 4. 启动
yazi
```

### 主要依赖

```bash
# Arch Linux
sudo pacman -S pandoc-cli duckdb mediainfo ffmpeg imagemagick typst \
  starship ouch 7zip file gvfs glib2 util-linux fzf zoxide
```

其中 `fzf` 与 `zoxide` 对应 Yazi 内置插件，分别供 `z`（fzf 跳转）和 `Z`（zoxide 跳目录）使用。

其他发行版按上表工具名安装即可（个别包名不同）。

> 更新配置：Yazi 中按 `U` 执行 `scripts/update_config.sh`，会强制覆盖本地改动，执行前请先备份。

---

## 六、更新

在 Yazi 里按大写 **`U`**，会运行 `scripts/update_config.sh`，把本配置强制同步到作者仓库的最新版本。

流程：

1. 先弹确认提示：`你确定要强制覆盖本地 Yazi 配置吗? (y/N)`
2. 按 **`y`** 继续；按 `N`、回车或其他键则取消
3. `git fetch --all` 拉取作者最新提交
4. `git reset --hard origin/main` **强制覆盖本地所有已跟踪文件**——`keymap.toml`、`theme.toml`、
   `init.lua`、`yazi.toml`、`package.toml` 等全部变回仓库版本，你自己的改动一律丢弃
5. `git clean -fd` **删除所有未跟踪的文件和目录**
6. 结束前提示 `按回车键继续`，回车后回到 Yazi

⚠️ **更新前请先备份重要改动**。它不会自动备份，也不会再问你第二次：

```bash
# 方式一：整目录备份（最稳）
cp -r ~/.config/yazi ~/.config/yazi.bak

# 方式二：把本地改动提交成一个 commit，之后还能用 git 找回来
cd ~/.config/yazi && git add -A && git commit -m "我的本地改动"
```

特别注意，下面这些会被第 5 步的 `git clean -fd` 删掉，因为它们没有被 Git 跟踪：

- **书签数据**：`~/.config/yazi/bookmark`（`yamb` 插件的全部书签就存在这个文件里）
- 自己手动放进去的其他文件或目录（自改脚本、临时备份等）

更新完成后，如果 `package.toml` 里的插件有增删，再执行一次 `ya pkg install` 补齐。

---

## 七、说明

- 配置部分（`yazi.toml` / `keymap.toml` / `init.lua` / `theme.toml`）以 **MIT License** 发布，见 [`LICENSE`](./LICENSE)。
- `plugins/` 与 `flavors/` 为上游开源项目的副本，版权归各自作者所有。

<div align="center">

如果这套配置帮到了你，欢迎点个 ⭐ Star ～

Made with ❤️ by [linxuan-sys](https://github.com/linxuan-sys)

</div>
