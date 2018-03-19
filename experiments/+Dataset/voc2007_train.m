function dataset = voc2007_train(dataset, usage, use_flip, removed_classes, cache_name)
% change to point to your devkit install
devkit                      = voc2007_devkit();

switch usage
    case {'train'}
        dataset.imdb_train    = {  imdb_from_voc_reduced(devkit, usage, '2007', use_flip, removed_classes, cache_name) };
        dataset.roidb_train   = cellfun(@(x) x.roidb_func(x, cache_name,  'removed_classes', removed_classes), dataset.imdb_train, 'UniformOutput', false);
        tmp    = load(['imdb/' cache_name '/imdb_' dataset.imdb_train{1}.name '_new']);
        dataset.imdb_train{1} = tmp.imdb;
    case {'trainval'}
         tmp    = load(['imdb/' cache_name '/imdb_voc_2007_train_new']);
         dataset.imdb_train{1} = tmp.imdb;
%        dataset.imdb_train    = {  imdb_from_voc_reduced(devkit, usage, '2007', use_flip, removed_classes, cache_name) };
        dataset.roidb_train   = cellfun(@(x) x.roidb_func(x, cache_name,  'removed_classes', removed_classes), dataset.imdb_train, 'UniformOutput', false);
        tmp    = load(['imdb/' cache_name '/imdb_voc_2007_train_new']);
        dataset.imdb_train{1} = tmp.imdb;
     case {'val'}
        dataset.imdb_train    = {  imdb_from_voc_reduced(devkit, usage, '2007', use_flip, removed_classes, cache_name) };
        dataset.roidb_train   = cellfun(@(x) x.roidb_func(x, cache_name,  'removed_classes', removed_classes), dataset.imdb_train, 'UniformOutput', false);
        tmp    = load(['imdb/' cache_name '/imdb_' dataset.imdb_train{1}.name '_new']);
        dataset.imdb_train{1} = tmp.imdb;
        
    case {'test'}
        dataset.imdb_test     = imdb_from_voc(devkit, 'train', '2007', use_flip) ;
        dataset.roidb_test    = dataset.imdb_test.roidb_func(dataset.imdb_test);
    otherwise
        error('usage = ''train'' or ''test''');
end

end
