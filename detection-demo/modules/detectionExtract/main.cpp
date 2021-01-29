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
#include <yarp/sig/ImageFile.h>
#include <yarp/cv/Cv.h>

#include <opencv2/core/core.hpp>
#include <opencv2/opencv.hpp>

#include <cstring>
#include <vector>
#include <iostream>
#include <utility>

#include <detectionExtract_IDLServer.h>

using namespace yarp::math;
using namespace yarp::cv;

typedef cv::Point3_<uint8_t> Pixel;

/********************************************************/
class Processing : public yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>
{
    std::string moduleName;
    yarp::os::RpcClient camPort;
    yarp::os::RpcServer handlerPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >  depthImageOutPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >   displayImageOutPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >   colourImageInPort;
    yarp::os::BufferedPort<yarp::os::Bottle >    bbInPort;
    yarp::os::BufferedPort<yarp::os::Bottle >    distOutPort;

    bool    camera_configured;
    double  fov_h;
    double  fov_v;
    yarp::sig::ImageOf<yarp::sig::PixelFloat> depth;

    double minVal = 0.5;
    double maxVal = 2;
    yarp::os::Bottle allPoints;
    yarp::os::Mutex semComp;
    cv::Mat imgMat;
    cv::Mat img_out;
    
    
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

        BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>::open( "/" + moduleName + "/float:i" );
        depthImageOutPort.open("/" + moduleName + "/depth:o");
        camPort.open("/" + moduleName + "/cam:rpc");
        bbInPort.open("/" + moduleName + "/blobs:i");
        distOutPort.open("/" + moduleName + "/distance:o");
        displayImageOutPort.open("/" + moduleName + "/image:o");
        colourImageInPort.open("/" + moduleName + "/image:i");

        yarp::os::Network::connect(camPort.getName().c_str(), "/depthCamera/rpc:i", "tcp");

        yarp::os::Network::connect("/yarpOpenPose/float:o", BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>::getName().c_str(), "fast_tcp");
        yarp::os::Network::connect("/detHandler:dets:o", bbInPort.getName().c_str(), "tcp");

        yarp::os::Network::connect(depthImageOutPort.getName().c_str(), "/outviewer", "fast_tcp");
        yarp::os::Network::connect(displayImageOutPort.getName().c_str(), "/image", "fast_tcp");
        yarp::os::Network::connect("/yarpOpenPose/propag:o", colourImageInPort.getName().c_str(), "fast_tcp");

        camera_configured=false;

        fov_h = 55.0;
        fov_v = 42.0;

