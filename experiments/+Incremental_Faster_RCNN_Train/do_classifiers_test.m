function [ mAP ] = do_classifiers_test(cache_dir, conf, suffix, cls_mod , model, imdb, fid, varargin)
%% Parse inputs
ip = inputParser;
ip.addParamValue('num_of_reg',    300, @isscalar);

ip.parse(varargin{:});
opts = ip.Results;

switch cls_mod
  case 'SVMs'
    mAP = SVMs_test(conf, model, imdb, suffix);
  case 'gurls'
    mAP = GURLS_classifiers_test(cache_dir, conf, model, imdb, suffix);
  case 'rls'
    mAP = Faster_with_RLS_test(model, imdb, suffix, fid);
  case {'rls_falkon'}
    mAP = Faster_with_FALKON_test(model, conf, imdb, suffix, fid);  
  case {'rls_falkon_try'}
    mAP = Faster_with_FALKON_test_try(model, conf, imdb, suffix, fid);  
  case {'rls_falkon_try_try'}
    mAP = Faster_with_FALKON_test_try_try(model, conf, imdb, suffix, fid);
  case {'rls_falkon_try_try_half_neg'}
    mAP = Faster_with_FALKON_test_try_try(model, conf, imdb, suffix, fid);
  case {'rls_falkon_fullBootstrap'}
    mAP = Faster_with_FALKON_test_fullBootstrap(model, conf, imdb, suffix, fid);
  case {'rls_falkon_miniBootstrap'}
    mAP = Faster_with_FALKON_test_try_try(model, conf, imdb, suffix, fid);
  case {'rls_falkon_miniBootstrap_demo'}
    mAP = Faster_with_FALKON_miniBootstrap_test_exp_for_demo( model, conf, imdb, suffix, fid,  opts.num_of_reg);
  case {'rls_falkon_no_norm'}
    mAP = Faster_with_FALKON_test_no_norm(model, conf, imdb, suffix, fid);  
  case 'incremental'
    mAP = incremental_classifiers_test(cache_dir, conf, model, imdb, suffix);

end

