# DevSwarm Pair Programming Guide

**Real-time collaborative coding with zero infrastructure.**

## Quick Start (30 seconds)

### Option 1: Public Sync Server (Instant)

1. **Open the editor:**
   ```bash
   # From the devswarm repo
   open pair-editor.html
   # Or just double-click the file
   ```

2. **Configure connection:**
   - Sync Server: `wss://demos.yjs.dev` (public test server)
   - Room Name: `devswarm-YOURNAME` (pick unique name)
   - Your Name: `YourName`
   - Click **Connect**

3. **Share with others:**
   ```
   Tell them to:
   1. Open pair-editor.html
   2. Enter SAME room name: devswarm-YOURNAME
   3. Connect
   ```

4. **Start coding together!**
   - Type code in the editor
   - See each other's cursors in real-time
   - Chat in the sidebar
   - Changes sync instantly

---

## Option 2: Self-Hosted Sync Server (5 minutes)

**More private, more control.**

### Setup (One Person Runs This)

```bash
# Install Hocuspocus (Yjs sync server)
npm install -g @hocuspocus/server

# Run server
npx @hocuspocus/server \
  --port 1234 \
  --quiet

# Server running on: ws://localhost:1234
```

**Or with Docker:**
```bash
docker run -d \
  -p 1234:1234 \
  --name hocuspocus \
  hocuspocus/hocuspocus
```

### Expose to Internet (For Remote Pairing)

**Option A: ngrok (easiest)**
```bash
# Install: https://ngrok.com/download
ngrok http 1234

# You get URL like: https://abc123.ngrok.io
# Share this with others
```

**Option B: Cloudflare Tunnel**
```bash
# Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/
cloudflared tunnel --url http://localhost:1234

# You get URL like: https://abc-123.trycloudflare.com
```

**Option C: Your own domain**
```nginx
# Nginx config
server {
    listen 443 ssl;
    server_name sync.yourdevswarm.com;

    location / {
        proxy_pass http://localhost:1234;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Connect Everyone

Share your sync server URL:
```
Sync Server: wss://abc123.ngrok.io
Room Name: devswarm-main
```

Everyone connects to the same room → instant collaboration!

---

## Option 3: P2P Mode (No Server)

**Coming soon:** Direct peer-to-peer via WebRTC (y-webrtc).

---

## Usage Guide

### Basic Workflow

```
1. One person sets up sync server (or use public)
2. Everyone opens pair-editor.html
3. Enter SAME room name
4. Start coding together
```

### Features

**Real-time Editing:**
- See each other's cursors
- Colored by user
- Type anywhere, no conflicts
- CRDT ensures consistency

**Chat:**
- Side panel for discussion
- Persists in session
- All participants see messages

**Awareness:**
- See who's online
- Connection status indicator
- Peer count

### Advanced: Integrate with VS Code

**Use your actual editor:**

```bash
# Install Live Share (Microsoft)
code --install-extension ms-vsliveshare.vsliveshare

# Or use this Yjs VS Code extension
# https://github.com/yjs/y-vscode
```

But for DevSwarm prototyping, the web editor is perfect.

---

## Architecture

```
┌─────────────┐      WebSocket      ┌─────────────┐
│  Browser 1  │◄────────────────────►│   Hocus-    │
│ (pair-editor│                      │   pocus     │
│    .html)   │      Yjs CRDT       │   Server    │
└─────────────┘                      └─────────────┘
       ▲                                    ▲
       │                                    │
       │          WebSocket + Yjs           │
       │                                    │
       ▼                                    ▼
┌─────────────┐                      ┌─────────────┐
│  Browser 2  │                      │  Browser 3  │
│             │◄────────────────────►│             │
└─────────────┘   Direct P2P Sync    └─────────────┘
                  (via awareness)
```

**Key tech:**
- **Yjs:** CRDT for conflict-free editing
- **WebSocket Provider:** Syncs state via server
- **Monaco:** VS Code's editor engine
- **y-monaco:** Binds Yjs to Monaco

---

## Security & Privacy

### Public Server (demos.yjs.dev)
- ⚠️ **NOT ENCRYPTED**
- ⚠️ Anyone who knows room name can join
- ⚠️ Do not share sensitive code
- ✅ Fine for prototyping/demos

### Self-Hosted Server
- ✅ You control the infrastructure
- ✅ Add authentication (Hocuspocus supports hooks)
- ✅ Add TLS/SSL (wss://)
- ✅ Can log/monitor sessions

**Recommended: Always use unique room names like UUIDs**

```javascript
// Generate secure room name
const room = crypto.randomUUID()
// Share this with your team: devswarm-a1b2c3d4-e5f6-...
```

### Future: End-to-End Encryption

**Coming in Phase 4:**
```
1. Generate room key (age/libsodium)
2. Share key out-of-band (QR code, 1Password)
3. Encrypt CRDT ops before sending to server
4. Server sees only ciphertext
5. Only key holders can decode
```

---

## Troubleshooting

### "Can't connect to server"

**Check:**
```bash
# Is server running?
curl http://localhost:1234
# Should return: Upgrade Required (that's OK)

# WebSocket test
wscat -c ws://localhost:1234
# Should connect
```

**Firewall:**
- Allow port 1234
- Or use ngrok/cloudflare tunnel

### "I don't see other users"

**Verify:**
- Same sync server URL?
- Same room name? (case-sensitive!)
- Check browser console for errors
- Try refreshing

### "Changes not syncing"

- Check connection indicator (should be green)
- Look at peer count (should be >0)
- Server might be overloaded (restart it)

### "Server crash on high traffic"

Hocuspocus is production-ready but defaults are conservative:

```bash
# Increase limits
npx @hocuspocus/server \
  --port 1234 \
  --max-debounce 10000 \
  --quiet
