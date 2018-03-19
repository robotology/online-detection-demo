function script_FALKON_voc2007_compute_sigma(bkg_numb, lambda, gpu_id)
clear mex;
gpuDevice(gpu_id);

compute_sigma_init_variables;

% region proposals generation
dataset.roidb_train  = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal,model.stage2_rpn, output_dir, x, y), ...
                                                                          dataset.imdb_train, dataset.roidb_train, 'UniformOutput', false);
% features extraction
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
                                                                          dataset.imdb_train, dataset.roidb_train); 

% region proposals generation
dataset.roidb_test = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn , output_dir, x, y), ...
                                                                          dataset.imdb_test, dataset.roidb_test, 'UniformOutput', false);
% features extraction
cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
                                                                          dataset.imdb_test, dataset.roidb_test);

                                                                                                                                          
% bbox regressors train
% model.bbox_regressors = load('bbox_reg/bbox_regressor_final.mat');
model.bbox_regressors = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y, 'bbox_model_suffix', bbox_model_suffix), ... 
                                                                          dataset.imdb_train, dataset.roidb_train);

    
file_name = [results_dir results_file_name];
fid = fopen(file_name, 'wt');
% fprintf(fid, 'Results for:\n bkg_num = %f \n sigma = %f \n lambda = %f \n', bkg_numb, sigma, lambda);


train_classifier_options.lambda=lambda;
negatives_selection.N = bkg_numb;
train_classifier_options.target_norm = 20;
train_classifier_options.M=3000;

sigma_opts = struct;
sigma_opts.layer = 7;
sigma_opts.cache_name = 'feature_extraction_cache';
sigma_opts.negatives_selection = negatives_selection;
sigma_opts.train_classifier_options = train_classifier_options;
sigma_range = Compute_sigma_range(dataset.imdb_train{1},sigma_opts, fid);

end
    