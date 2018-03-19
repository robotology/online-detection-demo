function script_FALKON_voc2007_ZF_M_variation(bkg_numb, sigma, lambda, Nyst_centres, iterations, gpu_id)
clear mex;
gpuDevice(gpu_id);

MVar_FALKON_voc_init_variables;

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
fprintf(fid, 'Results for:\n bkg_num = %f \n sigma = %f \n lambda = %f \n', bkg_numb, sigma, lambda);


% train classifiers
rebal_alpha = 0;
train_classifier_options.sigma=sigma;
train_classifier_options.lambda=lambda;
negatives_selection.N = bkg_numb;

results = struct;

results.matrix_cls = zeros(length(Nyst_centres),length(iterations));
results.matrix_reg = zeros(length(Nyst_centres),length(iterations));
results.Nyst_centres=Nyst_centres;
for m=1:length(Nyst_centres)
    for t=1:length(iterations)
    train_classifier_options.M=Nyst_centres(m);
    train_classifier_options.T=iterations(t);
    fprintf(fid, 'Num of Nystrom Centres: %d\n',train_classifier_options.M);
    fprintf(fid, 'Num of iterations: %d\n',train_classifier_options.T);

    model.classifiers.falkon = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, cls_mode, ...
                                                                      train_classifier_options, x, rebalancing, rebal_alpha, negatives_selection, fid), ...
                                                                      dataset.imdb_train, 'UniformOutput', false);

    addpath('./datasets/VOCdevkit2007/VOCcode_incremental');

    % TEST
    rmdir(boxes_dir,'s');
    mkdir(boxes_dir);

    % test classifiers
    res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
                                                                      model.classifiers.falkon{1}, x, fid), dataset.imdb_test, 'UniformOutput', false);
    aps_cls = [res_cls{1}(:).ap]';
    results.matrix_cls(m,t) = mean(aps_cls);
    % test regressors
    res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.feature_extraction, x, fid), ...
                                                                      dataset.imdb_test, 'UniformOutput', false);
    aps_reg = [res_reg{1}(:).ap]';
    results.matrix_reg(m,t) = mean(aps_reg);
    save([results_dir '/results_TVar.mat'], 'results');
    end
end

fclose(fid);
save([results_dir '/results_TVar.mat'], 'results');

end
    
