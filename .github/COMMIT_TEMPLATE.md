# Commit Message Template

Every commit message should serve as a **changelog entry** — someone scanning
`git log` should be able to reconstruct the full project history, including
what failed and how it was fixed.

## Format

```
<subject line — imperative, ≤72 chars>

WHY:
Motivation or context. What gap, bug, or request led to this change?

WHAT:
Summary of changes across files/scripts.

HOW:
Implementation approach, constraints, and design choices.

ISSUES (if any):
What was tried first? What failed? How was it caught?
Include error messages, version constraints, or failed approaches.

VALIDATION:
How was this tested? On what environment? What was verified?

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Section Guidelines

| Section | Required? | When to skip |
|---------|-----------|-------------|
| WHY | Always | Never — even "Add X to Brewfile" should say why X was added |
| WHAT | Always | Never |
| HOW | Multi-file changes | Single-file additions (e.g., Brewfile entry) |
| ISSUES | When something failed | Clean implementations with no surprises |
| VALIDATION | Feature/bugfix commits | Config-only changes (Brewfile, baseline lists) |

## Examples

### Feature commit (full detail)

```
Add launchd plist tracking to snapshot, diff, and restore

WHY:
Homebrew services like Ollama use launchd plists for auto-start
configuration. These weren't tracked, so service settings couldn't
be restored from snapshots.

WHAT:
- baseline/launchd.list: plist paths to track (one per line)
- snapshot-config.sh: copies plists to snapshots/XX/launchd/
- diff-snapshots.sh: diffs launchd/ between snapshots
- restore-config.sh: restores with .bak backup, new --launchd flag

HOW:
Follows existing dotfiles/defaults pattern: baseline list defines what
to track, snapshot captures, diff compares, restore puts back. Restore
uses a _launchd_dest() lookup function to map plist basename back to
full path from launchd.list.

ISSUES:
Initial implementation used `declare -A` (Bash 4+ associative arrays)
to cache basename->path mappings. Caught during validation on macOS
Bash 3.2.57: "declare: -A: invalid option" (exit code 2). Same class
of bug as a3f12e4 (mapfile). Replaced with per-call while-read lookup.

VALIDATION:
Tested on macOS Bash 3.2.57 (arm64-apple-darwin25):
- snapshot-config.sh: plist copied to launchd/ subdir
- diff-snapshots.sh: runs clean, skips when no prior launchd dir
- restore --launchd --dry-run: resolves path, previews backup + copy
- restore --dry-run (all categories): dotfiles + defaults + launchd
```

### Simple addition (minimal but complete)

```
Add Figma to Brewfile

WHY:
Figma Desktop needed for design-to-code workflow with Figma MCP server.

WHAT:
Added cask "figma" to baseline/Brewfile.
```

### Bugfix commit

```
Fix mapfile usage in diff-snapshots.sh for macOS Bash 3.2 compatibility

WHY:
diff-snapshots.sh failed on stock macOS because mapfile is a Bash 4+
builtin. macOS ships Bash 3.2 due to GPLv3 licensing.

WHAT:
Replaced mapfile call in diff-snapshots.sh with a while-read loop.

HOW:
`mapfile -t arr < <(command)` replaced with
`while IFS= read -r line; do arr+=("$line"); done < <(command)`.

ISSUES:
Discovered when running diff on a fresh macOS install — script exited
with "mapfile: command not found".

VALIDATION:
Verified diff output matches between Bash 3.2 and Bash 5.2.
```
