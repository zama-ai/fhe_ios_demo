"""Methods to deploy a server using Docker.

It builds a Docker image and spawns a Docker container that runs the server.

"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

DATE_FORMAT: str = "%Y_%m_%d_%H_%M_%S"


def delete_image(image_name: str):
    """Delete a Docker image.

    Arguments:
        image_name (str): to name of the image to delete.
    """
    to_delete = subprocess.check_output(
        f"docker ps -a --filter name={image_name} -q", shell=True
    ).decode("utf-8")
    if to_delete:
        subprocess.check_output(f"docker rmi {to_delete}", shell=True)


def stop_container(image_name: str):
    """Kill all containers that use a given image.

    Arguments:
        image_name (str): name of Docker image for which to stop Docker containers.
    """
    to_delete = subprocess.check_output(
        f"docker ps -q --filter ancestor={image_name}", shell=True
    ).decode("utf-8")
    if to_delete:
        subprocess.check_output(f"docker kill {to_delete}", shell=True)


def build_docker_image(image_name: str):
    """Build server Docker image.

    Arguments:
        image_name (str): name to give to the image.
    """
    delete_image(image_name)

    path_of_script = Path(__file__).parent.resolve()

    cwd = os.getcwd()
    with TemporaryDirectory() as directory:
        temp_dir = Path(directory)
        
        os.mkdir(str(temp_dir) + "/rust_folder")
        os.mkdir(str(temp_dir) + "/rust_folder/src")

        os.mkdir(str(temp_dir) + "/rust_array_stats")
        os.mkdir(str(temp_dir) + "/rust_array_stats/src")

        files = [
            "server.py",
            "server_requirements.txt",
            "rust_folder/Cargo.toml",
            "rust_folder/Cargo.lock",
            "rust_folder/src/main.rs",
            "rust_array_stats/Cargo.toml",
            "rust_array_stats/Cargo.lock",
            "rust_array_stats/src/main.rs"
        ]
        
        # Copy files
        for file_name in files:
            source = path_of_script / file_name
            target = temp_dir / file_name
            shutil.copyfile(src=source, dst=target)

        # Build image
        os.chdir(temp_dir)
        command = (
            f'docker build --tag {image_name}:latest --file "{path_of_script}/Dockerfile.server" .'
        )
        subprocess.check_output(command, shell=True)
    os.chdir(cwd)

def main(image_name: str):
    """Deploy function.

    - Builds Docker image.
    - Runs Docker server.
    - Stop container and delete image.

    Arguments:
        image_name (str): name of the Docker image
    """

    build_docker_image(image_name)

    if args.only_build:
        return

    PORT_TO_CHOOSE=8888

    # Run newly created Docker server
    try:
        with open("./url.txt", mode="w", encoding="utf-8") as file:
            file.write(f"http://localhost:{PORT_TO_CHOOSE}")
        subprocess.check_output(f"docker run -p {PORT_TO_CHOOSE}:5000 {image_name}", shell=True)
    except KeyboardInterrupt:
        message = "Terminate container? (y/n) "
        shutdown_instance = input(message).lower()
        while shutdown_instance not in {"no", "n", "yes", "y"}:
            shutdown_instance = input(message).lower()
        if shutdown_instance in {"y", "yes"}:
            stop_container(image_name=image_name)
            delete_image(image_name=image_name)
        sys.exit(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--image-name", dest="image_name", type=Path, default="server")
    parser.add_argument("--only-build", dest="only_build", action="store_true")
    args = parser.parse_args()
    main(image_name=args.image_name)
