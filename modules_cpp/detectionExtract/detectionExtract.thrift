#detectionExtract.thrift


struct Bottle{}
(
    yarp.name = "yarp::os::Bottle"
    yarp.includefile="yarp/os/Bottle.h"
)

/**
* detectionExtract_IDLServer
*
* Interface.
*/

service detectionExtract_IDLServer
{
    /**
     * Quit the module.
     * @return true/false on success/failure
     */
    bool quit();

    /**
     * Gets all the components (points) that belong to any of the segmented blobs
     * @param x: x coordinate of seed point
     * @param y: y coordinate of seed point
     * @return Bottle containing a list of points belonging to the segmented blob
     **/
    Bottle get_component_around(1:i32 x, 2:i32 y);
}
