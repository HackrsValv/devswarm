# Cross-Platform Git Forge Support

## Philosophy

**Write once, swarm anywhere.**

The self-distributing swarm should work identically on:
- GitHub
- GitLab  
- Gitea
- Forgejo
- Codeberg
- Any Git host with CI/CD

## Abstraction Layer

### Git Operations (Universal)
```
✓ clone, fetch, push (works everywhere)
✓ branches, commits, merges (git-native)
✓ remotes (standard git)
```

### Forge-Specific APIs (Requires Abstraction)
```
- Fork discovery
- Fork creation
- CI/CD configuration
- API authentication
- Webhooks/triggers
```

## Platform Detection

### Auto-detect from Git remote:

```python
def detect_forge(remote_url: str) -> str:
    """Detect Git forge from remote URL"""
    
    patterns = {
        'github': r'github\.com',
        'gitlab': r'gitlab\.com|gitlab\.',
        'gitea': r'gitea\.',
        'forgejo': r'codeberg\.org|forgejo\.',
        'bitbucket': r'bitbucket\.org',
        'sourcehut': r'git\.sr\.ht'
    }
    
    for forge, pattern in patterns.items():
        if re.search(pattern, remote_url):
            return forge
    
    # Try to detect from API endpoint
    return detect_via_api(remote_url)
```

## CI/CD Adapters

### GitHub Actions (Reference Implementation)
```yaml
name: Swarm Node
on: [push, fork, workflow_dispatch, schedule]
jobs:
  coordinate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./swarm-coordinator.sh
```

### GitLab CI (.gitlab-ci.yml)
```yaml
swarm-coordinator:
  image: alpine:latest
  script:
    - apk add --no-cache git curl jq
    - ./swarm-coordinator.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - if: $CI_PIPELINE_SOURCE == "schedule"
  schedule:
    - cron: "0 */6 * * *"
```

### Gitea/Forgejo Actions (.gitea/workflows/swarm.yml)
```yaml
name: Swarm Node
on:
  push:
  schedule:
    - cron: '0 */6 * * *'
jobs:
  coordinate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: ./swarm-coordinator.sh
```

### Woodpecker CI (.woodpecker.yml) - for self-hosted Gitea/Forgejo
```yaml
pipeline:
  swarm-coordinator:
    image: alpine:latest
    commands:
      - apk add --no-cache git curl jq bash
      - ./swarm-coordinator.sh
    when:
      event: [push, cron]
```

## Fork Discovery API Abstraction

### GitHub
```bash
curl https://api.github.com/repos/owner/repo/forks
```

### GitLab
```bash
curl https://gitlab.com/api/v4/projects/:id/forks
```

### Gitea/Forgejo
```bash
curl https://gitea.instance/api/v1/repos/owner/repo/forks
```

### Sourcehut (sr.ht)
```bash
# No fork API - use git refs instead
git ls-remote https://git.sr.ht/~user/repo
```

## Universal Swarm Coordinator (Platform-Agnostic)

