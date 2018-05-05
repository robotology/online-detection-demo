%  --------------------------------------------------------
%  Online-Object-Detection Demo
%  Author: Elisa Maiettini
%  --------------------------------------------------------

function [  ] = Detection_main(  )

yarp_initialization;

configuration_script;

active_caffe_mex(cnn_model.opts.gpu_id, cnn_model.opts.caffe_version);

% cnn model
disp('Loading cnn model paths...');
cnn_model.proposal_detection_model                            = load_proposal_detection_model(cnn_model_path);
cnn_model.proposal_detection_model.conf_proposal.test_scales  = cnn_model.opts.test_scales;
cnn_model.proposal_detection_model.conf_detection.test_scales = cnn_model.opts.test_scales;

% proposal net
disp('Setting RPN...');
cnn_model.rpn_net = caffe.Net(cnn_model.proposal_detection_model.proposal_net_def, 'test');
cnn_model.rpn_net.copy_from(cnn_model.proposal_detection_model.proposal_net);
% fast rcnn net
disp('Setting Fast R-CNN...');
cnn_model.fast_rcnn_net = caffe.Net(cnn_model.proposal_detection_model.detection_net_def, 'test');
cnn_model.fast_rcnn_net.copy_from(cnn_model.proposal_detection_model.detection_net);

% set gpu/cpu
if cnn_model.opts.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end   

%% -------------------- START DETECTION MODULE--------------------
state = 'init';

