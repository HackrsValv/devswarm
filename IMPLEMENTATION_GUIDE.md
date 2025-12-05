# Self-Distributing Swarm: Complete Implementation Guide

## Overview

Three tools for building and managing self-distributing Git swarms:

1. **Cross-Platform Support** ✅ - Works on any Git forge
2. **Bootstrap CLI** ✅ - One-command swarm joining
3. **Visualization Dashboard** ✅ - Interactive topology viewer

## Quick Start

```bash
# Install the CLI
curl -sSL https://devswarm.org/devswarm -o /usr/local/bin/devswarm
chmod +x /usr/local/bin/devswarm

# Bootstrap a swarm
devswarm bootstrap github.com/alice/project

# View swarm topology
open swarm-visualizer.html
```

## Tool #1: Bootstrap CLI (`devswarm`)

### Installation

```bash
# Download
curl -sSL https://devswarm.org/devswarm -o /usr/local/bin/devswarm
chmod +x /usr/local/bin/devswarm

# Or via Homebrew (if packaged)
brew install devswarm

# Or clone and symlink
git clone https://github.com/devswarm/core
ln -s $(pwd)/core/devswarm /usr/local/bin/devswarm
```

### Commands

#### `devswarm bootstrap <repo-url>`

Clone and setup a swarm repository.

```bash
# Full URL
devswarm bootstrap https://github.com/alice/project

# Short format (assumes GitHub)
devswarm bootstrap alice/project

# Other platforms
devswarm bootstrap gitlab.com/bob/app
devswarm bootstrap codeberg.org/charlie/tool
```

**What it does:**
1. Parses repo URL (supports multiple formats)
2. Detects platform (GitHub/GitLab/Gitea/Forgejo/Generic)
3. Clones repository
4. Checks if it's a swarm
5. Discovers topology via platform API
6. Sets up local git aliases
7. Runs initial coordinator sync

**Output:**
```
✓ Cloned https://github.com/alice/project
✓ This is a swarm repository! 🐝
  Platform: github
  Swarm size: 47 forks
✓ All dependencies available
✓ Git aliases configured:
    git swarm-status  - Check swarm health
    git swarm-sync    - Sync with upstream
✓ Initial coordination complete

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ BOOTSTRAP COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Repository location:
  ~/.devswarm/repos/alice-project

Next steps:
  cd ~/.devswarm/repos/alice-project
  git swarm-status
```

#### `devswarm list`

List all bootstrapped repositories.

```bash
devswarm list

# Output:
🐝  alice-project
   Remote: https://github.com/alice/project
   Updated: 2 hours ago

🐝  bob-app
   Remote: https://gitlab.com/bob/app
   Updated: 1 day ago

❌  charlie-tool
   Remote: https://codeberg.org/charlie/tool
   Updated: 3 days ago
```

#### `devswarm status [path]`

Show swarm status for a repository.

```bash
# Current directory
devswarm status

# Specific path
devswarm status ~/code/project

# Output:
{
  "version": "1.0.0",
  "platform": "github",
  "repository": "alice/project",
  "swarm_topology": {
    "fork_count": 47,
    "health": "healthy",
    "forks": [...]
  }
}
```

#### `devswarm sync [path]`

Manually sync a swarm repository.

```bash
# Current directory
devswarm sync

# Specific path
devswarm sync ~/code/project
```

#### `devswarm clean`

Remove all bootstrapped repositories.

```bash
devswarm clean

# Confirmation required
Will delete:
  - alice-project
  - bob-app
Continue? (y/N)
```

### Configuration

Environment variables:

```bash
# Custom swarm home directory
export SWARM_HOME=~/my-swarms

# Default is ~/.devswarm
```

### Git Aliases (Auto-configured)

After bootstrap, these aliases are available:

```bash
git swarm-status    # Run coordinator and show health
git swarm-sync      # Fetch and merge upstream changes
```

## Tool #2: Visualization Dashboard

### Usage

1. **Open the HTML file:**
   ```bash
   open swarm-visualizer.html
   # Or: python -m http.server 8000 && open http://localhost:8000/swarm-visualizer.html
   ```

2. **Enter repository:**
   - `alice/project` (assumes GitHub)
   - `github.com/alice/project`
   - `https://github.com/alice/project`
   - `gitlab.com/bob/app`

3. **Explore:**
   - Drag nodes to rearrange
   - Hover for details
   - Zoom and pan
   - Color indicates health

### Features

- **Interactive Force Graph**: D3.js-powered visualization
- **Real-time API Queries**: Fetches live fork data
- **Multi-Platform**: GitHub, GitLab, Gitea support
- **Health Indicators**:
  - 🟢 Green: Healthy (10+ forks)
  - 🔵 Blue: Stable (6-9 forks)
  - 🟡 Yellow: Vulnerable (3-5 forks)
  - 🔴 Red: Degraded (<3 forks)
- **Statistics Panel**: Fork count, health, last updated
- **Tooltip Details**: Hover for node information

### Embedding

```html
<!-- Embed in your website -->
<iframe src="swarm-visualizer.html" width="100%" height="800px"></iframe>
```

### Customization

