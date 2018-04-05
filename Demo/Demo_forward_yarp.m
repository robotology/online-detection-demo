function [  ] = Demo_forward_yarp()
%DEMO_FORWARD Summary of this function goes here
%   Detailed explanation goes here

%% -------------------- CONFIG --------------------
yarp_initialization;

configuration_script;

active_caffe_mex(cnn_model.opts.gpu_id, cnn_model.opts.caffe_version);

%% -------------------- INIT_MODEL --------------------

% classifier
cls_model = load(cls_model_path);  %------------------------------------------------------------------- %TO-CHECK

% bbox regressor
bbox_model = load(bbox_model_path); %-------------------------------------------------------------------%TO-CHECK

% cnn model
cnn_model.proposal_detection_model    = load_proposal_detection_model(cnn_model_path);
cnn_model.proposal_detection_model.conf_proposal.test_scales = cnn_model.opts.test_scales;
cnn_model.proposal_detection_model.conf_detection.test_scales = cnn_model.opts.test_scales;
if opts.use_gpu
    cnn_model.proposal_detection_model.conf_proposal.image_means = gpuArray(cnn_model.proposal_detection_model.conf_proposal.image_means);
   cnn_model.proposal_detection_model.conf_detection.image_means = gpuArray(cnn_model.proposal_detection_model.conf_detection.image_means);
end

% proposal net
cnn_model.rpn_net = caffe.Net(cnn_model.proposal_detection_model.proposal_net_def, 'test');
cnn_model.rpn_net.copy_from(cnn_model.proposal_detection_model.proposal_net);
% fast rcnn net
cnn_model.fast_rcnn_net = caffe.Net(cnn_model.proposal_detection_model.detection_net_def, 'test');
cnn_model.fast_rcnn_net.copy_from(cnn_model.proposal_detection_model.detection_net);

% set gpu/cpu
if cnn_model.opts.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end   

%% -------------------- START PREDICTION --------------------

while (true)
    
    %% Fetch image
    fetch_tic = tic;
    
    yarpImage=portImage.read(false);%get the yarp image from port
    if (sum(size(yarpImage)) ~= 0) %check size of bottle 
         h=yarpImage.height;
         w=yarpImage.width;
         pixSize=yarpImage.getPixelSize();
         tool=yarp.YarpImageHelper(h, w);
         IN = tool.getRawImg(yarpImage); %use leo pape image patch
         TEST = reshape(IN, [h w pixSize]); %need to reshape the matrix from 1D to h w pixelSize 
       
         im=uint8(zeros(h, w, pixSize)); %create an empty image with the correct dimentions
         r = cast(TEST(:,:,1),'uint8');  % need to cast the image from int16 to uint8
         g = cast(TEST(:,:,2),'uint8');
         b = cast(TEST(:,:,3),'uint8');
         im(:,:,1)= r; % copy the image to the previoulsy create matrix
         im(:,:,2)= g;
         im(:,:,3)= b;         
         im_gpu = gpuArray(im);

         fprintf('fetching images required %f seconds', toc(fetch_tic));

         %% Performing detection
         prediction_tic = tic;

         [cls_scores boxes] = Detect(im_gpu, classes, cnn_model, cls_model, bbox_model, detect_thresh);
         fprintf('Prediction required %f seconds', toc(prediction_tic));

         %% Detections visualization
         vis_tic = tic;
         boxes_cell = cell(length(classes), 1);
         for i = 1:length(boxes_cell)
             boxes_cell{i} = [boxes(:, (1+(i-1)*4):(i*4)), cls_scores(:, i)];
         end
         f = figure();
         showboxes(im, boxes_cell, classes, 'voc'); %TO-STUDY what it does
         fprintf('Visualization required %f seconds', toc(vis_tic));


         %% Sending detections
         send_tic = tic;
         sendDetectedImage(im, portFilters, tool);
         sendDetections(boxes_cell);
         fprintf('Sending image and detections required %f seconds', toc(send_tic));
    end
end

end

function proposal_detection_model = load_proposal_detection_model(model_dir)
    ld                          = load(fullfile(model_dir, 'model'));
    proposal_detection_model    = ld.proposal_detection_model;
    clear ld;
    
    proposal_detection_model.proposal_net_def ...
                                = fullfile(model_dir, proposal_detection_model.proposal_net_def);
    proposal_detection_model.proposal_net ...
                                = fullfile(model_dir, proposal_detection_model.proposal_net);
    proposal_detection_model.detection_net_def ...
                                = fullfile(model_dir, proposal_detection_model.detection_net_def);
    proposal_detection_model.detection_net ...
                                = fullfile(model_dir, proposal_detection_model.detection_net);
    
end
function ImSent = sendDetectedImage(image, port, tool)
     ImSent=false;
     yarp_img = yarp.ImageRgb();                        % create a new yarp image to send results to ports
     yarp_img.resize(w,h);                              % resize it to the desired size
     yarp_img.zero();                                   % set all pixels to black
     image = reshape(image, [h*w*pixSize 1]);           % reshape the matlab image to 1D
     tempImg = cast(image ,'int16');                    % cast it to int16
     yarp_img = tool.setRawImg(tempImg, h, w, pixSize); % pass it to the setRawImg function (returns the full image)
     port.write(yarp_img);                              % send it off % TO-CHECK return value
end

function DetsSent = sendDetections(detections, port)
    DetsSent=false;
    
    b = yarp.Bottle();
    for i = 1:length(detections)
        % append detections element to b
    end
    port.write(b); % TO-CHECK return value
end

function closePorts(portImage,port,portFilters)

    disp('Going to close the port');
    portImage.close;
    port.close;
    portFilters.close;
    portDets.close;
    
end