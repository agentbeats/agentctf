"""Docker Environment Manager - supports multiple runtimes"""

import subprocess
import time
import re
from pathlib import Path


class DockerManager:
    """Docker Environment Manager - supports multiple runtimes"""

    def __init__(self, task_id: str, task_config: dict):
        """Initialize Docker Manager

        Args:
            task_id: Task ID
            task_config: Task configuration (contains _runtime_dir)
        """
        self.task_id = task_id
        self.task_config = task_config

        # Get runtime directory from task_config
        runtime_dir = task_config.get("_runtime_dir")
        if runtime_dir:
            self.runtime_dir = Path(runtime_dir)
        else:
            # Fall back to default
            runtime = task_config.get("_runtime", "lobechat-0.150.5")
            self.runtime_dir = (
                Path(__file__).parent.parent.parent
                / "data"
                / "env"
                / (runtime + "-victim")
            )

        # Container names - read from task_config.environment
        # Container names are now version-based (e.g., lobechat-0.150.5-victim)
        env_config = task_config.get("environment", {})
        runtime = task_config.get("_runtime", "")
        self.target_container = env_config.get("target_container", f"{runtime}-victim")
        self.attacker_container = env_config.get(
            "attacker_container", f"{runtime}-attacker"
        )

        # Parse port from the runtime directory's docker-compose.yml
        self.target_port = self._get_target_port()

    def _get_target_port(self) -> int:
        """Parse the target port from docker-compose.yml

        Returns:
            Port number, defaults to 3210
        """
        compose_file = self.runtime_dir / "docker-compose.yml"
        if not compose_file.exists():
            return 3210

        try:
            content = compose_file.read_text()
            # Look for PORT=xxxx or port in healthcheck
            port_match = re.search(r"PORT[=:](\d+)", content)
            if port_match:
                return int(port_match.group(1))
            # Look for localhost:xxxx in healthcheck
            health_match = re.search(r"localhost:(\d+)", content)
            if health_match:
                return int(health_match.group(1))
        except Exception:
            pass

        return 3210

    def start_environment(self) -> bool:
        """Start the Docker environment

        Returns:
            Whether the environment started successfully
        """
        print(f"[DockerManager] Starting environment for task: {self.task_id}")
        print(f"[DockerManager] Runtime dir: {self.runtime_dir}")

        try:
            result = subprocess.run(
                ["docker", "compose", "up", "-d", "--build"],
                cwd=str(self.runtime_dir),
                capture_output=True,
                text=True,
                timeout=1800,  # 30 minutes - some images (e.g. lobechat) need to clone+npm install
            )
            if result.returncode != 0:
                print(f"[DockerManager] Failed to start: {result.stderr}")
                return False

            print(f"[DockerManager] Docker Compose started successfully")
            return True

        except subprocess.TimeoutExpired:
            print("[DockerManager] Timeout starting Docker environment")
            return False
        except Exception as e:
            print(f"[DockerManager] Error: {e}")
            return False

    def wait_for_target_ready(self, timeout: int = 180) -> bool:
        """Wait for the target container to be ready

        Args:
            timeout: Timeout duration (seconds)

        Returns:
            Whether the target is ready
        """
        print(
            f"[DockerManager] Waiting for {self.target_container} to be ready (port {self.target_port})..."
        )

        for i in range(timeout):
            try:
                # Check if the container is running
                result = subprocess.run(
                    [
                        "docker",
                        "inspect",
                        "-f",
                        "{{.State.Running}}",
                        self.target_container,
                    ],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if result.returncode == 0 and "true" in result.stdout.lower():
                    # If the container has a healthcheck and it's healthy, treat it as ready.
                    # This avoids false negatives when the service returns non-2xx status codes on "/".
                    health = subprocess.run(
                        [
                            "docker",
                            "inspect",
                            "-f",
                            "{{if .State.Health}}{{.State.Health.Status}}{{end}}",
                            self.target_container,
                        ],
                        capture_output=True,
                        text=True,
                        timeout=10,
                    )
                    if (
                        health.returncode == 0
                        and health.stdout.strip().lower() == "healthy"
                    ):
                        print(
                            f"[DockerManager] Target ready (took {i}s; docker health=healthy)"
                        )
                        return True

                    # Check if the service is responding
                    health_check = subprocess.run(
                        [
                            "docker",
                            "exec",
                            self.target_container,
                            "curl",
                            "-s",
                            "-o",
                            "/dev/null",
                            "-w",
                            "%{http_code}",
                            f"http://localhost:{self.target_port}",
                        ],
                        capture_output=True,
                        text=True,
                        timeout=10,
                    )
                    if health_check.returncode == 0 and health_check.stdout.strip() in [
                        "200",
                        "304",
                        "307",
                        "302",
                    ]:
                        print(f"[DockerManager] Target ready (took {i}s)")
                        return True

            except Exception:
                pass

            if i % 10 == 0:
                print(f"[DockerManager] Still waiting... ({i}/{timeout}s)")
            time.sleep(1)

        print(f"[DockerManager] Target not ready after {timeout}s")
        return False

    def setup_internal_service(self) -> bool:
        """Set up the internal service (run start.sh)

        Returns:
            Whether setup was successful
        """
        start_script_path = self.task_config.get("_start_script_path")
        if not start_script_path or not Path(start_script_path).exists():
            print("[DockerManager] No start script found")
            return True  # Not an error; some tasks may not need one

        print(f"[DockerManager] Setting up internal service...")

        try:
            # Copy start.sh to the target container
            result = subprocess.run(
                [
                    "docker",
                    "cp",
                    start_script_path,
                    f"{self.target_container}:/workspace/start.sh",
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode != 0:
                print(f"[DockerManager] Failed to copy start.sh: {result.stderr}")
                return False

            # Run start.sh in the background
            result = subprocess.run(
                [
                    "docker",
                    "exec",
                    "-d",
                    self.target_container,
                    "bash",
                    "/workspace/start.sh",
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode != 0:
                print(f"[DockerManager] Failed to run start.sh: {result.stderr}")
                return False

            # Wait for the internal service to start
            time.sleep(5)
            print(f"[DockerManager] Internal service started")
            return True

        except Exception as e:
            print(f"[DockerManager] Error setting up internal service: {e}")
            return False

    def exec_in_attacker(self, command: str, timeout: int = 60) -> tuple[bool, str]:
        """Execute a command in the attacker container

        Args:
            command: Command to execute
            timeout: Timeout duration (seconds)

        Returns:
            (success, output)
        """
        return self.exec_in_container(self.attacker_container, command, timeout)

    def exec_in_target(self, command: str, timeout: int = 60) -> tuple[bool, str]:
        """Execute a command in the target container

        Args:
            command: Command to execute
            timeout: Timeout duration (seconds)

        Returns:
            (success, output)
        """
        return self.exec_in_container(self.target_container, command, timeout)

    def exec_in_container(
        self, container: str, command: str, timeout: int = 60
    ) -> tuple[bool, str]:
        """Execute a command in the specified container

        Args:
            container: Container name
            command: Command to execute
            timeout: Timeout duration (seconds)

        Returns:
            (success, output)
        """
        try:
            result = subprocess.run(
                ["docker", "exec", container, "bash", "-c", command],
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            output = result.stdout
            if result.stderr:
                output += f"\nSTDERR:\n{result.stderr}"
            return result.returncode == 0, output

        except subprocess.TimeoutExpired:
            return False, f"Command timed out after {timeout}s"
        except Exception as e:
            return False, str(e)

    def get_file_content(self, container: str, file_path: str) -> str | None:
        """Get file content from a container

        Args:
            container: Container name
            file_path: File path

        Returns:
            File content or None
        """
        try:
            result = subprocess.run(
                ["docker", "exec", container, "cat", file_path],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode == 0:
                return result.stdout
            return None
        except Exception:
            return None

    def stop_environment(self) -> bool:
        """Stop the Docker environment

        Returns:
            Whether the environment stopped successfully
        """
        print(f"[DockerManager] Stopping environment for task: {self.task_id}")

        try:
            result = subprocess.run(
                ["docker", "compose", "down", "-v"],
                cwd=str(self.runtime_dir),
                capture_output=True,
                text=True,
                timeout=120,
            )
            if result.returncode != 0:
                print(f"[DockerManager] Warning during cleanup: {result.stderr}")

            print(f"[DockerManager] Environment stopped")
            return True

        except Exception as e:
            print(f"[DockerManager] Error stopping environment: {e}")
            return False
