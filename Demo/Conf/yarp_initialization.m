addpath('/home/IIT.LOCAL/emaiettini/workspace/Repos/yarp-matlab-bindings/build/install/mex')

% Yarp imports
import yarp.BufferedPortImageRgb
import yarp.BufferedPortBottle
import yarp.Port
import yarp.Bottle
import yarp.Time
import yarp.ImageRgb
import yarp.Image
import yarp.PixelRgb

port=yarp.BufferedPortBottle;        %port for reading "quit" signal
portImage=yarp.BufferedPortImageRgb; %Buffered Port for reading image
portFilters=yarp.Port;               %port for sending detected image
portDets=yarp.Port;                  %port for sending detections


%first close the port just in case
%(this is to try to prevent matlab from beuing unresponsive)
port.close;
portImage.close;
portFilters.close;
portDets.close;

%open the ports 
disp('opening ports...');
port.open('/detection/command:i');
disp('opened port /detection/command:i');
pause(0.5);
portImage.open('/detection/img:i');
disp('opened port /detection/img:i');
pause(0.5);
portFilters.open('/detection/img:o');
disp('opened port /detection/img:o');
pause(0.5);
portDets.open('/detection/dets:o');
disp('opened port /detection/dets:o');
pause(0.5);
disp('yarp initialization done.');

