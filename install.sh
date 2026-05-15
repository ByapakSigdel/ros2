#!/usr/bin/env bash
# One-shot installer: ROS2 Humble + Gazebo Classic 11 + TurtleBot3 + AWS Small House
# Run from this directory:  bash install.sh
# Re-runnable: skips steps that already succeeded.
set -e

WS="$HOME/ros2_apartment_sim"
cd "$WS"

echo "==> 1/7 Base apt deps"
sudo apt update
sudo apt install -y curl gnupg lsb-release software-properties-common locales git wget

echo "==> 2/7 Locale (UTF-8)"
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

echo "==> 3/7 ROS2 apt repo"
sudo add-apt-repository universe -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update

echo "==> 4/7 ROS2 Humble desktop + Gazebo bridge + TB3 + Nav2/SLAM + tools"
sudo apt install -y \
  ros-humble-desktop \
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
  python3-colcon-common-extensions \
  python3-rosdep python3-vcstool

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
  sudo rosdep init
fi
rosdep update

echo "==> 5/7 Clone AWS RoboMaker Small House world into workspace"
cd "$WS/src"
if [ ! -d aws-robomaker-small-house-world ]; then
  git clone -b ros2 https://github.com/aws-robotics/aws-robomaker-small-house-world.git
fi

echo "==> 6/7 rosdep + colcon build"
cd "$WS"
source /opt/ros/humble/setup.bash
rosdep install --from-paths src --ignore-src -r -y || true
colcon build --symlink-install

echo "==> 7/7 Shell setup (.bashrc)"
BRC="$HOME/.bashrc"
grep -q "ros2_apartment_sim" "$BRC" || cat >> "$BRC" <<'EOF'

# --- ROS2 apartment sim ---
source /opt/ros/humble/setup.bash
[ -f $HOME/ros2_apartment_sim/install/setup.bash ] && source $HOME/ros2_apartment_sim/install/setup.bash
export TURTLEBOT3_MODEL=waffle
export GAZEBO_MODEL_PATH=$GAZEBO_MODEL_PATH:$HOME/ros2_apartment_sim/src/aws-robomaker-small-house-world/models:/opt/ros/humble/share/turtlebot3_gazebo/models
export GAZEBO_RESOURCE_PATH=$GAZEBO_RESOURCE_PATH:$HOME/ros2_apartment_sim/src/aws-robomaker-small-house-world/worlds
# --- end ---
EOF

echo ""
echo "================================================================"
echo "Done. Open a NEW WSL shell, then run:"
echo "  ros2 launch apartment_sim apartment.launch.py"
echo "================================================================"
