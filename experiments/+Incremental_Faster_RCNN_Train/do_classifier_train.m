function [ model_classifier ] = do_classifier_train(conf, cnn_model, cls_mod, imdb_train )

% -------------------- CONFIG --------------------
% net_file     = './data/caffe_nets/finetune_voc_2007_trainval_iter_70k';
% cache_name   = 'v1_finetune_voc_2007_trainval_iter_70k';
% cls_mod can be 'SVMs' or 'incRLS'
crop_mode    = 'warp';
crop_padding = 16;
layer        = 7;
k_folds      = 0;

switch cls_mod
    case {'SVMs'}
           fprintf('svm classifier \n')
           [model_classifier, model_classifier_kfold] = ...
           svm_classifiers_train(conf, imdb_train, cnn_model, ...
          'layer',        layer, ...
          'k_folds',      k_folds, ...
          'crop_mode',    crop_mode, ...
          'crop_padding', crop_padding);
        
    case {'gurls'}
        fprintf('gurls classifier \n')
        options = struct;
        options.kernelfun = 'linear';
    %         options.Xval = [];
    %         options.yval = [];
    %         options.loadData = true;
    %         options.loadingFcn = @() collectORload_xy_stacked( dbtruepath_tr, dbtruepath_val, save_Xtr, save_Xval, saving_ext, ...
    %             train_reg_path, val_reg_path, input_dir_fc );

        model_classifier = GURLS_classifiers_train(options, imdb_train, cnn_model, conf);

        % [X, y, Ntrain] = rls_out.options.loadingFcn();
        % rls_model = gurls_train(X,y);
    otherwise
        error('classifier unknown');
end

