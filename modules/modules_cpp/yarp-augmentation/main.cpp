/*
 * Copyright (C) 2016 iCub Facility - Istituto Italiano di Tecnologia
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
#include <yarp/os/ResourceFinder.h>
#include <yarp/os/RFModule.h>
#include <yarp/os/Network.h>
#include <yarp/os/Log.h>
#include <yarp/os/Time.h>
#include <yarp/os/LogStream.h>
#include <yarp/os/Semaphore.h>
#include <yarp/sig/Image.h>
#include <yarp/os/RpcClient.h>

#include <opencv2/core/core.hpp>
#include <opencv2/opencv.hpp>
#include <opencv2/core/types_c.h>
#include <opencv2/videoio/videoio_c.h>


#include <dirent.h>
#include <cstring>
#include <iostream>
#include <vector>
#include <memory>

#include "yarpAugmentation_IDL.h"

/********************************************************/
class Processing : public yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >
{
    std::string moduleName;

    yarp::os::RpcServer handlerPort;

    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >       inPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >       outPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >       imagePort;
    yarp::os::BufferedPort<yarp::os::Bottle>  targetPort;

    yarp::os::RpcServer rpc;
    std::string path;

    int incrementFile;
    int frameNum;
    int state;

    std::vector<std::string> files;

    bool inBackground;
    int whichBackground;

public:
    int framesPerState;
    bool useLighting;
    bool useBackgrounds;
    bool allowedAugmentation;

    /********************************************************/

    Processing( const std::string &moduleName, const std::string &path )
    {
        this->moduleName = moduleName;
        this->path = path;
        incrementFile = 0;
    }

    /********************************************************/
    ~Processing()
    {

    };

     /********************************************************/
    std::vector<std::string> GetDirectoryFiles(const std::string& dir)
    {
        std::vector<std::string> files;
        std::shared_ptr<DIR> directory_ptr(opendir(dir.c_str()), [](DIR* dir){ dir && closedir(dir); });
        struct dirent *dirent_ptr;
        if (!directory_ptr) {
            std::cout << "Error opening : " << std::strerror(errno) << dir << std::endl;
            return files;
        }

        while ((dirent_ptr = readdir(directory_ptr.get())) != nullptr)
        {
            files.push_back(std::string(dirent_ptr->d_name));
        }
        return files;
    }

    /********************************************************/
    bool open(){

        this->useCallback();

        BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >::open( "/" + moduleName + "/depth:i" );
        inPort.open("/"+ moduleName + "/image:i");
        outPort.open("/"+ moduleName + "/depth:o");
        imagePort.open("/" + moduleName + "/image:o");
        targetPort.open("/"+ moduleName + "/target:o");
        frameNum = 1;

        rpc.open("/"+moduleName+"/rpcdata");

        yDebug() << "the path is: " << path.c_str();

        files = GetDirectoryFiles(path);

        for ( auto i = files.begin(); i != files.end(); i++ )
        {
            std::cout << *i << std::endl;
        }

        state = 0;
        whichBackground = 0;
        inBackground = false;

        allowedAugmentation = false;

        yDebug() << "Completed configuration ";
        yDebug() << "Starting with useLighting" << useLighting << "&& useBackgrounds" << useBackgrounds << "framesPerState" << framesPerState;

        if (useBackgrounds && !useLighting)
            framesPerState = framesPerState/3;

        return true;
    }

    /********************************************************/
    void close()
    {
        inPort.close();
        outPort.close();
        targetPort.close();
        imagePort.close();
        BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >::close();
    }

    /********************************************************/
    void interrupt()
    {
        BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >::interrupt();
    }

