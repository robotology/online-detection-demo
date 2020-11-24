# Authors: Elisa Maiettini

cmake_minimum_required(VERSION 3.1)
project(WS-demo)

set(python_bin ${CMAKE_CURRENT_SOURCE_DIR}/src/AnnotationsPropagator.py
			   ${CMAKE_CURRENT_SOURCE_DIR}/src/ExplorationModule.py
               ${CMAKE_CURRENT_SOURCE_DIR}/src/StreamUncertaintyBasedMethod.py)

find_package(ICUBcontrib REQUIRED)
find_package(YARP 3.1 REQUIRED)
list(APPEND CMAKE_MODULE_PATH ${ICUBCONTRIB_MODULE_PATH})

include(ICUBcontribOptions)
include(ICUBcontribHelpers)

if(NOT CMAKE_CONFIGURATION_TYPES)
  if(NOT CMAKE_BUILD_TYPE)
      message(STATUS "Setting build type to 'Release' as none was specified.")
      set_property(CACHE CMAKE_BUILD_TYPE PROPERTY VALUE "Release")
  endif()
endif()

icubcontrib_set_default_prefix()

add_subdirectory(app)

add_custom_target(copy_python_in_build ALL)
add_custom_command(TARGET copy_python_in_build POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${python_bin} ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}
                   COMMENT "Copying ${python_bin} to ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/")

install(PROGRAMS ${python_bin} DESTINATION bin)

# generate ad-hoc project to perform "make uninstall"
icubcontrib_add_uninstall_target()
