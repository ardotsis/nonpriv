import os


def get_script_paths(dir_path: str) -> list[str]:
    paths = []
    for item in os.listdir(dir_path):
        if item[-4:] == ".ps1":
            path = os.path.join(dir_path, item)
            paths.append(path)

    return paths
