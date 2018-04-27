% addpath('/home/IIT.LOCAL/emaiettini/workspace/Repos/yarp-matlab-bindings/build/install/mex')

% Yarp imports
yarp.matlab.LoadYarp

import yarp.BufferedPortImageRgb
import yarp.BufferedPortBottle
import yarp.Port
import yarp.Bottle
import yarp.Time
import yarp.ImageRgb
import yarp.Image
import yarp.PixelRgb

%Ports definition
portCmd        = yarp.BufferedPortBottle;        % Port for reading commands
portImage      = yarp.BufferedPortImageRgb;      % Buffered Port for reading image
portAnnotation = yarp.BufferedPortBottle;        % Port for receiving annotations
portDets       = yarp.BufferedPortBottle;        % Port for sending detections
portImg        = yarp.Port;                      % Port for propagating images

%first close the port just in case
%(this is to try to prevent matlab from beuing unresponsive)
portCmd.close;
portImage.close;
portAnnotation.close;
portDets.close;
portImg.close;

%open the ports 
disp('opening ports...');

portCmd.open('/detection/command:i');
disp('opened port /detection/command:i');
pause(0.5);
portImage.open('/detection/img:i');
disp('opened port /detection/img:i');
pause(0.5);
portAnnotation.open('/detection/annotations:i');
disp('opened port /detection/detimg:o');
pause(0.5);
portDets.open('/detection/dets:o');
disp('opened port /detection/dets:o');
pause(0.5);
portImg.open('/detection/img:o');
disp('opened port /detection/img:o');
pause(0.5);


% Images options
h=240;
w=320;
pixSize=3;
tool=yarp.matlab.YarpImageHelper(h, w);

disp('yarp initialization done.');