while ~strcmp(state,'quit')
    
    disp('asking for command');
    cmd_bottle = yarp.Bottle();
    cmd_bottle = portCmd.read(false);
    
    %% Switching state according to command read from port
    if ~isempty(cmd_bottle)
       command = cmd_bottle.get(0).asString().toCharArray';
       switch command
           case{'quit'}
               disp('switching to state Quit...');
               state = 'quit';
               
           case{'train'}
               train_tic = tic;
               acquisition_tic = tic;
               disp('switching to state Train...');
               state = 'train'; 
               
               disp('Initializing train variables...');
               new_label = cmd_bottle.get(1).asString().toCharArray';
               new_to_add = isempty(find(strcmp(dataset.classes,new_label)));
               if new_to_add
                   new_cls_idx                                = length(dataset.bbox_regressor) + 1;
                   dataset.classes{length(dataset.classes)+1} = new_label;
                   max_img_per_class                          = max_img_for_new_class;
                   
                   total_negatives = negatives_selection.batch_size*negatives_selection.iterations;
                  
               else
                   new_cls_idx                                               = find(strcmp(dataset.classes,new_label));
                   max_img_per_class                                         = max_img_for_new_class;
                   total_negatives                                           = negatives_selection.batch_size*negatives_selection.iterations;

                   dataset.bbox_regressor{new_cls_idx}.pos_bbox_regressor    = [];
                   dataset.bbox_regressor{new_cls_idx}.y_bbox_regressor      = []; 

                   dataset.reg_classifier{new_cls_idx}.pos_region_classifier = [];
                   dataset.reg_classifier{new_cls_idx}.neg_region_classifier = [];
                   
               end
               
               if total_negatives > max_img_per_class
                   negatives_selection.neg_per_image = round(total_negatives/max_img_per_class);
               else
                   negatives_selection.neg_per_image = 1;
               end
               
               cnn_model.opts.after_nms_topN = after_nms_topN_train;
                          
               % Region classifier variables
               curr_negative_number          = 0;
               train_images_counter          = 0;

               pos_region_classifier         = struct;
               pos_region_classifier.box     = [];
               pos_region_classifier.feat    = [];

               neg_region_classifier         = struct;
               neg_region_classifier.box     = [];
               neg_region_classifier.feat    = [];

               % Bbox refinement variables
               pos_bbox_regressor            = struct;
               pos_bbox_regressor.box        = [];
               pos_bbox_regressor.feat       = [];

               y_bbox_regressor              = [];               
               
           case{'test'}
               disp('switching to state Test...');
               state = 'test';
               cnn_model.opts.after_nms_topN = after_nms_topN_test;
               
           case{'forget'}
               if ~isempty(dataset.classes)
                   % Find class to remove
                   remove_label = cmd_bottle.get(1).asString().toCharArray';
                   if strcmp(remove_label, 'all')
                       disp('Switching to state Forget...');
                       state = 'forget';
                       
                       disp('Forgetting all classes...');
                       dataset.bbox_regressor = cell(0);
                       dataset.reg_classifier = cell(0);
                       dataset.classes        = cell(0);

                       disp('Done.')
                   else
                       % Selecting and removing requested class
                       idx_to_remove = find(strcmp(dataset.classes,remove_label));
                       if idx_to_remove > 0
                           disp('Switching to state Forget...');
                           state = 'forget';
                           
                           dataset.bbox_regressor(idx_to_remove) = [];
                           dataset.reg_classifier(idx_to_remove) = [];
                           dataset.classes(idx_to_remove)        = [];
                       else
                           disp('Could not find class to forget. Going back to Test state...');
                           state = 'test';
                           cnn_model.opts.after_nms_topN = after_nms_topN_test;
                       end
                   end
               else
                   disp('Dataset is empty. Could not forget requested class.');
               end
               
           case{'load'}
               if strcmp(cmd_bottle.get(1).asString().toCharArray', 'dataset')
                   disp('switching to state Load_dataset...');
                   state = 'load_dataset';
                   load_dataset_name = cmd_bottle.get(2).asString().toCharArray';
               else
                   disp('Loading old model not implemented.')
                   disp('Switching to state Test...');
                   state = 'test';
                   cnn_model.opts.after_nms_topN = after_nms_topN_test;
               end           
               
           case{'save'}
               if strcmp(cmd_bottle.get(1).asString().toCharArray', 'dataset')
                   disp('Switching to state Save_dataset...');
                   state = 'save_dataset';
                   save_dataset_name = cmd_bottle.get(2).asString().toCharArray';
               elseif strcmp(cmd_bottle.get(1).asString().toCharArray', 'model')
                   disp('Switching to state Save_model...');
                   state = 'save_model';
                   save_model_name = cmd_bottle.get(2).asString().toCharArray';
               else
                   disp('Unrecognized save command. Switching to state Test...');
                   state = 'test';
                   cnn_model.opts.after_nms_topN = after_nms_topN_test;
               end
           case{'list'}
               if strcmp(cmd_bottle.get(1).asString().toCharArray', 'classes')
                   disp('Switching to state list_classes...');
                   state = 'list_classes';
               else
                   disp('Unrecognized list command. Switching to state Test...');
                   state = 'test';
                   cnn_model.opts.after_nms_topN = after_nms_topN_test;
               end
             
           otherwise
              fprintf('Command unknown\n'); 
       end     
    end

    %% State machine
    switch state
       case{'quit'}
           if ~exist([current_path '/Demo/Datasets/' default_dataset_name] , 'file')
               disp('Saving dataset...');
               save([current_path '/Demo/Datasets/' default_dataset_name], 'dataset');
           end
           
           if ~exist([current_path '/Demo/Models/' default_model_name] , 'file')
               disp('Saving model...');      
               model = struct;
               model.region_classifier = region_classifier;
               model.bbox_regressor = bbox_regressor;
               save([current_path '/Demo/Models/' default_model_name], 'model');
           end

           disp('Shutting down...');
           
       case{'init'}
           %% -----------------------------------------INITIALIZATION ------------------------------------------------
            disp('----------------------INITIALIZATION----------------------');            
            disp('Creating empty dataset and model...')
            dataset = struct;
            dataset.bbox_regressor = cell(0);
            dataset.reg_classifier = cell(0);
            dataset.classes        = cell(0);

            region_classifier      = [];
            bbox_regressor         = [];
            disp('Done.')
            disp('If you want to load an old dataset, please type: load dataset *datasetname*.')
        
            disp('Switching to state Test...');
            state = 'test';
            cnn_model.opts.after_nms_topN = after_nms_topN_test;
            
       case{'train'} 
           %% -------------------------------------------- TRAIN -------------------------------------------------------
           disp('----------------------TRAIN----------------------');
           disp('Waiting image and annotations from ports...');
           
           annotations_bottle = portAnnotation.read(true);
           yarpImage   = portImage.read(true);  
           
           if (annotations_bottle.size() ~= 0 && sum(size(yarpImage)) ~= 0)
                 fprintf('Processing image: %d/%d', train_images_counter, max_img_per_class);
%                annotations = annotations_bottle.pop();
%                if (annotations.asList().get(0).isString() && strcmp(annotations.asList().get(0).asString(), 'hand'))
                                
                   % Gathering mat image and gpuarray
                   TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
                   im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
                   im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
                   im(:,:,2)= cast(TEST(:,:,2),'uint8');
                   im(:,:,3)= cast(TEST(:,:,3),'uint8');         
                   % im_gpu = gpuArray(im);

                   % Gathering GT box and label 
                   for j = 1:length(annotations_bottle)
                       ann = annotations_bottle.pop();
                       gt_boxes = [ann.asList().get(0).asDouble(), ann.asList().get(1).asDouble(), ...
                                   ann.asList().get(2).asDouble(), ann.asList().get(3).asDouble()];  % bbox format: [tl_x, tl_y, br_x, br_y]
                   end
                   forwardAnnotations(yarpImage, gt_boxes, new_label, portImg, portDets);
                    % Extract regions from image and filtering
                    [boxes, scores]                 = proposal_im_detect(cnn_model.proposal_detection_model.conf_proposal, cnn_model.rpn_net, im);
                    aboxes                          = boxes_filter([boxes, scores], cnn_model.opts.per_nms_topN, cnn_model.opts.nms_overlap_thres, ...
                                                                    cnn_model.opts.after_nms_topN, cnn_model.opts.use_gpu);

                    % Select positive regions
%                     selection_tic = tic;
                    overlaps = boxoverlap(aboxes, gt_boxes); 

                    % Positive regions for bounding box regressor
                    [cur_bbox_pos, cur_bbox_y]      = select_positives_for_bbox(aboxes(:,1:4), gt_boxes, overlaps, bbox_opts.min_overlap); 
                    pos_bbox_regressor.box          = cat(1, pos_bbox_regressor.box, cur_bbox_pos);
                    y_bbox_regressor                = cat(1,y_bbox_regressor,cur_bbox_y);          

                    % Positive regions for region classifier
                    pos_region_classifier.box       = cat(1, pos_region_classifier.box, gt_boxes);

                    % Select negative regions for region classifier
                    if curr_negative_number < total_negatives
                        curr_cls_neg                = select_negatives_for_cls(aboxes(:,1:4), overlaps, negatives_selection); 
                        neg_region_classifier.box   = cat(1, neg_region_classifier.box, curr_cls_neg);
                        curr_negative_number        = curr_negative_number + size(curr_cls_neg,1);
                    else
                        curr_cls_neg = [];
                        neg_region_classifier.box = [];
                    end
%                     fprintf('--Positives and negatives selection required %f seconds\n', toc(selection_tic));

                    % Extract features from regions 
%                     feature_tic = tic;
                    % -- Select regions to extract features from
                    regions_for_features           = cat(1, cur_bbox_pos, curr_cls_neg); % cur_bbox_pos contains gt_box too so no need to repeat it  

                    % -- Network forward
                    
%                   features             = cnn_features_shared_conv(cnn_model.proposal_detection_model.conf_detection, im_gpu, aboxes(:, 1:4), cnn_model.fast_rcnn_net, [], 'fc7', ...
%                                                               cnn_model.rpn_net.blobs(cnn_model.proposal_detection_model.last_shared_output_blob_name),  cnn_model.opts.after_nms_topN);
                    features             = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), ...
                                                                   cnn_model.fast_rcnn_net, [], 'fc7');         
%                     features                       = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), ...
%                                                                cnn_model.fast_rcnn_net, [], 'fc7'); 
%                     fprintf('--Feature extraction required %f seconds\n', toc(feature_tic));

                    % Update total features datasets
                    pos_bbox_regressor.feat        = cat(1, pos_bbox_regressor.feat, features(1:size(cur_bbox_pos,1),:));
                    pos_region_classifier.feat     = cat(1, pos_region_classifier.feat, features(1,:));
                    neg_region_classifier.feat     = cat(1, neg_region_classifier.feat, features(size(cur_bbox_pos,1)+1:(size(cur_bbox_pos,1)+size(curr_cls_neg,1)),:));

                    train_images_counter = train_images_counter +1;
