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

port           = yarp.BufferedPortBottle;        %port for reading "quit" signal
portImage      = yarp.BufferedPortImageRgb;      %Buffered Port for reading image
portAnnotation = yarp.Port;        %port for receiving annotations

%first close the port just in case
%(this is to try to prevent matlab from beuing unresponsive)
port.close;
portImage.close;
portAnnotation.close;

%open the ports 
disp('opening ports...');
port.open('/detection/command:i');
disp('opened port /detection/command:i');
pause(0.5);
portImage.open('/detection/img:i');
disp('opened port /detection/img:i');
pause(0.5);
portAnnotation.open('/detection/annotations:i');
disp('opened port /detection/detimg:o');
pause(0.5);

