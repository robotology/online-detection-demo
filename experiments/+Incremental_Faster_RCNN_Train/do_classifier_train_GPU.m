function [ model_classifier ] = do_classifier_train_GPU(conf, cnn_model, cls_mod, options, imdb_train, rebalancing, rebal_alpha, negatives_selection, fpid)

switch cls_mod
    case {'SVMs'}
           fprintf('svm classifier chosen\n')
           
           crop_mode    = 'warp';
           crop_padding = 16;
           layer        = 7;
           k_folds      = 0;
           
           [model_classifier, model_classifier_kfold] = ...
           svm_classifiers_train(conf, imdb_train, cnn_model, ...
          'layer',        layer, ...
          'k_folds',      k_folds, ...
          'crop_mode',    crop_mode, ...
          'crop_padding', crop_padding);
        
    case {'gurls'}
        fprintf('gurls classifier chosen \n')
        
        model_classifier = GURLS_classifiers_train(options, conf, cnn_model, imdb_train);
        
    case {'rls'}
        fprintf('rls classifier chosen \n')
        
        model_classifier = Faster_with_RLS_train(options, conf, cnn_model, imdb_train);
    
    case {'rls_randBKG'}
        fprintf('rls classifier with random background samples chosen \n')
        
        if ~exist('rebalancing', 'var') || isempty(rebalancing)
          rebalancing = true;
        end
        
        model_classifier = Faster_with_RLS_train_randBKG(options, conf, cnn_model, imdb_train, negatives_selection,...
                                                         rebalancing, fpid,'rebal_alpha', rebal_alpha);
                                                     
    case {'rls_falkon'}
        fprintf('rls classifier with FALKON implementation chosen \n')
        
        rebalancing = false;
        
        model_classifier = Faster_with_FALKON_train_randBKG(options, conf, cnn_model, imdb_train, negatives_selection,...
                                                         rebalancing, fpid,'rebal_alpha', rebal_alpha);
    case {'rls_falkon_GPU'}
        fprintf('rls classifier with FALKON implementation chosen \n')

        rebalancing = false;

        model_classifier = Faster_with_FALKON_train_randBKG_GPU(options, conf, cnn_model, imdb_train, negatives_selection,...
                                                         rebalancing, fpid,'rebal_alpha', rebal_alpha);
    otherwise
        error('classifier unknown');
end