%                end
           end         

           if train_images_counter >= max_img_per_class

                fprintf('Sufficient dataset acquired in %d seconds.\nTraining...\n',toc(acquisition_tic));
                sendTrainDone(portDets);
                
                % Update dataset with data from new class
                dataset.bbox_regressor{new_cls_idx}                       = struct;
                dataset.bbox_regressor{new_cls_idx}.pos_bbox_regressor    = pos_bbox_regressor;
                dataset.bbox_regressor{new_cls_idx}.y_bbox_regressor      = y_bbox_regressor; 

                dataset.reg_classifier{new_cls_idx}                       = struct;
                dataset.reg_classifier{new_cls_idx}.pos_region_classifier = pos_region_classifier;
                dataset.reg_classifier{new_cls_idx}.neg_region_classifier = neg_region_classifier;

                actual_train_tic = tic;
                region_classifier                      = Train_region_classifier(region_classifier, dataset.reg_classifier, cls_opts, new_cls_idx);
                region_classifier.classes{new_cls_idx} = new_label;
                bbox_regressor                         = Train_bbox_regressor(bbox_regressor, dataset.bbox_regressor, new_cls_idx);
                
                fprintf('Train region classifier and bbox regressor required %f seconds\n', toc(actual_train_tic));
                fprintf('Train process required %f seconds\n', toc(train_tic));
                
                disp('Train done.');
                disp('Restoring Test state...');
                state = 'test';
                cnn_model.opts.after_nms_topN          = after_nms_topN_test;
           end

         case{'test'}
           %% ------------------------------------------- DETECT ----------------------------------------------------
           disp('Waiting image from port...');
           detection_tic = tic;

           yarpImage   = portImage.read(true);                       % get the yarp image from port
           TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
           im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
           im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
           im(:,:,2)= cast(TEST(:,:,2),'uint8');
           im(:,:,3)= cast(TEST(:,:,3),'uint8');         
           % im_gpu = gpuArray(im);
           
           % Performing detection
           if ~isempty(region_classifier)
               region_classifier.training_opts = cls_opts;
               [cls_scores boxes] = Detect(im, dataset.classes, cnn_model, region_classifier, bbox_regressor, detect_thresh);
           else
               boxes      = [];
               cls_scores = [];
           end
           % Sending detections        
           boxes_cell = cell(length(dataset.classes), 1);
           for i = 1:length(boxes_cell)
             boxes_cell{i} = [boxes{i}, cls_scores{i}];
           end           
           sendDetections(boxes_cell, portDets, portImg, im, dataset.classes, tool, [h,w,pixSize]);
           fprintf('Detection required %f seconds\n', toc(detection_tic));   
           
        case{'forget'}
           %% ------------------------------------------- FORGET ----------------------------------------------------
           disp('----------------------FORGET----------------------');
           disp('Training new model without forgotten class...');
           if ~isempty(dataset.reg_classifier)
               region_classifier.detectors.models(idx_to_remove) = [];
               region_classifier.classes(idx_to_remove)          = [];
               bbox_regressor.models(idx_to_remove)              = [];
           else
               region_classifier = [];
               bbox_regressor = [];
           end
           
           disp('Switching to state Test...');
           state = 'test';
           cnn_model.opts.after_nms_topN = after_nms_topN_test;
           
        case{'list_classes'}
           %% ------------------------------------------- LIST CLASSES ----------------------------------------------------
           disp('----------------------LIST_CLASSES----------------------');
           disp('Current classes are:');
           disp(dataset.classes);       

        case{'load_dataset'}
           %% ------------------------------------------- LOAD DATASET----------------------------------------------------
           disp('----------------------LOAD_DATASET----------------------');
           if exist([current_path '/Demo/Datasets/' load_dataset_name], 'file')
               disp('Loading dataset...');
               load([current_path '/Demo/Datasets/' load_dataset_name]);
               
               disp('Loaded dataset for classes:');
               disp(dataset.classes);
               
               disp('Training new models with the loaded dataset...');
               cls_to_train              = 1:length(dataset.reg_classifier);
               region_classifier         = Train_region_classifier(region_classifier,dataset.reg_classifier, cls_opts,cls_to_train);
               region_classifier.classes = dataset.classes;
               bbox_regressor            = Train_bbox_regressor(bbox_regressor, dataset.bbox_regressor, cls_to_train); 
              
               disp('Done.');
           else
               disp('Specified dataset does not exist.');
           end
           
           disp('Switching to state Test...');
           state = 'test';
           cnn_model.opts.after_nms_topN = after_nms_topN_test;         
           
        case{'save_dataset'}
           %% ------------------------------------------- SAVE DATASET-----------------------------------------------------
           disp('----------------------SAVE_DATASET----------------------');
           disp('Saving dataset...');
           if exist([current_path '/Demo/Datasets/' save_dataset_name], 'file')
               disp('dataset file already exists, adding a new_ flag to the specified name...');
               save_dataset_name = [ 'new_' save_dataset_name];
           end
           save([current_path '/Demo/Datasets/' save_dataset_name], 'dataset', '-v7.3');
           disp('Done.');
           
           disp('Switching to state Test...');
           state = 'test';
           cnn_model.opts.after_nms_topN = after_nms_topN_test;
           
        case{'save_model'}
           %% --------------------------------------------- SAVE MODEL------------------------------------------------------
           disp('----------------------SAVE_MODEL----------------------');
           disp('Saving model...');
           if exist([current_path '/Demo/Models/' save_model_name], 'file')
               disp('dataset file already exists, adding a new_ flag to the specified name...');
               save_model_name = ['new_' save_model_name];
           end
           model = struct;
           model.region_classifier = region_classifier;
           model.bbox_regressor    = bbox_regressor;
           save([current_path '/Demo/Models/' save_model_name], 'model');
           disp('Done.');
           
           disp('Switching to state Test...');
           state = 'test';
           cnn_model.opts.after_nms_topN = after_nms_topN_test;
           
        otherwise
           fprintf('State unknown\n'); 
   end     
