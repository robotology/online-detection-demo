# Authors: Elisa Maiettini

cmake_minimum_required(VERSION 2.6)
set(PROJECTNAME WS-demo)

file(GLOB scripts ${CMAKE_CURRENT_SOURCE_DIR}/scripts/*.xml)
file(GLOB config ${CMAKE_CURRENT_SOURCE_DIR}/config/*.ini)
                  
set(python_bin ${CMAKE_CURRENT_SOURCE_DIR}/python/iCWT_player.py
			   ${CMAKE_CURRENT_SOURCE_DIR}/python/BoxesVisualizer.py
			   ${CMAKE_CURRENT_SOURCE_DIR}/python/Manager.py
               ${CMAKE_CURRENT_SOURCE_DIR}/python/iCWT_player_RF.py)

find_package(YARP REQUIRED)
#find_package(ICUB REQUIRED)
find_package(ICUBcontrib REQUIRED)
#list(APPEND CMAKE_MODULE_PATH ${YARP_MODULE_PATH} ${ICUB_MODULE_PATH} ${ICUBCONTRIB_MODULE_PATH})
list(APPEND CMAKE_MODULE_PATH ${YARP_MODULE_PATH} ${ICUBCONTRIB_MODULE_PATH})
include(YarpInstallationHelpers)
include(ICUBcontribOptions)
include(ICUBcontribHelpers)
icubcontrib_set_default_prefix()

yarp_install(FILES ${scripts} DESTINATION ${ICUBCONTRIB_APPLICATIONS_INSTALL_DIR})
yarp_install(FILES ${config}    DESTINATION ${ICUBCONTRIB_CONTEXTS_INSTALL_DIR}/${PROJECT_NAME})
               
add_custom_target(copy_python_in_build ALL)
add_custom_command(TARGET copy_python_in_build POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${python_bin} ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}
                   COMMENT "Copying ${python_bin} to ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/")

install(PROGRAMS ${python_bin} DESTINATION bin)
