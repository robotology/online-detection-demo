# Copyright: (C) 2017 Department of Robotics Brain and Cognitive Sciences - Istituto Italiano di Tecnologia
# Authors: Vadim Tikhanoff
# CopyPolicy: Released under the terms of the GNU GPL v2.0.

cmake_minimum_required(VERSION 2.6)
set(PROJECTNAME detection-lua)

file(GLOB scripts ${CMAKE_CURRENT_SOURCE_DIR}/scripts/*.xml)
set(lua_bin       ${CMAKE_CURRENT_SOURCE_DIR}/../detection_demo.lua
                  ${CMAKE_CURRENT_SOURCE_DIR}/../detection_image.lua)

find_package(YARP REQUIRED)
find_package(ICUB REQUIRED)
find_package(ICUBcontrib REQUIRED)
list(APPEND CMAKE_MODULE_PATH ${YARP_MODULE_PATH} ${ICUB_MODULE_PATH} ${ICUBCONTRIB_MODULE_PATH})
include(YarpInstallationHelpers)
include(ICUBcontribOptions)
include(ICUBcontribHelpers)
icubcontrib_set_default_prefix()

yarp_install(FILES ${scripts} DESTINATION ${ICUBCONTRIB_APPLICATIONS_INSTALL_DIR})

# We cannot go for "yarp_install(PROGRAMS ${lua_bin} DESTINATION bin)", since on Windows, only
# at build time (i.e. not during installation), we have to handle the Debug|Release subfolders.
# Requirements: the cmake "-E copy" command does not change file permissions, hence the file needs
# to be stored in the versioning database with *executable* rights.

add_custom_target(copy_lua_in_build ALL)
add_custom_command(TARGET copy_lua_in_build POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${lua_bin} ${CMAKE_BINARY_DIR}/bin/${CMAKE_CFG_INTDIR}
               COMMENT "Copying ${lua_bin} to ${CMAKE_BINARY_DIR}/bin/${CMAKE_CFG_INTDIR}/")
install(PROGRAMS ${lua_bin} DESTINATION bin)