end

disp('Closing ports...');
portCmd.close;
portImage.close;
portAnnotation.close;
portDets.close;
portImg.close;

disp('Bye bye!');

end

function [cur_bbox_X, cur_bbox_Y] = select_positives_for_bbox(boxes, gt_box, overlaps, min_overlap)

sel_ex = find(overlaps >= min_overlap); 

cur_bbox_X = cat(1,gt_box, boxes(sel_ex, :));
cur_bbox_Y = [];

for j = 1:size(cur_bbox_X, 1)
    ex_box = cur_bbox_X(j, :);

    src_w = ex_box(3) - ex_box(1) + eps;
    src_h = ex_box(4) - ex_box(2) + eps;
    src_ctr_x = ex_box(1) + 0.5*src_w;
    src_ctr_y = ex_box(2) + 0.5*src_h;

    gt_w = gt_box(3) - gt_box(1) + eps;
    gt_h = gt_box(4) - gt_box(2) + eps;
    gt_ctr_x = gt_box(1) + 0.5*gt_w;
    gt_ctr_y = gt_box(2) + 0.5*gt_h;

    dst_ctr_x = (gt_ctr_x - src_ctr_x) * 1/src_w;
    dst_ctr_y = (gt_ctr_y - src_ctr_y) * 1/src_h;
    dst_scl_w = log(gt_w / src_w);
    dst_scl_h = log(gt_h / src_h);

    target = [dst_ctr_x dst_ctr_y dst_scl_w dst_scl_h];

    cur_bbox_Y = cat(1,cur_bbox_Y,target);
