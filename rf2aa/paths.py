import os
from pathlib import Path

try:
    path_prefix = Path(os.environ["RF2AA_DATA_HOME"])
except KeyError:
    raise ValueError(
        "RF2AA_DATA_HOME environment variable is not set") from None


def resolve_path(*args):
    return path_prefix.joinpath(*args)
