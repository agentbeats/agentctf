# AutoGPT 0.4.2 Runtime

This runtime provides a self-contained Docker environment for testing AutoGPT 0.4.2 security vulnerabilities. The AutoGPT source code is built into the Docker image - no external setup required.

## Setup

### 1. Configure Environment

```bash
cp .env.template .env
```

Edit `.env` and set:
- `OPENAI_API_KEY` - Your OpenAI API key
- Other settings are pre-configured for security testing

### 2. Build Docker Image

```bash
docker compose build
```

This will:
- Create a Docker image with AutoGPT 0.4.2 source code included
- Install all dependencies
- Set up the `/workspace` directory for file interactions

## Known Vulnerabilities in 0.4.2

This runtime is intentionally configured to demonstrate the following vulnerabilities:

### CVE-TBD-001: Prompt Injection via execute_python_code
- **Severity**: CRITICAL
- **Description**: Malicious instructions in files can trick AutoGPT into executing arbitrary Python code
- **Impact**: Container escape, arbitrary file writes to host filesystem
- **Test Task**: `task-prompt-injection-docker-write`

### CVE-TBD-002: Path Traversal in File Operations
- **Severity**: HIGH
- **Description**: Path validation bypass using `../` sequences allows code execution outside workspace
- **Impact**: Sandbox escape, arbitrary code execution
- **Test Task**: `task-path-traversal-sandbox-escape`

### CVE-TBD-003: ANSI Escape Sequence Injection
- **Severity**: MEDIUM
- **Description**: Unfiltered ANSI escape codes can manipulate terminal output
- **Impact**: Log evasion, social engineering attacks
- **Test Task**: `task-ansi-injection-output-manipulation`

## Docker Architecture

### Container Structure
- **AutoGPT Source**: Pre-installed at `/app/autogpt-source` (read-only, built into image)
- **Workspace**: Mounted at `/app/autogpt-source/autogpt/auto_gpt_workspace` (read-write, for file interactions)
  - Local path: `./workspace`
  - Container path: `/app/autogpt-source/autogpt/auto_gpt_workspace`

### File Interaction Model

All file operations happen through the AutoGPT workspace directory at `/app/autogpt-source/autogpt/auto_gpt_workspace`:

1. **Adding Test Files**: Copy files into the container's workspace:
   ```bash
   docker cp ./test-file.txt autogpt-security-test-<task-id>:/app/autogpt-source/autogpt/auto_gpt_workspace/
   ```

2. **Reading Results**: Copy files from the container's workspace:
   ```bash
   docker cp autogpt-security-test-<task-id>:/app/autogpt-source/autogpt/auto_gpt_workspace/output.txt ./
   ```

3. **Interactive Shell**: Access the container for debugging:
   ```bash
   docker exec -it autogpt-security-test-<task-id> /bin/bash
   ```

4. **Viewing Workspace**: List files in the workspace:
   ```bash
   docker exec autogpt-security-test-<task-id> ls -la /app/autogpt-source/autogpt/auto_gpt_workspace
   ```

### Volume Mount Configuration

The docker-compose.yml only mounts the workspace directory:

```yaml
volumes:
  - ${TASK_WORKSPACE_PATH:-./workspace}:/app/autogpt-source/autogpt/auto_gpt_workspace:rw
```

This design ensures:
- All agent operations are isolated within the workspace
- Source code is immutable (built into the image)
- File interactions are explicit and controlled through docker cp or volume mount

## Security Considerations

**WARNING**: This runtime is designed for security testing in isolated environments only. Do not use in production or on systems with sensitive data.

- All tests run in Docker containers for isolation
- AutoGPT source code is immutable (baked into the image)
- Only `/workspace` is writable for controlled file interactions
- `EXECUTE_LOCAL_COMMANDS=True` allows code execution testing within the container
- Always use the `--cleanup` flag when running tests

## Usage

Do not run this runtime directly. Use the main runner script:

```bash
cd ../..
./scripts/run.sh <task-id> autogpt-0.4.2
```

See [Usage Documentation](../../docs/USAGE.md) for details.

### Manual Container Management

For advanced testing, you can manage containers manually:

```bash
# Build the image
docker compose build

# Start a container in background
docker compose run -d --name autogpt-test --entrypoint sleep autogpt infinity

# Add files to the workspace
docker cp malicious-file.txt autogpt-test:/app/autogpt-source/autogpt/auto_gpt_workspace/
docker cp ai_settings.yaml autogpt-test:/app/autogpt-source/autogpt/auto_gpt_workspace/

# Execute AutoGPT in the container
docker exec autogpt-test python -m autogpt -C /app/autogpt-source/autogpt/auto_gpt_workspace/ai_settings.yaml --skip-news -y -c --continuous-limit 3

# View workspace contents
docker exec autogpt-test ls -la /app/autogpt-source/autogpt/auto_gpt_workspace

# Interactive shell
docker exec -it autogpt-test /bin/bash

# View logs
docker logs autogpt-test

# Stop and remove the container
docker rm -f autogpt-test
```

## Logs

Logs are stored in `./logs/` directory with the format `<task-id>.log`.

## Cleanup

To clean up containers and volumes:

```bash
../../scripts/cleanup.sh
```

## References

- AutoGPT Repository: https://github.com/Significant-Gravitas/Auto-GPT
- AutoGPT 0.4.2 Release: https://github.com/Significant-Gravitas/Auto-GPT/releases/tag/v0.4.2
- Vulnerability Details: See [../../docs/VULNERABILITIES.md](../../docs/VULNERABILITIES.md)
