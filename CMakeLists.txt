# Copyright: (C) 2016 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Vadim Tikhanoff
#          Elisa Maiettini
# CopyPolicy: Released under the terms of the GNU GPL v2.0.

cmake_minimum_required(VERSION 3.1)
project(online-detection-demo)

find_package(ICUBcontrib REQUIRED)
find_package(YARP 3.1 REQUIRED COMPONENTS OS sig dev math rosmsg cv)
find_package(OpenCV REQUIRED)
list(APPEND CMAKE_MODULE_PATH ${ICUBCONTRIB_MODULE_PATH})

include(ICUBcontribOptions)
include(ICUBcontribHelpers)

if(NOT CMAKE_CONFIGURATION_TYPES)
  if(NOT CMAKE_BUILD_TYPE)
      message(STATUS "Setting build type to 'Release' as none was specified.")
      set_property(CACHE CMAKE_BUILD_TYPE PROPERTY VALUE "Release")
  endif()
endif()

option(OOD_Weak_supervision "Enables compilation of weak supervision application" ON)
option(OOD_detectionExtract "Enables compilation ofe in bounding box segmentation" OFF)
option(OOD_humanStructure   "Enables compilation of humanStructure" OFF)
option(OOD_augmentation     "Enables compilation of yarp-augmentation" OFF)
option(OOD_dispBlobber      "Enables compilation of yarp-blob" ON)
option(OOD_multiviewer      "Enables compilation of yarp-multi-viewer" ON)
option(OOD_offline          "Enables compilation of offline experiments part" OFF)

icubcontrib_set_default_prefix()

add_subdirectory(modules)
add_subdirectory(app)

# generate ad-hoc project to perform "make uninstall"
icubcontrib_add_uninstall_target()
