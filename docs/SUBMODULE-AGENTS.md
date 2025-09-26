# Distributed AI Agent Architecture for Submodules

## 🎯 Vision: Domain-Specific AI Agents

Each submodule operates with its own specialized AI agent that understands its specific domain, technologies, and objectives. These agents coordinate through the parent CCPM system.

## 🏗️ Architecture

```
your-project (Parent Agent - Orchestrator)
├── images/ubi-proxy (Proxy Agent - Network Specialist)
├── images/openwisp-radius (RADIUS Agent - Auth Expert)
├── images/openwisp-users (User Agent - Identity Manager)
├── images/openwisp_wifi-login-page (UI Agent - Frontend Specialist)
└── MCP/just-do-it (DevOps Agent - Infrastructure Expert)
```

## 📋 Submodule Agent Profiles

### 1. **ubi-proxy** - Network Proxy Specialist
**Focus**: HTTP forwarding, field mapping, circuit breakers
**Expertise**: FastAPI, httpx, resilience patterns
**CCPM Status**: ✅ Active (needs sync)
**Current Tasks**:
- Field mapping (macaddr → mac)
- Circuit breaker implementation
- 38 failing tests to fix

### 2. **openwisp-radius** - Authentication Expert
**Focus**: RADIUS protocol, JWT validation, session management
**Expertise**: FreeRADIUS, Django, REST APIs
**CCPM Status**: ⚠️ Needs setup
**Priority Tasks**:
- Privy JWT token validation (#43)
- Session timeout configuration
- MAC address association

### 3. **openwisp-users** - Identity Management
**Focus**: User registration, profile management, permissions
**Expertise**: Django models, user authentication
**CCPM Status**: ⚠️ Needs setup
**Priority Tasks**:
- Auto-registration from wallet address
- User-device mapping
- Session tracking

### 4. **openwisp_wifi-login-page** - Frontend UI Expert
**Focus**: Captive portal UI, MetaMask integration, mobile UX
**Expertise**: React, Privy SDK, Web3
**CCPM Status**: ⚠️ Needs setup
**Priority Tasks**:
- Privy SDK integration (#54)
- Mobile-optimized authentication
- Error handling and retry logic

### 5. **MCP/just-do-it** - DevOps Automation
**Focus**: Docker orchestration, CI/CD, deployment
**Expertise**: Docker, GitHub Actions, Infrastructure
**CCPM Status**: ⚠️ Needs setup
**Priority Tasks**:
- Container health monitoring
- Automated testing pipelines
- Production deployment

## 🔄 Synchronization Strategy

### Phase 1: CCPM Distribution (Immediate)
```bash
# Copy improved PM scripts to each submodule
for submodule in images/ubi-proxy images/openwisp-radius images/openwisp-users images/openwisp_wifi-login-page; do
  cp .claude/scripts/pm/standup.sh "$submodule/.claude/scripts/pm/"
  cp .claude/scripts/pm/sync*.sh "$submodule/.claude/scripts/pm/"
done
```

### Phase 2: Agent Specialization
Each submodule gets custom CLAUDE.md with:
- Domain-specific instructions
- Technology stack guidance
- Testing requirements
- Integration points

### Phase 3: Cross-Agent Communication
```yaml
parent_sync:
  command: /pm:sync-submodules
  action: Aggregate status from all submodules

submodule_report:
  command: /pm:report-parent
  action: Push status to parent CCPM
```

## 🎮 Agent Commands

### Parent Agent (Orchestrator)
- `/pm:sync-submodules` - Pull status from all submodules
- `/pm:dispatch [task] [submodule]` - Assign task to submodule
- `/pm:integration-test` - Run cross-module tests

### Submodule Agents
- `/pm:local-sync` - Sync with parent repo
- `/pm:report-status` - Report to parent CCPM
- `/pm:test-integration` - Test integration points

## 📊 Implementation Timeline

### Week 1 (Current - Sept 27)
1. ✅ Sync CCPM improvements to ubi-proxy
2. ⏳ Setup CCPM for openwisp-radius (critical for #43)
3. ⏳ Create specialized CLAUDE.md for each

### Week 2 (Sept 30 - Oct 4)
1. Setup remaining submodules
2. Implement cross-agent sync
3. Test distributed workflows

### Week 3 (Oct 7-11)
1. Refine agent specializations
2. Automate status aggregation
3. Performance optimization

## 🚀 Quick Start for Each Submodule

### For ubi-proxy:
```bash
cd images/ubi-proxy
/pm:epic-start core-proxy  # Start failing tests fix
/pm:test-runner            # Run 38 tests with agent
```

### For openwisp-radius:
```bash
cd images/openwisp-radius
/pm:init radius-integration  # Create RADIUS epic
/pm:start 43                 # Start external auth task
```

### For wifi-login-page:
```bash
cd images/openwisp_wifi-login-page
/pm:init privy-integration   # Create Privy epic
/pm:start 54                 # Start MetaMask UI task
```

## 🎯 Benefits of Distributed Agents

1. **Context Optimization**: Each agent maintains focused context
2. **Parallel Development**: Multiple agents work simultaneously
3. **Domain Expertise**: Specialized knowledge per component
4. **Reduced Confusion**: Clear boundaries and responsibilities
5. **Better Testing**: Component-specific test strategies

## 🔗 Integration Points

### Critical Dependencies:
```
wifi-login-page → openwisp-radius → ubi-proxy → router
     (UI)           (Auth)          (Forward)   (Unlock)
```

### Data Flow:
1. User connects (wifi-login-page)
2. MetaMask auth (Privy SDK)
3. Token validation (openwisp-radius)
4. Session creation (openwisp-users)
5. Router unlock (ubi-proxy)

## 📈 Success Metrics

- Each submodule has 100% test coverage
- Integration tests pass across modules
- Parent can aggregate status in < 1 second
- Agents maintain < 50% context usage
- October 22 demo ready with all components

## 🛠️ Next Actions

1. **Immediate**: Sync ubi-proxy CCPM scripts
2. **Today**: Setup openwisp-radius CCPM for #43
3. **Tomorrow**: Create specialized CLAUDE.md files
4. **This Week**: Launch parallel agent development

---

## Command to Initialize All Submodules

```bash
# Run from parent directory
./scripts/init-submodule-agents.sh
```

This will:
1. Copy CCPM to all submodules
2. Create specialized CLAUDE.md
3. Initialize epics based on parent tasks
4. Setup cross-module sync

**Let's make each AI agent a domain expert!** 🚀