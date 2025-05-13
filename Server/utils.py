"""Utility functions for Celery, FastAPI server and Radis data-base."""

import os
import logging
import yaml 
import datetime
from pathlib import Path
from contextlib import contextmanager
from typing import Dict
from glob import glob
from fastapi import Form, Query, Request, HTTPException
from dotenv import load_dotenv, dotenv_values

# Load environment variables from 'ENV_FILE' file
ENV_FILE = os.getenv("ENV_FILE")
load_dotenv(dotenv_path=ENV_FILE)
env_values = dotenv_values(ENV_FILE)

URL = os.getenv("URL")
CONTAINER_PORT = os.getenv("FASTAPI_CONTAINER_PORT_HTTPS")
PORT = os.getenv("PORT")
FASTAPI_HOST_PORT_HTTPS = os.getenv("FASTAPI_HOST_PORT_HTTPS")

SHARED_DIR = os.getenv("SHARED_DIR")
FILES_FOLDER = Path(__file__).parent / SHARED_DIR
FILES_FOLDER.mkdir(exist_ok=True)

BACKUP_DIR = os.getenv("BACKUP_DIR")
BACKUP_FOLDER = Path(__file__).parent / BACKUP_DIR
BACKUP_FOLDER.mkdir(exist_ok=True)

LOG_LEVEL = os.getenv("CELERY_LOGLEVEL").upper()
LOG_FILE = Path(__file__).parent / "server.log"
CONFIG_FILE = Path(__file__).parent / "tasks.yaml"


class TaskLogger:
    def __init__(self, logger):
        self._logger = logger
        self._task_name = None

    @contextmanager
    def task_context(self, task_name):
        old_task_name = self._task_name
        self._task_name = task_name
        try:
            yield self
        finally:
            self._task_name = old_task_name

    def _log(self, level, msg, *args, **kwargs):
        if self._task_name:
            msg = f"[{self._task_name}] {msg}"
        return getattr(self._logger, level)(msg, *args, **kwargs)

    def info(self, msg, *args, **kwargs):
        return self._log("info", msg, *args, **kwargs)

    def error(self, msg, *args, **kwargs):
        return self._log("error", msg, *args, **kwargs)

    def warning(self, msg, *args, **kwargs):
        return self._log("warning", msg, *args, **kwargs)

    def debug(self, msg, *args, **kwargs):
        return self._log("debug", msg, *args, **kwargs)


async def get_task_id(request: Request, task_id: str = Query(None), task_id_form: str = Form(None)):
    """Retieve the `task_id` from Query, Form, or Request Body."""
    form_data = await request.form()
    return task_id or task_id_form or form_data.get("task_id")


async def get_task_name(request: Request, task_name: str = Query(None), task_name_form: str = Form(None)):
    """Retieve the `task_name` from Query, Form, or Request Body."""
    form_data = await request.form()
    return task_name or task_name_form or form_data.get("task_name")


async def get_uid(request: Request, uid: str = Query(None), uid_form: str = Form(None)):
    """Retrieve the `uid` from Query, Form, or Request Body."""
    form_data = await request.form()
    return uid or uid_form or form_data.get("uid")


def format_input_filename(uid: str, task_name: str) -> str:
    return FILES_FOLDER / f"{uid}.{task_name}.input.fheencrypted"


def format_output_filename(template: str, uid: str) -> str:
    return FILES_FOLDER / template.format(uid=uid)


def format_backup_filename(template: str, uid: str, task_id: str) -> str:
    return FILES_FOLDER / f"backup.{template.format(uid=f'{uid}.{task_id}')}"


def ensure_file_exists(file_path: Path, error_message: str) -> None:
    """Ensures that the specified file exists; otherwise, logs an error and raises an exception.

    Args:
        file_path (Path): The path of the file to check.
        error_message (str): The error message to log and include in the exception.

    Raises:
        HTTPException: Raised with status code 500 if the file does not exist.
    """
    if not file_path.exists():
        logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)
    else:
        logger.debug(f"📁 Output file path: `{file_path}` exists.")


def fetch_backup_files(task_id: str, uid: str):
    """Retrieve backup files along with the last modification timestamp.

    Args:
        task_id (str): The unique identifier of the task.
        uid (str): The unique user identifier.

    Returns:
        A list of matching backup file paths and the last modification timestamp or `None`
        if no file was found.
    """
    pattern = FILES_FOLDER / f"backup.{uid}.{task_id}.*output*.fheencrypted"
    matching_files = glob(str(pattern))

    if not matching_files:
        logger.debug(f"🔍 [task_id=`%s`, uid=`%s`] No backup files found.", get_id_prefix(task_id), get_id_prefix(uid))
        return None

    file = Path(matching_files[0])
    last_mtime = file.stat().st_mtime  # Get file's last modified time
    formatted_date = datetime.datetime.fromtimestamp(last_mtime).strftime("%Y-%m-%d %H:%M:%S")

    return {'files': [str(file) for file in matching_files], 'timestamp': formatted_date}


def fetch_file_content(output_file_path: Path):
    """Reads a file and returns its content.

    Args:
        output_file_path (Path): The path of the file to read.

    Returns:
        bytes: The content of the file.

    Raises:
        HTTPException: Raised with status code 500 if the file cannot be read.
    """
    ensure_file_exists(
        output_file_path, error_message=f"❌ Output file `{output_file_path}` not found."
    )
    try:
        data = output_file_path.read_bytes()
        logger.info(
            f"📁 Successfully read output file `{output_file_path}` (Size: `{len(data)}` bytes)"
        )
    except Exception as e:
        error_message=f"❌ Failed to read output file `{output_file_path}`: `{e}`."
        logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)

    return data


def save_backup_file(backup_path, data) -> None:
    """Save  data to a backup file.

    Args:
        backup_path (Path): The path where the backup file should be saved.
        data (bytes): The binary data.

    Returns:
        None
    """
    try:
        backup_path.write_bytes(data)
        logger.debug(f"💾 Successfully saved backup file at `{backup_path}`.")
    except Exception as e:
        logger.warning(f"🚨 Failed to create backup `{backup_path}`: {e}.")


def get_id_prefix(_id: str) -> str:
    """Returns the first part of an identifier.

    Args:
        _id (str): A hyphen-separated identifier.

    Returns:
        str: The first segment of `_id` before the first hyphen.
    """
    return _id.split('-')[0] if _id is not None else None

# Configure logging
logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(),  # Also log to stderr for Docker logs
    ],
)

logger = logging.getLogger(__name__)

# Replace the existing logger with our wrapped version
task_logger = TaskLogger(logger)

# Load task configuration
try:
    with open(CONFIG_FILE, "r", encoding="utf-8") as file:
        config = yaml.safe_load(file)
        use_cases = config.get("tasks", {})
    logger.debug("📁 Successfully loaded configuration from `%s`", CONFIG_FILE)
except Exception as e:
    logger.error("❌ Failed to load configuration file `%s`: `%s`", CONFIG_FILE, e)
    raise e
