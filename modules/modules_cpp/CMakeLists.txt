# Copyright (C) 2018 Fondazione Istituto Italiano di Tecnologia (IIT)
# All Rights Reserved.
# Authors: Vadim Tikhanoff <vadim.tikhanoff@iit.it>

if(OOD_Weak_supervision OR OOD_HRI)
    add_subdirectory(blobAnnotation)
endif()

if(OOD_humanStructure)
    add_subdirectory(humanStructure)
endif()

if(OOD_detectionExtract)
    add_subdirectory(detectionExtract)
endif()

if(OOD_dispBlobber)
    add_subdirectory(yarp-blob)
endif()

if(OOD_augmentation)
    add_subdirectory(yarp-augmentation)
endif()

if(OOD_multiviewer)
    add_subdirectory(yarp-multi-viewer)
endif()
