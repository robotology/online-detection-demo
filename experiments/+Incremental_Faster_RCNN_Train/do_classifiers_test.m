function [ mAP ] = do_classifiers_test(conf, model, suffix, cls_mod , imdb)
%DO_CLASSIFIERS_TEST Summary of this function goes here
%   Detailed explanation goes here



switch cls_mod
  case 'SVMs'
    mAP = SVMs_test(conf, model, imdb, suffix);
  case 'gurls'
    maP = GURLS_classifiers_test(conf, model, imdb, suffix);


end

