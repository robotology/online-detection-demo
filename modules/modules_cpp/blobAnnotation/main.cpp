/******************************************************************************
 *                                                                            *
 * Copyright (C) 2020 Fondazione Istituto Italiano di Tecnologia (IIT)        *
 * All Rights Reserved.                                                       *
 *                                                                            *
 ******************************************************************************/

/**
 * @file main.cpp
 * @authors: Vadim Tikhanoff <vadim.tikhanoff@iit.it>
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

#include <blobAnnotation_IDLServer.h>

using namespace yarp::math;
using namespace yarp::cv;


/* Declare global variables */
cv::Point point1, point2; /* vertical points of the bounding box */
int drag = 0;
cv::Rect rect; /* bounding box */
cv::Mat img, roiImg; /* roiImg - the part of the image in the bounding box */
int select_flag = 0;

cv::Point clickedPoint;
cv::Point draggedPoint;

bool isMouseDown = false;
bool isMouseUp   = false;
bool isDragging  = false;
bool gotEvent = false;

void CallBackFunc(int event, int x, int y, int flags, void* userdata)
{
     if  ( event == cv::EVENT_LBUTTONDOWN )
     {
          yInfo() << "Left button of the mouse is clicked - position (" << x << ", " << y << ")";
          isMouseDown = true;
          isMouseUp   = false;
          clickedPoint.x = x;
          clickedPoint.y = y;
     }
     else if  ( event == cv::EVENT_LBUTTONUP )
     {
          if (isMouseDown)
          {
              yInfo() << "Left button of the mouse is up";
              isMouseDown = false;
              gotEvent = true;
              isDragging  = false;
          }
     }
     else if  ( event == cv::EVENT_RBUTTONDOWN )
     {
          yInfo() << "Right button of the mouse is clicked - position (" << x << ", " << y << ")";
     }
     else if  ( event == cv::EVENT_MBUTTONDOWN )
     {
          yInfo() << "Middle button of the mouse is clicked - position (" << x << ", " << y << ")";
     }
     else if ( event == cv::EVENT_MOUSEMOVE )
     {
          if (isMouseDown)
          {
              isDragging = true;
              draggedPoint.x = x;
              draggedPoint.y = y;
              //yInfo() << "Mouse move in the window - position (" << x << ", " << y << ")";
          }
     }
}

/********************************************************/
class Processing : public yarp::os::BufferedPort<yarp::os::Bottle>
{
    std::string moduleName;
    
public:
    bool gotNewDetection;
    yarp::os::Bottle detections;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >    imageInPort;

    cv::Mat imgMat;

    /********************************************************/
    Processing( const std::string &moduleName)
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
        BufferedPort<yarp::os::Bottle >::open( "/" + moduleName + "/detections:i" );
        imageInPort.open("/" + moduleName + "/image:i");

        yarp::os::Network::connect("/write", this->BufferedPort<yarp::os::Bottle >::getName().c_str());
        yarp::os::Network::connect("/icub/camcalib/left/out", imageInPort.getName().c_str());

        gotNewDetection = false;

        return true;
    }

    /********************************************************/
    yarp::os::Bottle retreiveDetections()
    {
        gotNewDetection = false;
        return detections;
    }

    cv::Mat retreiveImage()
    {
        return imgMat;
    }

    /********************************************************/
    void close()
    {
        BufferedPort<yarp::os::Bottle >::close();
        imageInPort.close();
    }

    /********************************************************/
    void interrupt()
    {
        BufferedPort<yarp::os::Bottle >::interrupt();
        imageInPort.interrupt();
    }

    /********************************************************/
    void onRead( yarp::os::Bottle &data )
    {
        yarp::sig::ImageOf<yarp::sig::PixelRgb> *inImage = imageInPort.read();
        
        imgMat = toCvMat(*inImage);
        cv::cvtColor(imgMat, imgMat, CV_BGR2RGB);
        detections = data;
        gotNewDetection = true;
    }
};

/********************************************************/
class Module : public yarp::os::RFModule, public blobAnnotation_IDLServer
{
    yarp::os::ResourceFinder    *rf;
    yarp::os::RpcServer         rpcPort;

    Processing                  *processing;
    friend class                processing;

    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >    imageOutPort;
    yarp::os::BufferedPort<yarp::os::Bottle >    clickPoints;
    yarp::os::BufferedPort<yarp::os::Bottle >    blobPort;

