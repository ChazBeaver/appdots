# 🧠 Neovim Keymap Cheatsheet (Telescope + Git Workflow)

---

# 📂 FILES / NAVIGATION

| Keymap       | Action                                              |
| ------------ | --------------------------------------------------- |
| `<leader>ff` | Find ALL files (project, includes hidden + ignored) |
| `<leader>fa` | Find ALL files from `$HOME`                         |
| `<leader>fo` | Find Omarchy files                                  |
| `<leader>fb` | Find buffers                                        |
| `<leader>fr` | Recent files                                        |

---

# 🔍 SEARCH

| Keymap       | Action                                   |
| ------------ | ---------------------------------------- |
| `<leader>sl` | Deep search (includes hidden)            |
| `<leader>ss` | Search input string (deep search)        |
| `<leader>sw` | Search word under cursor (deep search)   |
| `<leader>sg` | Search git repo                          |
| `<leader>sd` | Search diagnostics                       |

---

# 🌿 GIT — TELESCOPE (READ / EXPLORE)

| Keymap                 | Action                               |
| ---------------------- | ------------------------------------ |
| `<leader>gcc`          | Git commits                          |
| `<leader>gb`           | Git branches                         |
| `<leader>gt`           | Git status                           |
| `<leader>gfh`          | Git history (current file)           |
| `<leader>gfh` (visual) | Git history (selected lines)         |

---

# 🧩 GIT — NEOGIT (WORKFLOW)

| Keymap        | Action                                      |
| ------------- | ------------------------------------------- |
| `<leader>ga`  | Open Neogit                                 |
| `<leader>gC`  | Commit popup                                |
| `<leader>gL`  | Log popup                                   |
| `<leader>gl`  | Pull popup                                  |
| `<leader>gP`  | Push popup                                  |
| `<leader>gcm` | Quick commit (inline message)               |
| `<leader>gp`  | Quick push `origin HEAD`                    |
| `<leader>gss` | Git status `--short` (floating window)      |
| `<leader>gsl` | Git status (floating window)                |
| `<leader>gmb` | Merge branches (interactive picker)         |

---

# 📦 GIT — STAGING

| Keymap        | Action             |
| ------------- | ------------------ |
| `<leader>gsf` | Stage current file |
| `<leader>gsa` | Stage ALL files    |
| `<leader>ghs` | Stage hunk         |

---

# 🔍 GIT — INSPECT / DIFF

| Keymap        | Action                    |
| ------------- | ------------------------- |
| `<leader>ghp` | Preview hunk              |
| `<leader>gd`  | Diff current file vs HEAD |
| `<leader>gB`  | Blame line                |

---

# 🔁 GIT — NAVIGATION (HUNKS)

| Keymap        | Action        |
| ------------- | ------------- |
| `<leader>ghn` | Next hunk     |
| `<leader>ghN` | Previous hunk |

---

# ♻️ GIT — RESET / UNDO

| Keymap        | Action     |
| ------------- | ---------- |
| `<leader>ghr` | Reset hunk |

---

# 🪟 NEOGIT STATUS — FLOATING PREVIEW

| Keymap    | Action                                            |
| --------- | ------------------------------------------------- |
| `zf`      | Open floating diff preview                        |
| `<Enter>` | Preview file in floating window                   |
| `e`       | Edit file                                         |
| `q`       | Close preview                                     |
| `<Esc>`   | Close preview                                     |

---

# ⚡ MENTAL MODEL

### Everything Git starts with:

```
<leader>g
```

### Then:

- `c` → commits / commit  
- `b` → branches  
- `t` → status (Telescope)  
- `f` → file history  
- `s` → stage / status  
- `h` → hunk  
- `d` → diff  
- `B` → blame  
- `p` → push  
- `n/N` → next / previous hunk  
- `a` → open Neogit  
- `m` → commit / merge  
- `L` → log  
- `l` → pull  
- `ss` → short status  
- `sl` → long status  
- `mb` → merge branches  

---

# 🚀 BONUS (Git CLI equivalents)

| Action                          | Command                                  |
| ------------------------------- | ---------------------------------------- |
| Reset everything                | `git reset --hard HEAD`                  |
| Full wipe (including untracked) | `git reset --hard HEAD && git clean -fd` |
| Unstage                         | `git restore --staged .`                 |
| Discard changes                 | `git restore .`                          |
