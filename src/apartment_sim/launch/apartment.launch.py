"""Bring up Gazebo + multi-sensor bot + RViz, with WSL-friendly env and bisection knobs.

Args:
  model:=lite|full     lite = LIDAR+IMU+depth only (default). full = + 4 RGB cams.
  world:=house|empty   house = AWS small house (default). empty = empty world (debug).
  software_gl:=0|1     1 = force software OpenGL (slow but ultra-stable).
"""
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import (IncludeLaunchDescription, DeclareLaunchArgument,
                            SetEnvironmentVariable, OpaqueFunction)
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, Command, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def _make_nodes(context, *args, **kwargs):
    pkg_share = get_package_share_directory('apartment_sim')
    pkg_gazebo_ros = get_package_share_directory('gazebo_ros')

    model = LaunchConfiguration('model').perform(context)
    world = LaunchConfiguration('world').perform(context)

    xacro_file = {
        'lite': 'multi_sensor_bot_lite.urdf.xacro',
        'full': 'multi_sensor_bot.urdf.xacro',
    }[model]
    xacro_path = os.path.join(pkg_share, 'urdf', xacro_file)

    if world == 'house':
        world_path = os.path.expanduser(
            '~/ros2_apartment_sim/src/aws-robomaker-small-house-world/worlds/small_house.world')
    else:
        world_path = os.path.join(pkg_gazebo_ros, 'worlds', 'empty.world')

    rviz_config = os.path.join(pkg_share, 'rviz', 'apartment.rviz')
    robot_description = {'robot_description': ParameterValue(
        Command(['xacro ', xacro_path]), value_type=str)}

    gzserver = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(pkg_gazebo_ros, 'launch', 'gzserver.launch.py')),
        launch_arguments={'world': world_path, 'verbose': 'true'}.items(),
    )
    gzclient = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(pkg_gazebo_ros, 'launch', 'gzclient.launch.py')),
    )
    rsp = Node(package='robot_state_publisher', executable='robot_state_publisher',
               output='screen',
               parameters=[robot_description, {'use_sim_time': True}])
    spawn = Node(package='gazebo_ros', executable='spawn_entity.py',
                 arguments=['-topic', 'robot_description',
                            '-entity', 'multi_sensor_bot',
                            '-x', LaunchConfiguration('x_pose'),
                            '-y', LaunchConfiguration('y_pose'),
                            '-z', '0.05'],
                 output='screen')
    rviz = Node(package='rviz2', executable='rviz2', name='rviz2',
                arguments=['-d', rviz_config],
                parameters=[{'use_sim_time': True}], output='screen')
    return [gzserver, gzclient, rsp, spawn, rviz]


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument('model',       default_value='lite',  description='lite|full'),
        DeclareLaunchArgument('world',       default_value='house', description='house|empty'),
        DeclareLaunchArgument('software_gl', default_value='0',     description='0|1'),
        DeclareLaunchArgument('x_pose',      default_value='-3.0'),
        DeclareLaunchArgument('y_pose',      default_value='1.0'),

        # --- WSL Gazebo stability env vars (apply to all child processes) ---
        SetEnvironmentVariable(name='OGRE_RTT_MODE', value='Copy'),
        SetEnvironmentVariable(name='SVGA_VGPU10',   value='0'),
        # Set LIBGL_ALWAYS_SOFTWARE=1 manually before launching if you set software_gl:=1.

        OpaqueFunction(function=_make_nodes),
    ])
