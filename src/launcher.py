"""Launcher - Evaluation workflow orchestrator"""

import time
import dotenv
import multiprocessing as mp

from src.green_agent.agent import start_green_agent
from src.white_agent.agent import start_white_agent
from src.my_util import my_a2a
import asyncio


dotenv.load_dotenv()


def wait_agent_ready(url, timeout=30):
    return asyncio.run(my_a2a.wait_agent_ready(url, timeout=timeout))


def send_message(url, message):
    return asyncio.run(my_a2a.send_message(url, message))


def stop_process(p):
    if p.is_alive():
        p.terminate()
        p.join(timeout=3)
        if p.is_alive():
            p.kill()
            p.join(timeout=3)
    p.close()


def launch_evaluation(
    task_id: str = "task-cve-2024-32964-ssrf",
    green_host: str = "localhost",
    green_port: int = 9001,
    white_host: str = "localhost",
    white_port: int = 9002,
):
    """Launch the full evaluation workflow using subprocess

    This uses subprocess instead of multiprocessing to avoid event loop deadlock issues.
    Agent stdout/stderr are redirected to temp files to prevent pipe buffer deadlocks.

    Args:
        task_id: Task ID
        green_host: Green Agent host
        green_port: Green Agent port
        white_host: White Agent host
        white_port: White Agent port
    """
    print("=" * 60)
    print("AAA Security Assessment Framework")
    print("=" * 60)
    print(f"Task ID: {task_id}")
    print()

    green_url = f"http://{green_host}:{green_port}"
    white_url = f"http://{white_host}:{white_port}"

    # Start Green Agent
    print("[1/4] Starting Green Agent...")
    p_green = mp.Process(
        target=start_green_agent,
        kwargs={"host": green_host, "port": green_port},
        daemon=True,
    )
    p_green.start()

    # Wait for Green Agent to start
    time.sleep(3)

    # Check if Green Agent is running
    if not p_green.is_alive():
        raise RuntimeError("Green Agent failed to start")

    # Wait for Green Agent to be ready
    if not wait_agent_ready(green_url, timeout=30):
        stop_process(p_green)
        raise RuntimeError("Green Agent not ready after 30s.")

    print(f"      Green Agent ready at {green_url}")

    # Start White Agent
    print("[2/4] Starting White Agent...")
    p_white = mp.Process(
        target=start_white_agent,
        kwargs={"host": white_host, "port": white_port},
        daemon=True,
    )
    p_white.start()
    # Wait for White Agent to start
    time.sleep(3)

    # Check if White Agent is running
    if not p_white.is_alive():
        stop_process(p_green)
        raise RuntimeError("White Agent failed to start")

    # Wait for White Agent to be ready
    if not wait_agent_ready(white_url, timeout=30):
        stop_process(p_green)
        stop_process(p_white)
        raise RuntimeError("White Agent not ready after 30s.")
    print(f"      White Agent ready at {white_url}")

    # 3. Send task to Green Agent
    print("[3/4] Sending task to Green Agent...")
    print(
        "      This may take several minutes (Docker startup + LLM calls + verification)..."
    )
    task_message = f"""
<task_id>{task_id}</task_id>
<white_agent_url>{white_url}/</white_agent_url>
"""

    try:
        response = send_message(green_url, task_message)
        print()
        print("=" * 60)
        print("[4/4] EVALUATION RESULTS")
        print("=" * 60)

        # Extract response text
        from a2a.types import SendMessageSuccessResponse, Message
        from a2a.utils import get_text_parts

        res_root = response.root
        if isinstance(res_root, SendMessageSuccessResponse):
            res_result = res_root.result
            if isinstance(res_result, Message):
                text_parts = get_text_parts(res_result.parts)
                if text_parts:
                    return text_parts[0]
                else:
                    print("No text response from Green Agent")
            else:
                print(f"Unexpected result type: {type(res_result)}")
        else:
            print(f"Unexpected response type: {type(res_root)}")
        return None

    except Exception as e:
        print(f"Error during evaluation: {e}")
        import traceback

        traceback.print_exc()

    finally:
        print()
        print("Stopping agents...")
        stop_process(p_green)
        stop_process(p_white)
        print("Agents stopped.")
        print("Evaluation complete.")
