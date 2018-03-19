function dataset = voc2007_test(dataset, usage, use_flip, removed_classes, cache_name)
% change to point to your devkit install
devkit                      = voc2007_devkit();

switch usage
    case {'train'}
        dataset.imdb_train    = {  imdb_from_voc(devkit, 'test', '2007', use_flip) };
        dataset.roidb_train   = cellfun(@(x) x.roidb_func(x), dataset.imdb_train, 'UniformOutput', false);
    case {'test'}
         tmp    = load(['imdb/' cache_name '/imdb_voc_2007_test_new']);
         dataset.imdb_test = tmp.imdb;
%        dataset.imdb_test     = imdb_from_voc_reduced(devkit, 'test', '2007', use_flip, removed_classes, cache_name) ;
         dataset.roidb_test    = dataset.imdb_test.roidb_func(dataset.imdb_test, cache_name, 'removed_classes', removed_classes);
       % tmp    = load(['imdb/' cache_name '/imdb_voc_2007_test_new']);
       % dataset.imdb_test = tmp.imdb;
    otherwise
        error('usage = ''train'' or ''test''');
end

end
