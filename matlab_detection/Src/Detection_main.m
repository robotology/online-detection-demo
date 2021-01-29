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

cnn_model.proposal_detection_model.is_share_feature = is_share_feature;
% set gpu/cpu
if cnn_model.opts.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end   

%% -------------------- START DETECTION MODULE--------------------
state = 'init';

while ~strcmp(state,'quit')
    
%     disp('asking for command');
    cmd_bottle = yarp.Bottle();
    cmd_bottle = portCmd.read(false);
    
    %% Switching state according to command read from port
    if ~isempty(cmd_bottle)
       command = cmd_bottle.get(0).asString().toCharArray';
       switch command
           case{'quit'}
               disp('switching to state Quit...');
               state = 'quit';
               
           case{'start'}
               refinemenet_type = cmd_bottle.get(1).asString().toCharArray';
               if strcmp(refinemenet_type, 'refinement')
                   disp('switching to state Refine...');
                   state = 'refine_stream';
                   % Send command to exploration and weakly supervised modules
%                    portRefine.write();
%                    b = portRefine.prepare();
%                    b.clear();
%                    b.addString('start');
%                    b.addString('refine');
%                    portRefine.write();

                   % Initialize variables
                   disp('Initializing refinement variables...');
                   train_images_counter          = 0;
                   refine_dataset                = struct;
                   refine_dataset.classes        = dataset.classes;
                   refine_dataset.bbox_regressor = cell(size(dataset.bbox_regressor));
                   refine_dataset.reg_classifier = cell(size(dataset.reg_classifier));             
                   for i = 1:length(dataset.classes)
                       refine_dataset.bbox_regressor{i} = struct;
                       refine_dataset.bbox_regressor{i}.pos_bbox_regressor = struct;
                       refine_dataset.bbox_regressor{i}.pos_bbox_regressor.box     = [];
                       refine_dataset.bbox_regressor{i}.pos_bbox_regressor.feat    = [];
                       refine_dataset.bbox_regressor{i}.y_bbox_regressor           = [];
                       refine_dataset.reg_classifier{i} = struct;
                       refine_dataset.reg_classifier{i}.pos_region_classifier.box  = [];
                       refine_dataset.reg_classifier{i}.pos_region_classifier.feat = [];
                       refine_dataset.reg_classifier{i}.neg_region_classifier.box  = [];
                       refine_dataset.reg_classifier{i}.neg_region_classifier.feat = [];
                   end
                   cnn_model.opts.after_nms_topN = after_nms_topN_train;
                   classes_to_update_idx = [];
                   
               elseif strcmp(refinemenet_type, 'batch')
                   disp('Batch refinement modality still to be implemented')
               else
                   disp('Unknown refinement modality')
               end
               
           case{'stop'}
               action_to_stop = cmd_bottle.get(1).asString().toCharArray';
               if strcmp(action_to_stop, 'refinement')
                   disp('switching to state Update Model...');
                   state = 'update_model';
                   % Update dataset with the new collected dataset
                   new_batches = 0;
                   dataset.classes = refine_dataset.classes;
                   region_classifier.classes = dataset.classes;
                   for j =1:length(classes_to_update_idx)
                       c = classes_to_update_idx(j);
                       dataset.bbox_regressor{c}.pos_bbox_regressor.box = cat(1, ...
                                                        dataset.bbox_regressor{c}.pos_bbox_regressor.box, ...
                                                        refine_dataset.bbox_regressor{c}.pos_bbox_regressor.box);
                       dataset.bbox_regressor{c}.pos_bbox_regressor.feat = cat(1, ...
                                                        dataset.bbox_regressor{c}.pos_bbox_regressor.feat, ...
                                                        refine_dataset.bbox_regressor{c}.pos_bbox_regressor.feat);
                       dataset.bbox_regressor{c}.y_bbox_regressor = cat(1, ...
                                                        dataset.bbox_regressor{c}.y_bbox_regressor, ...
                                                        refine_dataset.bbox_regressor{c}.y_bbox_regressor);
                                                    
                       dataset.reg_classifier{c}.pos_region_classifier.box = cat(1, ...
                                                        dataset.reg_classifier{c}.pos_region_classifier.box, ...
                                                        refine_dataset.reg_classifier{c}.pos_region_classifier.box);
                       dataset.reg_classifier{c}.pos_region_classifier.feat = cat(1, ...
                                                        dataset.reg_classifier{c}.pos_region_classifier.feat, ...
                                                        refine_dataset.reg_classifier{c}.pos_region_classifier.feat);
                       dataset.reg_classifier{c}.neg_region_classifier.box = cat(1, ...
                                                        dataset.reg_classifier{c}.neg_region_classifier.box, ...
                                                        refine_dataset.reg_classifier{c}.neg_region_classifier.box);
                       dataset.reg_classifier{c}.neg_region_classifier.feat = cat(1, ...
                                                        dataset.reg_classifier{c}.neg_region_classifier.feat, ...
                                                        refine_dataset.reg_classifier{c}.neg_region_classifier.feat);
                                                    
                       if new_batches < ceil(size(refine_dataset.reg_classifier{c}.neg_region_classifier.box,1)/cls_opts.negatives_selection.batch_size)
                           new_batches = ceil(size(refine_dataset.reg_classifier{c}.neg_region_classifier.box,1)/cls_opts.negatives_selection.batch_size);
                       end
                   end           
                   cls_opts.negatives_selection.iterations = cls_opts.negatives_selection.iterations + new_batches;
               else
                   disp('Unknown action to stop')
               end
                               
           case{'train'}
               train_tic = tic;
               acquisition_tic = tic;
               disp('switching to state Train...');
               state = 'train'; 
               
               disp('Initializing train variables...');
               new_label = cell(1);
               new_label{1} = cmd_bottle.get(1).asString().toCharArray';
               new_to_add = isempty(find(strcmp(dataset.classes,new_label{1})));
               if new_to_add
                   new_cls_idx                                = length(dataset.bbox_regressor) + 1;
                   dataset.classes{length(dataset.classes)+1} = new_label{1};
                   max_img_per_class                          = max_img_for_new_class;
                   
                   total_negatives = negatives_selection.batch_size*negatives_selection.iterations;
                  
               else
                   new_cls_idx                                               = find(strcmp(dataset.classes,new_label{1}));
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
           if ~exist([current_path dataset_path default_dataset_name] , 'file')
               disp('Saving dataset...');
               save([current_path dataset_path default_dataset_name], 'dataset');
           end
           
           disp('Saving model...');      
           model = struct;
           model.region_classifier = region_classifier;
           model.bbox_regressor = bbox_regressor;
           save([current_path model_path default_model_name], 'model');

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
            region_classifier.training_opts = cls_opts;
            disp('Done.')
            disp('If you want to load an old dataset, please type: load dataset *datasetname*.')
        
            disp('Switching to state Test...');
            state = 'test';
            cnn_model.opts.after_nms_topN = after_nms_topN_test;
            
        
       case{'update_model'}
           actual_train_tic = tic;
           region_classifier                      = Train_region_classifier(region_classifier, dataset.reg_classifier, cls_opts, classes_to_update_idx);               
           bbox_regressor                         = Train_bbox_regressor(bbox_regressor, dataset.bbox_regressor, classes_to_update_idx);

           fprintf('Train region classifier and bbox regressor required %f seconds\n', toc(actual_train_tic));
           %fprintf('Train process required %f seconds\n', toc(train_tic));

           disp('Train done.');
           disp('Restoring Test state...');
           state = 'test';
           cnn_model.opts.after_nms_topN          = after_nms_topN_test;
           
       case{'train'} 
           %% -------------------------------------------- TRAIN -------------------------------------------------------
           disp('----------------------TRAIN----------------------');
           
           annotations_bottle = portAnnotation.read(true);
           yarpImage   = portImage.read(true);  
           
           if (annotations_bottle.size() ~= 0 && sum(size(yarpImage)) ~= 0)
                 fprintf('Processing image: %d/%d', train_images_counter, max_img_per_class);
                                
                   % Gathering mat image and gpuarray
                   TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
                   im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
                   im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
                   im(:,:,2)= cast(TEST(:,:,2),'uint8');
                   im(:,:,3)= cast(TEST(:,:,3),'uint8');         
                   % im_gpu = gpuArray(im);

                   % Gathering GT box and label 
                   gt_boxes = zeros(length(annotations_bottle),4);
                   for j = 1:length(annotations_bottle)
                       ann           = annotations_bottle.pop();
                       gt_boxes(j,:) = [ann.asList().get(0).asDouble(), ann.asList().get(1).asDouble(), ...
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
                    [cur_bbox_pos, cur_bbox_y, ~]      = select_positives_for_bbox(aboxes(:,1:4), gt_boxes, overlaps, bbox_opts.min_overlap); 
                    pos_bbox_regressor.box          = cat(1, pos_bbox_regressor.box, cur_bbox_pos);
                    y_bbox_regressor                = cat(1,y_bbox_regressor,cur_bbox_y);          

                    % Positive regions for region classifier
                    pos_region_classifier.box       = cat(1, pos_region_classifier.box, gt_boxes);

                    % Select negative regions for region classifier
                    if curr_negative_number < total_negatives
                        [curr_cls_neg,~]                = select_negatives_for_cls(aboxes(:,1:4), overlaps, negatives_selection); 
                        neg_region_classifier.box   = cat(1, neg_region_classifier.box, curr_cls_neg);
                        curr_negative_number        = curr_negative_number + size(curr_cls_neg,1);
                    else
                        curr_cls_neg = [];
                        neg_region_classifier.box = [];
                    end
%                     fprintf('--Positives and negatives selection required %f seconds\n', toc(selection_tic));

                    % Extract features from regions 
                    % -- Select regions to extract features from
                    regions_for_features           = cat(1, cur_bbox_pos, curr_cls_neg); % cur_bbox_pos contains gt_box too so no need to repeat it  

                    % -- Network forward

                    if cnn_model.proposal_detection_model.is_share_feature
                           features             = cnn_features_shared_conv(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), cnn_model.fast_rcnn_net, region_classifier.training_opts.feat_layer, ...
                                                                           cnn_model.rpn_net.blobs(cnn_model.proposal_detection_model.last_shared_output_blob_name));
                    else
                           features             = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), ...
                                                                    cnn_model.fast_rcnn_net, [], region_classifier.training_opts.feat_layer);                                                
                    end

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
                
                region_classifier.classes{new_cls_idx} = new_label{1};
                
                classes_to_update_idx = new_cls_idx;
                state = 'update_model';
           end
           
         case{'refine_batch'}
           %% -------------------------------------------- REFINE -------------------------------------------------------
           disp('----------------------REFINE----------------------');
           
           annotations_bottle = portAnnotation.read(true);
           yarpImage   = portImage.read(true);  
           
           if (annotations_bottle.size() ~= 0 && sum(size(yarpImage)) ~= 0)
                 fprintf('Processing image: %d', train_images_counter);
                             
                   % Gathering mat image and gpuarray
                   TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
                   im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
                   im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
                   im(:,:,2)= cast(TEST(:,:,2),'uint8');
                   im(:,:,3)= cast(TEST(:,:,3),'uint8');         
                   % im_gpu = gpuArray(im);

                   % Gathering GT box and label 
                   gt_boxes = zeros(size(annotations_bottle),4);
                   new_labels = cell(size(annotations_bottle));
                   for j = 1:size(annotations_bottle)
                       ann           = annotations_bottle.pop();
                       gt_boxes(j,:)   = [ann.asList().get(0).asDouble(), ann.asList().get(1).asDouble(), ...
                                        ann.asList().get(2).asDouble(), ann.asList().get(3).asDouble()];  % bbox format: [tl_x, tl_y, br_x, br_y]
                       new_labels{j} = ann.asList().get(4).asString().toCharArray';
                       label_id = find(strcmp(dataset.classes,new_labels{j}));
                       if isempty(label_id)
                           % A new classes has been encountered
                           dataset.classes{length(dataset.classes)+1} = new_labels{j};
                           region_classifier.classes = dataset.classes;
                           label_id = length(dataset.classes);
                           
                           refine_dataset.bbox_regressor{end+1} = struct;
                           refine_dataset.bbox_regressor{end}.pos_bbox_regressor = struct;
                           refine_dataset.bbox_regressor{end}.pos_bbox_regressor.box     = [];
                           refine_dataset.bbox_regressor{end}.pos_bbox_regressor.feat    = [];
                           refine_dataset.bbox_regressor{end}.y_bbox_regressor           = [];
                           refine_dataset.reg_classifier{end+1} = struct;
                           refine_dataset.reg_classifier{end}.pos_region_classifier.box  = [];
                           refine_dataset.reg_classifier{end}.pos_region_classifier.feat = [];
                           refine_dataset.reg_classifier{end}.neg_region_classifier.box  = [];
                           refine_dataset.reg_classifier{end}.neg_region_classifier.feat = [];
                           
                           dataset.bbox_regressor{end+1} = struct;
                           dataset.bbox_regressor{end}.pos_bbox_regressor = struct;
                           dataset.bbox_regressor{end}.pos_bbox_regressor.box     = [];
                           dataset.bbox_regressor{end}.pos_bbox_regressor.feat    = [];
                           dataset.bbox_regressor{end}.y_bbox_regressor           = [];
                           dataset.reg_classifier{end+1} = struct;
                           dataset.reg_classifier{end}.pos_region_classifier.box  = [];
                           dataset.reg_classifier{end}.pos_region_classifier.feat = [];
                           dataset.reg_classifier{end}.neg_region_classifier.box  = [];
                           dataset.reg_classifier{end}.neg_region_classifier.feat = [];
                       end
                       classes_to_update_idx = [classes_to_update_idx, label_id];
                   end
                  
                   forwardAnnotations(yarpImage, gt_boxes, new_labels, portImg, portDets);
                    % Extract regions from image and filtering
                    [boxes, scores]                 = proposal_im_detect(cnn_model.proposal_detection_model.conf_proposal, cnn_model.rpn_net, im);
                    aboxes                          = boxes_filter([boxes, scores], cnn_model.opts.per_nms_topN, cnn_model.opts.nms_overlap_thres, ...
                                                                    cnn_model.opts.after_nms_topN, cnn_model.opts.use_gpu);

                     
                    % Positive regions for bounding box regressor
                    tmp_dataset = struct;
                    tmp_dataset.reg_classifier_pos_idx = cell(0);
                    tmp_dataset.reg_classifier_neg_idx = cell(0);
                    tmp_dataset.bbox_regressor_idx = cell(0); 
                    tmp_dataset.classes        = cell(0);
                    tmp_dataset.unique_idx = [];
                    for j =1:length(new_labels)
                        overlaps = boxoverlap(aboxes, gt_boxes(j,:));
                        [cur_bbox_pos, cur_bbox_y, cur_bbox_idx] = select_positives_for_bbox(aboxes(:,1:4), gt_boxes(j,:), ...
                                                                               overlaps, bbox_opts.min_overlap); 