```bash
#!/bin/bash
# swarm-coordinator.sh - Works on any Git forge

set -e

# Detect platform
detect_platform() {
    # Check CI environment variables
    if [ -n "$GITHUB_ACTIONS" ]; then
        echo "github"
    elif [ -n "$GITLAB_CI" ]; then
        echo "gitlab"
    elif [ -n "$GITEA_ACTIONS" ]; then
        echo "gitea"
    elif [ -n "$FORGEJO_ACTIONS" ]; then
        echo "forgejo"
    elif [ -n "$CI_WOODPECKER" ]; then
        echo "woodpecker"
    else
        # Detect from git remote
        REMOTE=$(git remote get-url origin)
        case "$REMOTE" in
            *github.com*) echo "github" ;;
            *gitlab.com*|*gitlab.*) echo "gitlab" ;;
            *gitea.*) echo "gitea" ;;
            *codeberg.org*) echo "forgejo" ;;
            *) echo "generic" ;;
        esac
    fi
}

PLATFORM=$(detect_platform)
echo "Detected platform: $PLATFORM"

# Get repository info (platform-agnostic)
get_repo_info() {
    # Extract from git remote
    REMOTE=$(git remote get-url origin)
    
    # Parse owner/repo from various URL formats
    if [[ "$REMOTE" =~ ^https?://([^/]+)/([^/]+)/([^/]+)(\.git)?$ ]]; then
        FORGE_HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"
        REPO="${BASH_REMATCH[3]%.git}"
    elif [[ "$REMOTE" =~ ^git@([^:]+):([^/]+)/([^/]+)(\.git)?$ ]]; then
        FORGE_HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"
        REPO="${BASH_REMATCH[3]%.git}"
    fi
    
    echo "FORGE_HOST=$FORGE_HOST"
    echo "OWNER=$OWNER"
    echo "REPO=$REPO"
}

eval $(get_repo_info)

# Discover forks (platform-specific)
discover_forks() {
    case "$PLATFORM" in
        github)
            curl -s "https://api.github.com/repos/$OWNER/$REPO/forks?per_page=100" \
                | jq -r '.[].full_name'
            ;;
        gitlab)
            PROJECT_ID="${OWNER}%2F${REPO}"
            curl -s "https://${FORGE_HOST}/api/v4/projects/${PROJECT_ID}/forks" \
                | jq -r '.[].path_with_namespace'
            ;;
        gitea|forgejo)
            curl -s "https://${FORGE_HOST}/api/v1/repos/${OWNER}/${REPO}/forks" \
                | jq -r '.[].full_name'
            ;;
        *)
            # Fallback: no API, just count git refs
            echo "generic-git-host (no fork API)"
            ;;
    esac
}

# Count forks
FORKS=$(discover_forks)
FORK_COUNT=$(echo "$FORKS" | grep -v '^$' | wc -l)

echo "Discovered $FORK_COUNT forks:"
echo "$FORKS"

# Create/update swarm manifest (platform-agnostic)
mkdir -p .swarm

cat > .swarm/manifest.json << EOF
{
  "version": "1.0.0",
  "platform": "$PLATFORM",
  "forge_host": "$FORGE_HOST",
  "repository": "$OWNER/$REPO",
  "node_id": "$(echo "$OWNER/$REPO" | sha256sum | cut -c1-16)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "swarm_topology": {
    "fork_count": $FORK_COUNT,
    "forks": $(echo "$FORKS" | jq -R . | jq -s .)
  }
}
EOF

echo "✓ Swarm manifest updated"

# Commit changes (if any)
git config user.name "Swarm Coordinator"
git config user.email "swarm@devswarm.local"

if ! git diff --quiet .swarm/; then
    git add .swarm/
    git commit -m "🐝 Swarm: Update topology ($FORK_COUNT forks on $PLATFORM)"
    
    # Try to push (may fail on forks without write access - that's OK)
    git push origin HEAD 2>/dev/null || echo "Push skipped (no write access)"
fi

echo "✓ Swarm coordination complete"
```

## Installation Templates

### Multi-Platform Installer

