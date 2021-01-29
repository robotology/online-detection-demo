# Copyright: (C) 2018 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Vadim Tikhanoff
# CopyPolicy: Released under the terms of the GNU GPL v2.0.

cmake_minimum_required(VERSION 3.5)
project(yarp-augmentation)


yarp_add_idl(IDL_GEN_FILES ${PROJECT_NAME}.thrift)

set(idl ${PROJECT_NAME}.thrift)

include_directories(${OpenCV_INCLUDE_DIRS})

add_executable(${PROJECT_NAME} main.cpp  ${idl} ${IDL_GEN_FILES})
target_link_libraries(${PROJECT_NAME} ${YARP_LIBRARIES} ${OpenCV_LIBRARIES})

install(TARGETS ${PROJECT_NAME} DESTINATION bin)
yarp_install(FILES DESTINATION ${ICUBCONTRIB_MODULES_INSTALL_DIR})

add_subdirectory(app)