    cv::Mat imgMat;
    cv::Mat img_out;

    bool gotNewDetections;
    bool selectedDetection;

    bool closing;

    int x ;
    int y ;
    int width;
    int height;
    
    int detectionIndex;

    bool topLeftSelected;
    bool topRightSelected;
    bool bottomLeftSelected;
    bool bottomRightSelected;
    bool topMidSelected;
    bool bottomMidSelected;
    bool leftMidSelected;
    bool rightMidSelected;
    bool totalSelected;

    bool isActive;
    bool updateScene;
    bool isReadyToSend;

    cv::Point fixedBottomLeftPoint;

    int offset = 4;

    cv::Point topLeft, topRight, topMid, bottomLeft, bottomRight, bottomMid, midRight, midLeft;

    std::vector<cv::Rect> detectionRects;
    std::vector<std::string> detectionLabels;
    size_t detectionSize;
    
    
public:

    /********************************************************/
    bool configure(yarp::os::ResourceFinder &rf)
    {
        this->rf=&rf;
        std::string moduleName = rf.check("name", yarp::os::Value("blobAnnotation"), "module name (string)").asString();
        setName(moduleName.c_str());

        rpcPort.open(("/"+getName("/rpc:i")).c_str());
        
        imageOutPort.open("/" + moduleName + "/image:o");
        blobPort.open("/" + moduleName + "/blobs:o");

        yarp::os::Network::connect(imageOutPort.getName().c_str(), "/viewer");

        yarp::os::Network::connect(blobPort.getName().c_str(), "/read");
        
        clickedPoint.x = -1;
        clickedPoint.y = -1;
        detectionIndex = -1;

        gotNewDetections = false;
        selectedDetection = false;

        totalSelected = false;
        topLeftSelected = false;
        topRightSelected = false;
        bottomLeftSelected = false;
        bottomRightSelected = false;
        topMidSelected = false;
        bottomMidSelected = false;
        leftMidSelected = false;
        rightMidSelected = false;

        isActive = false;
        isReadyToSend = false;

        x = 0;
        y = 0;
        width = 0;
        height = 0;

        processing = new Processing( moduleName );
        /* now start the thread to do the work */
        processing->open();
        
        attach(rpcPort);
        
        closing = false;
        updateScene = false;
        detectionSize = 0;

        cv::namedWindow("detections", 1);

        cvSetMouseCallback("detections", CallBackFunc, NULL);

        return true;
    }
    
    /************************************************************************/
    bool attach(yarp::os::RpcServer &source)
    {
        return this->yarp().attachAsServer(source);
    }
    
    /**********************************************************/
    bool interruptModule()
    {
        rpcPort.interrupt();
        
        imageOutPort.interrupt();
        blobPort.interrupt();
        
        return true;
    }
    /**********************************************************/
    bool close()
    {
        imageOutPort.close();
        blobPort.close();

        processing->interrupt();
        processing->close();
        delete processing;

        return true;
    }

    /**********************************************************/
    bool quit()
    {
        closing = true;
        return true;
    }

    /********************************************************/
    double getPeriod()
    {
        return 0.1;
    }

    /********************************************************/
    bool addDetection()
    {
        cv::Point newPoint;
        newPoint.x = 10;
        newPoint.y = 10;
        int width  = 30;
        int height = 30;

        yInfo() << "before" << detectionRects.size();
        for (size_t i = 0; i < detectionRects.size(); i++)
        {
            yInfo() << detectionRects[i].x << detectionRects[i].y << detectionRects[i].width << detectionRects[i].height;
        }

        detectionRects.push_back(cv::Rect(newPoint.x, newPoint.y, width, height ));
        detectionLabels.push_back("...");

        yInfo() << "after" << detectionRects.size();
        for (size_t i = 0; i < detectionRects.size(); i++)
        {
            yInfo() << detectionRects[i].x << detectionRects[i].y << detectionRects[i].width << detectionRects[i].height;
        }

        updateScene = true;
        selectedDetection = false;
        detectionIndex = detectionRects.size() -1;
        drawSelectMarkers(detectionRects.size() -1);

        return true;
    }