end
end

function curr_cls_neg = select_negatives_for_cls(aboxes, overlaps, negatives_selection)
    I = find(overlaps < negatives_selection.neg_ovr_thresh);
    idx = randperm(length(I), negatives_selection.neg_per_image);
    curr_cls_neg = aboxes(I(idx),:);
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

function aboxes = boxes_filter(aboxes, per_nms_topN, nms_overlap_thres, after_nms_topN, use_gpu)
    % to speed up nms
    if per_nms_topN > 0
        aboxes = aboxes(1:min(length(aboxes), per_nms_topN), :);
    end
    % do nms
    if nms_overlap_thres > 0 && nms_overlap_thres < 1
        aboxes = aboxes(nms(aboxes, nms_overlap_thres, use_gpu), :);       
    end
    if after_nms_topN > 0
        aboxes = aboxes(1:min(length(aboxes), after_nms_topN), :);
    end
end

function forwardAnnotations(yarp_img, box, new_label, imgPort, portAnnOut)
    b = portAnnOut.prepare();
    b.clear();
    
    det_list = b.addList();
    det_list.addString('train');
    det_list.addDouble(box(1));       % x_min
    det_list.addDouble(box(2));       % y_min
    det_list.addDouble(box(3));       % x_max
    det_list.addDouble(box(4));       % y_max
    det_list.addString(new_label);    % string label
        
    stamp = yarp.Stamp();
    imgPort.setEnvelope(stamp); 
    portAnnOut.setEnvelope(stamp);
    
    imgPort.write(yarp_img);   
    portAnnOut.write();
