#!/bin/bash
# Universal Swarm Coordinator
# Works on: GitHub, GitLab, Gitea, Forgejo, Codeberg, any Git host

set -euo pipefail

VERSION="1.0.0"
SWARM_DIR=".swarm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[SWARM]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

detect_platform() {
    # Check CI environment variables first
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "github"
        return
    elif [ -n "${GITLAB_CI:-}" ]; then
        echo "gitlab"
        return
    elif [ -n "${GITEA_ACTIONS:-}" ]; then
        echo "gitea"
        return
    elif [ -n "${FORGEJO_ACTIONS:-}" ]; then
        echo "forgejo"
        return
    elif [ -n "${CI_WOODPECKER:-}" ]; then
        echo "woodpecker"
        return
    fi
    
    # Fall back to git remote detection
    local remote
    remote=$(git remote get-url origin 2>/dev/null || echo "")
    
    case "$remote" in
        *github.com*) echo "github" ;;
        *gitlab.com*|*gitlab.*) echo "gitlab" ;;
        *gitea.*) echo "gitea" ;;
        *codeberg.org*|*forgejo.*) echo "forgejo" ;;
        *git.sr.ht*) echo "sourcehut" ;;
        *bitbucket.org*) echo "bitbucket" ;;
        *) echo "generic" ;;
    esac
}

# ============================================================================
# REPOSITORY PARSING
# ============================================================================

parse_repo_info() {
    local remote
    remote=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [[ -z "$remote" ]]; then
        error "No git remote found"
        return 1
    fi
    
    # Parse HTTPS URLs: https://host/owner/repo.git
    if [[ "$remote" =~ ^https?://([^/]+)/([^/]+)/([^/]+)(\.git)?$ ]]; then
        FORGE_HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"
        REPO="${BASH_REMATCH[3]%.git}"
    # Parse SSH URLs: git@host:owner/repo.git
    elif [[ "$remote" =~ ^git@([^:]+):([^/]+)/([^/]+)(\.git)?$ ]]; then
        FORGE_HOST="${BASH_REMATCH[1]}"
        OWNER="${BASH_REMATCH[2]}"
        REPO="${BASH_REMATCH[3]%.git}"
    else
        error "Could not parse git remote: $remote"
        return 1
    fi
    
    export FORGE_HOST OWNER REPO
}

# ============================================================================
# FORK DISCOVERY (Platform-Specific)
# ============================================================================

discover_forks_github() {
    local api_url="https://api.github.com/repos/$OWNER/$REPO/forks?per_page=100"
    local auth_header=""
    
    # Use token if available (for rate limiting)
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header="-H Authorization: Bearer $GITHUB_TOKEN"
    fi
    
    curl -sSL $auth_header "$api_url" 2>/dev/null \
        | jq -r '.[].full_name' 2>/dev/null \
        || echo ""
}

discover_forks_gitlab() {
    local project_id="${OWNER}%2F${REPO}"
    local api_url="https://${FORGE_HOST}/api/v4/projects/${project_id}/forks?per_page=100"
    local auth_header=""
    
    if [ -n "${GITLAB_TOKEN:-}" ]; then
        auth_header="-H PRIVATE-TOKEN: $GITLAB_TOKEN"
    fi
    
    curl -sSL $auth_header "$api_url" 2>/dev/null \
        | jq -r '.[].path_with_namespace' 2>/dev/null \
        || echo ""
}

discover_forks_gitea() {
    local api_url="https://${FORGE_HOST}/api/v1/repos/${OWNER}/${REPO}/forks?limit=100"
    local auth_header=""
    
    if [ -n "${GITEA_TOKEN:-}" ]; then
        auth_header="-H Authorization: token $GITEA_TOKEN"
    fi
    
    curl -sSL $auth_header "$api_url" 2>/dev/null \
        | jq -r '.[].full_name' 2>/dev/null \
        || echo ""
}

discover_forks_forgejo() {
    # Forgejo uses same API as Gitea
    discover_forks_gitea
}

discover_forks_generic() {
    # Fallback: discover via swarm/* branches
    git ls-remote origin 'refs/heads/swarm/fork-*' 2>/dev/null \
        | sed 's|.*refs/heads/swarm/fork-||' \
        || echo ""
}

discover_forks() {
    case "$PLATFORM" in
        github) discover_forks_github ;;
        gitlab) discover_forks_gitlab ;;
        gitea) discover_forks_gitea ;;
        forgejo) discover_forks_forgejo ;;
        *) discover_forks_generic ;;
    esac
}

# ============================================================================
# SWARM HEALTH CALCULATION
# ============================================================================

calculate_health() {
    local fork_count=$1
    
    if [ "$fork_count" -ge 10 ]; then
        echo "healthy"
    elif [ "$fork_count" -ge 6 ]; then
        echo "stable"
    elif [ "$fork_count" -ge 3 ]; then
        echo "vulnerable"
    else
        echo "degraded"
    fi
}

# ============================================================================
# MANIFEST GENERATION
# ============================================================================

