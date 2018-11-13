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

#include <opencv2/core/core.hpp>
#include <opencv2/opencv.hpp>

#include <cstring>
#include <vector>
#include <iostream>
#include <utility>
#include <dirent.h>

#include <stdio.h>
#include <stdarg.h>

using namespace yarp::math;

/********************************************************/
class Multiview : public yarp::os::BufferedPort<yarp::os::Bottle>
{
    std::string moduleName;
    yarp::os::RpcServer handlerPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >   imageInPort;
    yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> >   imageOutPort;
    
    std::string path;
    std::string newOjectPath;
    std::vector<std::string> files;
    
    std::map<std::string, cv::Rect> imagesInfo;
    std::vector<std::string> imagesNames;
    
    std::map<double, cv::Rect> objectsWithConfidence;
    std::map<double, cv::Rect> objectsInBackgroud;
    
    cv::Mat allImages;
    
    std::string newName;
    bool inTraining;
    bool avoid;
    
    std::map<std::string, cv::Mat> matInfo;
    std::vector<cv::Mat> matList;
    
    cv::Mat originalImage;
    cv::Mat clearImage;
    cv::Mat image_cv;

public:
    /********************************************************/

    Multiview( const std::string &moduleName, const std::string &path)
    {
        this->moduleName = moduleName;
        this->path = path;
    }

    /********************************************************/
    ~Multiview()
    {
    };

    /********************************************************/
    bool open(){

        this->useCallback();

        BufferedPort<yarp::os::Bottle>::open( "/" + moduleName + "/detections:i" );
        imageInPort.open("/" + moduleName + "/image:i");
        imageOutPort.open("/" + moduleName + "/image:o");
      
        yarp::os::Network::connect(imageOutPort.getName().c_str(), "/viewer/objects", "mjpeg");
        //yarp::os::Network::connect(imageOutPort.getName().c_str(), "/viewer/test", "fast_tcp");
        yarp::os::Network::connect( "/depthCamera/rgbImage:o", imageInPort.getName().c_str(), "mjpeg");
        
        //yDebug() << "the path is: " << path.c_str();
        //newOjectPath = "/Users/vtikha/Desktop/GTC/new/imagesOjects";

        inTraining = false;
        avoid = false;
        
        //std::vector<cv::Mat> matList;
        //matList = getAllImages(path);
        
        matList.clear();
        matInfo.clear();
        
        yarp::sig::ImageOf<yarp::sig::PixelRgb> *inImage = imageInPort.read();
        cv::Mat image = cv::cvarrToMat((IplImage *)inImage->getIplImage());
        cv::Mat tmpBlack(image.size(), CV_8UC3, cv::Scalar(0, 0, 0));
        allImages = tmpBlack.clone();
        image_cv = tmpBlack.clone();
        
        imagesInfo.clear();
        
        //allImages = gatherImages(matList);
        
        yarp::os::Network::connect("/detection/dets:o", BufferedPort<yarp::os::Bottle>::getName().c_str(), "tcp");
        yarp::os::Network::connect("/dets", BufferedPort<yarp::os::Bottle>::getName().c_str(), "tcp");
        
        //allImages.convertTo(allImages, CV_8U, 0.5);
        //imwrite( "test.png", allImages );
        return true;
    }
    
    /********************************************************/
    std::vector<cv::Mat> getAllImages(std::string &path)
    {
        files.clear();
        imagesNames.clear();
        
        files = GetDirectoryFiles(path);
        std::vector<std::string> nameList;
        for ( auto i = files.begin(); i != files.end(); i++ )
        {
            yDebug() << *i;
            std::string tmp = *i;
            std::string::size_type idx=0;
            if (std::isalnum(tmp[idx]))
            {
                yDebug() << "isAlpha";
                std::string cleanstr = tmp.substr(0, tmp.size()-4);
                imagesNames.push_back(cleanstr);
                nameList.push_back(tmp);
            }
        }
        
        std::vector<cv::Mat> matList;
        
        yDebug() << "The size of objects collected is:" << nameList.size();
        
        for (int i = 0; i<nameList.size(); i++)
        {
            yInfo() << nameList[i].c_str();
            cv::Mat image;
            std::string imageFile = path + "/" + nameList[i];
            yDebug() << "File " << imageFile.c_str();
            image = cv::imread(imageFile, CV_LOAD_IMAGE_COLOR);
            resize(image, image, cv::Size(100, 120), 0, 0, cv::INTER_CUBIC);
            
            if(! image.data )                              // Check for invalid input
            {
                yError() << "Cannot load file " << imageFile;
            }
            
            matList.push_back(image);
        }
        return matList;
    }
    
