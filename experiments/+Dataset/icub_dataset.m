function dataset = icub_dataset(dataset, usage, use_flip, cache_name, img_set,chosen_classes)
% iCub-Transformations trainval set 
% set opts.imdb_train opts.roidb_train 
% or set opts.imdb_test opts.roidb_train

% change to point to your devkit install
icub_dev                      = icub_devkit();

switch usage
    case {'train'}
        dataset.imdb_train    = {  imdb_from_icub(icub_dev, img_set, use_flip, cache_name, chosen_classes)};
        dataset.roidb_train   = cellfun(@(x) x.roidb_func(x, cache_name), dataset.imdb_train, 'UniformOutput', false);
        tmp                   = load(['imdb/' cache_name '/imdb_' dataset.imdb_train{1}.name]);
        dataset.imdb_train{1} = tmp.imdb;
    case {'test'}
        dataset.imdb_test     = {  imdb_from_icub(icub_dev, img_set, use_flip, cache_name, chosen_classes)}; 
        dataset.roidb_test    = cellfun(@(x) x.roidb_func(x, cache_name), dataset.imdb_test, 'UniformOutput', false); 
        tmp                   = load(['imdb/' cache_name '/imdb_' dataset.imdb_train{1}.name]);
        dataset.imdb_train{1} = tmp.imdb;
    case {'val'}
        dataset.imdb_val      = {  imdb_from_icub(icub_dev, img_set, use_flip, cache_name, chosen_classes)}; 
        dataset.roidb_val     = cellfun(@(x) x.roidb_func(x,cache_name), dataset.imdb_val, 'UniformOutput', false); 
        tmp                   = load(['imdb/' cache_name '/imdb_' dataset.imdb_train{1}.name]);
        dataset.imdb_train{1} = tmp.imdb;
    case {'TASK1_train'}
        dataset.TASK1.imdb_train    = {  imdb_from_icub(icub_dev, 'TASK1_train', use_flip)};
        dataset.TASK1.roidb_train   = cellfun(@(x) x.roidb_func(x), dataset.TASK1.imdb_train, 'UniformOutput', false);
   
    otherwise
        error('usage = ''train'' or ''test''');
end

end
