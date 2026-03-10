# AgentCTF x AgentXploit Competition

Welcome to the AgentCTF x AgentXploit competition, where participants design and implement AI agents that autonomously exploit vulnerabilities across diverse application environments—including other AI agents—in a Capture The Flag (CTF) format.

## Overview

This competition challenges participants to build AI agents capable of identifying and exploiting real-world vulnerabilities. The competition features environments spanning 20+ application frameworks, with tasks covering real-world CVEs. Targeted frameworks include LangChain, AutoGPT, etc.  A portion of tasks are released as a development set. 

This repository contains:
- Dev set environments and tasks under `./data/`
- A judge agent for evaluation under `./src/green_agent/`
- An example participant agent under `./src/white_agent/`

The evaluation pipeline follows the **AAA (Agentified Agent Assessment)** paradigm and uses tasks sourced from AgentXploit. Relevant materials:
- [AAA Overview](https://docs.agentbeats.org/#towards-agentified-agent-assessment-aaa)
- [AAA Evaluation Walkthrough](https://docs.agentbeats.org/Blogs/blog-2/)
- [AgentXploit Paper](https://arxiv.org/abs/2505.05849v1)

## Submission Guidelines

1. **Read the materials** and fork the repository.
2. **Implement your agent** (with an A2A interface) in `./src/white_agent/`.
   - Only modify files in `./src/white_agent/` and `pyproject.toml`. Do not alter the Green Agent code or task configurations. Official evaluation uses the same Green Agent; non-compliance may result in disqualification.
3. **Test locally** using the dev set, then bundle results and code with the provided CLI tools.
   - Do not include model weights or large files. Total submission size must be under 1 MB.
   - The bundle automatically includes the latest `run-all` results. Ensure a full run is complete before bundling, and do not modify results afterward—official evaluation will rerun them to verify authenticity.
4. **Submit** via the [Google Form](https://forms.gle/t8WcX8zGU7tNAgKTA) before **23:59 AoE, March 20, 2026**.

## Scoring Policy

Submissions are evaluated against both the dev set and a hidden test set. For each task, the agent receives a LiteLLM API key with a **$10 budget** and **15 minutes** to generate an exploit.

The key is provided via a `.env` file:
```sh
LITELLM_PROXY_API_KEY=sk-xxxxx
LITELLM_PROXY_API_BASE=...
```

Participants should specify the LLM they used so organizers can provision the appropriate model access. Most popular models are supported, including `openai/*`, `gemini/*`, and `vertex_ai/claude-*`. Prefix with `litellm_proxy/` in most cases:
```sh
LITELLM_MODEL=litellm_proxy/openai/gpt-4o
```

## Getting Started

### Install Dependencies

```sh
curl -fsSL https://get.docker.com | sh      # Docker & Docker Compose
curl -LsSf https://astral.sh/uv/install.sh | sh  # uv
uv sync                                      # install Python dependencies
```

### Configure API Keys

```sh
cp .env.example .env
# Edit .env and add your API keys
```

### Run the Agent

**Single task:**
```sh
uv run python main.py run-one task-cve-2023-29374-llmmath-rce
```

Expected output:
```
=== Assessment Result ===
Task: ...
CVE: ...
Status: SUCCESS
Score: 5/5
Duration: 41.59s
Steps: 7

Reasoning:
...

Full result saved to: ...
```

**Full batch + bundle generation:**
```sh
uv run python main.py run-all
```

Expected output:
```
...
Full result saved to: ...
Average score so far: 40.00
============================================================
Evaluating tasks: 100%|███████████████████████████████| ...
Submission bundle created: submission.zip
```

Review the generated `submission.zip` before submitting to ensure correctness.

## Contact

For questions or support, please leave an issue on GitHub or contact the organizers [here](mailto:sec+agentctf26@berkeley.edu). Feedback is highly appreciated to improve future iterations of the competition.

## License & Responsible Disclosure

This framework is intended for **educational and research purposes only**. All included CVEs are publicly disclosed vulnerabilities. Participants must adhere to responsible disclosure policies.
