"""Generic task loader - supports multi-task generalization"""

import json
from pathlib import Path


class TaskLoader:
    """Generic task loader"""

    def __init__(self, tasks_dir: str | None = None, runtimes_dir: str | None = None):
        """Initialize the task loader

        Args:
            tasks_dir: Path to the tasks directory, defaults to tasks/ under the project root
            runtimes_dir: Path to the runtimes directory, defaults to runtimes/ under the project root
        """
        project_root = Path(__file__).parent.parent.parent

        if tasks_dir is None:
            self.tasks_dir = project_root / "data" / "task"
        else:
            self.tasks_dir = Path(tasks_dir)

        if runtimes_dir is None:
            self.runtimes_dir = project_root / "data" / "env"
        else:
            self.runtimes_dir = Path(runtimes_dir)

    def load_task(self, task_id: str) -> dict:
        """Load task configuration

        Args:
            task_id: Task ID (directory name)

        Returns:
            Dictionary containing task configuration and script contents
        """
        task_dir = self.tasks_dir / task_id

        # Load task_config.json
        config_path = task_dir / "task_config.json"
        if not config_path.exists():
            raise FileNotFoundError(f"Task config not found: {config_path}")

        with open(config_path, "r") as f:
            config = json.load(f)

        # Load verify.sh
        verify_path = task_dir / "verify.sh"
        if verify_path.exists():
            config["_verify_script"] = verify_path.read_text()
            config["_verify_script_path"] = str(verify_path)

        # Load start.sh
        start_path = task_dir / "start.sh"
        if start_path.exists():
            config["_start_script"] = start_path.read_text()
            config["_start_script_path"] = str(start_path)

        # Determine runtime
        config["_runtime"] = self.get_runtime(task_id, config)
        config["_runtime_dir"] = str(self.runtimes_dir / (config["_runtime"] + "-victim"))

        return config

    def get_runtime(self, task_id: str, config: dict) -> str:
        """Get the runtime corresponding to a task

        Args:
            task_id: Task ID
            config: Task configuration

        Returns:
            Runtime directory name

        Raises:
            ValueError: if runtime is not specified in task_config
        """
        runtime = config.get("setup_container", {}).get("runtime")
        if runtime:
            return runtime
        raise ValueError(
            f"Task {task_id} missing 'setup_container.runtime' in task_config.json. "
            "Each task must specify its runtime."
        )

    def list_tasks(self) -> list[str]:
        """List all available tasks

        Returns:
            List of task IDs
        """
        tasks = []
        for d in self.tasks_dir.iterdir():
            if d.is_dir() and (d / "task_config.json").exists():
                tasks.append(d.name)
        return sorted(tasks)

    def get_task_summary(self, task_id: str) -> dict:
        """Get task summary information

        Args:
            task_id: Task ID

        Returns:
            Task summary dictionary
        """
        config = self.load_task(task_id)
        return {
            "task_id": task_id,
            "task_name": config.get("task_name", "Unknown"),
            "cve": config.get("vulnerability", {}).get("cve", "Unknown"),
            "type": config.get("vulnerability", {}).get("type", "Unknown"),
            "severity": config.get("vulnerability", {}).get("severity", "Unknown"),
            "runtime": config.get("_runtime", "Unknown"),
        }
