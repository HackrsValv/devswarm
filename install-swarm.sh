#!/bin/bash
# Universal Swarm Installer
# Detects your Git forge and installs the appropriate CI configuration

set -euo pipefail

VERSION="1.0.0"
BASE_URL="https://raw.githubusercontent.com/devswarm/core/main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[SWARM]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════╗
║                                               ║
║   🐝  SELF-DISTRIBUTING SWARM INSTALLER  🐝   ║
║                                               ║
║   Write once, swarm anywhere.                 ║
║   Works on any Git forge.                     ║
║                                               ║
╚═══════════════════════════════════════════════╝
EOF
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

detect_platform() {
    local remote
    remote=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [[ -z "$remote" ]]; then
        error "Not in a git repository or no remote 'origin' configured"
    fi
    
    case "$remote" in
        *github.com*) echo "github" ;;
        *gitlab.com*|*gitlab.*) echo "gitlab" ;;
        *gitea.*) echo "gitea" ;;
        *codeberg.org*|*forgejo.*) echo "forgejo" ;;
        *git.sr.ht*) echo "sourcehut" ;;
        *) echo "generic" ;;
    esac
}

# ============================================================================
# DOWNLOAD FILES
# ============================================================================

download_file() {
    local url=$1
    local dest=$2
    
    if curl -sSL "$url" -o "$dest" 2>/dev/null; then
        return 0
    else
        # Fallback to local templates if available
        local filename=$(basename "$dest")
        if [ -f "templates/$filename" ]; then
            cp "templates/$filename" "$dest"
            return 0
        fi
        return 1
    fi
}

# ============================================================================
# INSTALL COORDINATOR
# ============================================================================

install_coordinator() {
    log "Installing universal swarm coordinator..."
    
    if download_file "$BASE_URL/swarm-coordinator.sh" "swarm-coordinator.sh"; then
        chmod +x swarm-coordinator.sh
        log "✓ Coordinator script installed"
    else
        error "Failed to download coordinator script"
    fi
}

# ============================================================================
# INSTALL CI CONFIG
# ============================================================================

install_github_actions() {
    log "Installing GitHub Actions workflow..."
    
    mkdir -p .github/workflows
    
    if download_file "$BASE_URL/templates/github-actions.yml" ".github/workflows/swarm.yml"; then
        log "✓ GitHub Actions workflow installed"
        info "  Location: .github/workflows/swarm.yml"
        info "  The workflow will run automatically on push and every 6 hours"
    else
        error "Failed to download GitHub Actions template"
    fi
}

install_gitlab_ci() {
    log "Installing GitLab CI configuration..."
    
    if download_file "$BASE_URL/templates/gitlab-ci.yml" ".gitlab-ci.yml"; then
        log "✓ GitLab CI configuration installed"
        info "  Location: .gitlab-ci.yml"
        info "  Configure a schedule in GitLab UI: CI/CD -> Schedules"
        info "  Recommended cron: 0 */6 * * * (every 6 hours)"
    else
        error "Failed to download GitLab CI template"
    fi
}

install_gitea_actions() {
    log "Installing Gitea Actions workflow..."
    
    mkdir -p .gitea/workflows
    
    if download_file "$BASE_URL/templates/gitea-actions.yml" ".gitea/workflows/swarm.yml"; then
        log "✓ Gitea Actions workflow installed"
        info "  Location: .gitea/workflows/swarm.yml"
    else
        error "Failed to download Gitea Actions template"
    fi
}

install_forgejo_actions() {
    log "Installing Forgejo Actions workflow..."
    
    mkdir -p .forgejo/workflows
    
    if download_file "$BASE_URL/templates/gitea-actions.yml" ".forgejo/workflows/swarm.yml"; then
        log "✓ Forgejo Actions workflow installed"
        info "  Location: .forgejo/workflows/swarm.yml"
    else
        warn "Failed to download Forgejo Actions template, trying Gitea path..."
        install_gitea_actions
    fi
}

install_woodpecker_ci() {
    log "Installing Woodpecker CI configuration..."
    
    if download_file "$BASE_URL/templates/woodpecker-ci.yml" ".woodpecker.yml"; then
        log "✓ Woodpecker CI configuration installed"
        info "  Location: .woodpecker.yml"
        info "  Configure cron schedule in Woodpecker UI"
    else
        error "Failed to download Woodpecker CI template"
    fi
}