    /********************************************************/
    void close()
    {
        BufferedPort<yarp::os::Bottle>::close();
        imageInPort.close();
        imageOutPort.close();
    }

    /********************************************************/
    void interrupt()
    {
        BufferedPort<yarp::os::Bottle >::interrupt();
        imageOutPort.interrupt();
        imageOutPort.interrupt();
    }
    
    /********************************************************/
    void configureImages()
    {
        resize(image_cv, image_cv, allImages.size(), 0, 0, cv::INTER_CUBIC);
        
        originalImage = allImages.clone();
        clearImage = allImages.clone();
        
    }

    /********************************************************/
    void onRead( yarp::os::Bottle &bottle_yarp )
    {
        //yDebug() << "*************************";
        
        yarp::sig::ImageOf<yarp::sig::PixelRgb> &outImage  = imageOutPort.prepare();
        //yDebug() << "the size of the bottle is " << bottle_yarp.size();
        
        //yDebug() << bottle_yarp.toString();
       
        originalImage = allImages.clone();
        clearImage = allImages.clone();
        
        bool contrastDone = false;
        
        objectsWithConfidence.clear();
       
        for (size_t j=0; j<bottle_yarp.size(); j++)
        {
            if (!contrastDone)
                originalImage.convertTo(originalImage, CV_8U, 0.3);
            
            if (bottle_yarp.get(0).isList())
            {
                yarp::os::Bottle *item=bottle_yarp.get(j).asList();
            
                if (item->get(0).asString().compare("train") == 0)
                {
                    yarp::sig::ImageOf<yarp::sig::PixelRgb> *inImage = imageInPort.read();
                    
                    newName = item->get(5).asString();
                    
                    if (!avoid)
                    {
                        imagesNames.push_back(newName);
                        
                        /*cv::Mat image;
                        std::string imageFile = newOjectPath + "/" + newName + ".png";
                        yDebug() << "File " << imageFile.c_str();
                        image = cv::imread(imageFile, CV_LOAD_IMAGE_COLOR);
                        resize(image, image, cv::Size(100, 120), 0, 0, cv::INTER_CUBIC);
                        
                        std::string saveAsName = path + "/" + newName + ".png";
                        imwrite( saveAsName, image );
                        
                        std::vector<cv::Mat> matList;
                        matList = getAllImages(path);
                        allImages = gatherImages(matList);
                         */
                        
                        cv::Mat image = cv::cvarrToMat((IplImage *)inImage->getIplImage());
                        
                        cv::Point tl, br;
                        tl.x = item->get(1).asDouble();
                        tl.y = item->get(2).asDouble();
                        
                        br.x = item->get(3).asDouble();
                        br.y = item->get(4).asDouble();
                        
                        cv::Rect myROI(tl.x, tl.y, br.x-tl.x, br.y-tl.y);
                        
                        cv::Mat croppedImage = image(myROI);
                        
                        resize(croppedImage, croppedImage, cv::Size(100, 120), 0, 0, cv::INTER_CUBIC);
                        
                        matInfo.insert(std::make_pair(newName, croppedImage));
                        
                        /*std::map<std::string, cv::Mat>::iterator it;
                        
                        it = matInfo.find(newName);
                        
                        matList.clear();
                        
                        if(it != matInfo.end())
                        {
                            matList.push_back(it->second);
                        }*/
                        
                        std::map<std::string, cv::Mat>::iterator it = matInfo.begin();
                        while(it != matInfo.end())
                        {
                            if (it->first.compare(newName) == 0)
                            {
                                matList.push_back(it->second);
                            }
                            it++;
                        }
                        
                        allImages = gatherImages(matList);
                        cv::cvtColor( allImages, allImages, CV_BGR2RGB );
                        
                        avoid = true;
                    }
                    
                    configureImages();
                    
                    std::map<std::string, cv::Rect>::iterator it = imagesInfo.begin();
                    
                    cv::Rect ROI;
                    
                    cv::Mat cropped_image;
                    while(it != imagesInfo.end())
                    {
                        if (it->first.compare(newName) == 0)
                        {
                            ROI = it->second;
                            cropped_image = clearImage(ROI);
                            cropped_image.convertTo(cropped_image, CV_8U, 0.8);
                            cropped_image.copyTo(originalImage(ROI));
                            rectangle( originalImage, ROI.tl(), ROI.br(), cv::Scalar(0, 0, 255), 2, 8, 0 );
                        }
                        it++;
                    }
                    
                    image_cv = originalImage.clone();
                    cv::cvtColor( image_cv, image_cv, CV_BGR2RGB );
                }
                else if (item->get(0).asString().compare("done.") == 0  && avoid)
                {
                    avoid = false;
                    image_cv = originalImage.clone();
                    cv::cvtColor( image_cv, image_cv, CV_BGR2RGB );
                }
                else if (!avoid && item->size()>0 && item->get(0).asString().compare("train") != 0 && item->get(0).asString().compare("done.") != 0)
                {
                    yDebug() << item->toString().c_str();
                    yarp::os::Bottle *elements = item->get(6).asList();
                    yDebug() << "size is" << elements->size() << elements->toString().c_str();
                    
                    if (elements->size() != matInfo.size())
                    {
                        yError() << "GOT A MIS-ALIGNMENT OF OBJECTS";
                        
                        yError() << " matInfo size " << matInfo.size();
                        std::string value;
                        
                        std::set<std::string> stringList;
                        for (size_t i=0; i<elements->size(); i++)
                            stringList.insert(elements->get(i).asString());
                        
                        std::map<std::string, cv::Mat>::iterator iter = matInfo.begin();
                        
                        while(iter != matInfo.end())
                        {
                            if (stringList.find(iter->first) == stringList.end())
                            {
                                yError() << "Did not find" << iter->first;
                                value = iter->first;
                                matInfo.erase(iter);
                                break;
                            }
                            
                            iter++;
                        }
                        
                        yDebug() << __LINE__;
                        yError() << " matInfo size " << matInfo.size();
                        matList.clear();
                        imagesNames.clear();
                        std::map<std::string, cv::Mat>::iterator subInt = matInfo.begin();
                        
                        while(subInt != matInfo.end())
                        {
                            imagesNames.push_back(subInt->first);
                            matList.push_back(subInt->second);
                            yError() << "Inserting objects find" << subInt->first;
                            subInt++;
                        }
                        
                        yDebug() << __LINE__;
                        allImages = gatherImages(matList);
                        yDebug() << __LINE__;
                        cv::cvtColor( allImages, allImages, CV_BGR2RGB );
                        yDebug() << __LINE__;
                    }
                    yDebug() << __LINE__;
                    
                    std::string objectOfInterest = item->get(5).asString();
                    double confidence = item->get(4).asDouble();
                    yDebug() << "object of interest is" << objectOfInterest << "with confidence" << confidence;
                    
                    std::map<std::string, cv::Rect>::iterator it = imagesInfo.begin();
                    
                    cv::Rect ROI;
                    cv::Mat cropped_image;
                    while(it != imagesInfo.end())
                    {
                        if (it->first.compare(objectOfInterest) == 0)
                        {
                            ROI = it->second;
                            
                            objectsWithConfidence.insert(std::make_pair(confidence, ROI));
                        }
                        it++;
                    }
                }
            }
            contrastDone = true;
        }
        
        std::map<double, cv::Rect>::iterator it = objectsWithConfidence.begin();
        
        while(it != objectsWithConfidence.end())
        {
            cv::Rect ROI = it->second;
            //double conf = it->first;
            cv::Mat cropped_image;
            cropped_image = clearImage(ROI);
            //cropped_image.convertTo(cropped_image, CV_8U, conf);
            cropped_image.convertTo(cropped_image, CV_8U, 0.8);
            cropped_image.copyTo(originalImage(ROI));
            rectangle( originalImage, ROI.tl(), ROI.br(), cv::Scalar(0, 255, 0), 2, 8, 0 );
            it++;
        }
        
        image_cv = originalImage.clone();
        cv::cvtColor( image_cv, image_cv, CV_BGR2RGB );
        
        IplImage yarpImg = image_cv;
        outImage.resize(yarpImg.width, yarpImg.height);
        cvCopy( &yarpImg, (IplImage *)outImage.getIplImage());
        imageOutPort.write();
    }
    