        return true;
    }

    /********************************************************/
    void close()
    {
        BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>::close();
        camPort.close();
        depthImageOutPort.close();
        displayImageOutPort.close();
        bbInPort.close();
        distOutPort.close();
        colourImageInPort.close();
    }

    /********************************************************/
    void interrupt()
    {
        BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>::interrupt();
        camPort.interrupt();
        depthImageOutPort.interrupt();
        displayImageOutPort.interrupt();
        bbInPort.interrupt();
        distOutPort.interrupt();
    }

    /****************************************************************/
    bool getCameraOptions()
    {
        if (camPort.getOutputCount()>0)
        {
            yarp::os::Bottle cmd,rep;
            cmd.addVocab(yarp::os::Vocab::encode("visr"));
            cmd.addVocab(yarp::os::Vocab::encode("get"));
            cmd.addVocab(yarp::os::Vocab::encode("fov"));
            if (camPort.write(cmd,rep))
            {
                if (rep.size()>=5)
                {
                    fov_h=rep.get(3).asDouble();
                    fov_v=rep.get(4).asDouble();
                    yInfo()<<"camera fov_h (from sensor) ="<<fov_h;
                    yInfo()<<"camera fov_v (from sensor) ="<<fov_v;
                    return true;
                }
            }
        }
        return true;
    }

    /****************************************************************/
    bool getPoint3D(const int u, const int v, yarp::sig::Vector &p) const
    {
        if ((u>=0) && (u<depth.width()) && (v>=0) && (v<depth.height()))
        {
            double f=depth.width()/(2.0*tan(fov_h*(M_PI/180.0)/2.0));
            double d=depth(u,v);
            if ((d>0.0) && (f>0.0))
            {

                double x=u-0.5*(depth.width()-1);
                double y=v-0.5*(depth.height()-1);

                p=d*ones(3);
                p[0]*=x/f;
                p[1]*=y/f;

                return true;
            }
        }
        return false;
    }
    /********************************************************/
    void removeHigherThreshold(Pixel &pixel, const int value)
    {
        //yDebug()<< "foreach" << pixel.x << value;
        if (pixel.x > value)
        {
            yError() << "setting to 0" << pixel.x << value;;
            pixel.x = 0;
        }
    }
    
    /**********************************************************/
    yarp::os::Bottle get_component_around(const int32_t x, const int32_t y){
        
        yarp::os::Bottle& tosend = getComponents(img_out, x, y);
        
        return tosend;
    }
    
    /**********************************************************/
    yarp::os::Bottle& getComponents(cv::Mat &img, int x, int y)
    {
        allPoints.clear();
        semComp.lock();
        
        cv::Mat nonZeroCoordinates;
        
        cv::findNonZero(img, nonZeroCoordinates);
        
        for (size_t i = 0; i < nonZeroCoordinates.total(); i++ ) {
            yarp::os::Bottle &subjList = allPoints.addList();
            subjList.addInt(nonZeroCoordinates.at<cv::Point>(i).x);
            subjList.addInt(nonZeroCoordinates.at<cv::Point>(i).y);
        }
        semComp.unlock();
        
        return allPoints;
    }

    /********************************************************/
    void onRead( yarp::sig::ImageOf<yarp::sig::PixelFloat> &float_yarp)
    {
        yarp::os::Bottle &distBottle = distOutPort.prepare();
        distBottle.clear();
        yarp::sig::ImageOf<yarp::sig::PixelMono> &outDepthImage  = depthImageOutPort.prepare();
        yarp::sig::ImageOf<yarp::sig::PixelRgb> &outImage  = displayImageOutPort.prepare();

        yarp::sig::ImageOf<yarp::sig::PixelRgb> *inImage = colourImageInPort.read();

        //imgMat = cv::cvarrToMat((IplImage *)inImage->getIplImage());
        imgMat = toCvMat(*inImage);
    
        depth = float_yarp;

        yarp::os::Bottle *blobs=bbInPort.read(true);

        cv::Mat img_cv(float_yarp.height(), float_yarp.width(), CV_8UC1, cv::Scalar(255));
        cv::Mat img_blobs(float_yarp.height(), float_yarp.width(), CV_8UC1, cv::Scalar(0));

        //cv::Mat float_cv = cv::cvarrToMat((IplImage *)float_yarp.getIplImage());
        cv::Mat float_cv = toCvMat(float_yarp);

        cv::Mat mono_cv = cv::Mat::ones(float_yarp.height(), float_yarp.width(), CV_8UC1);

        float_cv -= minVal;
        float_cv.convertTo(mono_cv, CV_8U, 255.0/(maxVal-minVal) );

        cv::Mat depth_cv(float_yarp.height(), float_yarp.width(), CV_8UC1, cv::Scalar(255));

        depth_cv = depth_cv - mono_cv;

        cv::Mat mask;
        inRange(depth_cv, cv::Scalar(255), cv::Scalar(255), mask);
        cv::Mat black_image(depth_cv.size(), CV_8U, cv::Scalar(0));
        black_image.copyTo(depth_cv, mask);

        cv::Mat rgb_cv;
        cvtColor(mono_cv,rgb_cv,CV_GRAY2RGB);

        semComp.lock();
        
        img_out = cv::Mat::zeros( imgMat.size(), CV_8UC1 );

        cv::Mat input_roi;
        cv::Mat input_roi_rgb;
        cv::Mat threshImg;

        cv::Mat segmented(inImage->height(), inImage->width(), CV_8UC3, cv::Scalar(0,0,0));

        //yDebug()<<"list size" << blobs->size();
        //yDebug()<<"blob size" << blobs->get(0).asList()->size();

        int index = 0;
        if (blobs->size() > 1)
            index = 1;

        cv::Point tl,br;

        if (blobs->get(index).asList()->size() > 1)
        {
            yarp::os::Bottle *item=blobs->get(index).asList();

            tl.x=(int)item->get(0).asDouble();
            tl.y=(int)item->get(1).asDouble();
            br.x=(int)item->get(2).asDouble();
            br.y=(int)item->get(3).asDouble();

            rectangle( imgMat, cv::Point(tl.x, tl.y), cv::Point(br.x, br.y), cv::Scalar(0,204,0), 2, 8, 0 );

            cv::Point cog;
            cog.x = tl.x + (br.x - tl.x)/2;
            cog.y = tl.y + (br.y - tl.y)/2;

            double valueCog = depth_cv.at<uchar>(cv::Point(cog.x,cog.y));

            cv::Rect roi = cv::Rect(tl.x, tl.y, br.x - tl.x, br.y - tl.y);
            input_roi= depth_cv(roi);
            input_roi_rgb= imgMat(roi);

            double minLocVal, maxLocVal;
            cv::Point minLoc, maxLoc;
            cv::minMaxLoc( input_roi, &minLocVal, &maxLocVal, &minLoc, &maxLoc );

            yDebug()<<"**************************************** valueCog maxLocVal;" << valueCog << maxLocVal;

            double maxValThreshed = (valueCog - 10);
            cv::threshold(input_roi, threshImg, maxValThreshed, 255, cv::THRESH_BINARY);

            threshImg.copyTo(img_blobs(cv::Rect(tl.x, tl.y, br.x - tl.x, br.y - tl.y)));
        }

        if (blobs->size()>0)
        {
            std::vector<std::vector<cv::Point> > cnt;
            std::vector<cv::Vec4i> hrch;

            findContours( img_blobs, cnt, hrch, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_NONE );

            for( size_t i = 0; i< cnt.size(); i++ )
            {
                yInfo() << contourArea(cnt[i]);
                if (contourArea(cnt[i]) > 5)
                {
                    int border = 3;
                    cv::Rect rect;
                    rect = cv::Rect( border, border, input_roi_rgb.cols - (border*2), input_roi_rgb.rows-(border*2));

                    cv::Mat bgModel,fgModel; // the models (internally used)

                    // GrabCut segmentation
                    cv::Mat result;
                    cv::grabCut(input_roi_rgb, result, rect, bgModel, fgModel, 1, cv::GC_INIT_WITH_RECT);

                    // Get the pixels marked as likely foreground
                    cv::compare(result,cv::GC_PR_FGD,result,cv::CMP_EQ);

                    cv::Mat foreground(input_roi_rgb.size(),CV_8UC3,cv::Scalar(0,0,0));
                    input_roi_rgb.copyTo(foreground,result); // bg pixels not copied
                    foreground.copyTo(segmented(cv::Rect(tl.x, tl.y, foreground.cols, foreground.rows)));

                    cvtColor(segmented,img_out,CV_RGB2GRAY);
                    cv::threshold( img_out, img_out, 1, 255, cv::THRESH_BINARY );

                }
            }
        }
        
        semComp.unlock();

        outDepthImage.resize(img_out.size().width, img_out.size().height);
        outDepthImage = fromCvMat<yarp::sig::PixelMono>(img_out);
        depthImageOutPort.write();

        outImage.resize(imgMat.size().width, imgMat.size().height);
        outImage = fromCvMat<yarp::sig::PixelRgb>(imgMat);
        displayImageOutPort.write();

        distOutPort.write();

    }
};

/********************************************************/
class Module : public yarp::os::RFModule, public detectionExtract_IDLServer
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
        std::string moduleName = rf.check("name", yarp::os::Value("detectionExtract"), "module name (string)").asString();
        setName(moduleName.c_str());

        rpcPort.open(("/"+getName("/rpc:i")).c_str());
        attach(rpcPort);
        
        closing = false;

        processing = new Processing( moduleName );
        /* now start the thread to do the work */
        processing->open();

        return true;
    }
    
    /************************************************************************/
    bool attach(yarp::os::RpcServer &source){
        return this->yarp().attachAsServer(source);
    }
    
    /**********************************************************/
    bool interruptModule()
    {
        rpcPort.interrupt();
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
    
    /**********************************************************/
    yarp::os::Bottle get_component_around(const int32_t x, const int32_t y)
    {
        return processing->get_component_around(x, y);
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