%                         cur_bbox_idx = [0, cur_bbox_idx];
                        tmp_dataset.bbox_regressor_idx{j} = cur_bbox_idx;
                      
                        cls_id = find(strcmp(dataset.classes,new_labels{j}));
                        tmp_dataset.classes{j} = new_labels{j};
                        
                        % Positive regions for bbox regressor
                        refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.box = cat(1, ...
                                                                                       refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.box, ...
                                                                                       cur_bbox_pos);
                        refine_dataset.bbox_regressor{cls_id}.y_bbox_regressor = cat(1, refine_dataset.bbox_regressor{cls_id}.y_bbox_regressor, ...
                                                                                       cur_bbox_y);
                                                                                   
                        % Positive regions for region classifier
                        curr_cls_pos = gt_boxes(j,:);
                        curr_cls_pos_idx = j;
                        tmp_dataset.reg_classifier_pos_idx{j} = curr_cls_pos_idx;
                        refine_dataset.reg_classifier{cls_id}.pos_region_classifier.box = cat(1, ... 
                                                                                       refine_dataset.reg_classifier{cls_id}.pos_region_classifier.box, ...
                                                                                       curr_cls_pos);
                                                                                   
                        % Select negative regions for region classifier
                        [curr_cls_neg, curr_cls_neg_idx] = select_negatives_for_cls(aboxes(:,1:4), overlaps, negatives_selection); 
                        tmp_dataset.reg_classifier_neg_idx{j} = curr_cls_neg_idx;
                        refine_dataset.reg_classifier{cls_id}.neg_region_classifier.box = cat(1, ...
                                                                                       refine_dataset.reg_classifier{cls_id}.neg_region_classifier.box, ...
                                                                                       curr_cls_neg);
                        tmp_dataset.unique_idx = unique(cat(1, tmp_dataset.unique_idx, cur_bbox_idx, curr_cls_neg_idx));
                          
                    end
                    % Extract features from regions 
                    % -- Select regions to extract features from
                    regions_for_features           = cat(1,gt_boxes, aboxes(tmp_dataset.unique_idx, 1:4));  

                    % -- Network forward
                    if cnn_model.proposal_detection_model.is_share_feature
                           features             = cnn_features_shared_conv(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), cnn_model.fast_rcnn_net, region_classifier.training_opts.feat_layer, ...
                                                                           cnn_model.rpn_net.blobs(cnn_model.proposal_detection_model.last_shared_output_blob_name));
                    else
                           features             = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), ...
                                                                    cnn_model.fast_rcnn_net, [], region_classifier.training_opts.feat_layer);                                                
                    end

                    % Update total features datasets
                    % A questo punto le features saranno = [gt_feat, selected_aboxes_feat]
                    for j =1:length(tmp_dataset.classes)
                        cls_id = find(strcmp(dataset.classes,new_labels{j}));
                        [~,tmp_b_id] = ismember(tmp_dataset.bbox_regressor_idx{j}, tmp_dataset.unique_idx);
                        % tmp_b_id contiene gli indici di unique_idx in cui
                        % si trovano elementi di bbox_regressor_idx.
                        % gli elementi di unique_idx contengono l'info
                        % dell'indice nella struttura delle regioni e
                        % nell'indice l'info dell'indice della feature
                        % corrispondente => se unique_idx(j) = i vuol dire
                        % che la regione i-esima ha feature corrispondente
                        % features(j)
                        bbox_pos_idx = tmp_b_id + length(tmp_dataset.classes);
                        [~,tmp_c_id] = ismember(tmp_dataset.reg_classifier_neg_idx{j}, tmp_dataset.unique_idx);
                        cls_neg_idx = tmp_c_id + length(tmp_dataset.classes);
                        refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.feat = cat(1, ...
                                                                refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.feat, ...
                                                                features(tmp_dataset.reg_classifier_pos_idx{j}, :) , ...
                                                                features(1:size(bbox_pos_idx,1),:));
                        refine_dataset.reg_classifier{cls_id}.pos_region_classifier.feat = cat(1, ...
                                                                refine_dataset.reg_classifier{cls_id}.pos_region_classifier.feat, ...
                                                                features(tmp_dataset.reg_classifier_pos_idx{j}, :));
                        refine_dataset.reg_classifier{cls_id}.neg_region_classifier.feat = cat(1, ...
                                                                refine_dataset.reg_classifier{cls_id}.neg_region_classifier.feat, ...
                                                                features(cls_neg_idx,:));

                    end
                    
                        
                    classes_to_update_idx = unique(classes_to_update_idx);
                    train_images_counter = train_images_counter +1;
           end
           
         case{'refine_stream'}
           %% -------------------------------------------- REFINE -------------------------------------------------------
           disp('----------------------REFINE----------------------');
           
           yarpImage = portImage.read(true);  
           
           if (sum(size(yarpImage)) ~= 0)                           
                   % Gathering mat image and gpuarray
                   TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
                   im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
                   im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
                   im(:,:,2)= cast(TEST(:,:,2),'uint8');
                   im(:,:,3)= cast(TEST(:,:,3),'uint8');         
                   % im_gpu = gpuArray(im);
                   
                   % Performing detection
                   if isfield(region_classifier, 'classes') && ~isempty(dataset.classes)
                       region_classifier.training_opts = cls_opts;
                       [cls_scores, boxes, aboxes, features] = Detect(im, dataset.classes, cnn_model, region_classifier, bbox_regressor, detect_thresh, show_regions, portRegs);
                   else
                       boxes      = [];
                       cls_scores = [];
                   end
                   % Sending detections        
                   boxes_cell = cell(length(dataset.classes), 1);
                   for i = 1:length(boxes_cell)
                     boxes_cell{i} = [boxes{i}, cls_scores{i}];
                   end           
                   sendDetections(boxes_cell, portRefineAnnotationOUT, portRefineImageOUT, im, dataset.classes, tool, [h,w,pixSize]);

                   
                   % Wait for annotations from the AL
                   disp('Waiting for weakly supervised annotations...')
                   annotations_bottle = portRefineAnnotationIN.read(true);
