function script_FALKON_on_voc2007_newCV(bkg_numb, nyst_centres, gpu_id)

gpuDevice(gpu_id);

FALKON_newCV_init_variables;

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
model.bbox_regressors = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y), ... 
                                                                          dataset.imdb_train, dataset.roidb_train);


if(train_classifier_options.cross_validation.required)
    train_classifier_options.cross_validation.lambdas = lambdas;
    % region proposals generation
    use_flipped                 = false;
    % removed_classes          = {'cat','chair','cow','diningtable','dog','horse','motorbike','person','pottedplant','sheep','sofa','train','tvmonitor'};
    removed_classes = {};
    mkdir(['imdb/' imdb_val_cache_name]);
    dataset                     = Dataset.voc2007_train(dataset, 'val', use_flipped, removed_classes, imdb_cache_name);
    dataset.roidb_val = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn , output_dir, x, y), ...
                                                                              dataset.imdb_val, dataset.roidb_val, 'UniformOutput', false);
    % features extraction
    cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
                                                                          dataset.imdb_val, dataset.roidb_val);
end

best_model = {};
file_name = [results_dir '/test_bkg' int2str(bkg_numb) '.txt'];
bkg_fid = fopen(file_name, 'wt');
fprintf( bkg_fid, 'Results for bkg_num = %f \n', bkg_numb);


sigmas = Compute_sigma_range(dataset.imdb_train{1},sigma_opts, bkg_fid)
train_classifier_options.cross_validation.sigmas = sigmas;
best_model.results_matrix_cls = zeros(length(sigmas),length(lambdas));
best_model.results_matrix_reg = zeros(length(sigmas),length(lambdas));
best_model.reg_mAP_val = 0.0;
for k=1:length(sigmas)
    file_name = [results_dir '/precisions_bkg' int2str(bkg_numb) '_M' int2str(nyst_centres) '_sigma' int2str(sigmas(k)) '.txt'];
    fid = fopen(file_name, 'wt');
    train_classifier_options.sigma = sigmas(k);
    fprintf( fid, 'Results for:\nNumber of Nystrom Centres = %f \n', train_classifier_options.M);
    fprintf( fid, 'Sigma = %f \n', train_classifier_options.sigma);
    for l=1:length(lambdas)
        train_classifier_options.lambda = lambdas(l);
        fprintf( fid, 'Lambda = %f \n', train_classifier_options.lambda);

        % train classifiers
        rebal_alpha = 0;
        model.classifiers.falkon = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, cls_mode, ...
                                                                          train_classifier_options, x, rebalancing, rebal_alpha, negatives_selection, fid), ...
                                                                          dataset.imdb_train, 'UniformOutput', false);

        addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
        rmdir(boxes_dir,'s');
        mkdir(boxes_dir);

        % test classifiers
        res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
                                                                          model.classifiers.falkon{1}, x, fid), dataset.imdb_val, 'UniformOutput', false);
        aps_cls = [res_cls{1}(:).ap]';
        best_model.results_matrix_cls(k,l) = mean(aps_cls);

        % test regressors
        res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.feature_extraction, x, fid), ...
                                                                          dataset.imdb_val, 'UniformOutput', false);
        aps_reg = [res_reg{1}(:).ap]';
        best_model.results_matrix_reg(k,l) = mean(aps_reg);

        if(best_model.reg_mAP_val <= mean(aps_reg))
            best_model.detectors = model.classifiers.falkon;
            best_model.cls_mAP_val = mean(aps_cls);
            best_model.reg_mAP_val = mean(aps_reg);
            best_model.lambda = lambdas(l);
            best_model.sigma = sigmas(k);
            best_model.M =  nyst_centres;
            model_to_save = best_model;
            fprintf('saving partial results...');
            save([results_dir '/best_model_' int2str(bkg_numb)  'bkg_tmp.mat'], 'model_to_save');
        end

    end
end
model_to_save = best_model;
fprintf('saving partial results...');
save([results_dir '/best_model_' int2str(bkg_numb)  'bkg_tmp.mat'], 'model_to_save'); 
fclose(fid);
    
fprintf('saving workspace...');
save([results_dir 'trainval_40k20k.mat'])
fprintf(bkg_fid, 'Best model for %f background regions is: \n', bkg_numb);
fprintf(bkg_fid, 'sigma = %f  \n', best_model.sigma);
fprintf(bkg_fid, 'lambda = %f  \n', best_model.lambda);
fprintf(bkg_fid, 'M = %f  \n', best_model.M);
fprintf(bkg_fid, 'and has mAP after classification on validation set = %f  \n', best_model.cls_mAP_val);
fprintf(bkg_fid, 'and has mAP after regression on validation set = %f  \n', best_model.reg_mAP_val);

% Retrain using trainval set

% TEST
rmdir(boxes_dir,'s');
mkdir(boxes_dir);

% test classifiers
res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
                                                              best_model.detectors{1}, x, bkg_fid), dataset.imdb_test, 'UniformOutput', false);
final_aps_cls = [res_cls{1}(:).ap]';
best_model.cls_mAP_final_test = mean(final_aps_cls);

% test regressors
res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.feature_extraction, x, bkg_fid), ...
                                                              dataset.imdb_test, 'UniformOutput', false);
final_aps_reg = [res_reg{1}(:).ap]';
best_model.reg_mAP_final_test = mean(final_aps_reg);


model = best_model;
fprintf('saving results...');
save([results_dir '/best_model_' int2str(bkg_numb)  'bkg.mat'], 'model');  

rmdir(boxes_dir,'s');
end
