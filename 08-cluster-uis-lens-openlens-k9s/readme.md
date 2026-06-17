# Cluster UIs: Lens, OpenLens, and k9s

You do not have to drive Kubernetes from `kubectl` alone. A handful of UIs make day-to-day cluster work much faster — viewing pods, tailing logs, opening exec shells, switching contexts. This chapter covers the three tools every DevOps engineer should know in 2026.

## Section 1: The choice between Lens Desktop, OpenLens, and k9s in 2026

### Lens Desktop

Lens **went paid in 2023**. It is now distributed by Mirantis and team features (cluster sharing, central catalog, security extensions) require a **Mirantis subscription**. There is still a free **Personal tier**, but with limitations on the number of clusters and disabled features. If your employer already pays for Mirantis, Lens Desktop is fine. Otherwise, almost everyone moved to OpenLens or k9s.

### OpenLens

**The open-source fork of Lens.** Free forever. Same UI as the original Lens (the source code was forked just before the paywall). **Most students in this class use OpenLens.**

Install:

```bash
# Windows
choco install -y openlens

# Mac
brew install --cask openlens
```

### k9s

**A terminal UI (TUI) instead of a GUI.** Fast, keyboard-driven, and runs happily inside a tmux session if you live in the terminal. **This is the modern DevOps engineer's daily tool** — you can drive a cluster faster from k9s than from any GUI once your fingers know the keys.

Install:

```bash
# Mac
brew install k9s

# Windows
choco install k9s

# Linux
curl -sS https://webinstall.dev/k9s | bash
```

## Section 2: k9s cheat sheet

Launch:

```bash
k9s
```

Inside k9s, everything is a colon-command or a single keystroke.

| Action | Keys |
|---|---|
| Switch kube-context | `:ctx` then pick from list then Enter |
| List pods | `:pods` (or `:po`) |
| Switch namespace | `n` (then pick from the popup), or `:ns` |
| List deployments | `:deploy` |
| List services | `:svc` |
| List nodes | `:nodes` |
| View logs of selected pod | `l` |
| Exec a shell into selected pod | `s` |
| Describe selected resource | `d` |
| Edit selected resource (opens $EDITOR) | `e` |
| Delete selected resource | `ctrl-d` |
| Filter the current view | `/` then type |
| Go back / cancel | `esc` |
| Quit k9s | `:q` or `ctrl-c` |

Tip: `k9s -n my-namespace` jumps straight into that namespace on launch.

## Recommendation

- **For this class**: pick **k9s + kubectl** as your daily driver. It teaches you the resource model faster than any GUI.
- **If you want a GUI**: install **OpenLens**. Skip Lens Desktop unless your employer pays for it.
- The Lens install commands above are **optional**. Most engineers use k9s + kubectl directly and only open a GUI for occasional visual inspection (multi-cluster dashboards, log search, metrics).

## Cleanup

Nothing to delete in the cluster — these are local tools.

```bash
# Optional: uninstall the local tools
brew uninstall --cask openlens   # Mac
brew uninstall k9s               # Mac
choco uninstall openlens         # Windows
choco uninstall k9s              # Windows
```