```bash
#!/bin/bash
# install-swarm.sh - Auto-detects platform and installs appropriate CI config

set -e

detect_platform() {
    REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    
    case "$REMOTE" in
        *github.com*) echo "github" ;;
        *gitlab.com*|*gitlab.*) echo "gitlab" ;;
        *gitea.*) echo "gitea" ;;
        *codeberg.org*) echo "forgejo" ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM=$(detect_platform)

echo "Detected platform: $PLATFORM"
echo "Installing swarm coordinator..."

# Download universal coordinator script
curl -sSL https://devswarm.org/swarm-coordinator.sh > swarm-coordinator.sh
chmod +x swarm-coordinator.sh

# Install platform-specific CI config
case "$PLATFORM" in
    github)
        mkdir -p .github/workflows
        curl -sSL https://devswarm.org/templates/github-actions.yml \
            > .github/workflows/swarm.yml
        echo "✓ Installed GitHub Actions workflow"
        ;;
    
    gitlab)
        curl -sSL https://devswarm.org/templates/gitlab-ci.yml \
            > .gitlab-ci.yml
        echo "✓ Installed GitLab CI config"
        ;;
    
    gitea|forgejo)
        mkdir -p .gitea/workflows
        curl -sSL https://devswarm.org/templates/gitea-actions.yml \
            > .gitea/workflows/swarm.yml
        echo "✓ Installed Gitea/Forgejo Actions workflow"
        ;;
    
    *)
        echo "⚠ Unknown platform - installing generic CI config"
        cat > .ci-swarm.yml << 'EOF'
# Generic CI configuration
# Adapt this to your CI system
script:
  - ./swarm-coordinator.sh
schedule:
  - "0 */6 * * *"
EOF
        ;;
esac

# Commit
git add -A
git commit -m "🐝 Initialize self-distributing swarm

Platform: $PLATFORM
Installed: CI configuration + coordinator script

Fork this repo to join the swarm!"

echo ""
echo "✓ Swarm initialized!"
echo ""
echo "Next steps:"
echo "  1. git push"
echo "  2. Share repo URL"
echo "  3. Others fork = automatic swarm growth"
```

## Platform Feature Matrix

| Feature | GitHub | GitLab | Gitea | Forgejo | Generic Git |
|---------|--------|--------|-------|---------|-------------|
| Fork discovery | ✅ API | ✅ API | ✅ API | ✅ API | ⚠️ Manual |
| Fork creation | ✅ Button | ✅ Button | ✅ Button | ✅ Button | git clone |
| CI/CD | Actions | GitLab CI | Actions | Actions | Varies |
| Webhooks | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| API auth | Token | Token | Token | Token | N/A |
| Public repos | ✅ Free | ✅ Free | ✅ Free | ✅ Free | ✅ |

## Fallback Strategy (Generic Git)

For hosts without fork APIs:

```bash
# Announce forks via git branches
git checkout -b "swarm/fork-by-alice"
git push origin swarm/fork-by-alice

# Discover via branch listing
git ls-remote origin 'refs/heads/swarm/*'
```

## Cross-Platform Bootstrap

```bash
# Works on ANY platform
git clone https://github.com/user/repo.git
# OR
git clone https://gitlab.com/user/repo.git
# OR  
git clone https://codeberg.org/user/repo.git

cd repo

# Platform auto-detected
./swarm-coordinator.sh
```

## Benefits

1. **Write Once, Run Anywhere**
   - Same coordinator script
   - Platform-specific CI wrappers
   - Git-native fallbacks

2. **No Vendor Lock-in**
   - Switch platforms = change CI config
   - Swarm topology preserved in git
   - Fork graph migrates with repo

3. **Graceful Degradation**
   - Full API support → Best experience
   - Limited API → Basic features
   - No API → Manual coordination

4. **Federation Ready**
   - Swarm can span multiple platforms
   - GitHub fork → GitLab fork → Gitea fork
   - Git protocol as universal bridge

## Migration Example

```bash
# Start on GitHub
git clone https://github.com/alice/project
# ... swarm grows to 50 GitHub forks ...

# Migrate to GitLab
git remote add gitlab https://gitlab.com/alice/project.git
git push gitlab main

# Update CI config
rm -rf .github/
cp .gitlab-ci.yml.template .gitlab-ci.yml
git add -A
git commit -m "Migrate to GitLab"
git push gitlab main

# Swarm reconstitutes on GitLab
# Old GitHub forks still work via git protocol
# New GitLab forks join automatically
```

## The Ultimate Goal

**Any Git forge becomes a swarm host.**

No platform-specific lock-in.
Fork button = universal "join swarm" mechanism.
Git protocol = universal coordination layer.

---

Next: Bootstrap CLI tool that works everywhere.
