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
#include <yarp/os/Mutex.h>

#include <yarp/os/LockGuard.h>
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
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >    imageOutPort;
    yarp::os::BufferedPort<yarp::os::Bottle >    targetPort;
    yarp::os::BufferedPort<yarp::os::Bottle >    blobPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelFloat>>   depthPort;
	yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelMono> >   depthImageOutPort;
    yarp::os::RpcClient camPort;

    yarp::sig::ImageOf<yarp::sig::PixelFloat> depth;

    bool    camera_configured;
    double  fov_h;
    double  fov_v;
    bool    isHand;

    double minVal;
    double maxVal;

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
    bool open()
    {

        this->useCallback();

        BufferedPort<yarp::os::Bottle >::open( "/" + moduleName + "/skeleton:i" );
        imageOutPort.open("/" + moduleName + "/image:o");
        targetPort.open("/" + moduleName + "/target:o");
        blobPort.open("/" + moduleName + "/blobs:o");
        camPort.open("/" + moduleName + "/cam:rpc");
        depthPort.open("/" + moduleName + "/depth:i");
		depthImageOutPort.open("/" + moduleName + "/depthImage:o");

        yarp::os::Network::connect("/yarpOpenPose/target:o", BufferedPort<yarp::os::Bottle >::getName().c_str(), "fast_tcp");
        yarp::os::Network::connect(imageOutPort.getName().c_str(), "/viewer/structure", "fast_tcp");
        yarp::os::Network::connect(camPort.getName().c_str(), "/depthCamera/rpc:i", "fast_tcp");
        yarp::os::Network::connect("/depthCamera/depthImage:o", depthPort.getName().c_str(), "fast_tcp");
		yarp::os::Network::connect(depthImageOutPort.getName().c_str(), "/viewer/depth", "fast_tcp");
        yarp::os::Network::connect("/yarpOpenPose/image:o", "/viewer/skeletons", "fast_tcp");

        camera_configured=true;

        isHand = false;

        fov_h = 55;
        fov_v = 42;

        minVal = 0.2;
        maxVal = 2.25;

        return true;
    }

    /********************************************************/
    void close()
    {
        imageOutPort.close();
        BufferedPort<yarp::os::Bottle >::close();
        targetPort.close();
        blobPort.close();
        camPort.close();
        depthPort.close();
		depthImageOutPort.close();
    }

    /********************************************************/
    void interrupt()
    {
        BufferedPort<yarp::os::Bottle >::interrupt();
        imageOutPort.interrupt();
        targetPort.interrupt();
        blobPort.interrupt();
        camPort.interrupt();
        depthPort.interrupt();
		depthImageOutPort.interrupt();
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
        return false;
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
    void onRead( yarp::os::Bottle &data )
    {
        if (!camera_configured)
            camera_configured=getCameraOptions();

        yarp::sig::ImageOf<yarp::sig::PixelFloat> *float_in_yarp=depthPort.read();
        depth = *float_in_yarp;

        yarp::sig::ImageOf<yarp::sig::PixelMono> &mono_out_yarp  = depthImageOutPort.prepare();
        yarp::os::Bottle &target  = targetPort.prepare();
        target.clear();
        yarp::os::Bottle target_unordered;
        target_unordered.clear();

        int skeletonSize = data.get(0).asList()->size();
        int internalElements = 0;

        if (skeletonSize>0)
        {
            target_unordered = data;
            internalElements = data.get(0).asList()->get(0).asList()->size();
        }

        //convert float image
        cv::Mat float_cv = cv::cvarrToMat((IplImage *)float_in_yarp->getIplImage());
        cv::Mat mono_cv = cv::Mat::ones(float_in_yarp->height(), float_in_yarp->width(), CV_8UC1);

        float_cv -= minVal;
        float_cv.convertTo(mono_cv, CV_8U, 255.0/(maxVal-minVal) );

        cv::Mat mono_img_cv(float_in_yarp->height(), float_in_yarp->width(), CV_8UC1, cv::Scalar(255));

        mono_img_cv = mono_img_cv - mono_cv;

        cv::Mat mask;
        inRange(mono_img_cv, cv::Scalar(255), cv::Scalar(255), mask);
        cv::Mat black_image(mono_img_cv.size(), CV_8U, cv::Scalar(0));
        black_image.copyTo(mono_img_cv, mask);

        std::vector<cv::Point> neck2D;
        std::vector<cv::Point> nose2D;
        std::vector<cv::Point> rightEar2D;
        std::vector<cv::Point> leftEar2D;
        std::vector<cv::Point> leftShoulder2D;
        std::vector<cv::Point> rightShoulder2D;
        std::vector<cv::Point> rightWrist2D;
        std::vector<cv::Point> leftWrist2D;
        std::vector<cv::Point> rightElbow2D;
        std::vector<cv::Point> leftElbow2D;

        cv::Point point;

        std::vector<cv::Point3d> neck3D;
        std::vector<cv::Point3d> leftWrist3D;
        std::vector<cv::Point3d> rightWrist3D;
        std::vector<cv::Point3d> leftElbow3D;
        std::vector<cv::Point3d> rightElbow3D;

        std::vector<yarp::os::Bottle> shapes;
        std::vector<std::pair <int,int> > elements;

        for (int i = 0; i < skeletonSize; i++)
        {
            if (yarp::os::Bottle *propField = data.get(0).asList()->get(i).asList())
            {
                for (int ii = 0; ii < internalElements; ii++)
                {
                    if (yarp::os::Bottle *propFieldPos = propField->get(ii).asList())
                    {
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"REar") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            rightEar2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"LEar") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            leftEar2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"Neck") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            neck2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"Nose") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            nose2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"LShoulder") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            leftShoulder2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"RShoulder") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            rightShoulder2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"RElbow") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            rightElbow2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"LElbow") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            leftElbow2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"RWrist") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            rightWrist2D.push_back(point);
                        }
                        if ( std::strcmp (propFieldPos->get(0).asString().c_str(),"LWrist") == 0)
                        {
                            point.x = (int)propFieldPos->get(1).asDouble();
                            point.y = (int)propFieldPos->get(2).asDouble();
                            leftWrist2D.push_back(point);
                        }
                    }
                }
            }
        }

        int increment = 0;
        isHand = false;

        for (size_t i = 0; i < skeletonSize; i++)
        {
            cv::Point topLeft;
            cv::Point bottomRight;

            cv::Point leftWrist;
            cv::Point rightWrist;

            cv::Point3d point3D;

            int length = 0;
            int shift = 10;

            if (neck2D[i].x > 0)
            {
                if (leftEar2D[i].x > 0 && rightEar2D[i].x > 0)
                {
                    length = leftEar2D[i].x - rightEar2D[i].x;
                    topLeft.x = rightEar2D[i].x - shift;
                    topLeft.y = rightEar2D[i].y - length;

                    bottomRight.x = leftEar2D[i].x + shift;
                    bottomRight.y = leftEar2D[i].y + length;
                }
                else if (leftEar2D[i].x == 0 && rightEar2D[i].x > 0)
                {
                    length = nose2D[i].x - rightEar2D[i].x;
                    topLeft.x = rightEar2D[i].x - shift;
                    topLeft.y = rightEar2D[i].y - length;

                    bottomRight.x = nose2D[i].x + shift;
                    bottomRight.y = nose2D[i].y + length;
                }
                else if (rightEar2D[i].x == 0 && leftEar2D[i].x > 0)
                {
                    length = leftEar2D[i].x - nose2D[i].x;
                    topLeft.x = nose2D[i].x - shift;
                    topLeft.y = nose2D[i].y - length;

                    bottomRight.x = leftEar2D[i].x + shift;
                    bottomRight.y = leftEar2D[i].y + length;
                }

                if (topLeft.x < 1)
                    topLeft.x = 1;
                else if (topLeft.x > 319)
                    topLeft.x = 319;
                else if (topLeft.y < 1)
                    topLeft.y = 1;
                else if (topLeft.y > 239)
                    topLeft.y = 239;

                if (bottomRight.x < 1)
                    bottomRight.x = 1;
                else if (bottomRight.x > 319)
                    bottomRight.x = 319;
                else if (bottomRight.y < 1)
                    bottomRight.y = 1;
                else if (bottomRight.y > 239)
                    bottomRight.y = 239;

                yarp::sig::Vector pLeft;
                yarp::sig::Vector pNeck;
                yarp::sig::Vector pRight;

                if (neck2D[i].x > 0 && neck2D[i].y > 0)
                {
                    if (getPoint3D(neck2D[i].x, neck2D[i].y, pNeck))
                    {
                        point3D.x = pNeck[0];
                        point3D.y = pNeck[1];
                        point3D.z = pNeck[2];
                        neck3D.push_back(point3D);
                    }
                    if (leftWrist2D[i].x > 0 && leftWrist2D[i].y > 0)
                    {
                        if (getPoint3D(leftWrist2D[i].x, leftWrist2D[i].y, pLeft))
                        {
                            point3D.x = pLeft[0];
                            point3D.y = pLeft[1];
                            point3D.z = pLeft[2];
                            leftWrist3D.push_back(point3D);
                        }
                        else
                        {
                            point3D.x = 0.0;
                            point3D.y = 0.0;
                            point3D.z = 0.0;
                            leftWrist3D.push_back(point3D);
                        }
                    }
                    else
                    {
                        point3D.x = 0.0;
                        point3D.y = 0.0;
                        point3D.z = 0.0;
                        leftWrist3D.push_back(point3D);
                    }
                    if (rightWrist2D[i].x > 0 && rightWrist2D[i].y > 0)
                    {
                        if (getPoint3D(rightWrist2D[i].x, rightWrist2D[i].y, pRight))
                        {
                            point3D.x = pRight[0];
                            point3D.y = pRight[1];
                            point3D.z = pRight[2];
                            rightWrist3D.push_back(point3D);
                        }
                        else
                        {
                            point3D.x = 0.0;
                            point3D.y = 0.0;
                            point3D.z = 0.0;
                            rightWrist3D.push_back(point3D);
                        }
                    }
                    else
                    {
                        point3D.x = 0.0;
                        point3D.y = 0.0;
                        point3D.z = 0.0;
                        rightWrist3D.push_back(point3D);
                    }
                    if (leftElbow2D[i].x > 0 && leftElbow2D[i].y > 0)
                    {
                        if (getPoint3D(leftElbow2D[i].x, leftElbow2D[i].y, pRight))
                        {
                            point3D.x = pRight[0];
                            point3D.y = pRight[1];
                            point3D.z = pRight[2];
                            leftElbow3D.push_back(point3D);
                        }
                        else
                        {
                            point3D.x = 0.0;
                            point3D.y = 0.0;
                            point3D.z = 0.0;
                            leftElbow3D.push_back(point3D);
                        }
                    }
                    else
                    {
                        point3D.x = 0.0;
                        point3D.y = 0.0;
                        point3D.z = 0.0;
                        leftElbow3D.push_back(point3D);
                    }

                    if (rightElbow2D[i].x > 0 && rightElbow2D[i].y > 0)
                    {
                        if (getPoint3D(rightElbow2D[i].x, rightElbow2D[i].y, pRight))
                        {
                            point3D.x = pRight[0];
                            point3D.y = pRight[1];
                            point3D.z = pRight[2];
                            rightElbow3D.push_back(point3D);
                        }
                        else
                        {
                            point3D.x = 0.0;
                            point3D.y = 0.0;
                            point3D.z = 0.0;
                            rightElbow3D.push_back(point3D);
                        }
                    }
                    else
                    {
                        point3D.x = 0.0;
                        point3D.y = 0.0;
                        point3D.z = 0.0;
                        rightElbow3D.push_back(point3D);
                    }
                }

                yarp::os::Bottle tmp;

                if (topLeft.x < bottomRight.x && topLeft.y < bottomRight.y)
                {
                    tmp.addInt(topLeft.x);
                    tmp.addInt(topLeft.y);
                    tmp.addInt(bottomRight.x);
                    tmp.addInt(bottomRight.y);
                    //yInfo() << "IN NORMAL" << tmp.toString();
                    elements.push_back(std::make_pair(topLeft.x,increment));
                    shapes.push_back(tmp);
                    increment++;
                }
                else
                {
                    tmp.addInt(topLeft.x);
                    tmp.addInt(topLeft.y);
                    tmp.addInt(bottomRight.x);
                    tmp.addInt(bottomRight.y);
                    //yError() << "WTF NORMAL" << tmp.toString();
                }
            }
            else
            {
                if (leftEar2D[i].x > 0 && rightEar2D[i].x > 0)
                {
                    length = rightEar2D[i].x - leftEar2D[i].x;
                    topLeft.x = leftEar2D[i].x - shift;
                    topLeft.y = leftEar2D[i].y - length;

                    bottomRight.x = rightEar2D[i].x + shift;
                    bottomRight.y = rightEar2D[i].y + length;

                    if (topLeft.x < 1)
                        topLeft.x = 1;
                    else if (topLeft.x > 319)
                        topLeft.x = 319;
                    else if (topLeft.y < 1)
                        topLeft.y = 1;
                    else if (topLeft.y > 239)
                        topLeft.y = 239;

                    if (bottomRight.x < 1)
                        bottomRight.x = 1;
                    else if (bottomRight.x > 319)
                        bottomRight.x = 319;
                    else if (bottomRight.y < 1)
                        bottomRight.y = 1;
                    else if (bottomRight.y > 239)
                        bottomRight.y = 239;

                    yarp::os::Bottle tmp;

                    if (topLeft.x < bottomRight.x && topLeft.y < bottomRight.y)
                    {
                        tmp.addInt(topLeft.x);
                        tmp.addInt(topLeft.y);
                        tmp.addInt(bottomRight.x);
                        tmp.addInt(bottomRight.y);
                        yInfo() << "IN REVERSED" << tmp.toString();
                        elements.push_back(std::make_pair(topLeft.x, increment));
                        shapes.push_back(tmp);
                        increment++;
                    }
                    else
                    {
                        tmp.addInt(topLeft.x);
                        tmp.addInt(topLeft.y);
                        tmp.addInt(bottomRight.x);
                        tmp.addInt(bottomRight.y);
                        yError() << "WTF REVERSED" << tmp.toString();
                    }
                }
            }
        }

        cv::Point hand;
        cv::Point elbow;

        cv::Mat cleanedImg (float_in_yarp->height(), float_in_yarp->width(), CV_8UC1, cv::Scalar(0));

        for (int i = 0; i < neck3D.size(); i++)
        {
            if (neck2D[i].x > 0)
            {
                bool isLeft = false;
                bool isRight = false;

                double wristsDiff = fabs( leftWrist3D[i].z - rightWrist3D[i].z);
                double elbowsDiff = fabs( leftElbow3D[i].z - rightElbow3D[i].z);

                if (neck3D[i].z > 0)
                {
                    if (leftWrist3D[i].z > 0 && rightWrist3D[i].z > 0 )
                    {
                        if ( wristsDiff > 0.2 && leftWrist3D[i].z < rightWrist3D[i].z )
                        {
                            isLeft = true;
                        }
                        else if (wristsDiff > 0.2 && rightWrist3D[i].z < leftWrist3D[i].z )
                        {
                            isRight = true;
                        }
                        else
                        {
                            yDebug() << "ignoring wrists";
                        }
                    }
                    else if (leftElbow3D[i].z > 0 && rightElbow3D[i].z > 0)
                    {
                        if (  elbowsDiff > 0.1 && leftElbow3D[i].z < rightElbow3D[i].z )
                        {
                            isLeft = true;
                        }
                        if (elbowsDiff > 0.1 && rightElbow3D[i].z < leftElbow3D[i].z )
                        {
                            isRight = true;
                        }
                        else
                        {
                            yDebug() << "ignoring elbows";
                        }
                    }
                    else
                    {
                        yDebug() << "ignoring skeleton, rubbish";
                    }

                    if (isLeft)
                    {
                        yDebug() << "SHOULD LOOK AT LEFT HAND";
                        hand.x = leftWrist2D[i].x;
                        hand.y = leftWrist2D[i].y;
                        elbow.x = leftElbow2D[i].x;
                        elbow.y = leftElbow2D[i].y;
                    }

                    else if (isRight)
                    {
                        yDebug() << "SHOULD LOOK AT RIGHT HAND";
                        hand.x = rightWrist2D[i].x;
                        hand.y = rightWrist2D[i].y;
                        elbow.x = rightElbow2D[i].x;
                        elbow.y = rightElbow2D[i].y;
                    }
                    else
                       yDebug() << "IGNORING SKELETON";
                }
            }
        }

        if (hand.x > 0 && hand.y > 0)
        {
            int chosenValue = -1;

            double value = mono_img_cv.at<uchar>(hand);
            int maxValThreshed = (value - 3);

            cv::threshold(mono_img_cv, cleanedImg, maxValThreshed, 255, cv::THRESH_BINARY);

            std::vector<std::vector<cv::Point> > cnt;
            std::vector<cv::Vec4i> hrch;

            findContours( cleanedImg, cnt, hrch, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE );

            std::vector<std::vector<cv::Point> > contours_poly( cnt.size() );
            std::vector<cv::Rect> boundRect( cnt.size() );

            std::vector<cv::Moments> mu(cnt.size() );
            std::vector<cv::Point2f> mc( cnt.size() );

            for (int x = 0; x < cnt.size(); x++)
            {
                mu[x] = moments( cnt[x], false );
                mc[x] = cv::Point2f( mu[x].m10/mu[x].m00 , mu[x].m01/mu[x].m00 );

                if ( abs(hand.x-mc[x].x) < 100 && contourArea(cnt[x]) > 300 && contourArea(cnt[x]) < 5000)
                    chosenValue = x;
            }

            if (chosenValue >= 0)
            {
                approxPolyDP( cv::Mat(cnt[chosenValue]), contours_poly[chosenValue], 3, true );
                boundRect[chosenValue] = boundingRect( cv::Mat(contours_poly[chosenValue]) );

                cv::rectangle(mono_img_cv, boundRect[chosenValue].tl(), boundRect[chosenValue].br(), cv::Scalar( 255, 255, 255), 2, 8);
                yarp::os::Bottle tmp;
                shapes.clear();

                tmp.addInt(boundRect[chosenValue].tl().x);
                tmp.addInt(boundRect[chosenValue].tl().y);
                tmp.addInt(boundRect[chosenValue].br().x);
                tmp.addInt(boundRect[chosenValue].br().y);

                shapes.push_back(tmp);
                isHand = true;
            }
        }

        if (elements.size()>0)
        {
            //for (int i=0; i<elements.size(); i++)
            //    yInfo() << "Testing elements " << i << elements[i].first << elements[i].second;

            std::sort(elements.begin(), elements.end());

            //for (int i=0; i<elements.size(); i++)
            //    yInfo() << "Sorted elements " << i << elements[i].first << elements[i].second;

            yarp::os::Bottle &organisedList = target.addList();

            if ( shapes.size() > 0)
            {
                yarp::os::Bottle &blobs  = blobPort.prepare();
                blobs.clear();

                yarp::os::Bottle &mainList = blobs.addList();

                if (isHand)
                   mainList.addString("hand");
                else
                   mainList.addString("face");

                //yInfo() << "**************** element SIZE" << elements.size() << "shape SIZE" << shapes.size() ;
                for (int i=0; i<shapes.size(); i++)
                {
                    yarp::os::Bottle &tmp = mainList.addList();

                    if (isHand)
                    {
                        tmp.addInt(shapes[i].get(0).asInt());
                        tmp.addInt(shapes[i].get(1).asInt());
                        tmp.addInt(shapes[i].get(2).asInt());
                        tmp.addInt(shapes[i].get(3).asInt());
                    }
                    else
                    {
                        tmp.addInt(shapes[elements[i].second].get(0).asInt());
                        tmp.addInt(shapes[elements[i].second].get(1).asInt());
                        tmp.addInt(shapes[elements[i].second].get(2).asInt());
                        tmp.addInt(shapes[elements[i].second].get(3).asInt());
                    }
                }

                //Send ordered skeletons
                for (int i=0; i<elements.size(); i++)
                {
                    yarp::os::Bottle &tmpList = organisedList.addList();
                    tmpList.append(*data.get(0).asList()->get(elements[i].second).asList());
                }

                targetPort.write();
            }
        }

        IplImage ipltemp=mono_img_cv;
        mono_out_yarp.resize(ipltemp.width, ipltemp.height);
        cvCopy( &ipltemp, (IplImage *) mono_out_yarp.getIplImage());

        depthImageOutPort.write();
        imageOutPort.write();
        blobPort.write();
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
        std::string moduleName = rf.check("name", yarp::os::Value("human-structure"), "module name (string)").asString();
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
        closing = true;
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