    /********************************************************/
    void onRead( yarp::sig::ImageOf<yarp::sig::PixelMono> &dispImage )
    {

        yarp::sig::ImageOf<yarp::sig::PixelRgb> &augmentedImage  = imagePort.prepare();
        yarp::sig::ImageOf<yarp::sig::PixelRgb> &outImage  = outPort.prepare();
        yarp::os::Bottle &outTargets = targetPort.prepare();

        yarp::sig::ImageOf<yarp::sig::PixelRgb> *inImage = inPort.read();

        outImage.resize(dispImage.width(), dispImage.height());
        augmentedImage.resize(dispImage.width(), dispImage.height());

        outImage.zero();
        augmentedImage.zero();

        cv::Mat inColour_cv = cv::cvarrToMat((IplImage *)inImage->getIplImage());
        
        cv::Mat imgout = inColour_cv.clone();

        cv::Mat disp = cv::cvarrToMat((IplImage *)dispImage.getIplImage());

        double sigmaX1 = 1.5;
        double sigmaY1 = 1.5;
        int gaussSize = 5;
        int backgroundThresh = 30;

        cv::GaussianBlur(disp, disp, cv::Size(gaussSize,gaussSize), sigmaX1, sigmaY1);

        cv::threshold(disp, disp, backgroundThresh, -1, cv::THRESH_TOZERO);

        int dilate_niter = 2;
        int erode_niter = 1;
        double sigmaX2 = 1;
        double sigmaY2 = 1;

        //cv::dilate(disp, disp, cv::Mat(), cv::Point(-1,-1), dilate_niter, cv::BORDER_CONSTANT, cv::morphologyDefaultBorderValue());

       // cv::GaussianBlur(disp, disp, cv::Size(gaussSize,gaussSize), sigmaX2, sigmaY2, cv::BORDER_DEFAULT);

        //cv::erode(disp, disp, cv::Mat(), cv::Point(-1,-1), erode_niter, cv::BORDER_CONSTANT, cv::morphologyDefaultBorderValue());

        /* Find the max value and its position and apply a threshold to remove the backgound */
        double minVal, maxVal;
        cv::Point minLoc, maxLoc;
        cv::minMaxLoc( disp, &minVal, &maxVal, &minLoc, &maxLoc );

        int imageThreshRatioLow = 10;

        int maxValThreshed = (maxVal - imageThreshRatioLow );
        if (maxValThreshed < 80)
            maxValThreshed = 80;

        //cv::Mat cleanedImg;
        //cv::threshold(disp, cleanedImg, maxValThreshed, 255, cv::THRESH_BINARY);

        /* Find the contour of the closest objects */
        std::vector<std::vector<cv::Point> > cnt;
        std::vector<cv::Vec4i> hrch;

        findContours( disp, cnt, hrch, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_TC89_L1 );

        /* get moments and mass center */
        std::vector<cv::Moments> mu(cnt.size() );
        for( size_t i = 0; i < cnt.size(); i++ )
            mu[i] = moments( cnt[i], false );

        std::vector<cv::Point2f> mc( cnt.size() );

        for( size_t i = 0; i < cnt.size(); i++ )
            mc[i] = cv::Point2f( mu[i].m10/mu[i].m00 , mu[i].m01/mu[i].m00 );

        std::vector<std::vector<cv::Point> > contours_poly( cnt.size() );
        std::vector<cv::Rect> boundRect( cnt.size() );

        /* Use pointPolygonTest using the previous maxvalue location to compare with all contours found */
        int highestVal = -1;

        yDebug() << "contour" << cnt.size();

        for( size_t i = 0; i< cnt.size(); i++ )
        {
            //if (pointPolygonTest( cnt[i], cv::Point2f(maxLoc.x, maxLoc.y), 1 ) > 0 && contourArea(cnt[i]) > 400 && contourArea(cnt[i]) < 10000)
                if (pointPolygonTest( cnt[i], cv::Point2f(maxLoc.x, maxLoc.y), 1 ) > 0)
                highestVal = i;
        }

        cvtColor(disp, disp, cv::COLOR_GRAY2RGB);

        cv::Mat bw(inColour_cv.size(), CV_8UC3, cv::Scalar(0,0,0));
        cv::Mat imageOutput(inColour_cv.size(), CV_8UC3, cv::Scalar(255,255,255));
        cv::Mat mask(inColour_cv.size(), CV_8UC3, cv::Scalar(0,0,0));

        outTargets.clear();

        if (highestVal >= 0)
        {
            cv::drawContours( disp, cnt, highestVal, cvScalar(37, 206, 144), 2, 8, hrch, 0, cv::Point() );
            circle(disp, mc[highestVal], 3, cv::Scalar(0, 255, 0), -1, 8, 0);

            approxPolyDP( cv::Mat(cnt[highestVal]), contours_poly[highestVal], 3, true );
            boundRect[highestVal] = boundingRect( cv::Mat(contours_poly[highestVal]) );

            yarp::os::Bottle &t=outTargets.addList();
            t.addDouble(boundRect[highestVal].tl().x);
            t.addDouble(boundRect[highestVal].tl().y);
            t.addDouble(boundRect[highestVal].br().x);
            t.addDouble(boundRect[highestVal].br().y);

            if (inBackground && useBackgrounds)
                cv::drawContours( bw, cnt, highestVal, cvScalar(255, 255, 255), 2, 8, hrch, 0, cv::Point() );

            floodFill(bw, mc[highestVal], cv::Scalar(255,255,255));
            inColour_cv.copyTo(imageOutput, bw);
        }

        if (outTargets.size() >0 )
        {
            targetPort.write();

            if (state > 2)
            {
                yError() << "Setting background TRUE *****************************************************" ;
                inBackground = true;
                state = 0;
            }

            if (frameNum > 1000)
                frameNum = 1;

            yDebug() << "Frame Number is: " << frameNum << "and state is" << state;
            if (frameNum % framesPerState == 0 )
            {
                state++;
                yError() << "done *****************************************************" ;
            }

            if (inBackground && state > 2)
                whichBackground++;

            if (whichBackground == files.size()-2)
            {
                yError() << "Setting background FALSE *****************************************************" ;
                inBackground = false;
                whichBackground = 0;
                state = 0;
            }

            if(useBackgrounds && inBackground)
            {
                cv::Mat image;
                std::string backgroundFile = path + "/bkgrd-" + std::to_string(whichBackground+1) + ".jpg";
                yDebug() << "File " << backgroundFile.c_str();

                image = cv::imread(backgroundFile, cv::IMREAD_COLOR);

                cv::cvtColor( image, image, cv::COLOR_BGR2RGB );

                if(! image.data )                              // Check for invalid input
                {
                    yError() << "Cannot load file " << backgroundFile;
                    inBackground = false;
                }
                bitwise_not ( bw, bw );
                image.copyTo(imageOutput, bw);
            }

            if (state == 1)
            {
                if (useLighting)
                    imageOutput.convertTo(imageOutput, CV_8U, 0.5);
            }
            if (state == 2)
            {
                if (useLighting)
                    imageOutput.convertTo(imageOutput, CV_8U, 1.5);
            }

            frameNum++;
            
            if (allowedAugmentation)
            {
                imgout = imageOutput.clone();

            }
            //else
                //imgout = inColour_cv.clone();
            
        }
        
        IplImage orig = imgout;
        augmentedImage.resize(inImage->width(), inImage->height());
        cvCopy( &orig, (IplImage *) augmentedImage.getIplImage());
        imagePort.write();

        IplImage out = disp;
        outImage.resize(out.width, out.height);
        cvCopy( &out, (IplImage *) outImage.getIplImage());
        outPort.write();
    }
};

