# Copyright: (C) 2017 Department of Robotics Brain and Cognitive Sciences - Istituto Italiano di Tecnologia
# Authors: Vadim Tikhanoff
# Authors: Elisa Maiettini
# CopyPolicy: Released under the terms of the GNU GPL v2.0.

cmake_minimum_required(VERSION 2.6)
set(PROJECTNAME detection-app)

file(GLOB scripts ${CMAKE_CURRENT_SOURCE_DIR}/scripts/*.xml)
file(GLOB config ${CMAKE_CURRENT_SOURCE_DIR}/config/*.ini)

set(python_bin ${CMAKE_CURRENT_SOURCE_DIR}/python/detections_handler.py)


if(OOD_offline)
    list(APPEND python_bin ${CMAKE_CURRENT_SOURCE_DIR}/python/Manager.py
                           ${CMAKE_CURRENT_SOURCE_DIR}/python/iCWT_player_RF.py)
endif() 
if(OOD_Weak_supervision)
    list(APPEND python_bin ${CMAKE_CURRENT_SOURCE_DIR}/python/BoxesVisualizer.py)
endif() 

set(lua_bin    ${CMAKE_CURRENT_SOURCE_DIR}/lua/detection_demo.lua
               ${CMAKE_CURRENT_SOURCE_DIR}/lua/detection_image.lua
               ${CMAKE_CURRENT_SOURCE_DIR}/lua/detection_speech_helper.lua)

find_package(YARP REQUIRED)
find_package(ICUB REQUIRED)
find_package(ICUBcontrib REQUIRED)
list(APPEND CMAKE_MODULE_PATH ${YARP_MODULE_PATH} ${ICUB_MODULE_PATH} ${ICUBCONTRIB_MODULE_PATH})

include(YarpInstallationHelpers)
include(ICUBcontribOptions)
include(ICUBcontribHelpers)
icubcontrib_set_default_prefix()

yarp_install(FILES ${scripts} DESTINATION ${ICUBCONTRIB_APPLICATIONS_INSTALL_DIR})
yarp_install(FILES ${config}  DESTINATION ${ICUBCONTRIB_CONTEXTS_INSTALL_DIR}/${PROJECT_NAME})

# We cannot go for "yarp_install(PROGRAMS ${lua_bin} DESTINATION bin)", since on Windows, only
# at build time (i.e. not during installation), we have to handle the Debug|Release subfolders.
# Requirements: the cmake "-E copy" command does not change file permissions, hence the file needs
# to be stored in the versioning database with *executable* rights.
               
add_custom_target(copy_python_app_in_build ALL)
add_custom_target(copy_lua_in_build ALL)

add_custom_command(TARGET copy_python_app_in_build POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${python_bin} ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}
                   COMMENT "Copying ${python_bin} to ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/")

add_custom_command(TARGET copy_lua_in_build POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${lua_bin} ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}
                   COMMENT "Copying ${lua_bin} to ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/")

install(PROGRAMS ${lua_bin} ${python_bin} DESTINATION bin)
