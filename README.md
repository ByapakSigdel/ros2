# ROS2 Apartment Sim

Indoor Gazebo simulation for a multi-sensor mobile robot.
Tested on **Ubuntu 22.04 (WSL2 or native)** with **ROS2 Humble + Gazebo Classic 11**.

The robot is a differential-drive base carrying:

- 360° **LIDAR** (`/scan`)
- **IMU** (`/imu`)
- Front-facing **RGB-D depth camera** (`/depth_camera/...`)
- 4 **RGB cameras** — front / rear / left / right (full robot variant only)

The world is the open-source **AWS RoboMaker Small House**: a furnished apartment with rooms, walls, and obstacles.

---

## 0. Quick start with Docker (recommended for sharing)

If `install.sh` fails on someone else's machine, use Docker — it pins Ubuntu,
ROS, Gazebo, every apt package, **and clones the AWS world** (which is
`.gitignore`d, so a plain `git clone` of this repo is missing it — the #1 reason
a teammate's setup breaks).

**Requirements:** Windows 11 + WSL2 with Docker (Docker Desktop WSL integration,
or Docker Engine inside the WSL distro). WSLg provides the GUI automatically — no
X server to install.

Run everything **from inside your WSL2 distro** (not PowerShell):

```bash
cd ~/ros2_apartment_sim
docker compose build          # first time only, ~15-25 min
docker compose up             # Gazebo + RViz windows open on your desktop
```

Drive the robot from a second WSL terminal:

```bash
docker compose exec sim bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

Other launch args — edit the `command:` line in `docker-compose.yml`, or run ad hoc:

```bash
docker compose run --rm sim ros2 launch apartment_sim apartment.launch.py model:=full
```

Rosbags written to `/ws/bags` inside the container appear in `./bags/` on the host.

**Troubleshooting**
- *No windows appear* — confirm `echo $DISPLAY` is non-empty in your WSL shell;
  run `wsl --update` in PowerShell to get current WSLg.
- *Gazebo runs very slowly* — it's using software rendering. If `ls /dev/dri`
  shows devices, uncomment the `devices:` block in `docker-compose.yml` for GPU
  acceleration.
- *Image build is huge* — expected (~6-8 GB); it's a full ROS desktop + Gazebo.

The native `install.sh` path below still works and is fine for your own machine.

---

## 1. Clone and install (one-time, ~10–20 min)

On a fresh Ubuntu 22.04:

```bash
git clone <YOUR_REPO_URL> ~/ros2_apartment_sim
cd ~/ros2_apartment_sim
bash install.sh
```

`install.sh` will:

1. Add the ROS2 apt repo
2. `apt install` ROS2 Humble desktop, Gazebo-ROS bridge, TurtleBot3 stack, Nav2, SLAM Toolbox, xacro, rviz2
3. `git clone` the AWS Small House world into `src/`
4. `rosdep install` package deps
5. `colcon build --symlink-install`
6. Append ROS2 + Gazebo env to `~/.bashrc`

It will prompt for your sudo password.

When done, **open a new terminal** so the updated `.bashrc` loads.

## 2. Run the simulation

```bash
ros2 launch apartment_sim apartment.launch.py
```

Default args: `model:=lite`, `world:=house`. Both Gazebo and RViz open.

### Drive the robot

In a second terminal:

```bash
ros2 run turtlebot3_teleop teleop_keyboard
```

(Drive keys: `w / a / s / d / x`, space = stop. Topic `/cmd_vel` is what the diff-drive plugin listens on, so any teleop tool that publishes `geometry_msgs/Twist` to `/cmd_vel` works.)

## 3. Launch arguments

```bash
ros2 launch apartment_sim apartment.launch.py model:=<lite|full> world:=<house|empty> x_pose:=<m> y_pose:=<m>
```

| Arg | Default | Values | What it does |
|---|---|---|---|
| `model` | `lite` | `lite`, `full` | `lite` = LIDAR + IMU + 1 depth cam (stable everywhere). `full` adds 4 extra RGB cams. |
| `world` | `house` | `house`, `empty` | `house` = AWS Small House apartment. `empty` = bare ground plane (debug). |
| `x_pose` | `-3.0` | float | Spawn X (meters). |
| `y_pose` | `1.0`  | float | Spawn Y (meters). |

## 4. Topics

| Sensor / Function | Topic | Type |
|---|---|---|
| LIDAR | `/scan` | `sensor_msgs/LaserScan` |
| IMU | `/imu` | `sensor_msgs/Imu` |
| Depth camera color | `/depth_camera/image_raw` | `sensor_msgs/Image` |
| Depth camera depth | `/depth_camera/depth/image_raw` | `sensor_msgs/Image` |
| Depth camera cloud | `/depth_camera/points` | `sensor_msgs/PointCloud2` |
| Front RGB *(full)*  | `/camera_front/image_raw` | `sensor_msgs/Image` |
| Rear RGB *(full)*   | `/camera_rear/image_raw`  | `sensor_msgs/Image` |
| Left RGB *(full)*   | `/camera_left/image_raw`  | `sensor_msgs/Image` |
| Right RGB *(full)*  | `/camera_right/image_raw` | `sensor_msgs/Image` |
| Odometry | `/odom` | `nav_msgs/Odometry` |
| Joint states | `/joint_states` | `sensor_msgs/JointState` |
| Drive command | `/cmd_vel` | `geometry_msgs/Twist` |
| TF | `/tf`, `/tf_static` | |

List live: `ros2 topic list`. Check rate: `ros2 topic hz /scan`.

## 5. Collecting data

### Record a rosbag
```bash
# all topics
ros2 bag record -a -o ~/apartment_run_$(date +%Y%m%d_%H%M%S)

# selected topics only (smaller)
ros2 bag record /scan /imu /odom /depth_camera/depth/image_raw /tf /tf_static
```

### Play back
```bash
ros2 bag play <bag_dir> --clock
```

### Live SLAM
```bash
ros2 launch slam_toolbox online_async_launch.py use_sim_time:=true
```

## 6. Repository layout

```
ros2_apartment_sim/
├── install.sh                       # one-shot installer (apt + clone world + build)
├── README.md
├── .gitignore
└── src/
    ├── apartment_sim/               # this package
    │   ├── package.xml
    │   ├── CMakeLists.txt
    │   ├── urdf/
    │   │   ├── multi_sensor_bot.urdf.xacro       # full: 4 RGB + depth + LIDAR + IMU
    │   │   └── multi_sensor_bot_lite.urdf.xacro  # lite: depth + LIDAR + IMU
    │   ├── launch/apartment.launch.py
    │   └── rviz/apartment.rviz
    └── aws-robomaker-small-house-world/   # cloned by install.sh (gitignored)
```

## 7. Notes & WSL gotchas

- **Run `install.sh` only once.** Re-running is safe (idempotent) but unnecessary. To rebuild only the workspace after editing your own files: `colcon build --symlink-install` from `~/ros2_apartment_sim`.
- **WSL2 only** (not WSL1). Update with `wsl --update` from Windows PowerShell if Gazebo is slow or glitchy.
- The **`Missing model.config for ...`** spam in Gazebo logs is harmless GUI-side noise — Gazebo is scanning every ROS package directory because TurtleBot3's env hook adds `/opt/ros/humble/share` to `GAZEBO_MODEL_PATH`. Simulation runs fine.
- If Gazebo crashes with `RTShaderSystem.cc:480 Unable to find shader lib`: `GAZEBO_RESOURCE_PATH` is missing `/usr/share/gazebo-11`. Make sure `.bashrc` sources `/usr/share/gazebo/setup.sh` **before** any `GAZEBO_RESOURCE_PATH` exports (`install.sh` does this).
- **`model:=full` in WSL** can be heavy (5 simultaneous camera sensors). If it crashes, drop the camera resolutions in `urdf/multi_sensor_bot.urdf.xacro` (search for `<width>640</width>`).

## 8. Cheat sheet

| Action | Command |
|---|---|
| Install (fresh machine) | `bash install.sh` |
| Run sim (default) | `ros2 launch apartment_sim apartment.launch.py` |
| Run with all cameras | `ros2 launch apartment_sim apartment.launch.py model:=full` |
| Run on empty world (debug) | `ros2 launch apartment_sim apartment.launch.py world:=empty` |
| Drive the robot | `ros2 run turtlebot3_teleop teleop_keyboard` |
| List topics | `ros2 topic list` |
| Topic rate | `ros2 topic hz /scan` |
| Record everything | `ros2 bag record -a` |
| Run SLAM | `ros2 launch slam_toolbox online_async_launch.py use_sim_time:=true` |
| Rebuild after edits | `colcon build --symlink-install` |
# ros2
# ros2
# ros2
# ros2
