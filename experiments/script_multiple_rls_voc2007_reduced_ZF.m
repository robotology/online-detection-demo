function script_multiple_rls_voc2007_reduced_ZF(bkg_numbs, sigmas, gpu_id)

gpuDevice(gpu_id);

FALKON_init_variables;
% GURLS_init_variables;

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
% model.bbox_regressors = cellfun(@(x, y) Incremental_Faster_RCNN_Train.do_bbox_regressor_train(conf_fast_rcnn, model.feature_extraction, x, y), ... 
%                                                                           dataset.imdb_train, dataset.roidb_train);

% model.bbox_regressors = load('bbox_reg/bbox_regressor_final.mat');

negatives_selection.policy = 'from_all';
rebalancing = 'inv_freq';

% alphas = 0.1:0.1:1;
alphas = 0;
% bkg_numbs = 1000:2000:11000;
% bkg_numbs = 5000;
% sigmas = randperm(100,10)
% sigmas = [10 12 14 16 18 20 22 24 26 28 30 40 50 60 70 80 90 100];
lambdas = [0.1 0.02 0.01 0.009 0.001 0.0001 0.00001 0.000001];
results_matrix_cls = zeros(length(sigmas),length(lambdas));
results_matrix_reg = zeros(length(sigmas),length(lambdas));
for j=1:length(bkg_numbs)
%     file_name = [results_dir '/precisions_' int2str(bkg_numbs(j)) '_sigma_' int2str(bkg_numbs(j)) '.txt'];
%     fid = fopen(file_name, 'wt');
%     fprintf( fid, 'Results for %d background regions \n', bkg_numbs(j));  
    for k=1:length(sigmas)
        file_name = [results_dir '/precisions_' int2str(bkg_numbs(j)) '_sigma_' int2str(sigmas(k)) '.txt'];
        fid = fopen(file_name, 'wt');
        train_classifier_options.sigma = sigmas(k);
        fprintf( fid, 'Results for sigma = %f \n', train_classifier_options.sigma);
        for l=1:length(lambdas)
            train_classifier_options.lambda = lambdas(l);
            fprintf( fid, 'lambda = %f \n', train_classifier_options.lambda);
            for i=1:length(alphas)
                rebal_alpha = alphas(i);
%                 fprintf( fid, 'alpha = %f \n', rebal_alpha);
                negatives_selection.N = bkg_numbs(j);

                % train classifiers
                model.classifiers.falkon = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifier_train(conf_fast_rcnn, model.feature_extraction, cls_mode, ...
                                                                                  train_classifier_options, x, rebalancing, rebal_alpha, negatives_selection, fid), ...
                                                                                  dataset.imdb_train, 'UniformOutput', false);

                addpath('./datasets/VOCdevkit2007/VOCcode_incremental');
                rmdir(boxes_dir,'s');
                mkdir(boxes_dir);

                % test classifiers
                res_cls = cellfun(@(x) Incremental_Faster_RCNN_Train.do_classifiers_test(train_classifier_options.cache_dir, conf_fast_rcnn, '',  cls_mode, ...
                                                                                  model.classifiers.falkon{1}, x, fid), dataset.imdb_test, 'UniformOutput', false);
                aps_cls = [res_cls{1}(:).ap]';
                results_matrix_cls(k,l) = mean(aps_cls);

                % test regressors
                res_reg = cellfun(@(x) Incremental_Faster_RCNN_Train.do_regressor_test(conf_fast_rcnn, model.bbox_regressors.bbox_reg, model.feature_extraction, x, fid), ...
                                                                                  dataset.imdb_test, 'UniformOutput', false);
                aps_reg = [res_reg{1}(:).ap]';
                results_matrix_reg(k,l) = mean(aps_reg);
            end
        end
        fclose(fid);
        fprintf('saving partial  results');
        save([results_dir '/cls_mAP_' int2str(sigmas(k))  '.mat'], 'results_matrix_cls');
        save([results_dir '/reg_mAP_' int2str(sigmas(k))  '.mat'], 'results_matrix_reg');
    end
end

%save results
fprintf('saving results');

save([results_dir '/all_cls_mAP.mat', 'results_matrix_cls']);
save([results_dir '/all_reg_mAP.mat', 'results_matrix_reg']);

end

function [anchors, output_width_map, output_height_map] = proposal_prepare_anchors(conf, cache_name, test_net_def_file)
    [output_width_map, output_height_map] ...                           
                                = proposal_calc_output_size(conf, test_net_def_file);
    anchors                = proposal_generate_anchors(cache_name, ...
                                    'scales',  2.^[3:5]);
end
