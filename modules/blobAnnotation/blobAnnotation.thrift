#blobAnnotation.thrift


struct Bottle{}
(
    yarp.name = "yarp::os::Bottle"
    yarp.includefile="yarp/os/Bottle.h"
)

/**
* blobAnnotation_IDLServer
*
* Interface.
*/

service blobAnnotation_IDLServer
{
    /**
     * Quit the module.
     * @return true/false on success/failure
     */
    bool quit();

    /**
     * Activates the detection blob selection
     * @return true/false on success/failure
     **/
    bool selectDetection();

    /**
     * Stop the detection blob selection
     * the parameter label is the class of the blob
     * @return true/false on success/failure
     **/
    bool doneSelection(1:string label);

    /**
     * Add a new detection 
     * @return true/false on success/failure
     **/
    bool addDetection();

    /**
     * Delete a selected detection
     * @return true/false on success/failure
     **/
    bool deleteSelection();

    /**
     * Finish processing detections
     * @return true/false on success/failure
     **/
    bool finishAnnotation();
}
