/*
 * Copyright (C) 2018 iCub Facility - Istituto Italiano di Tecnologia
 * Author: Vadim Tikhanoff Elisa Maiettini
 * email:  vadim.tikhanoff@iit.it elisa.maiettini@iit.it
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

#include <opencv2/core/core.hpp>
#include <opencv2/opencv.hpp>

#include <cstring>
#include <vector>
#include <iostream>
#include <utility>

using namespace yarp::math;

/********************************************************/
class Processing : public yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>
{
    std::string moduleName;
    yarp::os::RpcClient camPort;
    yarp::os::RpcServer handlerPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >   depthImageOutPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >    displayImageOutPort;

    bool    camera_configured;
    double  fov_h;
    double  fov_v;
    yarp::sig::ImageOf<yarp::sig::PixelFloat> depth;

    double minVal = 0.2;
    double maxVal = 3.25;

    cv::Mat overlayFrame;

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
        displayImageOutPort.open("/" + moduleName + "/image:o");

        yarp::os::Network::connect(camPort.getName().c_str(), "/depthCamera/rpc:i", "tcp");
        yarp::os::Network::connect("/depthCamera/depthImage:o", BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>::getName().c_str(), "fast_tcp");
		yarp::os::Network::connect(depthImageOutPort.getName().c_str(), "/modified/depth", "fast_tcp");
        yarp::os::Network::connect(displayImageOutPort.getName().c_str(), "/modified/depthCol", "fast_tcp");

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
    }

    /********************************************************/
    void interrupt()
    {
        BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>::interrupt();
        camPort.interrupt();
        depthImageOutPort.interrupt();
        displayImageOutPort.interrupt();
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
    void onRead( yarp::sig::ImageOf<yarp::sig::PixelFloat> &float_yarp)
    {
        //if (!camera_configured)
            //camera_configured=getCameraOptions();

        yarp::sig::ImageOf<yarp::sig::PixelMono> &outDepthImage  = depthImageOutPort.prepare();
        yarp::sig::ImageOf<yarp::sig::PixelRgb> &outImage  = displayImageOutPort.prepare();

        depth = float_yarp;

        cv::Mat float_original_cv = cv::cvarrToMat((IplImage *)float_yarp.getIplImage());
        cv::Mat float_cv = float_original_cv;

        cv::Mat mono_cv = cv::Mat::ones(float_yarp.height(), float_yarp.width(), CV_8UC1);

        float_cv -= minVal;
        float_cv.convertTo(mono_cv, CV_8U, 255.0/(maxVal-minVal) );

        cv::Mat img_cv(float_yarp.height(), float_yarp.width(), CV_8UC1, cv::Scalar(255));
        cv::Mat img_blobs(float_yarp.height(), float_yarp.width(), CV_8UC1, cv::Scalar(255));

        img_cv = img_cv - mono_cv;

        cv::Mat mask;
        inRange(img_cv, cv::Scalar(255), cv::Scalar(255), mask);
        cv::Mat black_image(img_cv.size(), CV_8U, cv::Scalar(0));
        black_image.copyTo(img_cv, mask);

        img_blobs = img_cv;

        cv::Mat rgb_cv;
        cvtColor(img_cv,rgb_cv,CV_GRAY2RGB);
        cv::Mat overlayFrame;

        double minVal, maxVal;
        cv::Point minLoc, maxLoc;
        cv::minMaxLoc( img_cv, &minVal, &maxVal, &minLoc, &maxLoc );

        int imageThreshRatioLow = 100;

        int maxValThreshed = (maxVal - imageThreshRatioLow );

        cv::Mat cleanedImg;
        cv::threshold(img_cv, cleanedImg, maxValThreshed, 255, cv::THRESH_BINARY);

        std::vector<std::vector<cv::Point> > cnt;
        std::vector<cv::Vec4i> hrch;

        findContours( cleanedImg, cnt, hrch, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE );

        std::vector<cv::Moments> mu( cnt.size() );
        std::vector<cv::Point2f> mc( cnt.size() );

        //yInfo() << "contour size" << cnt.size();

        cv::Mat img_out(float_yarp.height(), float_yarp.width(), CV_8UC1, cv::Scalar(0));

        for( size_t i = 0; i < cnt.size(); i++ )
        {
            mu[i] = moments( cnt[i], false );
            mc[i] = cv::Point2f( mu[i].m10/mu[i].m00 , mu[i].m01/mu[i].m00 );

            //yInfo() << "contour area" << contourArea(cnt[i]);

            if (contourArea(cnt[i]) > 0 && contourArea(cnt[i]) < 1000)
            {
                //double value = img_blobs.at<uchar>(cv::Point(mc[i].x, mc[i].y));

                //yInfo() << "value" << value << "@ " << mc[i].x << mc[i].y;

                //int maxValThreshed = (value - 10);
                //cv::Mat cleanedImg;
                //cv::threshold(img_blobs, img_blobs, maxValThreshed, 255, cv::THRESH_BINARY);

                //std::vector<std::vector<cv::Point> > cnt;
                //std::vector<cv::Vec4i> hrch;

                //findContours( img_blobs, cnt, hrch, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE );

                cv::drawContours( img_cv, cnt, i, cvScalar(0,0,0), CV_FILLED, 8, hrch, 0, cv::Point() );

                //cv::drawContours( img_out, cnt, i, cvScalar(255,255,255), CV_FILLED, 8, hrch, 0, cv::Point() );

                //rgb_cv.copyTo(overlayFrame);
                //cv::drawContours( overlayFrame, cnt, i, cvScalar(255, 102, 102), CV_FILLED, 8, hrch, 0, cv::Point() );
                //double opacity = 0.8;
                //cv::addWeighted(overlayFrame, opacity, i, 1 - opacity, 0, rgb_cv);
            }
        }

        IplImage yarpImg = img_cv;
        outDepthImage.resize(yarpImg.width, yarpImg.height);
        cvCopy( &yarpImg, (IplImage *) outDepthImage .getIplImage());
        depthImageOutPort.write();

        IplImage yarpImgrgb = rgb_cv;
        outImage.resize(yarpImgrgb.width, yarpImgrgb.height);
        cvCopy( &yarpImgrgb, (IplImage *) outImage.getIplImage());
        displayImageOutPort.write();

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
        std::string moduleName = rf.check("name", yarp::os::Value("yarp-blob"), "module name (string)").asString();
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
