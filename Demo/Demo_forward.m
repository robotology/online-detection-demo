function [  ] = Demo_forward()
%DEMO_FORWARD Summary of this function goes here
%   Detailed explanation goes here

%% -------------------- CONFIG --------------------
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

%% -------------------- DATASET --------------------

image_ids = textread([dataset_path, 'ImageSets/', image_set, '.txt']);

%% -------------------- START PREDICTION --------------------

for j = 1:length(image_ids)
    
    %% Fetch image
    fetch_tic = tic;
    
    im = imread(fullfile(dataset_path, 'Images', image_ids{j}));    
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
    f = figure(j);
    showboxes(im, boxes_cell, classes, 'voc'); %TO-STUDY what it does
    fprintf('Visualization required %f seconds', toc(vis_tic));
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
