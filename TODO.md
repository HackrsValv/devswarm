# DevSwarm TODO

## Active Work (Priority D - All of the Above)

### ✅ Phase 1: Pair Editor (DONE - 2025-12-12 00:30)
- [x] Build real-time collaborative editor (pair-editor.html)
- [x] Integrate Yjs CRDT for conflict-free editing
- [x] Add Monaco editor (VS Code engine)
- [x] WebSocket sync via Hocuspocus
- [x] Chat sidebar for communication
- [x] Write comprehensive pairing guide
- [x] Test with public server (demos.yjs.dev)

### 🔄 Phase 2: IPFS Fragment Storage (IN PROGRESS)

#### Step 1: Enhance swarm-coordinator.sh (Tonight)
- [ ] Add IPFS detection in coordinator
- [ ] Pin manifest.json to IPFS on each CI run
- [ ] Update manifest with IPFS CID
- [ ] Optional: Pin to Pinata/web3.storage if token available
- [ ] Test on GitHub Actions with IPFS installed

#### Step 2: Package Command (Tomorrow)
- [ ] Create `devswarm package` command
- [ ] Implement tar compression of project
- [ ] Add age encryption (user's key)
- [ ] Integrate zfec for erasure coding (k=6, m=3)
- [ ] Upload 9 fragments to IPFS
- [ ] Generate manifest in .swarm/environments.json
- [ ] Test with small project (1-10 MB)

#### Step 3: Bootstrap Command (Weekend)
- [ ] Create `devswarm bootstrap --environment NAME`
- [ ] Fetch environment manifest from swarm
- [ ] Discover fragment locations (IPFS + fork network)
- [ ] Download ≥6 fragments in parallel
- [ ] Reconstruct using zfec decoder
- [ ] Decrypt with age
- [ ] Extract to ~/.devswarm/environments/NAME
- [ ] Test end-to-end: package → push → bootstrap on new machine

### 🚧 Phase 3: Multi-Backend Storage (Week 2)

#### GitHub Releases Backend
- [ ] Upload fragments as release assets
- [ ] Tag releases with environment version
- [ ] Fetch from releases API
- [ ] Fall back to IPFS if release deleted

#### S3 Backend (Optional)
- [ ] Add S3 uploader (boto3)
- [ ] User configures bucket in ~/.devswarm/config.yml
- [ ] Upload fragments to S3
- [ ] Fetch with presigned URLs

#### Storacha/web3.storage Backend
- [ ] Integrate web3.storage client
- [ ] Upload via their API
- [ ] Leverage Filecoin backing

### 🔮 Phase 4: CRDT Agent Coordination (Week 3)

#### Task Queue in CRDT
- [ ] Define task schema (id, type, description, status, result)
- [ ] Create shared Yjs array for tasks
- [ ] Build CLI: `devswarm task add "description"`
- [ ] Agents read from task queue
- [ ] Agents write results back to CRDT
- [ ] Test with dummy agent (echo task)

#### Agent Spawning
- [ ] Define agents in manifest (outliner, implementer, etc.)
- [ ] Docker images for each agent
- [ ] Bootstrap spawns agents automatically
- [ ] Agents connect to CRDT room
- [ ] Monitor agent health in coordinator

### 📚 Documentation (Ongoing)

- [ ] Blog post: "Self-Distributing Swarms Explained"
- [ ] Architecture diagram (all 5 layers)
- [ ] Video demo: Package → Bootstrap → Collaborate
- [ ] Contributing guide for swarm participants
- [ ] Security best practices
- [ ] Roadmap to 1.0

---

## Immediate Action Items (Tonight/Tomorrow)

### 1. Test Pair Editor
```bash
# Open pair-editor.html
# Connect to: wss://demos.yjs.dev
# Room: devswarm-main
# Verify real-time sync works
```

### 2. Install IPFS Dependencies
```bash
# Python
pip install ipfshttpclient zfec pyage

# CLI tools
brew install ipfs age

# Start IPFS daemon
ipfs init
ipfs daemon &
```

### 3. Prototype Fragment Encoding
```bash
# Create test script
cat > test-fragments.py << 'EOF'
import zfec
import subprocess
import json

# Test data
data = b"Hello DevSwarm! " * 1000  # ~16 KB

# Encode
encoder = zfec.Encoder(k=6, m=3)
fragments = encoder.encode(data)

# Upload to IPFS
cids = []
for i, frag in enumerate(fragments):
    result = subprocess.run(
        ["ipfs", "add", "-Q", "-"],
        input=frag,
        capture_output=True
    )
    cid = result.stdout.decode().strip()
    cids.append(cid)
    print(f"Fragment {i}: {cid}")

# Fetch and reconstruct (simulate k=6)
fetched = []
for cid in cids[:6]:
    result = subprocess.run(
        ["ipfs", "cat", cid],
        capture_output=True
    )
    fetched.append(result.stdout)

# Decode
decoder = zfec.Decoder(k=6, m=3)
reconstructed = decoder.decode(fetched)

# Verify
assert reconstructed == data
print("✓ Reconstruction successful!")
print(json.dumps({"fragments": cids}, indent=2))
EOF

python3 test-fragments.py
```

### 4. Update README
```bash
# Add section on pair programming
# Link to PAIR_PROGRAMMING.md
# Add roadmap section
```

### 5. Commit Progress
```bash
git add -A
git commit -m "🐝 Add pair programming editor + IPFS prototype plan"
git push origin main

# Swarm will propagate to all forks
```

---

## Dependencies Needed

### Python Packages
```bash
pip install \
  ipfshttpclient \  # IPFS API client
  zfec \            # Reed-Solomon erasure coding
  pyage \           # Age encryption (or use CLI)
  boto3             # AWS S3 (optional)
```

### System Tools
```bash
# macOS
brew install ipfs age jq

# Linux
# IPFS: https://docs.ipfs.tech/install/
# age: https://github.com/FiloSottile/age#installation
apt-get install jq
```

### Node.js (for sync server)
```bash
npm install -g @hocuspocus/server
```

---

## Testing Checklist

### Pair Editor
- [ ] Open pair-editor.html in 2 browsers
- [ ] Connect to same room
- [ ] Type in one, see in other instantly
- [ ] Test chat
- [ ] Test with 3+ peers
- [ ] Test reconnection after disconnect

### IPFS Integration
- [ ] `ipfs daemon` running
- [ ] Can add files: `echo "test" | ipfs add`
- [ ] Can retrieve: `ipfs cat <CID>`
- [ ] Test with 10 MB file
- [ ] Test with 100 MB file
- [ ] Measure latency

### Erasure Coding
- [ ] Encode test data → 9 fragments
- [ ] Reconstruct with fragments 0-5 (k=6)
- [ ] Reconstruct with fragments 3-8 (k=6)
- [ ] Verify data integrity
- [ ] Test with various k/m values

### Encryption
- [ ] Generate age key: `age-keygen > key.txt`
- [ ] Encrypt file: `age -e -r <pubkey> -o file.age file`
- [ ] Decrypt: `age -d -i key.txt file.age`
- [ ] Test with binary data
- [ ] Test with large files

---

## Success Metrics

### Week 1 (This Week)
- ✅ Pair editor works with 2+ people
- ✅ Can package project → fragments → IPFS
- ✅ Can bootstrap from fragments on new machine
- ✅ End-to-end test passes

### Week 2
- ✅ Multi-backend storage (IPFS + GitHub + S3)
- ✅ CLI is polished and documented
- ✅ 5+ people successfully bootstrap same environment
- ✅ Blog post published

### Week 3
- ✅ CRDT task queue works
- ✅ Dummy agent executes tasks
- ✅ Real-time collaboration with agents
- ✅ Demo video recorded

### Month 1
- ✅ 10+ production users
- ✅ 50+ swarm forks
- ✅ Featured on HN/Reddit
- ✅ Contributions from community

---

## Known Blockers

### Technical
- None currently (Kubo launched, dependencies clear)

### Organizational
- Need to test on multiple platforms (GitHub, GitLab, Gitea)
- Need to test with actual team (recruiting beta testers)

### User Experience
- Fragment retrieval might be slow on cold start
- Need progress indicators for long operations
- Error handling needs to be robust

---

## Questions to Answer

1. **How big can environments be?**
   - Test with 1 GB, 10 GB projects
   - Measure upload/download times
   - Optimize fragment size

2. **How many backends should we support initially?**
   - Start with IPFS only (simplest)
   - Add GitHub releases (uses existing swarm)
   - Defer S3/Storacha until demand

3. **What's the UX for key management?**
   - Store in ~/.devswarm/key.txt?
   - Support multiple keys?
   - Key rotation strategy?

4. **How do we handle versioning?**
   - Each package = new manifest version
   - Keep history in CRDT?
   - Garbage collection strategy?

---

## Resources

- **IPFS Docs:** https://docs.ipfs.tech/
- **zfec:** https://github.com/tahoe-lafs/zfec
- **age:** https://age-encryption.org/
- **Yjs:** https://docs.yjs.dev/
- **Hocuspocus:** https://tiptap.dev/hocuspocus

---

## Notes

- Currently at: **Phase 1 Complete ✅**
- Next up: **Phase 2.1 - IPFS Integration**
- Timeline: **3 weeks to MVP**
- Priority: **D (All of the Above)** - Aggressive but achievable

**Let's ship this.** 🐝

---

Last updated: 2025-12-12 00:30:10
