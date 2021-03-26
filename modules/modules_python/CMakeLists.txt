# Copyright (C) 2018 Fondazione Istituto Italiano di Tecnologia (IIT)
# All Rights Reserved.
# Authors: Elisa Maiettini <elisa.maiettini@iit.it>

if(NOT OOD_Weak_supervision AND NOT OOD_HRI)
    message("Weak_supervision is OFF")
    return()

elseif(OOD_HRI AND NOT OOD_Weak_supervision)
    message("OOD_HRI is ON and Weak_supervision is OFF")

	set(python_bin ${CMAKE_CURRENT_SOURCE_DIR}/Gui/OODRemote.py)

	add_custom_target(copy_python_in_build ALL)
	add_custom_command(TARGET copy_python_in_build POST_BUILD
		               COMMAND ${CMAKE_COMMAND} -E copy ${python_bin} ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}
		               COMMENT "Copying ${python_bin} to ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/")

	install(PROGRAMS ${python_bin} DESTINATION bin)
	return()

else()
	cmake_minimum_required(VERSION 3.1)
	project(detection-python-modules)

	set(WS_import_path "${CMAKE_CURRENT_SOURCE_DIR}/../../modules/modules_python/WeakSupervision")
	set(Tracker_import_path "${CMAKE_CURRENT_SOURCE_DIR}/../../external/re3-tensorflow")
	message(${Tracker_import_path})
	if(NOT EXISTS ${Tracker_import_path})
		message(FATAL_ERROR "re3-tensorflow repository has not properly been placed in the external folder.")
	endif()
	if(NOT EXISTS ${WS_import_path})
		message(FATAL_ERROR "The python modules of weak supervision are not in the expected folder.")
	endif()

	configure_file(AnnotationsPropagator/AnnotationsPropagator.py.in AnnotationsPropagator/AnnotationsPropagator.py @ONLY)
	configure_file(WeakSupervision/StreamUncertaintyBasedMethod.py.in WeakSupervision/StreamUncertaintyBasedMethod.py @ONLY)

	set(python_bin ${CMAKE_CURRENT_SOURCE_DIR}/../../build/modules/modules_python/AnnotationsPropagator/AnnotationsPropagator.py
				   ${CMAKE_CURRENT_SOURCE_DIR}/Exploration/ExplorationModule.py
				   ${CMAKE_CURRENT_SOURCE_DIR}/Gui/OODRemote.py
		           ${CMAKE_CURRENT_SOURCE_DIR}/../../build/modules/modules_python/WeakSupervision/StreamUncertaintyBasedMethod.py)

	add_custom_target(copy_python_in_build ALL)
	add_custom_command(TARGET copy_python_in_build POST_BUILD
		               COMMAND ${CMAKE_COMMAND} -E copy ${python_bin} ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}
		               COMMENT "Copying ${python_bin} to ${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/")

	install(PROGRAMS ${python_bin} DESTINATION bin)
	return()
endif()