generate_manifest() {
    local fork_count=$1
    local forks_json=$2
    local health=$3
    
    local node_id
    node_id=$(echo "$OWNER/$REPO" | sha256sum | cut -c1-16)
    
    mkdir -p "$SWARM_DIR"
    
    cat > "$SWARM_DIR/manifest.json" << EOF
{
  "version": "$VERSION",
  "platform": "$PLATFORM",
  "forge_host": "$FORGE_HOST",
  "repository": "$OWNER/$REPO",
  "node_id": "$node_id",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "swarm_topology": {
    "fork_count": $fork_count,
    "health": "$health",
    "forks": $forks_json
  },
  "distribution_mechanics": {
    "method": "fork-native",
    "replication": "automatic via git clone",
    "discovery": "platform API + git branches",
    "healing": "via CI/CD sync",
    "consensus": "git merge"
  }
}
EOF
}

# ============================================================================
# UPSTREAM SYNC (for forks)
# ============================================================================

sync_with_upstream() {
    # Check if this is a fork (has upstream remote or parent info)
    local upstream_url=""
    
    # Try to get upstream from git remotes
    if git remote | grep -q "^upstream$"; then
        upstream_url=$(git remote get-url upstream)
        log "Found upstream remote: $upstream_url"
    else
        # Try to detect from platform API
        case "$PLATFORM" in
            github)
                upstream_url=$(curl -sSL "https://api.github.com/repos/$OWNER/$REPO" 2>/dev/null \
                    | jq -r '.parent.html_url // empty' 2>/dev/null || echo "")
                ;;
            gitlab)
                local project_id="${OWNER}%2F${REPO}"
                upstream_url=$(curl -sSL "https://${FORGE_HOST}/api/v4/projects/${project_id}" 2>/dev/null \
                    | jq -r '.forked_from_project.http_url_to_repo // empty' 2>/dev/null || echo "")
                ;;
        esac
        
        if [ -n "$upstream_url" ]; then
            log "Detected fork parent: $upstream_url"
            git remote add upstream "$upstream_url" 2>/dev/null || true
        fi
    fi
    
    # Sync if upstream exists
    if [ -n "$upstream_url" ]; then
        log "Syncing with upstream..."
        git fetch upstream 2>/dev/null || warn "Failed to fetch upstream"
        
        # Try to merge upstream changes
        local main_branch
        main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
        
        git merge upstream/"$main_branch" --no-edit 2>/dev/null \
            && log "✓ Merged upstream changes" \
            || warn "Could not auto-merge upstream (manual merge may be needed)"
    fi
}

# ============================================================================
# GIT COMMIT
# ============================================================================

commit_changes() {
    # Configure git if needed
    git config user.name "Swarm Coordinator" 2>/dev/null || true
    git config user.email "swarm@devswarm.local" 2>/dev/null || true
    
    # Check if there are changes
    if ! git diff --quiet "$SWARM_DIR/" 2>/dev/null; then
        git add "$SWARM_DIR/"
        git commit -m "🐝 Swarm: Update topology ($1 forks, $2 health, $PLATFORM)" \
            || warn "Could not commit changes"
        
        # Try to push (may fail on forks without write access)
        git push origin HEAD 2>/dev/null \
            && log "✓ Pushed swarm state" \
            || warn "Push skipped (no write access or conflicts)"
    else
        log "No changes to swarm state"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "Universal Swarm Coordinator v$VERSION"
    
    # Detect platform
    PLATFORM=$(detect_platform)
    log "Platform: $PLATFORM"
    
    # Parse repository info
    if ! parse_repo_info; then
        error "Failed to parse repository info"
        exit 1
    fi
    log "Repository: $OWNER/$REPO on $FORGE_HOST"
    
    # Check for required tools
    for tool in git curl jq; do
        if ! command -v "$tool" &>/dev/null; then
            error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    # Sync with upstream if this is a fork
    sync_with_upstream
    
    # Discover forks
    log "Discovering swarm topology..."
    FORKS=$(discover_forks)
    FORK_COUNT=$(echo "$FORKS" | grep -v '^$' | wc -l)
    
    # Convert to JSON array
    FORKS_JSON=$(echo "$FORKS" | jq -R . | jq -s 'map(select(length > 0))')
    
    log "Discovered $FORK_COUNT forks"
    
    # Calculate health
    HEALTH=$(calculate_health "$FORK_COUNT")
    log "Swarm health: $HEALTH"
    
    # Generate manifest
    generate_manifest "$FORK_COUNT" "$FORKS_JSON" "$HEALTH"
    log "✓ Manifest updated"
    
    # Commit and push
    commit_changes "$FORK_COUNT" "$HEALTH"
    
    # Health warnings
    case "$HEALTH" in
        degraded)
            warn "⚠️  Swarm is DEGRADED (< 3 forks)"
            warn "Share this repo to improve resilience!"
            ;;
        vulnerable)
            warn "Swarm is VULNERABLE (< 6 forks)"
            warn "Consider encouraging more forks"
            ;;
    esac
    
    log "✓ Coordination complete"
    
    # Output summary
    cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SWARM STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Platform:  $PLATFORM
Repository: $OWNER/$REPO
Forks:     $FORK_COUNT
Health:    $HEALTH
Updated:   $(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
}

# Run main
main "$@"
