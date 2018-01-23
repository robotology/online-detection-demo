function [ mAP ] = do_classifiers_test(cache_dir, conf, suffix, cls_mod , model, imdb)
%DO_CLASSIFIERS_TEST Summary of this function goes here
%   Detailed explanation goes here



switch cls_mod
  case 'SVMs'
    mAP = SVMs_test(conf, model, imdb, suffix);
  case 'gurls'
    mAP = GURLS_classifiers_test(cache_dir, conf, model, imdb, suffix);
  case 'rls'
    mAP = Faster_with_RLS_test(model, imdb, suffix);
  case 'incremental'
    mAP = incremental_classifiers_test(cache_dir, conf, model, imdb, suffix);

end

