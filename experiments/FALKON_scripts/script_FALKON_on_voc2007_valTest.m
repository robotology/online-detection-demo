function script_FALKON_on_voc2007_valTest(bkg_numb, sigma, lambda, gpu_id)
clear mex;
gpuDevice(gpu_id);

FALKON_voc_init_variables_valTest;

% region proposals generation
dataset.roidb_val  = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal,model.stage2_rpn, output_dir, x, y), ...
                                                                          dataset.imdb_val, dataset.roidb_val, 'UniformOutput', false);
% features extraction
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
                                                                          dataset.imdb_val, dataset.roidb_val); 

% region proposals generation
dataset.roidb_test = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn , output_dir, x, y), ...
                                                                          dataset.imdb_test, dataset.roidb_test, 'UniformOutput', false);
% features extraction
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
                                                                          dataset.imdb_test, dataset.roidb_test);

                                                                                                                                          
% bbox regressors train
% model.bbox_regressors = load('bbox_reg/bbox_regressor_final.mat');
model.bbox_regressors = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y, 'bbox_model_suffix', bbox_model_suffix, 'reg_mode', reg_mode), ... 
                                                                          dataset.imdb_val, dataset.roidb_val);

    
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
                                                                  dataset.imdb_val, 'UniformOutput', false);

addpath('./datasets/VOCdevkit2007/VOCcode_incremental');

% TEST
rmdir(boxes_dir,'s');
mkdir(boxes_dir);

% test classifiers
res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
                                                                  model.classifiers.falkon{1}, x, fid), dataset.imdb_test, 'UniformOutput', false);

% test regressors
res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.feature_extraction, x, fid, 'reg_mode', reg_mode), ...
                                                                  dataset.imdb_test, 'UniformOutput', false);

end
    