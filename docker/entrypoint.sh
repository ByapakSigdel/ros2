#!/usr/bin/env bash
# Sources ROS 2 + Gazebo + the apartment_sim workspace, then runs the given command.
set -e

source /opt/ros/humble/setup.bash
source /usr/share/gazebo/setup.sh
[ -f /ws/install/setup.bash ] && source /ws/install/setup.bash

export TURTLEBOT3_MODEL=waffle
export GAZEBO_MODEL_PATH=${GAZEBO_MODEL_PATH}:/ws/src/aws-robomaker-small-house-world/models:/opt/ros/humble/share/turtlebot3_gazebo/models
export GAZEBO_RESOURCE_PATH=${GAZEBO_RESOURCE_PATH}:/ws/src/aws-robomaker-small-house-world/worlds

# WSL Gazebo stability (same knobs the launch file sets)
export OGRE_RTT_MODE=Copy
export SVGA_VGPU10=0

exec "$@"
