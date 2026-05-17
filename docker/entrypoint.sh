#!/usr/bin/env bash
# Sources ROS 2 + Gazebo + the workspace, enables WSL2 GPU rendering, then runs
# the given command. The GUI displays through WSLg (host's X server) — launch
# from a WSL2 / Linux terminal so $DISPLAY and /tmp/.X11-unix are present.
set -e

source /opt/ros/humble/setup.bash
source /usr/share/gazebo/setup.sh
[ -f /ws/install/setup.bash ] && source /ws/install/setup.bash

export TURTLEBOT3_MODEL=waffle
export GAZEBO_MODEL_PATH=${GAZEBO_MODEL_PATH}:/ws/src/aws-robomaker-small-house-world/models:/opt/ros/humble/share/turtlebot3_gazebo/models
export GAZEBO_RESOURCE_PATH=${GAZEBO_RESOURCE_PATH}:/ws/src/aws-robomaker-small-house-world/worlds

# WSL Gazebo stability knobs
export OGRE_RTT_MODE=Copy
export SVGA_VGPU10=0

# --- GPU rendering ---
# WSL2 exposes the host GPU's user-mode driver libs under /usr/lib/wsl/lib
# (mounted by docker-compose). With these on the path, Mesa uses the GPU
# instead of the llvmpipe software rasterizer.
if [ -d /usr/lib/wsl/lib ]; then
  export LD_LIBRARY_PATH=/usr/lib/wsl/lib:${LD_LIBRARY_PATH}
fi

if [ -z "${DISPLAY}" ]; then
  echo "[entrypoint] WARNING: \$DISPLAY is empty — no GUI."
  echo "[entrypoint] Run 'docker compose up' from a WSL2 / Linux terminal,"
  echo "[entrypoint] not from Windows PowerShell."
else
  renderer="$(glxinfo -B 2>/dev/null | sed -n 's/^.*OpenGL renderer string: //p')"
  echo "[entrypoint] DISPLAY=${DISPLAY}  GPU renderer: ${renderer:-unknown}"
  case "${renderer}" in
    *llvmpipe*|*softpipe*|"") echo "[entrypoint] NOTE: software rendering — GPU passthrough not active." ;;
  esac
fi

exec "$@"
