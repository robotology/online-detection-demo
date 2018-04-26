function [] = Image_sender()
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

imageSender=yarp.Port;                       % port for sending detected image
annotationSender=yarp.BufferedPortBottle;    % port for sending detections

% first close the port just in case
% (this is to try to prevent matlab from being unresponsive)

imageSender.close();
annotationSender.close();

% open the ports 
imageSender.open('/DataSender:imagess:o');
disp('opened port /images:o');
pause(0.5);

annotationSender.open('/DataSender:annotations:o');
disp('opened port /annotations:o');
pause(0.5);

load('/home/IIT.LOCAL/emaiettini/workspace/Repos/Incremental_Faster_RCNN/Demo/Helper_function/annotations_train_TASK2_10objs.mat')

%% -------------------- DATASET --------------------
current_path = pwd;
dataset_path = [current_path '/datasets/iCubWorld-Transformations/'];
image_set = 'train_TASK2_10objs';

image_ids = importdata([dataset_path, 'ImageSets/', image_set, '.txt']);

%% -------------------- START PREDICTION --------------------
h=480;
w=640;
pixSize = 3;
tool=yarp.matlab.YarpImageHelper(h, w);
for j = 1:length(image_ids)
    
    %% Fetch image
    fetch_tic = tic;
    
    image = imread([dataset_path '/Images/' image_ids{j} '.jpg']);    
    
    fprintf('Fetching image required %f seconds\n', toc(fetch_tic));
    
    %% Preapre image to send

    send_tic = tic;
    yarp_img = yarp.ImageRgb();                               % create a new yarp image to send results to ports
    yarp_img.resize(w,h);                                     % resize it to the desired size
    yarp_img.zero();                                          % set all pixels to black
    image = reshape(image, [h*w*pixSize 1]);                  % reshape the matlab image to 1D
    tempImg = cast(image ,'int16');                           % cast it to int16
    yarp_img = tool.setRawImg(tempImg, h, w, pixSize);        % pass it to the setRawImg function (returns the full image)

    %% Prepare annotations to send
    b = annotationSender.prepare();
    b.clear();
    % Prepare list
    ann_list = b.addList();
    % Add bounding box coordinates, score and string label of detected the object
    ann_list.addDouble(annotations{j}.bbox(1));       % x_min
    ann_list.addDouble(annotations{j}.bbox(2));       % y_min
    ann_list.addDouble(annotations{j}.bbox(3));       % x_max
    ann_list.addDouble(annotations{j}.bbox(4));       % y_max
    ann_list.addString(annotations{j}.label);         % string label
    
    %% Set timestamp for the two ports
    stamp = yarp.Stamp();
    stamp.update(j);
    annotationSender.setEnvelope(stamp);
    imageSender.setEnvelope(stamp);
    
    %% Send image and annotation
    imageSender.write(yarp_img);                             
    annotationSender.write();   
    
    fprintf('Sending image annotation required %f seconds\n\n', toc(send_tic));
    pause(0.25);
end


end