/********************************************************/
class Module : public yarp::os::RFModule, public yarpAugmentation_IDL
{
    yarp::os::ResourceFinder    *rf;
    yarp::os::RpcServer         rpcPort;

    Processing                  *processing;
    friend class                processing;

    bool                        closing;

    /********************************************************/
    bool attach(yarp::os::RpcServer &source)
    {
        return this->yarp().attachAsServer(source);
    }

public:

    /********************************************************/
    bool configure(yarp::os::ResourceFinder &rf)
    {
        this->rf=&rf;
        std::string moduleName = rf.check("name", yarp::os::Value("yarp-augmentation"), "module name (string)").asString();
        std::string path = rf.check("path", yarp::os::Value(""), "path name (string)").asString();
        std::string useLighting = rf.check("useLighting", yarp::os::Value("on"), "use lighting (string)").asString();
        std::string useBackgrounds = rf.check("useBackgrounds", yarp::os::Value("on"), "use lighting (string)").asString();
        int framesPerState = rf.check("setFrames", yarp::os::Value(20), "Frames to use before switching (int)").asInt();

        setName(moduleName.c_str());

        rpcPort.open(("/"+getName("/rpc")).c_str());

        closing = false;

        processing = new Processing( moduleName, path );

        yInfo() << "useLighting" << useLighting << "useBackgrounds" << useBackgrounds;

        if (useLighting=="on")
            processing->useLighting = true;
        else if (useLighting=="off")
            processing->useLighting = false;
        else
        {
            yInfo() << "cannot understand value for useLighting";
            return false;
        }

        if (useBackgrounds=="on")
            processing->useBackgrounds = true;
        else if (useBackgrounds=="off")
            processing->useBackgrounds = false;
        else
        {
            yInfo() << "cannot understand value for useBackgrounds";
            return false;
        }

        processing->framesPerState = framesPerState;

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

    /********************************************************/
    bool setNumFrames(const int32_t numFrames)
    {
        bool val = true;

        if (numFrames > 0)
            processing->framesPerState = numFrames;
        else
            val = false;

        return true;
    }

    /********************************************************/
    int getNumFrames()
    {
        return processing->framesPerState;
    }

    /********************************************************/
    bool setLighting(const std::string value)
    {
        bool returnVal = false;

        if (value=="on")
        {
            processing->useLighting = true;
            returnVal = true;
        }
        else if (value=="off")
        {
            processing->useLighting = false;
            returnVal = true;
        }
        else
            yInfo() << "error setting value lighting";

        return returnVal;
    }

    /********************************************************/
    bool setBackgrounds(const std::string value)
    {
        bool returnVal = false;

        if (value=="on")
        {
            processing->useBackgrounds = true;
            returnVal = true;
        }
        else if (value=="off")
        {
            processing->useBackgrounds = false;
            returnVal = true;
        }
        else
            yInfo() << "error setting value lighting";

        return returnVal;
    }

    /********************************************************/
    bool startAugmentation()
    {
        processing->allowedAugmentation = true;
        return true;
    }

    /********************************************************/
    bool stopAugmentation()
    {
        processing->allowedAugmentation = false;
        return true;
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
    rf.setDefaultConfigFile( "config.ini" );
    rf.setDefaultContext("yarp-augmentation");
    rf.configure(argc,argv);

    return module.runModule(rf);
}
