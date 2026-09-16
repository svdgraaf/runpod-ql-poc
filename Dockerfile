# Base image for the "no build step" POC.
#
# The image holds only the language runtime and the SDK. User code never lands
# here -- it comes from a mount at runtime (network volume today, global storage
# later). Rebuild this image only to bump Python or the SDK.
FROM python:3.13-slim

# The SDK. Pin this once the POC works, so a worker restart cannot pick up a
# different SDK than the one you tested.
RUN pip install --no-cache-dir runpod

# The launcher is the container's whole job: find the user's handler on the
# mount, import it, hand it to the SDK.
COPY launcher.py /opt/runpod/launcher.py

# Where the user's project is mounted. Serverless workers get the network
# volume at /runpod-volume; pods get it wherever the pod config says, commonly
# /workspace. Override per deployment.
ENV RUNPOD_APP_DIR=/runpod-volume/app \
    RUNPOD_HANDLER=handler.py:handler \
    RUNPOD_HOT_RELOAD=0 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

CMD ["python", "/opt/runpod/launcher.py"]
