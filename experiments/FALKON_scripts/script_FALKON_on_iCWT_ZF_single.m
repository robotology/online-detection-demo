function script_single_FALKON_on_voc2007_ZF(bkg_numb, sigma, lambda, gpu_id)
clear mex;
gpuDevice(gpu_id);

FALKON_iCWT_TASK2_single_init_variables;

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

                                                                                                                                          
% bbox regressors train
% model.bbox_regressors = load('bbox_reg/bbox_regressor_final.mat');
model.bbox_regressors = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y, 'bbox_model_suffix', bbox_model_suffix), ... 
                                                                          dataset.TASK2.imdb_train, dataset.TASK2.roidb_train);

    
file_name = [results_dir results_file_name];
fid = fopen(file_name, 'wt');
fprintf(fid, 'Results for:\n bkg_num = %f \n sigma = %f \n lambda = %f \n', bkg_numb, sigma, lambda);


% train classifiers
rebal_alpha = 0;
train_classifier_options.sigma=sigma;
train_classifier_options.lambda=lambda;
negatives_selection.N = bkg_numb;
train_classifier_options.target_norm = 20;
model.classifiers.falkon = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, cls_mode, ...
                                                                  train_classifier_options, x, rebalancing, rebal_alpha, negatives_selection, fid), ...
                                                                  dataset.TASK2.imdb_train, 'UniformOutput', false);

addpath('./datasets/VOCdevkit2007/VOCdevkit/VOCcode_incremental');

% TEST
rmdir(boxes_dir,'s');
mkdir(boxes_dir);

% test classifiers
res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
                                                                  model.classifiers.falkon{1}, x, fid), dataset.TASK2.imdb_test, 'UniformOutput', false);

% test regressors
res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.feature_extraction, x, fid), ...
                                                                  dataset.TASK2.imdb_test, 'UniformOutput', false);

end
    
