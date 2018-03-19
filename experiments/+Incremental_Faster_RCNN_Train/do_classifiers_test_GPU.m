function [ mAP ] = do_classifiers_test_GPU(cache_dir, conf, suffix, cls_mod , model, imdb, fid)

switch cls_mod
  case 'SVMs'
    mAP = SVMs_test(conf, model, imdb, suffix);
  case 'gurls'
    mAP = GURLS_classifiers_test(cache_dir, conf, model, imdb, suffix);
  case 'rls'
    mAP = Faster_with_RLS_test(model, imdb, suffix, fid);
  case {'rls_falkon'}
    mAP = Faster_with_FALKON_test(model, imdb, suffix, fid);
  case {'rls_falkon_GPU'}
    mAP = Faster_with_FALKON_test_GPU(model, imdb, suffix, fid);        
  case 'incremental'
    mAP = incremental_classifiers_test(cache_dir, conf, model, imdb, suffix);

end