    /********************************************************/
    cv::Mat gatherImages(std::vector<cv::Mat> &matList)
    {
        imagesInfo.clear();
        
        int size;
        int i;
        int m, n;
        int x, y;
        
        // w - Maximum number of images in a row
        // h - Maximum number of images in a column
        int w, h;
        
        // scale - How much we have to resize the image
        float scale;
        int max;
        
        // If the number of arguments is lesser than 0 or greater than 12
        // return without displaying
        if(matList.size() <= 0) {
            yError() << "Number of image too small....\n";
        }
        else if(matList.size() > 14) {
            yError() << "Number of images too large, can only handle maximally 12 images at a time ...";
        }
        
        // Determine the size of the image,
        // and the number of rows/cols
        // from number of arguments
        else if (matList.size() == 1) {
            w = h = 1;
            size = 300;
        }
        else if (matList.size() == 2) {
            w = 2; h = 1;
            size = 300;
        }
        else if (matList.size() == 3 || matList.size() == 4) {
            w = 2; h = 2;
            size = 300;
        }
        else if (matList.size() == 5 || matList.size() == 6) {
            w = 3; h = 2;
            size = 200;
        }
        else if (matList.size() == 7 || matList.size() == 8) {
            w = 4; h = 2;
            size = 200;
        }
        else {
            w = 4; h = 3;
            size = 150;
        }
        
        // Create a new 3 channel image
        cv::Mat DispImage = cv::Mat::zeros(cv::Size(100 + size*w, 60 + size*h), CV_8UC3);
        
        // Loop for nArgs number of arguments
        for (i = 0, m = 20, n = 20; i < matList.size(); i++, m += (20 + size))
        {
            cv::Mat img = matList[i].clone();
            
            if(img.empty()) {
                yError() << "Invalid arguments";
            }
            
            // Find the width and height of the image
            x = img.cols;
            y = img.rows;
            
            // Find whether height or width is greater in order to resize the image
            max = (x > y)? x: y;
            
            // Find the scaling factor to resize the image
            scale = (float) ( (float) max / size );
            
            // Used to Align the images
            if( i % w == 0 && m!= 20) {
                m = 20;
                n+= 20 + size;
            }
            
            // Set the image ROI to display the current image
            // Resize the input image and copy the it to the Single Big Image
            cv::Rect ROI(m, n, (int)( x/scale ), (int)( y/scale ));
            cv::Mat temp; resize(img,temp, cv::Size(ROI.width, ROI.height));
            
            imagesInfo.insert(std::make_pair(imagesNames[i].c_str(), ROI));
            
            temp.copyTo(DispImage(ROI));
        }
        return DispImage;
    }
    
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
    
};

/********************************************************/
class Module : public yarp::os::RFModule
{
    yarp::os::ResourceFinder    *rf;
    yarp::os::RpcServer         rpcPort;

    Multiview                  *multiview;
    friend class                processing;

    bool                        closing;

public:

    /********************************************************/
    bool configure(yarp::os::ResourceFinder &rf)
    {
        this->rf=&rf;
        std::string moduleName = rf.check("name", yarp::os::Value("yarp-multi-viewer"), "module name (string)").asString();
        setName(moduleName.c_str());
        std::string path = rf.check("path", yarp::os::Value(""), "path name (string)").asString();

        rpcPort.open(("/"+getName("/rpc")).c_str());

        closing = false;

        multiview = new Multiview( moduleName, path );
        /* now start the thread to do the work */
        multiview->open();

        attach(rpcPort);

        return true;
    }

    /**********************************************************/
    bool close()
    {
        multiview->interrupt();
        multiview->close();
        delete multiview;
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
    rf.setDefaultConfigFile( "config.ini" );
    rf.setDefaultContext("yarp-multi-viewer");
    rf.configure(argc,argv);

    return module.runModule(rf);
}
