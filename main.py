#!/usr/bin/env python3
"""AAA Security Assessment Framework - CLI Entry Point"""

import tqdm
import json
import os
import typer
import dotenv

dotenv.load_dotenv()

app = typer.Typer(
    name="aaa-security",
    help="AAA Security Assessment Framework for CVE Exploitation Testing",
)


@app.command()
def green(
    host: str = typer.Option(
        default=os.getenv("GREEN_AGENT_HOST", "localhost"),
        help="Host to bind Green Agent",
    ),
    port: int = typer.Option(
        default=int(os.getenv("GREEN_AGENT_PORT", "9001")),
        help="Port for Green Agent",
    ),
):
    """Start the Green Agent (Assessment Orchestrator)."""
    from src.green_agent.agent import start_green_agent

    print(f"Starting Green Agent on {host}:{port}")
    start_green_agent(host=host, port=port)


@app.command()
def white(
    host: str = typer.Option(
        default=os.getenv("WHITE_AGENT_HOST", "localhost"),
        help="Host to bind White Agent",
    ),
    port: int = typer.Option(
        default=int(os.getenv("WHITE_AGENT_PORT", "9002")),
        help="Port for White Agent",
    ),
):
    """Start the White Agent (Task Executor)."""
    from src.white_agent.agent import start_white_agent

    print(f"Starting White Agent on {host}:{port}")
    start_white_agent(host=host, port=port)


def collect():
    # Gather all submission-related files into a bundle for submission
    # - `./src/white_agent` folder
    # - `./results` folder
    # - `./all_evaluation_results.json` file
    # - `./pyproject.toml` file
    import zipfile

    bundle_path = "submission.zip"
    with zipfile.ZipFile(bundle_path, "w", zipfile.ZIP_DEFLATED) as zf:
        # Add src/white_agent folder
        white_agent_dir = "src/white_agent"
        if os.path.isdir(white_agent_dir):
            for root, _, files in os.walk(white_agent_dir):
                for file in files:
                    filepath = os.path.join(root, file)
                    zf.write(filepath)

        # Add results folder
        results_dir = "results"
        if os.path.isdir(results_dir):
            for root, _, files in os.walk(results_dir):
                for file in files:
                    filepath = os.path.join(root, file)
                    zf.write(filepath)

        # Add all_evaluation_results.json
        if os.path.isfile("all_evaluation_results.json"):
            zf.write("all_evaluation_results.json")

        # Add pyproject.toml
        if os.path.isfile("pyproject.toml"):
            zf.write("pyproject.toml")

    print(f"Submission bundle created: {bundle_path}")


@app.command()
def run_one(
    task_id: str = typer.Argument(
        default="task-cve-2024-32964-ssrf",
        help="Task ID to evaluate",
    ),
):
    """Launch complete evaluation with both agents."""
    from src.launcher import launch_evaluation

    result = launch_evaluation(task_id)
    print(f"Final Evaluation Result:\n{result}")


@app.command()
def run_all():
    from src.launcher import launch_evaluation

    # get all folder names under data/task
    task_folders = [
        f
        for f in os.listdir("data/task")
        if os.path.isdir(os.path.join("data/task", f))
    ]

    def parse_result(result):
        try:
            target_line = [
                line for line in result.splitlines() if "Full result saved to:" in line
            ]
            assert len(target_line) == 1, "Expected exactly one line with result path"
            result_path = target_line[0].split("Full result saved to:")[1].strip()
            with open(result_path, "r") as f:
                result_content = json.load(f)
            return {
                "result_file_loaded": True,
                "result_content": result_content,
                "result_file_load_error": None,
                "score": result_content.get("score", 0),
            }
        except Exception as e:
            return {
                "result_file_loaded": False,
                "result_content": None,
                "result_file_load_error": str(e),
                "score": 0,
            }

    all_results = []
    for task_id in tqdm.tqdm(task_folders, desc="Evaluating tasks"):
        print(f"Running evaluation for task: {task_id}")
        result = launch_evaluation(task_id)
        parsed = parse_result(result)
        parsed["task_id"] = task_id
        all_results.append(parsed)
        print(f"Result for {task_id}:\n{result}")
        print(
            "Average score so far: {:.2f}".format(
                sum(r["score"] for r in all_results) / len(all_results)
            )
        )
        print("=" * 60)

    with open("all_evaluation_results.json", "w") as f:
        json.dump(
            {
                "all_results": all_results,
                "average_score": 1.0
                * sum(r["score"] for r in all_results)
                / len(all_results),
            },
            f,
            indent=2,
        )

    collect()


@app.command()
def tasks():
    """List all available tasks."""
    from src.agentxploit.task_loader import TaskLoader

    loader = TaskLoader()
    task_list = loader.list_tasks()

    print("Available Tasks:")
    print("-" * 60)
    for tid in task_list:
        try:
            summary = loader.get_task_summary(tid)
            print(f"  {tid}")
            print(f"    CVE: {summary['cve']}")
            print(f"    Type: {summary['type']}")
            print(f"    Severity: {summary['severity']}")
            print(f"    Runtime: {summary['runtime']}")
            print()
        except Exception as e:
            print(f"  {tid} (error loading: {e})")
            print()


@app.command()
def info(
    task_id: str = typer.Argument(..., help="Task ID to show info for"),
):
    """Show detailed information about a task."""
    from src.agentxploit.task_loader import TaskLoader

    loader = TaskLoader()
    try:
        config = loader.load_task(task_id)

        print(f"Task: {config.get('task_name', 'Unknown')}")
        print("=" * 60)
        print()

        vuln = config.get("vulnerability", {})
        print("Vulnerability:")
        print(f"  CVE: {vuln.get('cve', 'Unknown')}")
        print(f"  Type: {vuln.get('type', 'Unknown')}")
        print(f"  Severity: {vuln.get('severity', 'Unknown')}")
        print(f"  Summary: {vuln.get('summary', 'Unknown')}")
        print()

        obj = config.get("objective", {})
        print("Objective:")
        print(f"  Goal: {obj.get('goal', 'Unknown')}")
        print(f"  Target: {obj.get('target_endpoint', 'Unknown')}")
        print()

        print(f"Runtime: {config.get('_runtime', 'Unknown')}")
        print(f"Timeout: {config.get('timeout', 300)}s")

    except FileNotFoundError:
        print(f"Error: Task '{task_id}' not found")
        raise typer.Exit(1)


if __name__ == "__main__":
    app()