    /********************************************************/
    bool finishAnnotation()
    {
        isReadyToSend = true;
        updateScene = true;
        detectionIndex = -1;
        selectedDetection = false;

        return true;
    }
    

    /********************************************************/
    bool deleteSelection()
    {
        bool returnval = false;

        if (selectedDetection)
        { 
            int index = detectionIndex;
            detectionRects.erase(detectionRects.begin()+index);
            detectionLabels.erase(detectionLabels.begin()+index);
        
            updateScene = true;
            detectionIndex = -1;
            selectedDetection = false;
            returnval = true;
        }
        return returnval;
    }

    /********************************************************/
    bool doneSelection(const std::string &label)
    {
        detectionLabels[detectionIndex] = label;
        detectionRects[detectionIndex].x = topLeft.x;
        detectionRects[detectionIndex].y = topLeft.y;
        detectionRects[detectionIndex].width = topRight.x - topLeft.x;
        detectionRects[detectionIndex].height = bottomLeft.y - topLeft.y; 

        for (size_t i = 0; i < detectionRects.size(); i++)
        {
            yDebug() << detectionLabels[i].c_str() << detectionRects[i].x << detectionRects[i].y;
        }

        updateScene = true;

        detectionIndex = -1;
        selectedDetection = false;
        
        return true;
    }

    /********************************************************/
    bool selectDetection()
    {   
        gotEvent = false;
        bool returnVal = false;

        while (!gotEvent)
        {
            yInfo() << "waiting for event";
            yarp::os::Time::delay(0.1);
        }
        gotEvent = true;
        yInfo() << "Got event @" << clickedPoint.x << clickedPoint.y;

        yInfo() << "Got " << " " << detectionRects.size() << " detections";
        
        for (size_t i = 0; i < detectionRects.size(); i++)
        {
            yInfo() << "rect x " << detectionRects[i].x ; 
            yInfo() << "rect y " << detectionRects[i].y ; 
            yInfo() << "rect width " << detectionRects[i].width ; 
            yInfo() << "rect height " << detectionRects[i].height;
        }
       
        for (size_t i = 0; i < detectionRects.size(); i++)
        {

            if ( clickedPoint.x > detectionRects[i].x && clickedPoint.x < (detectionRects[i].x + detectionRects[i].width) )
            {
                if ( clickedPoint.y > detectionRects[i].y && clickedPoint.y < (detectionRects[i].y + detectionRects[i].height) )
                {      
                    yInfo() << "Got it ";
                    returnVal = true;
                    detectionIndex = i;
                }
            }
        }

        if (returnVal)
            yInfo() << "Selected detection with index " << detectionIndex;
        else
            yInfo() << "Selected point does not belong to detection";

        clickedPoint.x = -1;
        clickedPoint.y = -1;

        return returnVal;
    }