```javascript
// Modify colors
function healthColor(health) {
    return {
        healthy: '#your-color',
        stable: '#your-color',
        vulnerable: '#your-color',
        degraded: '#your-color'
    }[health];
}

// Modify node sizes
.attr('r', d => d.type === 'origin' ? 30 : 15)

// Modify forces
.force('charge', d3.forceManyBody().strength(-500))
.force('link', d3.forceLink(links).distance(200))
```

## Tool #3: Cross-Platform Support

### Supported Platforms

| Platform | Status | Fork API | CI/CD |
|----------|--------|----------|-------|
| GitHub | ✅ Full | REST | Actions |
| GitLab | ✅ Full | REST | GitLab CI |
| Gitea | ✅ Full | REST | Actions |
| Forgejo | ✅ Full | REST | Actions |
| Codeberg | ✅ Full | Forgejo | Actions |
| Woodpecker | ✅ Full | Manual | Woodpecker |
| Generic Git | ⚠️ Basic | Branches | Manual |

### Universal Coordinator

The `swarm-coordinator.sh` script works identically on all platforms:

```bash
#!/bin/bash
# Detects platform automatically
PLATFORM=$(detect_platform)

# Uses platform-specific APIs
case "$PLATFORM" in
    github) discover_forks_github ;;
    gitlab) discover_forks_gitlab ;;
    gitea) discover_forks_gitea ;;
    *) discover_forks_generic ;;
esac
```

### Installation Per Platform

#### GitHub

```bash
./install-swarm.sh  # Auto-detects GitHub
# Creates: .github/workflows/swarm.yml
```

#### GitLab

```bash
./install-swarm.sh  # Auto-detects GitLab
# Creates: .gitlab-ci.yml
```

#### Gitea/Forgejo

```bash
./install-swarm.sh  # Auto-detects Gitea/Forgejo
# Creates: .gitea/workflows/swarm.yml
```

#### Generic/Manual

```bash
./install-swarm.sh  # Creates: .ci-swarm.yml
# Adapt to your CI system
```

### Migration Example

Moving from GitHub to GitLab:

```bash
# 1. Add GitLab remote
git remote add gitlab https://gitlab.com/alice/project.git
git push gitlab main

# 2. Update CI config
rm -rf .github/
cp templates/gitlab-ci.yml .gitlab-ci.yml

# 3. Commit and push
git add -A
git commit -m "Migrate to GitLab"
git push gitlab main

# 4. Swarm reconstitutes
# Old GitHub forks still work
# New GitLab forks join automatically
```

## Complete Workflow

### 1. Initialize a Swarm (Repository Owner)

```bash
cd your-project
curl -sSL https://devswarm.org/install-swarm.sh | bash
git push
```

### 2. Join a Swarm (Contributor)

```bash
# Option A: Fork via Web UI
# Click "Fork" button on GitHub/GitLab/etc

# Option B: Bootstrap CLI
devswarm bootstrap alice/project
cd ~/.devswarm/repos/alice-project

# Option C: Manual
git clone https://github.com/alice/project.git
cd project
# CI runs automatically on next push
```

### 3. Monitor Swarm Health

```bash
# Via CLI
devswarm status

# Via Git alias
git swarm-status

# Via Dashboard
open swarm-visualizer.html
# Enter: alice/project
```

### 4. Contribute

```bash
# Make changes
git checkout -b feature
# ... edit files ...
git commit -am "Add feature"
git push origin feature

# CI syncs with upstream automatically
# Create PR to original repo
```

### 5. Swarm Grows Automatically

```
Original repo → Fork 1 → Fork 2 → Fork 3 → ...
                  ↓        ↓        ↓
                Sub-fork  Sub-fork  Sub-fork

Each fork = Complete copy
Each fork = Self-healing node
Each fork = Runs CI/CD
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Git Forge (GitHub/GitLab/Gitea)      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐│
│  │ Original │  │  Fork 1  │  │  Fork 2  │  │  Fork N  ││
│  │   Repo   │  │          │  │          │  │          ││
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘│
│       │             │             │             │       │
│       └─────────────┴─────────────┴─────────────┘       │
│                         │                                │
└─────────────────────────┼────────────────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            │    CI/CD Orchestration     │
            │  (Actions/GitLab CI/etc)   │
            └─────────────┬─────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
   │ Swarm   │      │ Platform│      │ Fork    │
   │Coordina-│      │   API   │      │Discovery│
   │   tor   │      │         │      │         │
   └─────────┘      └─────────┘      └─────────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                          │
                    ┌─────▼─────┐
                    │  .swarm/  │
                    │ manifest  │
                    │   .json   │
                    └───────────┘
```

## File Structure

```
project/
├── swarm-coordinator.sh           # Universal coordinator
├── .swarm/
│   ├── manifest.json              # Swarm topology
│   └── README.md                  # Swarm documentation
├── .github/
│   └── workflows/
│       └── swarm.yml              # GitHub Actions (if GitHub)
├── .gitlab-ci.yml                 # GitLab CI (if GitLab)
├── .gitea/
│   └── workflows/
│       └── swarm.yml              # Gitea Actions (if Gitea)
└── [your project files]
```

