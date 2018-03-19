function script_FALKON_on_iCWT_trainval_ZF_7000(bkg_numbs, sigmas, lambdas, nyst_centres, iterations, gpu_id)

gpuDevice(gpu_id);

% script_faster_rcnn_ICUB_ZF(gpu_id);

fprintf('*********************************************************************************************************\n');
fprintf('*********************************************************************************************************\n');
fprintf('************************************* END OF NETWORK TRAINING *********************************************\n');
fprintf('*********************************************************************************************************\n');
fprintf('*********************************************************************************************************\n');


FALKON_iCWT_trainval_TASK2_init_variables;

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
reg_mode = 'no_norm'; %????????????????????????????????????????????????????????
model.bbox_regressors = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y, 'reg_mode', reg_mode), ... 
                                                                          dataset.TASK2.imdb_train, dataset.TASK2.roidb_train);

if(train_classifier_options.cross_validation.required)
    train_classifier_options.cross_validation.sigmas = sigmas;
    train_classifier_options.cross_validation.lambdas = lambdas;
%     % region proposals generation    
%     dataset.TASK2.roidb_val = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn , output_dir, x, y), ...
%                                                                               dataset.TASK2.imdb_val, dataset.TASK2.roidb_val, 'UniformOutput', false);
%     % features extraction
%     cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_extract_features(conf_fast_rcnn, model.feature_extraction, feature_layer, x, y), ...
%                                                                           dataset.TASK2.imdb_val, dataset.TASK2.roidb_val);
end

best_model = {};
file_name = [results_dir '/test_bkg' int2str(bkg_numbs) '.txt'];
bkg_fid = fopen(file_name, 'wt');
fprintf( bkg_fid, 'Results for bkg_num = %f \n', bkg_numbs);

best_model.results_matrix_cls = zeros(length(nyst_centres),length(sigmas),length(lambdas));
best_model.results_matrix_reg = zeros(length(nyst_centres),length(sigmas),length(lambdas));
best_model.reg_mAP_val = 0.0;
for m=1:length(nyst_centres)
    train_classifier_options.M = nyst_centres(m);
    for k=1:length(sigmas)
        file_name = [results_dir '/precisions_bkg' int2str(bkg_numbs) '_M' int2str(nyst_centres(m)) '_sigma' int2str(sigmas(k)) '.txt'];
        fid = fopen(file_name, 'wt');
        train_classifier_options.sigma = sigmas(k);
        fprintf( fid, 'Results for:\nNumber of Nystrom Centres = %f \n', train_classifier_options.M);
        fprintf( fid, 'Sigma = %f \n', train_classifier_options.sigma);
        for l=1:length(lambdas)
            train_classifier_options.lambda = lambdas(l);
            fprintf( fid, 'Lambda = %f \n', train_classifier_options.lambda);

            negatives_selection.N = bkg_numbs;

            % train classifiers
            rebal_alpha = 0;
            model.classifiers.falkon = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, cls_mode, ...
                                                                              train_classifier_options, x, rebalancing, rebal_alpha, negatives_selection, fid), ...
                                                                              dataset.TASK2.imdb_train, 'UniformOutput', false);

            addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
            rmdir(boxes_dir,'s');
            mkdir(boxes_dir);

            % test classifiers
            res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
                                                                              model.classifiers.falkon{1}, x, fid), dataset.TASK2.imdb_test, 'UniformOutput', false);
            aps_cls = [res_cls{1}(:).ap]';
            best_model.results_matrix_cls(m,k,l) = mean(aps_cls);

            % test regressors
            res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.feature_extraction, x, fid), ...
                                                                              dataset.TASK2.imdb_test, 'UniformOutput', false);
            aps_reg = [res_reg{1}(:).ap]';
            best_model.results_matrix_reg(m,k,l) = mean(aps_reg);

            if(best_model.reg_mAP_val <= mean(aps_reg))
                best_model.detectors = model.classifiers.falkon;
                best_model.cls_mAP_val = mean(aps_cls);
                best_model.reg_mAP_val = mean(aps_reg);
                best_model.lambda = lambdas(l);
                best_model.sigma = sigmas(k);
                best_model.M =  nyst_centres(m);
                
            end
            
        end
    end
    model_to_save = best_model;
    fprintf('saving partial results...');
    save([results_dir '/best_model_' int2str(bkg_numbs)  'bkg_tmp.mat'], 'model_to_save'); 
    fclose(fid);

end
fprintf('saving workspace...');
save([results_dir 'trainval_iCWT_TASK2.mat'], '-v7.3'); %?????????????????????????????????????????????????
fprintf(bkg_fid, 'Best model for %f background regions is: \n', bkg_numbs);
fprintf(bkg_fid, 'sigma = %f  \n', best_model.sigma);
fprintf(bkg_fid, 'lambda = %f  \n', best_model.lambda);
fprintf(bkg_fid, 'M = %f  \n', best_model.M);
fprintf(bkg_fid, 'and has mAP after classification on test set = %f  \n', best_model.cls_mAP_val);
fprintf(bkg_fid, 'and has mAP after regression on test set = %f  \n', best_model.reg_mAP_val);


%% TEST
rmdir(boxes_dir,'s');
% mkdir(boxes_dir);
% 
% % test classifiers
% res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
%                                                               best_model.detectors{1}, x, bkg_fid), dataset.TASK2.imdb_test, 'UniformOutput', false);
% final_aps_cls = [res_cls{1}(:).ap]';
% best_model.cls_mAP_final_test = mean(final_aps_cls);
% 
% % test regressors
% res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors, model.feature_extraction, x, bkg_fid, 'reg_mode', reg_mode), ...
%                                                               dataset.TASK2.imdb_test, 'UniformOutput', false);
% final_aps_reg = [res_reg{1}(:).ap]';
% best_model.reg_mAP_final_test = mean(final_aps_reg);
% 
% 
% model = best_model;
% fprintf('saving results...');
% save([results_dir '/best_model_' int2str(bkg_numbs)  'bkg_norm.mat'], 'model');  
% 
% rmdir(boxes_dir,'s');
end
