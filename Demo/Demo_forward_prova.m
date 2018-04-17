function [  ] = Demo_forward_prova(bkg_numb, sigma, lambda, gpu_id)
%DEMO_FORWARD Summary of this function goes here
%   Detailed explanation goes here

clear mex;
gpuDevice(gpu_id);

FALKON_iCWT_TASK2_single_init_variables;
current_path = pwd;
% classes = importdata([current_path '/Demo/Conf/Classes_T2.txt' ]);
% cls_model_path = [current_path '/Demo/Models/cls_model.mat' ];
% bbox_model_path = [current_path '/Demo/Models/bbox_model.mat' ];
dataset_path = [current_path '/datasets/iCubWorld-Transformations/'];
% cnn_model_path=[current_path '/output_iCWT_TASK1_10objs_40k20k_newBatchSize/faster_rcnn_final'];

%% FILES
% image_set = 'test_TASK2_10objs';


% region proposals generation
dataset.TASK2.roidb_train  = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal,model.stage2_rpn, output_dir, x, y), ...
                                                                          dataset.TASK2.imdb_train, dataset.TASK2.roidb_train, 'UniformOutput', false);
% features extraction
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
                                                                          dataset.TASK2.imdb_train, dataset.TASK2.roidb_train); 

% region proposals generation
dataset.TASK2.roidb_test = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn , output_dir, x, y), ...
                                                                          dataset.TASK2.imdb_test, dataset.TASK2.roidb_test, 'UniformOutput', false);
% features extraction
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
                                                                          dataset.TASK2.imdb_test, dataset.TASK2.roidb_test);

                                                                                                                                          
% % bbox regressors train
% % model.bbox_regressors = load('bbox_reg/bbox_regressor_final.mat');
model.bbox_regressors = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y, 'bbox_model_suffix', bbox_model_suffix), ... 
                                                                          dataset.TASK2.imdb_train, dataset.TASK2.roidb_train);
% 
%     
file_name = [results_dir results_file_name];
fid = fopen(file_name, 'wt');
fprintf(fid, 'Results for:\n bkg_num = %f \n sigma = %f \n lambda = %f \n', bkg_numb, sigma, lambda);
% 
% 
% % train classifiers
rebal_alpha = 0;
train_classifier_options.sigma=sigma;
train_classifier_options.lambda=lambda;
negatives_selection.N = bkg_numb;
train_classifier_options.target_norm = 20;
model.classifiers.falkon = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, cls_mode, ...
                                                                  train_classifier_options, x, rebalancing, rebal_alpha, negatives_selection, fid), ...
                                                                  dataset.TASK2.imdb_train, 'UniformOutput', false);
% 
addpath('./datasets/VOCdevkit2007/VOCdevkit/VOCcode_incremental');

% load([pwd  '/Demo/Models/cls_model.mat']);
% load([pwd  '/Demo/Models/bbox_model.mat']);

% TEST
rmdir(boxes_dir,'s');
mkdir(boxes_dir);
mkdir ('det_images')
for j = 1:3000
    
    %% Fetch image
    
    %% Regions classification and scores thresholding
    cls_tic = tic;
    d = cnn_load_cached_pool5_features(model.classifiers.falkon{1}.cache_name, ...
          dataset.TASK2.imdb_test{1}.name, dataset.TASK2.imdb_test{1}.image_ids{j});
    [cls_boxes, cls_scores, inds] = predict_FALKON(d.feat(2:end,:), model.classifiers.falkon{1}, 0.5, d.boxes(2:end,:));
    fprintf('Region classification required %f seconds\n', toc(cls_tic));

    %% Bounding boxes refinement
    bbox_tic = tic;
    boxes = predict_bbox_refinement( model.bbox_regressors, d.feat(2:end,:), cls_boxes, 10, inds );
    fprintf('Bounding box refinement required %f seconds\n', toc(bbox_tic));
    
    %% Detections visualization
    vis_tic = tic;
    boxes_cell = cell(10, 1);
    im = imread([dataset_path '/Images/' dataset.TASK2.imdb_test{1}.image_ids{j} '.jpg']);    
    for i = 1:length(boxes_cell)
      boxes_cell{i} = [boxes{i}, cls_scores{i}];
      keep = nms(boxes_cell{i}, 0.3);
      boxes_cell{i} = boxes_cell{i}(keep,:);
    end
%     f = figure(j);
    showboxes(im, boxes_cell, chosen_classes_T2, 'voc', true, ['det_images_new_regions/' int2str(j) '.jpg' ]); %TO-STUDY what it does
    fprintf('Visualization required %f seconds\n', toc(vis_tic));
%     pause(0.1);
%     close(f);
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
