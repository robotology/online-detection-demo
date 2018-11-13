# Copyright: (C) 2016 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Vadim Tikhanoff
# CopyPolicy: Released under the terms of the GNU GPL v2.0.
#
# yarp-augmentation.thrift

/**
* yarpAugmentation_IDL
*
* IDL Interface to \ref yarp augmentation
*/
service yarpAugmentation_IDL
{
    /**
     * Quit the module.
     * @return true/false on success/failure
     */
    bool quit();
    
    /**
     * Set number of frames for each state.
     * @return true/false on success/failure
     */
    bool setNumFrames(1:i32 numFrames );
    
    /**
     * Get number of frames for each state.
     * @return number of frames
     */
    i32 getNumFrames();
    
    /**
     * Set lighting on or not
     * @return true/false on success/failure
     */
    bool setLighting(1:string value);
    
    /**
     * Set backgrounds on or not
     * @return true/false on success/failure
     */
    bool setBackgrounds(1:string value);
}