```

---

## Embedding in DevSwarm

### Add to Your Swarm

```bash
# Copy editor to your repo
cp /tmp/devswarm/pair-editor.html ~/your-swarm/

# Commit
git add pair-editor.html
git commit -m "🐝 Add pair programming editor"
git push

# Now every fork has the editor
# Team members just open the HTML file
```

### Auto-Configure Room from Git

**Enhancement idea:**

```javascript
// In pair-editor.html
// Auto-detect repo and use as room name
const repo = await fetch('/.git/config')
  .then(r => r.text())
  .then(text => text.match(/url = .*\/(.+?)\.git/)[1])

const defaultRoom = `devswarm-${repo}`
```

### Integrate with Swarm Coordinator

**In swarm-coordinator.sh:**

```bash
# Start sync server on CI
if command -v npx >/dev/null 2>&1; then
    log "Starting pair programming server..."
    npx @hocuspocus/server --port 1234 --quiet &
    
    # Update manifest with server info
    jq '.sync_server = "ws://localhost:1234"' \
       .swarm/manifest.json > .swarm/manifest.tmp
    mv .swarm/manifest.tmp .swarm/manifest.json
fi
```

---

## Next Steps: Building the Full Stack

### Phase 1: Pair Editor ✅ (YOU ARE HERE)
- [x] Real-time collaborative editing
- [x] Chat functionality
- [x] WebSocket sync
- [x] Monaco editor integration

### Phase 2: CRDT Task Queue (This Week)
```javascript
// Shared task list
const ytasks = ydoc.getArray('tasks')

// Agent reads tasks
ytasks.observe(() => {
    const pending = ytasks.toArray().filter(t => t.status === 'pending')
    if (pending.length > 0) {
        executeTasks(pending)
    }
})

// Human adds task
ytasks.push([{
    id: crypto.randomUUID(),
    type: 'implement',
    description: 'Add IPFS fragment storage',
    status: 'pending',
    created: Date.now()
}])
```

### Phase 3: Agent Coordination (Next Week)
```bash
# Agent connects to same CRDT room
# Reads task queue
# Executes tasks
# Writes results back
# Human sees changes in real-time
```

### Phase 4: Fragment Storage (Week After)
```javascript
// Store code fragments in IPFS
// Reference CIDs in CRDT doc
// Bootstrap reconstructs from fragments
```

---

## FAQ

**Q: Why not Google Docs / Notion?**
A: Those are proprietary, centralized platforms. DevSwarm is about user sovereignty. Your code, your infrastructure.

**Q: Why not VS Code Live Share?**
A: Live Share requires Microsoft account. DevSwarm works on any platform, even self-hosted Git forges.

**Q: Can I use this for production?**
A: The editor is a prototype. For production, integrate Yjs into your actual tools (VS Code extension, CLI, etc.)

**Q: What's the latency?**
A: With local server: <10ms. With ngrok: 50-200ms. With public server: 100-500ms. CRDT ensures consistency regardless.

**Q: How many people can edit simultaneously?**
A: Yjs scales to 100+ concurrent editors. Server might need tuning.

**Q: Does it work offline?**
A: Partially. Your edits are stored locally (IndexedDB). When you reconnect, they sync. But you won't see others' changes while offline.

**Q: Can I integrate AI agents?**
A: **YES.** That's the next step. Agent connects as a "user", reads CRDT doc, writes results.

---

## Example Session

**Alice (sets up server):**
```bash
cd devswarm/
npx @hocuspocus/server --port 1234 --quiet &
ngrok http 1234
# Got: https://abc123.ngrok.io
```

**Alice (shares with Bob and Claude):**
```
Sync Server: wss://abc123.ngrok.io
Room: devswarm-ipfs-integration
```

**Bob (joins):**
```bash
open pair-editor.html
# Enters: wss://abc123.ngrok.io, devswarm-ipfs-integration, Bob
# Clicks Connect
```

**Claude (AI agent, joins programmatically):**
```python
import y_py as Y
from ypy_websocket import WebsocketProvider

ydoc = Y.YDoc()
provider = WebsocketProvider(ydoc, "wss://abc123.ngrok.io", "devswarm-ipfs-integration")

# Read code
code = ydoc.get_text("monaco")
print(code.to_string())

# Make edits (Alice and Bob see in real-time)
code.insert(0, "// AI-generated IPFS integration\n")
```

**All three coding together in real-time.** 🐝

---

## Resources

- **Yjs Docs:** https://docs.yjs.dev/
- **Hocuspocus:** https://tiptap.dev/hocuspocus
- **Monaco Editor:** https://microsoft.github.io/monaco-editor/
- **y-monaco:** https://github.com/yjs/y-monaco
- **y-websocket:** https://github.com/yjs/y-websocket

---

## License

MIT - Fork freely 🐝

---

**Ready to pair program?**

```bash
# 1. Open the editor
open pair-editor.html

# 2. Use public server (instant)
Server: wss://demos.yjs.dev
Room: devswarm-test-123
Name: YourName

# 3. Share room name with collaborators
# 4. Start coding together!
```

🐝 **The swarm is collaborative by default.**
