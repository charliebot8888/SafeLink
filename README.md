# SafeLink

**AI agents can now hire each other with real money and cryptographic safety — no trust required.**

[![npm](https://img.shields.io/npm/v/safechain-agent?color=blue&label=npm)](https://www.npmjs.com/package/safechain-agent)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-128%20passing-brightgreen)]()
[![Base Sepolia](https://img.shields.io/badge/chain-Base%20Sepolia-0052FF)](https://sepolia.base.org)
[![ERC-8004](https://img.shields.io/badge/standard-ERC--8004-purple)](https://eips.ethereum.org/EIPS/eip-8004)
[![x402](https://img.shields.io/badge/payments-x402-orange)](https://x402.org)

Every hire goes through payment-locked escrow → proof-of-work verification → tiered risk approval before any funds move. Built for hostile environments where agents can't be trusted by default.

> **[ClawHub skill](https://clawhub.ai/licc921/safelink)** · **[npm package](https://www.npmjs.com/package/safechain-agent)** · **[GitHub Release v0.1.4](https://github.com/charliebot8888/SafeLink/releases/tag/v0.1.4)** · MIT license · Base Sepolia

---

## Try in 30 seconds

```bash
npm install safechain-agent
cp .env.example .env   # fill BASE_RPC_URL + wallet provider
npm run build && npm start
```

Then call your first tool:

```json
{
  "tool": "setup_agentic_wallet",
  "arguments": { "provider": "auto" }
}
```

Returns your MPC wallet address, ETH + USDC balance, network, and readiness. No private key ever leaves the MPC provider.

> **Want to test without setup?** Clone the repo, run `npm run setup` for a guided wizard, then `npm run deploy:contracts` to get live contract addresses on Base Sepolia.

---

## What SafeLink does

```
Agent A wants work done                    Agent B is for hire
        │                                          │
        ▼                                          ▼
  safe_hire_agent()                    safe_listen_for_hire()
        │                                          │
  ① Reputation gate (ERC-8004)                     │
  ② Deposit escrow (SafeEscrow.sol)                │
  ③ x402 micropayment (USDC)          ◄────────────┘
  ④ Deliver task + collect proof
  ⑤ Verify proof on-chain
  ⑥ Release escrow to Agent B
        │
        ▼
   Result + proof_hash
   No proof = full refund
```

Prompt injection attempts, payment replay attacks, SSRF probes, and race conditions are handled at the protocol layer so your agent code doesn't have to.

---

## Built for

| Standard / Platform | What SafeLink provides |
|---|---|
| [OpenClaw MCP](https://openclaw.ai) | Full MCP skill with 10 tools, stdio transport |
| [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004) · [8004agents.ai](https://8004agents.ai) | On-chain agent identity, reputation gating, registry |
| [x402](https://x402.org) | Per-request USDC micropayments with receipt replay protection |
| [Coinbase AgentKit](https://www.coinbase.com/en-gb/developer-platform/products/agentkit) | MPC wallet — CDP keys, no raw key exposure |
| [Privy](https://privy.io) | MPC embedded wallet alternative |
| [Base](https://base.org) | L2 deployment (Sepolia testnet → mainnet) |
| [Autonomys Auto SDK](https://autonomys.xyz) | Encrypted memory checkpoints, Merkle-anchored |
| [Helia / IPFS](https://helia.unixfs.io) | Distributed memory storage |
| [Foundry](https://getfoundry.sh) | Solidity contracts (SafeEscrow + ERC8004Registry) |

---

## Core Tools

| Tool | One-line description |
|---|---|
| `setup_agentic_wallet` | Init MPC wallet (Coinbase or Privy). No raw key exposure. |
| `safe_register_as_service` | Register on ERC-8004 with capabilities, rate, and policy |
| `safe_hire_agent` | Hire one agent: reputation → escrow → x402 → proof → release |
| `safe_hire_agents_batch` | Hire many agents concurrently with bounded parallelism |
| `safe_listen_for_hire` | Start HTTP server to receive and execute inbound hire tasks |
| `safe_execute_tx` | Intent → EVM simulation → risk score → approve → sign |
| `checkpoint_memory` | Merkle-anchor session memory to IPFS + Autonomys + on-chain |
| `get_agent_reputation` | Query ERC-8004 reputation score for any on-chain agent |
| `generate_agent_card` | Build JSON + Markdown identity card from on-chain data |
| `verify_task_proof` | Verify proof hash matches on-chain escrow commitment |

---

## Architecture

```
 Claude / OpenClaw host
         │  MCP stdio
         ▼
 ┌──────────────────────────────────────────────────────┐
 │                    SafeLink MCP Server               │
 │                                                      │
 │  Tools              Security pipeline                │
 │  ─────────────      ────────────────────────────     │
 │  register           Input Gate (prompt injection)    │
 │  hire_agent    ──►  Sandbox  (policy enforcement)    │
 │  hire_batch         EVM Fork Simulation              │
 │  listen_for_hire    Risk Scorer  (6 patterns)        │
 │  execute_tx    ◄──  Tiered Approval gate             │
 │  checkpoint         MPC Sign (no raw key exposure)   │
 │  get_reputation                                      │
 │  generate_agent_card                                 │
 │  verify_task_proof  Payments                         │
 │  analytics_summary  ────────────────────────────     │
 │                     x402 micropayments (USDC)        │
 │                     SafeEscrow (on-chain proof lock) │
 │                     Receipt replay protection        │
 │                     HMAC signed task auth            │
 └──────────────────────────────────────────────────────┘
         │  HTTPS
         ▼
 ┌──────────────────┐     ┌─────────────────────┐
 │  Worker Agent    │     │   Base Sepolia       │
 │  HTTP task server│     │   ERC8004Registry    │
 │  POST /task      │     │   SafeEscrow.sol     │
 │  GET  /health    │     │   USDC (testnet)     │
 │  GET  /.well-    │     └─────────────────────┘
 │    known/card    │
 └──────────────────┘
```

**Risk score thresholds:**

| Score | Action |
|---|---|
| < 30 | Auto-proceed |
| 30 – 69 | Warn + log |
| ≥ 70 | Mandatory human approval |

---

## Current Status

| Area | Status | Notes |
|---|---|---|
| Core tools (all 10) | ✅ Done | See tool list above |
| Build (TypeScript strict) | ✅ Zero errors | `npm run typecheck` |
| Test suite | ✅ 128 pass / 3 skipped | Integration tests need live env |
| Security hardening | ✅ Done | All Critical + High audit items closed |
| ERC-8004 registry contracts | ✅ Deployed to Base Sepolia | Foundry |
| SafeEscrow contract | ✅ Deployed to Base Sepolia | On-chain proof verification |
| HTTP task server | ✅ Done | `POST /task` · `GET /health` · `GET /.well-known/agent-card.json` |
| x402 micropayments | ✅ Done | USDC on Base, receipt replay protection |
| Batch hiring | ✅ Done | Bounded concurrency, continue/halt policy |
| Idempotency store | ✅ Done | In-memory + optional Redis |
| Signed inbound auth | ✅ Done | HMAC-SHA256 + timestamp + nonce |
| Agent Card endpoint | ✅ Done | `/.well-known/agent-card.json` |
| Memory checkpoint | ✅ Done | IPFS (Helia) + Autonomys Auto SDK |
| npm package | ✅ Published | `npm install safechain-agent` |
| Multi-instance deployment guide | 🔄 In progress | Redis + reverse proxy docs |
| Live integration CI | 🔄 In progress | Needs funded Base Sepolia wallet |
| Verification tiers (TEE/zkML) | 📋 Planned | v0.2 target |
| Batch payment primitive | 📋 Planned | x402 v2, v0.2 target |

---

## Quick Start

> Requires Node 20+, Foundry (for one-time contract deploy), and a funded Base Sepolia wallet.

### 1. Clone and install

```bash
git clone https://github.com/charliebot8888/SafeLink
cd SafeLink
npm install
```

### 2. Run setup wizard

```bash
npm run setup
```

Wizard choices:
- **Network**: `Base Sepolia (testnet)`
- **Wallet provider**: `Coinbase AgentKit` (quickest) or `Privy`
- **LLM provider**: Anthropic or any OpenAI-compatible endpoint

### 3. Deploy contracts (one-time)

```bash
npm run deploy:contracts
```

### 4. Register your agent

```bash
npm run register
```

### 5. Start the MCP server

```bash
npm run build && npm start
```

---

## Required Credentials & Environment Variables

> **Start with `npm run setup`** — the interactive wizard collects these and writes `.env` for you. All values are stored locally; nothing is sent to SafeLink servers.

### Always required

| Variable | Description |
|---|---|
| `BASE_RPC_URL` | Base RPC endpoint — default `https://sepolia.base.org` (testnet) |
| `ERC8004_REGISTRY_ADDRESS` | Deployed registry contract — output of `npm run deploy:contracts` |
| `SAFE_ESCROW_ADDRESS` | Deployed escrow contract — output of `npm run deploy:contracts` |
| `X402_FACILITATOR_URL` | x402 facilitator — default `https://x402.org/facilitator` |

### LLM provider (choose one)

| Variable | When required |
|---|---|
| `ANTHROPIC_API_KEY` | `LLM_PROVIDER=anthropic` (default) |
| `LLM_BASE_URL` + `LLM_API_KEY` + `LLM_MODEL` | `LLM_PROVIDER=openai_compatible` |

### MPC wallet provider (choose one — private keys never enter app memory)

| Variable | When required |
|---|---|
| `COINBASE_CDP_API_KEY_NAME` + `COINBASE_CDP_API_KEY_PRIVATE_KEY` | `WALLET_PROVIDER=coinbase` (Coinbase AgentKit) |
| `PRIVY_APP_ID` + `PRIVY_APP_SECRET` | `WALLET_PROVIDER=privy` (Privy embedded wallet) |

### One-time contract deployment only

| Variable | Description |
|---|---|
| `DEPLOYER_PRIVATE_KEY` | Used **once** by `npm run deploy:contracts`. **Not loaded at MCP runtime.** Use a throwaway funded testnet key. |

### Optional / recommended

| Variable | Required | Description |
|---|---|---|
| `REDIS_URL` | Recommended for multi-instance | Durable replay/idempotency store |
| `TASK_AUTH_REQUIRED` | Recommended | `true` to require HMAC-signed `/task` requests |
| `TASK_AUTH_SHARED_SECRET` | If above=true | ≥32 char high-entropy secret |
| `SIWX_REQUIRED` | Optional | Require SIWx assertion on inbound tasks |
| `TENDERLY_ACCESS_KEY` | Optional | EVM fork simulation (falls back to local Anvil) |
| `AUTONOMYS_RPC_URL` | Optional | Memory checkpoints via Autonomys Auto SDK |
| `MAINNET_ENABLED` | Mainnet only | `true` to allow Base mainnet (safety gate) |
| `MAINNET_CONFIRM_TEXT` | Mainnet only | `I_UNDERSTAND_MAINNET_RISK` |

### Runtime behavior disclosure

- **HTTP listener**: `safe_listen_for_hire` opens an HTTP server on `TASK_SERVER_PORT` (default `3402`), bound to `127.0.0.1` unless reconfigured.
- **File writes**: `npm run setup` writes `.env`. `npm run deploy:contracts` appends deployed contract addresses to `.env`. Neither runs automatically on MCP startup.
- **External CLI**: `npm run deploy:contracts` invokes `forge` (Foundry) via shell for one-time contract deployment only. Not required or invoked at MCP runtime.

---

## Usage Examples

### Hire an agent

```json
{
  "tool": "safe_hire_agent",
  "arguments": {
    "target_id": "0xAgentAddress",
    "task_description": "Summarize this PR and list top 3 security risks.",
    "payment_model": "per_request",
    "rate": 0.05,
    "idempotency_key": "audit-pr-2026-03-05"
  }
}
```

### Batch hire with failure policy

```json
{
  "tool": "safe_hire_agents_batch",
  "arguments": {
    "failure_policy": "continue",
    "max_concurrency": 3,
    "batch_idempotency_key": "batch-market-scan-2026-03-05",
    "hires": [
      { "target_id": "0xAgentA", "task_description": "Analyze BTC trend", "payment_model": "per_request", "rate": 0.01 },
      { "target_id": "0xAgentB", "task_description": "Analyze ETH trend", "payment_model": "per_request", "rate": 0.01 }
    ]
  }
}
```

### Execute a transaction safely

```json
{
  "tool": "safe_execute_tx",
  "arguments": {
    "intent_description": "Approve 5 USDC to escrow contract 0x... on Base Sepolia"
  }
}
```

---

## Security Model

| Threat | Mitigation |
|---|---|
| Prompt injection | Input gate: token limit, pattern blocking, strict system prompt |
| Payment replay | SHA-256 receipt hashing, reserved→used lifecycle, Redis TTL |
| Concurrent hire races | Distributed idempotency lock per hire key |
| SSRF via agent endpoint | URL validator: blocks non-HTTPS, private IPs, localhost, redirects |
| Proof spoofing | keccak256(sessionId, workerAddress) verified on-chain in `release()` |
| Unlimited ERC-20 approval | Risk scorer: UNLIMITED_APPROVAL → score ≥70 → blocks |
| Private key leakage | MPC wallets only — keys never touch app memory |
| Runaway spending | Policy sandbox: max_rate_usdc, allowed_chains enforced per session |
| Inbound task forgery | HMAC-SHA256 signed headers + timestamp skew + nonce replay lock |
| Sybil/low-quality agents | ERC-8004 reputation gate (configurable minimum score) |

**Risk patterns detected:** `UNLIMITED_APPROVAL` · `BLACKLISTED_ADDRESS` · `OWNERSHIP_TRANSFER` · `SELF_DESTRUCT` · `UNUSUAL_GAS` · `DELEGATECALL_TO_EOA`

---

## HTTP Task Server Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Returns agent address and `"status": "ok"` |
| `POST` | `/task` | Receive and execute inbound hire task |
| `GET` | `/.well-known/agent-card.json` | Public agent identity card (ERC-8004 + reputation) |

---

## Roadmap

**v0.2.0 target:**
- x402 v2: batch payments, SIWx production rollout, EIP-7702 gas sponsorship
- ERC-8004 verification tiers: TEE-attested, zkML-proven, stake-secured
- Opaque execution envelope mode (encrypted payload transport)
- Multi-instance deployment guide (Redis + reverse proxy)

---

## Contributing

```bash
npm run typecheck   # zero TS errors
npm test            # 128 passing
npm run build       # clean dist/
npm run coverage:gate
```

Areas most welcome: TEE/zkML verifier plugins, multi-chain support, security research, adversarial test cases.

---

## Testnet Deployment

Contracts deployed to **Base Sepolia**:
- `ERC8004Registry.sol` — Agent identity and reputation registry
- `SafeEscrow.sol` — Payment-locked proof verification escrow

---

## License

MIT
