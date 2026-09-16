"""

Load user code from a mounted directory and serve it with the Runpod SDK.

Configuration is environment-driven right now, we can build that out later

RUNPOD_APP_DIR     directory the user's project is mounted at (for sls: /runpod-volume/app)
RUNPOD_HANDLER     "<file>:<function>", relative to RUNPOD_APP_DIR
RUNPOD_HOT_RELOAD  "1" re-imports the handler on every request
"""

import importlib.util
import os
import sys
import traceback

# this will be installed by the Dockerfile
import runpod

APP_DIR = os.path.abspath(os.environ.get("RUNPOD_APP_DIR", "/runpod-volume/app"))
ENTRY = os.environ.get("RUNPOD_HANDLER", "handler.py:handler")
HOT_RELOAD = os.environ.get("RUNPOD_HOT_RELOAD", "0") == "1"

MODULE_NAME = "runpod_user_app"


def _entry_parts():
    """translate the user provider handler string into a file path, ie: handler.py:handler -> /runpod-volume/app/handler.py, handler"""
    rel, _, func = ENTRY.partition(":")
    return os.path.join(APP_DIR, rel), func or "handler"


def _purge_user_modules():
    """Drop every module imported from the mount.

    Without this, only the entry file reloads and the user's own imports keep
    serving stale code.
    """
    for name, module in list(sys.modules.items()):
        path = getattr(module, "__file__", None)
        if path and os.path.abspath(path).startswith(APP_DIR + os.sep):
            del sys.modules[name]


def load_handler():
    """Import the handler from the mount. Raises if it cannot be loaded."""
    path, func_name = _entry_parts()
    if not os.path.isfile(path):
        raise FileNotFoundError(f"handler file not found: {path}")

    # this cleans out any loaded modules to support the hot reload
    _purge_user_modules()
    spec = importlib.util.spec_from_file_location(MODULE_NAME, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot import {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[MODULE_NAME] = module
    spec.loader.exec_module(module)

    handler = getattr(module, func_name, None)
    if handler is None:
        raise AttributeError(f"{path} has no function named {func_name!r}")
    if not callable(handler):
        raise TypeError(f"{path}:{func_name} is not callable")
    return handler


def _boot_banner():
    """Logging so we can see what's happening during boot."""
    try:
        contents = sorted(os.listdir(APP_DIR))
    except OSError as err:
        contents = f"<unreadable: {err}>"
    print(
        f"launcher: app_dir={APP_DIR} entry={ENTRY} "
        f"hot_reload={HOT_RELOAD} python={sys.version.split()[0]} "
        f"contents={contents}",
        flush=True,
    )


def _load_error_payload(err):
    return {
        "error": f"{type(err).__name__}: {err}",
        "app_dir": APP_DIR,
        "entry": ENTRY,
        "traceback": traceback.format_exc(limit=5),
    }


_boot_banner()

# Let the user import their own modules by name.
if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

# Load once at boot so a broken handler is visible in the worker log, not only
# in a response. Hot reload replaces this per request.
_handler = None
_load_error = None
try:
    _handler = load_handler()
    print(f"launcher: loaded {ENTRY}", flush=True)
except Exception as boot_err:  # noqa: BLE001 - any import error must be reported, not raised
    _load_error = boot_err
    print(f"launcher: failed to load {ENTRY}: {boot_err}", flush=True)


def dispatch(event):
    """We need to dispatch so we can overload the error handling"""
    global _handler, _load_error

    if HOT_RELOAD:
        try:
            _handler, _load_error = load_handler(), None
        except Exception as reload_err:  # noqa: BLE001 - reported to the caller
            _handler, _load_error = None, reload_err

    if _load_error is not None:
        return _load_error_payload(_load_error)

    return _handler(event)


runpod.serverless.start({"handler": dispatch})