end


function sendTrainDone(portAnnOut)
    b = portAnnOut.prepare();
    b.clear();
    
    det_list = b.addList();
    det_list.addString('done.');
        
    stamp = yarp.Stamp();
    portAnnOut.setEnvelope(stamp);
 
    portAnnOut.write();
end

function sendDetections(detections, detPort, imgPort, image, classes, tool, img_dims)
    b = detPort.prepare();
    b.clear();

    is_dets_per_class = cell2mat(cellfun(@(x) ~isempty(x), detections, 'UniformOutput', false));
    if sum(is_dets_per_class)
        % Prepare bottle b with detections and labels
        for i = 1:length(detections)
            for j = 1:size(detections{i},1)
                % Prepare list
                det_list = b.addList();
                % Add bounding box coordinates, score and string label of detected the object
                det_list.addDouble(detections{i}(j,1));       % x_min
                det_list.addDouble(detections{i}(j,2));       % y_min
                det_list.addDouble(detections{i}(j,3));       % x_max
                det_list.addDouble(detections{i}(j,4));       % y_max
                det_list.addDouble(detections{i}(j,5));       % score
                det_list.addString(classes{i});               % string label
            end
        end
    else
        det_list = b.addList();
    end
    
    % Prepare image to send
    yarp_img = yarp.ImageRgb();                                                 % create a new yarp image to send results to ports
    yarp_img.resize(img_dims(2),img_dims(1));                                   % resize it to the desired size
    yarp_img.zero();                                                            % set all pixels to black
    image = reshape(image, [img_dims(1)*img_dims(2)*img_dims(3) 1]);            % reshape the matlab image to 1D
    tempImg = cast(image ,'int16');                                             % cast it to int16
    yarp_img = tool.setRawImg(tempImg, img_dims(1), img_dims(2), img_dims(3));  % pass it to the setRawImg function (returns the full image)
    
    % Set timestamp for the two ports
    stamp = yarp.Stamp();
    imgPort.setEnvelope(stamp); 
    detPort.setEnvelope(stamp);
    
    %Send image and list of detections
    imgPort.write(yarp_img);   
    detPort.write();
end