    /********************************************************/
    bool drawSelectMarkers(int index)
    {
        imgMat = img_out.clone();

        if (!selectedDetection)
        {
            width  = detectionRects[index].width;
            height = detectionRects[index].height;
            x = detectionRects[index].x;
            y = detectionRects[index].y;
            yDebug() << "selectedDetection - Getting x and y from detectionRects ";
            selectedDetection = true;

            topLeft.x = x;
            topLeft.y = y;
            
            topRight.x = x + width;
            topRight.y = y;

            bottomLeft.x = x;
            bottomLeft.y = y + height;
            
            bottomRight.x = x + width;
            bottomRight.y = y + height;

            topMid.x = x + (width/2) - offset*2;
            topMid.y =  y - offset;
            
            bottomMid.x = x + (width/2) - offset*2;
            bottomMid.y = y + height - offset;

            midRight.x = x + width - offset;
            midRight.y = y + (height/2) - offset*2;

            midLeft.x = x - offset;
            midLeft.y = y + (height/2) - offset*2;

            //fixedBottomLeftPoint.y = bottomLeft.x;
            //fixedBottomLeftPoint.y = bottomLeft.y;

        }
        else
        {
            if (isDragging)
            {
                int tmpx = clickedPoint.x - draggedPoint.x;
                int tmpy = clickedPoint.y - draggedPoint.y;
     
               /* if (totalSelected || topLeftSelected || topMidSelected || topRightSelected || topRightSelected || rightMidSelected || bottomRightSelected || 
                bottomMidSelected || bottomLeftSelected || leftMidSelected)
                {
                    x = x - tmpx;
                    y = y - tmpy;
                }*/

                //Drag the whole box (slighty smaller to avoid overlap of boxes selection)
                if ( !isActive && draggedPoint.x > topLeft.x + offset && draggedPoint.x < ( topRight.x - offset) )
                {
                    if ( draggedPoint.y > topLeft.y + offset && draggedPoint.y < (bottomRight.y - offset) )
                    {     
                        totalSelected = true;
                        isActive = true;
                    }
                }

                //Drag the top left box 
                if ( !isActive && draggedPoint.x > (topLeft.x - offset) && draggedPoint.x < ((topLeft.x + offset) ))
                {
                    if ( draggedPoint.y > topLeft.y - offset && draggedPoint.y < (topLeft.y + offset) )
                    {   
                        topLeftSelected = true;
                        isActive = true;
                    }
                }

                //Drag the top mid box 
                if ( !isActive && draggedPoint.x > ((topLeft.x + topRight.x)/2) - offset*2 && draggedPoint.x <  ((topLeft.x + topRight.x)/2) + offset*2 )
                {
                    if ( draggedPoint.y > topLeft.y - offset && draggedPoint.y < (topLeft.y + offset) )
                    {   
                        topMidSelected = true;
                        isActive = true;
                    }
                }

                //Drag the top right box 
                if ( !isActive && draggedPoint.x > (topRight.x - offset) && draggedPoint.x < (topRight.x + offset) )
                {
                    if ( draggedPoint.y > (topRight.y - offset) && draggedPoint.y < (topRight.y + offset) )
                    {   
                        topRightSelected = true;
                        isActive = true;
                    }
                }

                //Drag the right mid box 
                if ( !isActive && draggedPoint.x > (topRight.x - offset) && draggedPoint.x < (topRight.x + offset) )
                {
                    if ( draggedPoint.y > ((topRight.y + bottomRight.y)/2 - offset*2) && draggedPoint.y < ((topRight.y + bottomRight.y)/2 + offset*2 ))
                    {   
                        rightMidSelected = true;
                        isActive = true;
                    }
                }

                //Drag the bottom right box 
                if ( !isActive && draggedPoint.x > (bottomRight.x - offset) && draggedPoint.x < (bottomRight.x + offset) )
                {
                    if ( draggedPoint.y > (bottomRight.y - offset) && draggedPoint.y < (bottomRight.y + offset) )
                    {   
                        bottomRightSelected = true;
                        isActive = true;
                    }
                }

                //Drag the bottom mid box 
                if ( !isActive && draggedPoint.x > ((bottomLeft.x + bottomRight.x)/2) - offset*2 && draggedPoint.x <  ((bottomLeft.x + bottomRight.x)/2) + offset*2 )
                {
                    if ( draggedPoint.y > bottomLeft.y - offset && draggedPoint.y < (bottomLeft.y + offset) )
                    {   
                        bottomMidSelected = true;
                        isActive = true;
                    }
                }

                //Drag the bottom left box 
                if ( !isActive && draggedPoint.x > (bottomLeft.x - offset) && draggedPoint.x < ((bottomLeft.x + offset) ))
                {
                    if ( draggedPoint.y > bottomLeft.y - offset && draggedPoint.y < (bottomLeft.y + offset) )
                    {   
                        bottomLeftSelected = true;
                        isActive = true;
                    }
                }

                //Drag the left mid box 
                if ( !isActive && draggedPoint.x > (topLeft.x - offset) && draggedPoint.x < (topLeft.x + offset) )
                {
                    if ( draggedPoint.y > ((topLeft.y + bottomLeft.y)/2 - offset*2) && draggedPoint.y < ((topLeft.y + bottomLeft.y)/2 + offset*2 ))
                    {   
                        leftMidSelected = true;
                        isActive = true;
                    }
                }

                if (totalSelected)
                {
                    topLeft.x = topLeft.x - tmpx;
                    topLeft.y = topLeft.y - tmpy;
                    topRight.x = topRight.x - tmpx;
                    topRight.y = topRight.y - tmpy;

                    bottomLeft.x = bottomLeft.x - tmpx;
                    bottomLeft.y = bottomLeft.y - tmpy;
                    bottomRight.x = bottomRight.x - tmpx;
                    bottomRight.y = bottomRight.y - tmpy;

                    topMid.x = topMid.x - tmpx;
                    topMid.y = topMid.y - tmpy;
                    bottomMid.x = bottomMid.x - tmpx;
                    bottomMid.y = bottomMid.y - tmpy;
                    midRight.x = midRight.x - tmpx;
                    midRight.y = midRight.y - tmpy;
                    midLeft.x = midLeft.x - tmpx;
                    midLeft.y = midLeft.y - tmpy;

                    topLeftSelected = false; 
                    topMidSelected = false; 
                    topRightSelected = false;
                    bottomLeftSelected = false;
                    bottomRightSelected = false;
                    bottomMidSelected = false;
                    leftMidSelected = false;
                    rightMidSelected = false;
                }//totalSelected

                if (topLeftSelected)
                {
                    topLeft.x = topLeft.x - tmpx;
                    topLeft.y = topLeft.y - tmpy;
                    topRight.y = topRight.y - tmpy;
                    bottomLeft.x = bottomLeft.x - tmpx;
                    
                    topMid.x = (((topLeft.x+topRight.x)/2) - offset*2) - tmpx;
                    topMid.y = topMid.y - tmpy;
                    bottomMid.x = (((topLeft.x+bottomRight.x)/2) - offset*2) - tmpx;

                    midLeft.x = midLeft.x - tmpx;
                    midLeft.y = (((topLeft.y+bottomLeft.y)/2) - offset*2) - tmpy;
                    
                    midRight.y = (((topRight.y+bottomRight.y)/2) - offset*2) - tmpy;

                    totalSelected = false;
                    topMidSelected = false; 
                    topRightSelected = false;
                    bottomLeftSelected = false;
                    bottomRightSelected = false;
                    bottomMidSelected = false;
                    leftMidSelected = false;
                    rightMidSelected = false;

                }//topLeftSelected

                if (topMidSelected)
                {
                    topLeft.y = topLeft.y - tmpy;
                    topRight.y = topRight.y - tmpy;
                    topMid.y = topMid.y - tmpy;
                    midLeft.y = (((topLeft.y+bottomLeft.y)/2) - offset*2) - tmpy;
                    midRight.y = (((topRight.y+bottomRight.y)/2) - offset*2) - tmpy;

                    totalSelected = false;
                    topRightSelected = false;
                    bottomLeftSelected = false;
                    bottomRightSelected = false;
                    bottomMidSelected = false;
                    leftMidSelected = false;
                    rightMidSelected = false;
                    topLeftSelected = false;

                }//topMidSelected

                if (topRightSelected)
                {
                    topRight.x = topRight.x - tmpx;
                    topRight.y = topRight.y - tmpy;
                    topLeft.y = topLeft.y - tmpy;
                    bottomRight.x = bottomRight.x - tmpx;
                    
                    topMid.x = (((topLeft.x+topRight.x)/2) - offset*2) - tmpx;
                    topMid.y = topMid.y - tmpy;
                    bottomMid.x = (((topLeft.x+bottomRight.x)/2) - offset*2) - tmpx;

                    midRight.x = midRight.x - tmpx;
                    midRight.y = (((topRight.y+bottomRight.y)/2) - offset*2) - tmpy;
                    
                    midLeft.y = (((topLeft.y+bottomLeft.y)/2) - offset*2) - tmpy;

                    totalSelected = false;
                    topMidSelected = false; 
                    topLeftSelected = false;
                    bottomLeftSelected = false;
                    bottomRightSelected = false;
                    bottomMidSelected = false;
                    leftMidSelected = false;
                    rightMidSelected = false;

                }//topRightSelected

                if (rightMidSelected)
                {
                    topRight.x = topRight.x - tmpx;
                    topMid.x = (((topLeft.x+topRight.x)/2) - offset*2) - tmpx;

                    bottomMid.x = (((bottomLeft.x+bottomRight.x)/2) - offset*2) - tmpx;
                    bottomRight.x = bottomRight.x - tmpx;

                    midRight.x = midRight.x - tmpx;

                    totalSelected = false;
                    topLeftSelected = false;
                    topRightSelected = false;
                    bottomLeftSelected = false;
                    bottomRightSelected = false;
                    bottomMidSelected = false;
                    leftMidSelected = false;
                    topMidSelected = false;
                    
                }//rightMidSelected
                
                if (bottomRightSelected)
                {
                    bottomRight.x = bottomRight.x - tmpx;
                    bottomRight.y = bottomRight.y - tmpy;
                    bottomLeft.y = bottomLeft.y - tmpy;
                    topRight.x = topRight.x - tmpx;
                    
                    
                    bottomMid.x = (((bottomLeft.x+bottomRight.x)/2) - offset*2) - tmpx;
                    bottomMid.y = bottomMid.y - tmpy;
                    
                    topMid.x = (((bottomLeft.x+bottomRight.x)/2) - offset*2) - tmpx;

                    midRight.x = midRight.x - tmpx;
                    midRight.y = (((topRight.y+bottomRight.y)/2) - offset*2) - tmpy;
                    
                    midLeft.y = (((topLeft.y+bottomLeft.y)/2) - offset*2) - tmpy;

                    totalSelected = false;
                    topMidSelected = false; 
                    topLeftSelected = false;
                    bottomLeftSelected = false;
                    topRightSelected = false;
                    bottomMidSelected = false;
                    leftMidSelected = false;
                    rightMidSelected = false;

                }//bottomRightSelected

                if (bottomMidSelected)
                {
                    bottomLeft.y = bottomLeft.y - tmpy;
                    bottomRight.y = bottomRight.y - tmpy;
                    bottomMid.y = bottomMid.y - tmpy;
                    midLeft.y = (((topLeft.y+bottomLeft.y)/2) - offset*2) - tmpy;
                    midRight.y = (((topRight.y+bottomRight.y)/2) - offset*2) - tmpy;

                    totalSelected = false;
                    topRightSelected = false;
                    bottomLeftSelected = false;
                    bottomRightSelected = false;
                    leftMidSelected = false;
                    rightMidSelected = false;
                    topLeftSelected = false;
                    topMidSelected = false;

                }//bottomMidSelected

                if (bottomLeftSelected)
                {
                    bottomLeft.x = bottomLeft.x - tmpx;
                    bottomLeft.y = bottomLeft.y - tmpy;
                    bottomRight.y = bottomRight.y - tmpy;
                    topLeft.x = topLeft.x - tmpx;
                    
                    bottomMid.x = (((bottomLeft.x+bottomRight.x)/2) - offset*2) - tmpx;
                    bottomMid.y = bottomMid.y - tmpy;
                    topMid.x = (((topLeft.x+topRight.x)/2) - offset*2) - tmpx;

                    midLeft.x = midLeft.x - tmpx;
                    midLeft.y = (((topLeft.y+bottomLeft.y)/2) - offset*2) - tmpy;
                    
                    midRight.y = (((topRight.y+bottomRight.y)/2) - offset*2) - tmpy;

                    totalSelected = false;
                    topMidSelected = false; 
                    topRightSelected = false;
                    topLeftSelected = false;
                    bottomRightSelected = false;
                    bottomMidSelected = false;
                    leftMidSelected = false;
                    rightMidSelected = false;

                }//bottomLeftSelected


                if (leftMidSelected)
                {
                    topLeft.x = topLeft.x - tmpx;
                    topMid.x = (((topLeft.x+topRight.x)/2) - offset*2) - tmpx;

                    bottomMid.x = (((bottomLeft.x+bottomRight.x)/2) - offset*2) - tmpx;
                    bottomLeft.x = bottomLeft.x - tmpx;

                    midLeft.x = midLeft.x - tmpx;

                    totalSelected = false;
                    topLeftSelected = false;
                    topRightSelected = false;
                    bottomLeftSelected = false;
                    bottomRightSelected = false;
                    bottomMidSelected = false;
                    rightMidSelected = false;
                    topMidSelected = false;
                    
                }//leftMidSelected

                 clickedPoint.x = draggedPoint.x;
                 clickedPoint.y = draggedPoint.y;
            }
            else
            {
                isActive = false;
                totalSelected = false;
                topLeftSelected = false; 
                topMidSelected = false; 
                topRightSelected = false;
                rightMidSelected = false;
                bottomRightSelected = false;
                bottomMidSelected = false;
                bottomLeftSelected = false;
                leftMidSelected = false;
            }
        }

        for (size_t i = 0; i < detectionRects.size(); i++)
        {
            if (i != index)
            {
                rectangle(imgMat, detectionRects[i], CV_RGB(0, 0, 204), 2, 8, 0);
            }
        }
        
        if (totalSelected) //the whole bb
        {
            line(imgMat, cv::Point(topLeft.x, topLeft.y), cv::Point(topRight.x, topRight.y ), CV_RGB(204, 0, 0), 2, 8, 0);
            line(imgMat, cv::Point(topRight.x, topRight.y ), cv::Point(bottomRight.x, bottomRight.y), CV_RGB(204, 0, 0), 2, 8, 0);
            line(imgMat, cv::Point(bottomRight.x, bottomRight.y), cv::Point(bottomLeft.x, bottomRight.y), CV_RGB(204, 0, 0), 2, 8, 0);
            line(imgMat, cv::Point(bottomLeft.x, bottomLeft.y), cv::Point(topLeft.x, topLeft.y), CV_RGB(204, 0, 0), 2, 8, 0);
        }
        else
        {
            line(imgMat, cv::Point(topLeft.x, topLeft.y), cv::Point(topRight.x, topRight.y), CV_RGB(0, 204, 0), 2, 8, 0);
            line(imgMat, cv::Point(topRight.x, topRight.y), cv::Point(bottomRight.x, bottomRight.y), CV_RGB(0, 204, 0), 2, 8, 0);
            line(imgMat, cv::Point(bottomRight.x, bottomRight.y), cv::Point(bottomLeft.x, bottomRight.y), CV_RGB(0, 204, 0), 2, 8, 0);
            line(imgMat, cv::Point(bottomLeft.x, bottomLeft.y), cv::Point(topLeft.x, topLeft.y), CV_RGB(0, 204, 0), 2, 8, 0);
        }

        if (topLeftSelected) //top left
            rectangle(imgMat, cv::Rect ( topLeft.x - offset, topLeft.y - offset, offset*2, offset*2 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( topLeft.x - offset, topLeft.y - offset, offset*2, offset*2 ), CV_RGB(0, 204, 0), -1, 8, 0);

        if (topRightSelected)//top right
            rectangle(imgMat, cv::Rect ( topRight.x - offset, topRight.y - offset, offset*2 , offset*2 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( topRight.x - offset, topRight.y - offset, offset*2 , offset*2 ), CV_RGB(0, 204, 0), -1, 8, 0);

        if(bottomRightSelected)//bottom right
            rectangle(imgMat, cv::Rect ( bottomRight.x - offset, bottomRight.y - offset, offset*2 , offset*2 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( bottomRight.x - offset, bottomRight.y - offset, offset*2 , offset*2 ), CV_RGB(0, 204, 0), -1, 8, 0);
        
        if (bottomLeftSelected)//bottom left
            rectangle(imgMat, cv::Rect ( bottomLeft.x - offset, bottomLeft.y - offset, offset*2 , offset*2 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( bottomLeft.x - offset, bottomLeft.y - offset, offset*2 , offset*2 ), CV_RGB(0, 204, 0), -1, 8, 0);
        
        if (topMidSelected)//top mid
            rectangle(imgMat, cv::Rect ( topMid.x, topMid.y, offset*4, offset*2 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( ((topLeft.x + topRight.x)/2) - offset*2, topLeft.y - offset, offset*4, offset*2 ), CV_RGB(0, 204, 0), -1, 8, 0);                

        if(bottomMidSelected)//bottom mid
            rectangle(imgMat, cv::Rect ( bottomMid.x, bottomMid.y, offset*4, offset*2 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( ((bottomLeft.x + bottomRight.x)/2) - offset*2, bottomLeft.y - offset, offset*4, offset*2 ), CV_RGB(0, 204, 0), -1, 8, 0);                   


        if (rightMidSelected)//mid right
            rectangle(imgMat, cv::Rect ( midRight.x, midRight.y, offset*2, offset*4 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( (topRight.x - offset), (topRight.y + bottomRight.y)/2 - offset*2, offset*2, offset*4  ), CV_RGB(0, 204, 0), -1, 8, 0);


        if (leftMidSelected) //mid left
            rectangle(imgMat, cv::Rect ( midLeft.x, midLeft.y, offset*2, offset*4 ), CV_RGB(204, 0, 0), -1, 8, 0);
        else
            rectangle(imgMat, cv::Rect ( (topLeft.x - offset), ((topLeft.y + bottomLeft.y)/2 - offset*2), offset*2, offset*4 ), CV_RGB(0, 204, 0), -1, 8, 0);

        return true;
    }

    /********************************************************/
    bool updateModule()
    {
        int k;
        yarp::os::Bottle &target  = blobPort.prepare();
        target.clear();
        yarp::sig::ImageOf<yarp::sig::PixelRgb> &outImage = imageOutPort.prepare();
        
        if (processing->gotNewDetection) 
        {
            yarp::os::Bottle detection = processing->retreiveDetections();

            imgMat = processing->retreiveImage();
            img_out = imgMat.clone();
            cv::cvtColor(img_out, img_out, CV_BGR2RGB);

            detectionSize = detection.get(0).asList()->size();

            yInfo() << "detection size is " << detectionSize;

            std::vector<cv::Point> tl, br;
            cv::Point tl_point;
            cv::Point br_point;

            std::string label;

            tl.clear();
            br.clear();

            detectionRects.clear();
            detectionLabels.clear();

            for (size_t i = 0; i < detectionSize; i++)
            {
                yDebug() << "first loop" << i;
                tl_point.x = detection.get(0).asList()->get(i).asList()->get(0).asInt();
                tl_point.y = detection.get(0).asList()->get(i).asList()->get(1).asInt();
                br_point.x = detection.get(0).asList()->get(i).asList()->get(2).asInt();
                br_point.y = detection.get(0).asList()->get(i).asList()->get(3).asInt();

                label = detection.get(0).asList()->get(i).asList()->get(4).asString();

                yInfo() << "rect x " << tl_point.x ; 
                yInfo() << "rect y " << tl_point.y ; 
                yInfo() << "rect width " <<br_point.x ; 
                yInfo() << "rect height " << br_point.y;
                yInfo() << "rect label " << label.c_str();

                tl.push_back(tl_point);
                br.push_back(br_point);

                yDebug() << "pushing in structure ";
                detectionRects.push_back (cv::Rect(tl[i].x, tl[i].y, br[i].x-tl[i].x, br[i].y-tl[i].y));
                detectionLabels.push_back(label);
            }

             for (size_t i = 0; i < detectionRects.size(); i++)
            {
                yInfo() << "rect x " << detectionRects[i].x ; 
                yInfo() << "rect y " << detectionRects[i].y ; 
                yInfo() << "rect width " << detectionRects[i].width ; 
                yInfo() << "rect height " << detectionRects[i].height;
                yInfo() << "rect label " << detectionLabels[i].c_str();
            }

            updateScene = true; 
        }

        if (updateScene)
        {
            imgMat = img_out.clone();
            
            for (size_t i = 0; i < detectionRects.size(); i++)
            {
                cv::putText(imgMat, detectionLabels[i].c_str(), cv::Point(detectionRects[i].x , detectionRects[i].y -5 ),  cv::FONT_HERSHEY_DUPLEX, 0.5, CV_RGB(0, 0, 204), 1);
                rectangle(imgMat, detectionRects[i], CV_RGB(0, 0, 204), 2, 8, 0);
            }
            
            if (isReadyToSend)
            {
                yarp::os::Bottle &list = target.addList();

                for (size_t i = 0; i < detectionRects.size(); i++)
                {
                    yarp::os::Bottle &elements = list.addList();
                    elements.addInt(detectionRects[i].x);
                    elements.addInt(detectionRects[i].y);
                    elements.addInt(detectionRects[i].x + detectionRects[i].width);
                    elements.addInt(detectionRects[i].y + detectionRects[i].height);

                    elements.addString(detectionLabels[i].c_str());
                }
                isReadyToSend = false;
                blobPort.write();

                outImage.resize(img_out.size().width, img_out.size().height);
                outImage = fromCvMat<yarp::sig::PixelRgb>(img_out);
                imageOutPort.write();

            }
           
            updateScene = false;
            //cv::cvtColor(imgMat, imgMat, CV_BGR2RGB);
        }

        if (detectionIndex > -1)
        {
            drawSelectMarkers(detectionIndex);
        }

        if (!imgMat.empty())
        {  
            cv::imshow("detections", imgMat);
        }
        cv::waitKey(25);

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
