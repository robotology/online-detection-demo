# Copyright: (C) 2018 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Vadim Tikhanoff
# CopyPolicy: Released under the terms of the GNU GPL v2.0.

cmake_minimum_required(VERSION 3.5)
project(yarp-multi-viewer)

find_package(YARP 3.1 REQUIRED COMPONENTS OS sig dev math rosmsg)
find_package(ICUBcontrib REQUIRED)
find_package(OpenCV REQUIRED)
list(APPEND CMAKE_MODULE_PATH ${ICUBCONTRIB_MODULE_PATH})

include(ICUBcontribOptions)
include(ICUBcontribHelpers)

icubcontrib_set_default_prefix()

include_directories(${OpenCV_INCLUDE_DIRS})
add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} ${YARP_LIBRARIES} ${OpenCV_LIBRARIES})
install(TARGETS ${PROJECT_NAME} DESTINATION bin)

yarp_install(FILES DESTINATION ${ICUBCONTRIB_MODULES_INSTALL_DIR})

add_subdirectory(app)

# generate ad-hoc project to perform "make uninstall"
icubcontrib_add_uninstall_target()