install_generic() {
    warn "Unknown platform - installing generic CI template"
    
    cat > .ci-swarm.yml << 'EOF'
# Generic CI Configuration for Self-Distributing Swarm
# Adapt this to your specific CI system

# Required dependencies: bash, git, curl, jq

script:
  - chmod +x ./swarm-coordinator.sh
  - ./swarm-coordinator.sh

# Schedule (adapt to your CI syntax)
schedule:
  - "0 */6 * * *"  # Every 6 hours

# Triggers (adapt to your CI syntax)
on:
  - push
  - schedule
EOF
    
    log "✓ Generic CI template created"
    info "  Location: .ci-swarm.yml"
    info "  You'll need to adapt this to your specific CI system"
}

install_ci_config() {
    local platform=$1
    
    case "$platform" in
        github) install_github_actions ;;
        gitlab) install_gitlab_ci ;;
        gitea) install_gitea_actions ;;
        forgejo) install_forgejo_actions ;;
        *) install_generic ;;
    esac
}

# ============================================================================
# CREATE README
# ============================================================================

create_readme() {
    local platform=$1
    
    cat > .swarm/README.md << EOF
# Self-Distributing Swarm

This repository is part of a self-distributing swarm.

## What is this?

A self-distributing swarm is a repository that:
- Automatically replicates via Git's fork mechanism
- Maintains its own health and topology
- Requires zero infrastructure (uses $platform's features)
- Is censorship-resistant (must delete ALL forks)

## How it works

1. **Fork = Replication**: Each fork is a complete copy
2. **CI/CD = Coordination**: Automated sync every 6 hours
3. **Git = Consensus**: Merge conflicts resolved via git
4. **API = Discovery**: Platform API discovers all forks

## Join the swarm

\`\`\`bash
# Fork this repo (or click the Fork button)
# Your fork automatically becomes part of the swarm
# CI/CD runs automatically to sync with the network
\`\`\`

## Swarm Health

Check \`.swarm/manifest.json\` for current topology:
- **Healthy**: 10+ forks
- **Stable**: 6-9 forks  
- **Vulnerable**: 3-5 forks
- **Degraded**: <3 forks

## Philosophy

Based on the [Unhosted](https://unhosted.org) philosophy:
- Users own their copies (via fork)
- No central server required
- Platform-agnostic (works on any Git forge)
- Consent-based participation (you choose to fork)

## Platform: $platform

This swarm is currently running on $platform but can migrate to any Git forge.

---

**By forking this repo, you're already participating in the swarm.** 🐝
EOF
    
    log "✓ Created swarm README"
}

# ============================================================================
# GIT COMMIT
# ============================================================================

commit_installation() {
    local platform=$1
    
    git config user.name "Swarm Installer" 2>/dev/null || true
    git config user.email "install@devswarm.local" 2>/dev/null || true
    
    git add -A
    
    cat << EOF | git commit -F -
🐝 Initialize self-distributing swarm

Platform: $platform
Version: $VERSION

Installed:
- Universal swarm coordinator
- CI/CD configuration for $platform
- Swarm documentation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HOW IT WORKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fork this repo = Join the swarm
Every fork = Complete copy
CI/CD syncs every 6 hours
Git provides consensus

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. git push
2. Share repo URL
3. Others fork = swarm grows automatically

The swarm is self-distributing, self-healing, 
and requires zero infrastructure. 🐝
EOF
    
    log "✓ Changes committed"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    clear
    banner
    echo ""
    
    log "Universal Swarm Installer v$VERSION"
    echo ""
    
    # Verify git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        error "Not in a git repository. Initialize with: git init"
    fi
    
    # Detect platform
    PLATFORM=$(detect_platform)
    log "Detected platform: $PLATFORM"
    echo ""
    
    # Confirm installation
    info "This will install:"
    info "  • Universal swarm coordinator script"
    info "  • CI/CD configuration for $PLATFORM"
    info "  • Swarm documentation"
    echo ""
    
    read -p "Continue? (y/N) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Installation cancelled"
        exit 0
    fi
    
    echo ""
    log "Installing swarm components..."
    echo ""
    
    # Install coordinator
    install_coordinator
    
    # Install CI config
    install_ci_config "$PLATFORM"
    
    # Create swarm directory and README
    mkdir -p .swarm
    create_readme "$PLATFORM"
    
    # Commit changes
    echo ""
    log "Committing installation..."
    commit_installation "$PLATFORM"
    
    # Success message
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ SWARM INSTALLATION COMPLETE${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    info "Next steps:"
    echo "  1. git push origin main"
    echo "  2. Share your repo URL"
    echo "  3. Each fork joins the swarm automatically"
    echo ""
    info "The swarm coordinator will run:"
    echo "  • On every push"
    echo "  • Every 6 hours automatically"
    echo "  • Manually via CI/CD interface"
    echo ""
    info "Check swarm health:"
    echo "  cat .swarm/manifest.json | jq ."
    echo ""
    echo -e "${CYAN}🐝 Welcome to the swarm! 🐝${NC}"
    echo ""
}

# Run
main "$@"