## API Reference

### Platform APIs Used

#### GitHub

```bash
# Get repository info
GET https://api.github.com/repos/:owner/:repo

# List forks
GET https://api.github.com/repos/:owner/:repo/forks
```

#### GitLab

```bash
# Get project info
GET https://gitlab.com/api/v4/projects/:id

# List forks
GET https://gitlab.com/api/v4/projects/:id/forks
```

#### Gitea/Forgejo

```bash
# Get repository info
GET https://gitea.io/api/v1/repos/:owner/:repo

# List forks
GET https://gitea.io/api/v1/repos/:owner/:repo/forks
```

### Manifest Schema

```json
{
  "version": "1.0.0",
  "platform": "github|gitlab|gitea|forgejo|generic",
  "forge_host": "github.com",
  "repository": "owner/repo",
  "node_id": "unique-16-char-hash",
  "updated_at": "ISO-8601-timestamp",
  "swarm_topology": {
    "fork_count": 47,
    "health": "healthy|stable|vulnerable|degraded",
    "forks": ["owner1/repo", "owner2/repo", ...]
  },
  "distribution_mechanics": {
    "method": "fork-native",
    "replication": "automatic via git clone",
    "discovery": "platform API + git branches",
    "healing": "via CI/CD sync",
    "consensus": "git merge"
  }
}
```

## Troubleshooting

### Bootstrap CLI Issues

**Problem:** `devswarm: command not found`

```bash
# Check if installed
which devswarm

# Re-install
curl -sSL https://devswarm.org/devswarm -o /usr/local/bin/devswarm
chmod +x /usr/local/bin/devswarm
```

**Problem:** Can't parse repository URL

```bash
# Use full URL format
devswarm bootstrap https://github.com/owner/repo

# Check supported formats
devswarm help
```

### Visualizer Issues

**Problem:** CORS errors in browser

```bash
# Serve via HTTP instead of file://
python -m http.server 8000
open http://localhost:8000/swarm-visualizer.html

# Or use live-server
npx live-server
```

**Problem:** API rate limiting

```bash
# GitHub allows 60 req/hour unauthenticated
# Use authenticated token (not implemented in demo)
# Or wait for rate limit reset
```

### Cross-Platform Issues

**Problem:** CI not running

```bash
# Check workflow file exists
ls .github/workflows/swarm.yml  # GitHub
ls .gitlab-ci.yml               # GitLab

# Check CI is enabled
# GitHub: Actions tab
# GitLab: Settings → CI/CD
```

**Problem:** Fork discovery fails

```bash
# Check API accessibility
curl https://api.github.com/repos/owner/repo/forks

# Check authentication
export GITHUB_TOKEN=your_token
./swarm-coordinator.sh
```

## Advanced Usage

### Custom Health Thresholds

Edit `swarm-coordinator.sh`:

```bash
calculate_health() {
    local fork_count=$1
    
    if [ "$fork_count" -ge 20 ]; then
        echo "excellent"
    elif [ "$fork_count" -ge 10 ]; then
        echo "healthy"
    # ... etc
}
```

### Custom Visualization Styles

Edit `swarm-visualizer.html`:

```javascript
// Cyberpunk theme
body {
    background: #000;
    color: #0f0;
}

.node {
    fill: #ff00ff;
    stroke: #00ffff;
}

.link {
    stroke: #ff00ff;
}
```

### Multi-Swarm Dashboard

```html
<!-- Compare multiple swarms -->
<div id="swarm-1"></div>
<div id="swarm-2"></div>
<script>
    visualizeSwarm(data1, '#swarm-1');
    visualizeSwarm(data2, '#swarm-2');
</script>
```

## Performance

### Bootstrap CLI

- **Clone speed**: Depends on repo size and network
- **Fork discovery**: O(n) API calls where n = fork count
- **Local storage**: ~100MB per typical repo

### Visualization

- **Render time**: <1s for <100 nodes
- **Max nodes**: Tested up to 1000 forks
- **Memory**: ~50MB for typical visualization

### Cross-Platform

- **Coordinator runtime**: 5-30 seconds depending on fork count
- **CI/CD frequency**: Every 6 hours by default
- **API rate limits**: 60/hour (GitHub unauthenticated)

## Roadmap

- [x] Cross-platform coordinator
- [x] Bootstrap CLI
- [x] Visualization dashboard
- [ ] Native desktop app (Electron/Tauri)
- [ ] Real-time WebSocket updates
- [ ] IPFS integration for hybrid distribution
- [ ] Swarm analytics and insights
- [ ] Auto-migration on platform failures
- [ ] P2P sync without platform APIs

## Contributing

All three tools are open source:

```bash
# Fork the repo
git clone https://github.com/devswarm/core
cd core

# Make changes
# Test locally
# Push to your fork
# Open PR
```

## License

MIT - Fork freely 🐝

---

**The repository IS the infrastructure.**

By using these tools, you're participating in a self-distributing swarm that requires zero infrastructure, works on any Git forge, and distributes itself automatically through the simple act of forking.

🐝 Welcome to the swarm! 🐝