%                    yarpImage          = portRefineImageIN.read(true);     

                   if (annotations_bottle.size() ~= 0 && sum(size(yarpImage)) ~= 0)
%                        TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
%                        im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
%                        im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
%                        im(:,:,2)= cast(TEST(:,:,2),'uint8');
%                        im(:,:,3)= cast(TEST(:,:,3),'uint8');     
                       
                       if annotations_bottle.get(0).isString() && strcmp(annotations_bottle.get(0).asString(), 'skip')
                           disp('Skip command received')
                       else
                           % Gathering GT box and label 
                           gt_boxes = zeros(size(annotations_bottle),4);
                           new_labels = cell(size(annotations_bottle));
                           for j = 1:size(annotations_bottle)
                               ann           = annotations_bottle.pop();
                               gt_boxes(j,:)   = [ann.asList().get(0).asDouble(), ann.asList().get(1).asDouble(), ...
                                                ann.asList().get(2).asDouble(), ann.asList().get(3).asDouble()];  % bbox format: [tl_x, tl_y, br_x, br_y]
                               new_labels{j} = ann.asList().get(4).asString().toCharArray';
                               label_id = find(strcmp(refine_dataset.classes,new_labels{j}));
                               if isempty(label_id)
                                   % A new classes has been encountered
                                   refine_dataset.classes{length(refine_dataset.classes)+1} = new_labels{j};
                                   label_id = length(refine_dataset.classes);

                                   refine_dataset.bbox_regressor{end+1} = struct;
                                   refine_dataset.bbox_regressor{end}.pos_bbox_regressor = struct;
                                   refine_dataset.bbox_regressor{end}.pos_bbox_regressor.box     = [];
                                   refine_dataset.bbox_regressor{end}.pos_bbox_regressor.feat    = [];
                                   refine_dataset.bbox_regressor{end}.y_bbox_regressor           = [];
                                   refine_dataset.reg_classifier{end+1} = struct;
                                   refine_dataset.reg_classifier{end}.pos_region_classifier.box  = [];
                                   refine_dataset.reg_classifier{end}.pos_region_classifier.feat = [];
                                   refine_dataset.reg_classifier{end}.neg_region_classifier.box  = [];
                                   refine_dataset.reg_classifier{end}.neg_region_classifier.feat = [];

                                   dataset.bbox_regressor{end+1} = struct;
                                   dataset.bbox_regressor{end}.pos_bbox_regressor = struct;
                                   dataset.bbox_regressor{end}.pos_bbox_regressor.box     = [];
                                   dataset.bbox_regressor{end}.pos_bbox_regressor.feat    = [];
                                   dataset.bbox_regressor{end}.y_bbox_regressor           = [];
                                   dataset.reg_classifier{end+1} = struct;
                                   dataset.reg_classifier{end}.pos_region_classifier.box  = [];
                                   dataset.reg_classifier{end}.pos_region_classifier.feat = [];
                                   dataset.reg_classifier{end}.neg_region_classifier.box  = [];
                                   dataset.reg_classifier{end}.neg_region_classifier.feat = [];
                               end
                               classes_to_update_idx = [classes_to_update_idx, label_id];
                           end

                           forwardAnnotations(yarpImage, gt_boxes, new_labels, portImg, portDets);

                           for j =1:length(new_labels)
                                overlaps = boxoverlap(aboxes, gt_boxes(j,:));
                                [cur_bbox_pos, cur_bbox_y, cur_bbox_idx] = select_positives_for_bbox(aboxes(:,1:4), gt_boxes(j,:), ...
                                                                                       overlaps, bbox_opts.min_overlap); 
                                cls_id = find(strcmp(refine_dataset.classes,new_labels{j}));


                                % Positive regions and features for bbox regressor
                                refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.box = cat(1, ...
                                                                                               refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.box, ...
                                                                                               cur_bbox_pos);
                                refine_dataset.bbox_regressor{cls_id}.y_bbox_regressor = cat(1, refine_dataset.bbox_regressor{cls_id}.y_bbox_regressor, ...
                                                                                               cur_bbox_y);

                                refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.feat = cat(1, ...
                                                                                               refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.feat, ...
                                                                                               features(1:size(cur_bbox_idx,1),:)); % Da aggiungere le feature dei ground truth

                                % Positive regions for region classifier
                                curr_cls_pos = gt_boxes(j,:);
                                refine_dataset.reg_classifier{cls_id}.pos_region_classifier.box = cat(1, ... 
                                                                                               refine_dataset.reg_classifier{cls_id}.pos_region_classifier.box, ...
                                                                                               curr_cls_pos);

                                % Negative regions and features for region classifier
                                [curr_cls_neg, curr_cls_neg_idx] = select_negatives_for_cls(aboxes(:,1:4), overlaps, negatives_selection); 
                                refine_dataset.reg_classifier{cls_id}.neg_region_classifier.box = cat(1, ...
                                                                                               refine_dataset.reg_classifier{cls_id}.neg_region_classifier.box, ...
                                                                                               curr_cls_neg);
                                refine_dataset.reg_classifier{cls_id}.neg_region_classifier.feat = cat(1, ...
                                                                                               refine_dataset.reg_classifier{cls_id}.neg_region_classifier.feat, ...
                                                                                               features(curr_cls_neg_idx,:));

                            end
                            % Extract features from new ground trith regions 
                            % -- Select regions to extract features from
                            regions_for_features           = gt_boxes;  

                            % -- Network forward
                            if cnn_model.proposal_detection_model.is_share_feature
                                   features             = cnn_features_shared_conv(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), cnn_model.fast_rcnn_net, region_classifier.training_opts.feat_layer, ...
                                                                                   cnn_model.rpn_net.blobs(cnn_model.proposal_detection_model.last_shared_output_blob_name));
                            else
                                   features             = cnn_features_demo(cnn_model.proposal_detection_model.conf_detection, im, regions_for_features(:, 1:4), ...
                                                                            cnn_model.fast_rcnn_net, [], region_classifier.training_opts.feat_layer);                                                
                            end

                            % Update total features datasets
                            for j =1:length(new_labels)
                                cls_id = find(strcmp(refine_dataset.classes,new_labels{j}));

                                refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.feat = cat(1, ...
                                                                        refine_dataset.bbox_regressor{cls_id}.pos_bbox_regressor.feat, ...
                                                                        features(j,:)); % Adding ground truth features
                                refine_dataset.reg_classifier{cls_id}.pos_region_classifier.feat = cat(1, ...
                                                                        refine_dataset.reg_classifier{cls_id}.pos_region_classifier.feat, ...
                                                                        features(j, :)); % Adding ground truth features

                            end
                            classes_to_update_idx = unique(classes_to_update_idx);
                            train_images_counter = train_images_counter +1;
                       end
                   end
           end
             
         case{'test'}
           %% ------------------------------------------- DETECT ----------------------------------------------------
           detection_tic = tic;

           yarpImage   = portImage.read(true);                       % get the yarp image from port
           TEST = reshape(tool.getRawImg(yarpImage), [h w pixSize]); % need to reshape the matrix from 1D to h w pixelSize       
           im=uint8(zeros(h, w, pixSize));                           % create an empty image with the correct dimentions
           im(:,:,1)= cast(TEST(:,:,1),'uint8');                     % copy the image to the previoulsy create matrix
           im(:,:,2)= cast(TEST(:,:,2),'uint8');
           im(:,:,3)= cast(TEST(:,:,3),'uint8');         
           % im_gpu = gpuArray(im);
           
           % Performing detection
           if isfield(region_classifier, 'classes') && ~isempty(dataset.classes)
               region_classifier.training_opts = cls_opts;
               [cls_scores, boxes, ~, ~] = Detect(im, dataset.classes, cnn_model, region_classifier, bbox_regressor, detect_thresh, show_regions, portRegs);
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
           tocs = tocs + toc(detection_tic);
           tocs_counter = tocs_counter + 1;
           if tocs_counter == 50
               fprintf('Detection requires %f seconds\n', tocs/50.0);
               tocs = 0;
               tocs_counter = 0;
           end
           
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
               region_classifier.training_opts = cls_opts;
               bbox_regressor    = [];
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
           if exist([current_path dataset_path load_dataset_name], 'file')
               disp('Loading dataset...');
               load([current_path dataset_path load_dataset_name]);
               
               disp('Loaded dataset for classes:');
               disp(dataset.classes);
               
               disp('Training new models with the loaded dataset...');
               cls_to_train              = 1:length(dataset.reg_classifier);
               region_classifier         = Train_region_classifier(region_classifier,dataset.reg_classifier, cls_opts,cls_to_train);
               region_classifier.classes = dataset.classes;
               bbox_regressor            = Train_bbox_regressor(bbox_regressor, dataset.bbox_regressor, cls_to_train); 
               region_classifier.training_opts = cls_opts;
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
           if exist([current_path dataset_path save_dataset_name], 'file')
               disp('dataset file already exists, adding a new_ flag to the specified name...');
               save_dataset_name = [ 'new_' save_dataset_name];
           end
           save([current_path dataset_path save_dataset_name], 'dataset', '-v7.3');
           disp('Done.');
           
           disp('Switching to state Test...');
           state = 'test';
           cnn_model.opts.after_nms_topN = after_nms_topN_test;
           
        case{'save_model'}
           %% --------------------------------------------- SAVE MODEL------------------------------------------------------
           disp('----------------------SAVE_MODEL----------------------');
           disp('Saving model...');
           if exist([current_path model_path save_model_name], 'file')
               disp('dataset file already exists, adding a new_ flag to the specified name...');
               save_model_name = ['new_' save_model_name];
           end
           model = struct;
           model.region_classifier = region_classifier;
           model.bbox_regressor    = bbox_regressor;
           save([current_path model_path save_model_name], 'model');
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
% portRefine.close;
portRefineAnnotationIN.close;
portRefineImageOUT.close;
portRefineAnnotationOUT.close;

disp('Bye bye!');

end
