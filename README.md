# mac-manage

A git-versioned CLI tool for tracking installs, managing configurations, and maintaining your Mac.

## Quick Start

```bash
cd ~/mac-manage

# See all commands
./mac-manage.sh help

# Take your first snapshot
./mac-manage.sh snapshot

# Check system health
./mac-manage.sh health

# List snapshots
./mac-manage.sh list

# Compare latest two snapshots
./mac-manage.sh diff

# Preview restoring from a snapshot (no changes made)
./mac-manage.sh restore snapshots/20250101-120000 --dry-run
```

## Commands

| Command | Description |
|---------|-------------|
| `snapshot` | Full snapshot: installed software + dotfiles + macOS preferences |
| `snapshot-installs` | Snapshot only installed software (brew, casks, mas, /Applications) |
| `snapshot-config` | Snapshot only dotfiles and macOS preference domains |
| `health` | Audit security settings, disk usage, backups, and updates |
| `diff [old] [new]` | Compare two snapshots (auto-selects latest two if no args) |
| `restore <dir> [opts]` | Restore dotfiles/defaults from a snapshot |
| `list` | List all snapshots with file counts |

### Restore Options

- `--dry-run` — Show what would change without making changes
- `--dotfiles` — Restore only dotfiles
- `--defaults` — Restore only macOS preference domains

---

## Security Hardening

Your Mac should have these enabled. Run `./mac-manage.sh health` to check.

### FileVault (Disk Encryption)

**System Settings > Privacy & Security > FileVault > Turn On**

Encrypts your entire disk. If your Mac is lost or stolen, nobody can read your data without your password. There is no performance penalty on Apple Silicon.

### Firewall

**System Settings > Network > Firewall > Turn On**

Blocks unauthorized incoming network connections. Safe to enable — it won't interfere with normal use.

### Lock Screen

**System Settings > Lock Screen**

- Set "Require password after screen saver begins" to **Immediately**
- Set "Start Screen Saver when inactive" to **5 minutes** (or your preference)

### Automatic Updates

**System Settings > General > Software Update > Automatic Updates**

Turn on all options: Download, Install macOS updates, Install app updates, Install Security Responses.

---

## Backup Strategy

### Time Machine (Essential)

**System Settings > General > Time Machine > Add Backup Disk**

Time Machine creates hourly backups to an external drive or network share. It's the easiest way to recover from disasters.

- Plug in an external USB drive (1TB+ recommended)
- macOS will offer to use it for Time Machine — accept
- Backups run automatically when the drive is connected
- You can exclude folders (like `~/Downloads`) to save space

### Additional Backups

Consider a cloud backup for off-site protection:
- **iCloud Drive** — built-in, good for documents
- **Backblaze** ($9/month) — backs up everything automatically

The 3-2-1 rule: 3 copies of data, on 2 different media, with 1 off-site.

---

## Homebrew Best Practices

### Daily Workflow

```bash
# Install something
brew install <package>

# Install a GUI app
brew install --cask <app>

# Search for packages
brew search <term>

# See what's installed
brew list
brew list --cask
```

### Maintenance

```bash
# Update Homebrew and all packages
brew update && brew upgrade

# Check for issues
brew doctor

# Clean up old versions
brew cleanup

# See what's outdated
brew outdated
```

### Brewfile

Your baseline Brewfile lives at `~/mac-manage/baseline/Brewfile`. To recreate your setup on a new Mac:

```bash
brew bundle install --file=~/mac-manage/baseline/Brewfile
```

To update the baseline after installing new things:

```bash
brew bundle dump --file=~/mac-manage/baseline/Brewfile --force
cd ~/mac-manage && git add baseline/Brewfile && git commit -m "Update Brewfile"
```

---

## Essential macOS Concepts

### Where Things Live

| Path | What's There |
|------|-------------|
| `/Applications` | GUI apps (drag-to-install or from App Store) |
| `/usr/local` or `/opt/homebrew` | Homebrew-managed packages (Apple Silicon uses `/opt/homebrew`) |
| `~/.zshrc` | Your shell configuration (runs every time you open Terminal) |
| `~/Library` | App preferences, caches, support files (hidden by default) |
| `~/.config` | Config files for CLI tools (XDG convention) |

### Key Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+Space | Spotlight search (find anything) |
| Cmd+Tab | Switch between apps |
| Cmd+\` | Switch windows within an app |
| Cmd+, | Open preferences for current app |
| Cmd+Q | Quit app (closing window doesn't quit) |
| Cmd+W | Close window/tab |
| Cmd+Shift+. | Show/hide hidden files in Finder |
| Ctrl+Cmd+Q | Lock screen |

### Terminal Tips

- **zsh** is the default shell on macOS
- `open .` opens the current directory in Finder
- `open -a "App Name"` launches an app from Terminal
- `pbcopy` / `pbpaste` — clipboard from the command line
- `defaults` — read/write macOS preferences (what this tool tracks)
- `caffeinate` — prevent your Mac from sleeping (useful during long tasks)

---

## Maintenance Schedule

### Weekly (automated if launchd is enabled)
- `./mac-manage.sh snapshot` — track what changed

### Monthly
- `./mac-manage.sh health` — check security and updates
- `brew update && brew upgrade` — update packages
- `brew cleanup` — reclaim disk space
- Review `./mac-manage.sh diff` — understand what changed

### After Major Changes
- Take a snapshot before and after installing new software
- Commit updated baseline: `cd ~/mac-manage && git add -A && git commit -m "Update baseline"`

---

## Auto-Snapshot with launchd

A plist is provided at `launchd/com.mike.mac-manage.snapshot.plist` that runs a snapshot every Sunday at 10am.

**To enable:**

```bash
cp ~/mac-manage/launchd/com.mike.mac-manage.snapshot.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mike.mac-manage.snapshot.plist
```

**To disable:**

```bash
launchctl unload ~/Library/LaunchAgents/com.mike.mac-manage.snapshot.plist
rm ~/Library/LaunchAgents/com.mike.mac-manage.snapshot.plist
```

**To test it runs:**

```bash
launchctl start com.mike.mac-manage.snapshot
```

---

## How It Works

- **Snapshots** are timestamped directories in `snapshots/` (git-ignored to avoid bloating history)
- **Scripts and baseline config** are version-controlled — this is what you'd use to set up a new Mac
- **Dotfiles are copied** (not symlinked) — simpler to understand, restore creates `.bak` backups
- **macOS defaults** are exported as both text (for readable diffs) and binary plist (for `defaults import` restore)
- **Everything is plain shell scripts** — no dependencies beyond what macOS and Homebrew provide
