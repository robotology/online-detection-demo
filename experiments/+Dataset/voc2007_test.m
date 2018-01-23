function dataset = voc2007_test(dataset, usage, use_flip, removed_classes)
% Pascal voc 2007 test set
% set opts.imdb_train opts.roidb_train 
% or set opts.imdb_test opts.roidb_train

% change to point to your devkit install
devkit                      = voc2007_devkit();

switch usage
    case {'train'}
        dataset.imdb_train    = {  imdb_from_voc(devkit, 'test', '2007', use_flip) };
        dataset.roidb_train   = cellfun(@(x) x.roidb_func(x), dataset.imdb_train, 'UniformOutput', false);
    case {'test'}
        if length(removed_classes)
            dataset.imdb_test     = imdb_from_voc_reduced(devkit, 'test', '2007', use_flip, removed_classes) ;
            dataset.roidb_test    = dataset.imdb_test.roidb_func(dataset.imdb_test, 'removed_classes', removed_classes);
            tmp    = load(['imdb/cache/imdb_' dataset.imdb_test.name '_new']);
            dataset.imdb_test = tmp.imdb;
        else
            dataset.imdb_test     = imdb_from_voc(devkit, 'test', '2007', use_flip) ;
            dataset.roidb_test    = dataset.imdb_test.roidb_func(dataset.imdb_test);
        end
    otherwise
        error('usage = ''train'' or ''test''');
end

end