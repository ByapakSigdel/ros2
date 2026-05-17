# syntax=docker/dockerfile:1
# ROS 2 Humble + Gazebo Classic 11 + apartment_sim.
#
# GUI via WSLg: Gazebo/RViz windows open on the host desktop, GPU-accelerated
# through the WSL2 GPU passthrough (/dev/dri + /usr/lib/wsl). Launch from a
# WSL2 (Windows 11) or native-Linux terminal — see README section 0.
FROM osrf/ros:humble-desktop

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# --- ROS / Gazebo packages (mirrors install.sh) + GL libs for GPU rendering ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      git wget curl \
      ros-dev-tools \
      ros-humble-gazebo-ros-pkgs \
      ros-humble-gazebo-ros2-control \
      ros-humble-turtlebot3 \
      ros-humble-turtlebot3-msgs \
      ros-humble-turtlebot3-gazebo \
      ros-humble-turtlebot3-simulations \
      ros-humble-turtlebot3-teleop \
      ros-humble-nav2-bringup \
      ros-humble-slam-toolbox \
      ros-humble-cartographer \
      ros-humble-cartographer-ros \
      ros-humble-xacro \
      ros-humble-joint-state-publisher \
      ros-humble-robot-state-publisher \
      ros-humble-rviz2 \
      ros-humble-teleop-twist-keyboard \
      python3-colcon-common-extensions \
      python3-rosdep python3-vcstool \
      libgl1-mesa-dri libglx-mesa0 mesa-utils x11-utils \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /ws

# --- Package source. Only apartment_sim is copied; the AWS world is cloned below
#     (it is .gitignored in the repo, which is exactly why friends' clones break). ---
COPY src/apartment_sim ./src/apartment_sim

RUN git clone -b ros2 --depth 1 \
      https://github.com/aws-robotics/aws-robomaker-small-house-world.git \
      src/aws-robomaker-small-house-world

# --- Resolve deps + build the workspace ---
RUN apt-get update \
  && rosdep update --rosdistro humble \
  && rosdep install --from-paths src --ignore-src -r -y \
  && rm -rf /var/lib/apt/lists/*

RUN source /opt/ros/humble/setup.bash \
  && colcon build --symlink-install

# --- Sourced by `docker compose exec ... bash` (interactive shells) ---
RUN cat >> /root/.bashrc <<'EOF'
source /opt/ros/humble/setup.bash
source /usr/share/gazebo/setup.sh
[ -f /ws/install/setup.bash ] && source /ws/install/setup.bash
export TURTLEBOT3_MODEL=waffle
export GAZEBO_MODEL_PATH=$GAZEBO_MODEL_PATH:/ws/src/aws-robomaker-small-house-world/models:/opt/ros/humble/share/turtlebot3_gazebo/models
export GAZEBO_RESOURCE_PATH=$GAZEBO_RESOURCE_PATH:/ws/src/aws-robomaker-small-house-world/worlds
[ -d /usr/lib/wsl/lib ] && export LD_LIBRARY_PATH=/usr/lib/wsl/lib:$LD_LIBRARY_PATH
EOF

COPY docker/entrypoint.sh /entrypoint.sh
# Strip CR in case the host cloned with Windows (CRLF) line endings —
# otherwise the shebang becomes 'bash\r' and the container exits 127.
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["ros2", "launch", "apartment_sim", "apartment.launch.py"]
