/*
 * Copyright (C) 2018 iCub Facility - Istituto Italiano di Tecnologia
 * Author: Vadim Tikhanoff
 * email:  vadim.tikhanoff@iit.it
 * Permission is granted to copy, distribute, and/or modify this program
 * under the terms of the GNU General Public License, version 2 or any
 * later version published by the Free Software Foundation.
 *
 * A copy of the license can be found at
 * http://www.robotcub.org/icub/license/gpl.txt
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details
 */

#include <yarp/os/BufferedPort.h>
#include <yarp/os/RpcClient.h>
#include <yarp/os/ResourceFinder.h>
#include <yarp/os/RFModule.h>
#include <yarp/os/Network.h>
#include <yarp/os/Log.h>
#include <yarp/os/LogStream.h>
#include <yarp/os/Semaphore.h>
#include <yarp/sig/Image.h>
#include <yarp/sig/Vector.h>
#include <yarp/math/Math.h>

#include <opencv2/core/core.hpp>
#include <opencv2/opencv.hpp>

#include <cstring>
#include <vector>
#include <iostream>
#include <utility>

using namespace yarp::math;

/********************************************************/
class Processing : public yarp::os::BufferedPort<yarp::os::Bottle>
{
    std::string moduleName;

    yarp::os::RpcServer handlerPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >    imageInPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >   imageOutPort;
    
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >   depthImageInPort;
	yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >   depthImageOutPort;

public:
    /********************************************************/

    Processing( const std::string &moduleName )
    {
        this->moduleName = moduleName;
    }

    /********************************************************/
    ~Processing()
    {
    };

    /********************************************************/
    bool open(){

        this->useCallback();

        BufferedPort<yarp::os::Bottle >::open( "/" + moduleName + "/blobs:i" );
        imageInPort.open("/" + moduleName + "/image:i");
        imageOutPort.open("/" + moduleName + "/image:o");
        depthImageInPort.open("/" + moduleName + "/depthImage:i");
		depthImageOutPort.open("/" + moduleName + "/depthImage:o");

        yarp::os::Network::connect("/dispBlobber/roi/left:o", BufferedPort<yarp::os::Bottle >::getName().c_str(), "tcp");
        yarp::os::Network::connect("/dispBlobber/opt:o", depthImageInPort.getName().c_str(), "fast_tcp");
        yarp::os::Network::connect("/depthCamera/rgbImage:o", imageInPort.getName().c_str(), "fast_tcp");
        yarp::os::Network::connect(depthImageOutPort.getName().c_str(), "/viewer/testDepth", "fast_tcp");
        yarp::os::Network::connect(imageOutPort.getName().c_str(), "/viewer/testRgb", "fast_tcp");
        
        return true;
    }

    /********************************************************/
    void close()
    {
        imageOutPort.close();
        imageInPort.close();
        BufferedPort<yarp::os::Bottle >::close();
        depthImageInPort.close();
		depthImageOutPort.close();
    }

    /********************************************************/
    void interrupt()
    {
        BufferedPort<yarp::os::Bottle >::interrupt();
        imageOutPort.interrupt();
        imageInPort.interrupt();
        depthImageInPort.interrupt();
		depthImageOutPort.interrupt();
    }

    /********************************************************/
    void onRead( yarp::os::Bottle &data )
    {
        yarp::sig::ImageOf<yarp::sig::PixelRgb> &outImage  = imageOutPort.prepare();
        yarp::sig::ImageOf<yarp::sig::PixelMono> &outDepthImage  = depthImageOutPort.prepare();

        yarp::sig::ImageOf<yarp::sig::PixelRgb> *inImage = imageInPort.read();
        yarp::sig::ImageOf<yarp::sig::PixelMono> *depth= depthImageInPort.read();
           
        outImage = *inImage;
        outDepthImage = *depth;
        
        cv::Mat imgDepthMat=cv::cvarrToMat(outImage.getIplImage());
        cv::Mat imgRgbMat=cv::cvarrToMat(outDepthImage.getIplImage());
        
        cv::Point tl;
        cv::Point br;
        
        tl.x = data.get(0).asList()->get(0).asInt();
        tl.y = data.get(0).asList()->get(1).asInt();
        br.x = data.get(0).asList()->get(2).asInt();
        br.x = data.get(0).asList()->get(3).asInt();
        
        cv::Scalar colour(0,76, 153);
        
        cv::rectangle(imgRgbMat, cv::Point(tl.x*(320/424), tl.y) , cv::Point(br.x*(320/424), br.y), colour,2);
        
        cv::rectangle(imgDepthMat,tl,br,255,2);
        
                
        depthImageOutPort.write();
        imageOutPort.write();
    }
};

/********************************************************/
class Module : public yarp::os::RFModule
{
    yarp::os::ResourceFinder    *rf;
    yarp::os::RpcServer         rpcPort;

    Processing                  *processing;
    friend class                processing;

    bool                        closing;

public:

    /********************************************************/
    bool configure(yarp::os::ResourceFinder &rf)
    {
        this->rf=&rf;
        std::string moduleName = rf.check("name", yarp::os::Value("test-dispBlobber"), "module name (string)").asString();
        setName(moduleName.c_str());

        rpcPort.open(("/"+getName("/rpc")).c_str());

        closing = false;

        processing = new Processing( moduleName );
        /* now start the thread to do the work */
        processing->open();

        attach(rpcPort);

        return true;
    }

    /**********************************************************/
    bool close()
    {
        processing->interrupt();
        processing->close();
        delete processing;
        return true;
    }

    /**********************************************************/
    bool quit(){
        closing = true;
        return true;
    }

    /********************************************************/
    double getPeriod()
    {
        return 0.1;
    }

    /********************************************************/
    bool updateModule()
    {
        return !closing;
    }
};

/********************************************************/
int main(int argc, char *argv[])
{
    yarp::os::Network::init();

    yarp::os::Network yarp;
    if (!yarp.checkNetwork())
    {
        yError("YARP server not available!");
        return 1;
    }

    Module module;
    yarp::os::ResourceFinder rf;

    rf.setVerbose();
    rf.configure(argc,argv);

    return module.runModule(rf);
}
