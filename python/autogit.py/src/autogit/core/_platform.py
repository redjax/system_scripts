import os
import platform
import sys


def os_type() -> str | None:
    """Return a string value OS type.

    Returns:
        (string): Value of `platform.system()`, i.e. `Windows`, `Linux`, `Darwin`, `Java`, or `Unknown`.
            Return value is None is platform cannot be detected.
    """
    ostype = platform.system()

    assert ostype in ["Windows", "Linux", "Darwin"], Exception(
        f"Unrecognized/unsupported OS type: '{ostype}'."
    )

    return ostype


## Initialize platform value
PLATFORM: str = os_type()
assert PLATFORM, Exception(f"Unable to detect OS platform.")
