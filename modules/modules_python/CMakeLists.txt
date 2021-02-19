# Copyright (C) 2018 Fondazione Istituto Italiano di Tecnologia (IIT)
# All Rights Reserved.
# Authors: Elisa Maiettini <elisa.maiettini@iit.it>

if(NOT OOD_Weak_supervision)
    message("Weak_supervision is OFF")
    return()
endif()

cmake_minimum_required(VERSION 3.1)
project(detection-python-modules)


set(python_bin ${CMAKE_CURRENT_SOURCE_DIR}/AnnotationsPropagator/AnnotationsPropagator.py
			   ${CMAKE_CURRENT_SOURCE_DIR}/Exploration/ExplorationModule.py
               ${CMAKE_CURRENT_SOURCE_DIR}/WeakSupervision/StreamUncertaintyBasedMethod.py)

add_custom_target(copy_python_in_build ALL)
add_custom_command(TARGET copy_python_in_build POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${python_bin} ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}
                   COMMENT "Copying ${python_bin} to ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/")

install(PROGRAMS ${python_bin} DESTINATION bin)
