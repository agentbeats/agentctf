"""Standardized assessment result format"""

import json
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path


@dataclass
class VerificationStep:
    """A single verification step"""
    command: str
    container: str
    success: bool
    output: str
    expected: str = ""


@dataclass
class AgentAction:
    """An action performed by the agent"""
    step: int
    action_type: str  # "bash" | "done"
    command: str = ""
    reasoning: str = ""
    output: str = ""
    success: bool = True


@dataclass
class AssessmentResult:
    """Standardized assessment result"""
    # Meta information
    task_id: str
    task_name: str
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())
    duration_seconds: float = 0.0

    # Vulnerability information
    cve: str = ""
    vulnerability_type: str = ""
    severity: str = ""

    # Assessment result
    success: bool = False
    score: int = 0  # 0-100
    reasoning: str = ""

    # Detailed information
    steps_taken: int = 0
    agent_actions: list = field(default_factory=list)
    verification_results: list = field(default_factory=list)
    workspace_files: dict = field(default_factory=dict)

    # Agent information
    green_agent_version: str = "1.0.0"
    white_agent_version: str = "1.0.0"
    llm_model: str = "openai/gpt-4o"

    @classmethod
    def from_task_config(cls, task_config: dict) -> "AssessmentResult":
        """Create a result object from task configuration"""
        vulnerability = task_config.get("vulnerability", {})
        return cls(
            task_id=task_config.get("task_id", "unknown"),
            task_name=task_config.get("task_name", "Unknown Task"),
            cve=vulnerability.get("cve", ""),
            vulnerability_type=vulnerability.get("type", ""),
            severity=vulnerability.get("severity", ""),
        )

    def to_dict(self) -> dict:
        """Convert to dictionary"""
        return asdict(self)

    def to_json(self, indent: int = 2) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict(), indent=indent, ensure_ascii=False)

    def save(self, results_dir: str | Path = "results") -> Path:
        """Save result to file

        Args:
            results_dir: Results directory

        Returns:
            Path of the saved file
        """
        results_dir = Path(results_dir)
        results_dir.mkdir(parents=True, exist_ok=True)

        # Generate filename
        timestamp_safe = self.timestamp.replace(":", "-").replace(".", "-")
        filename = f"{self.task_id}_{timestamp_safe}.json"
        filepath = results_dir / filename

        filepath.write_text(self.to_json())
        return filepath

    def summary(self) -> str:
        """Generate result summary"""
        status = "SUCCESS" if self.success else "FAILED"
        return f"""
=== Assessment Result ===
Task: {self.task_name}
CVE: {self.cve}
Status: {status}
Score: {self.score}/100
Duration: {self.duration_seconds:.2f}s
Steps: {self.steps_taken}

Reasoning:
{self.reasoning}
"""
