cmake_minimum_required(VERSION 3.8)
project(apartment_sim)

find_package(ament_cmake REQUIRED)

install(DIRECTORY
  launch
  urdf
  worlds
  rviz
  config
  DESTINATION share/${PROJECT_NAME}/
)

ament_package()
