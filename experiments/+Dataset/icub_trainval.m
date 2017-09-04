function dataset = icub_trainval(dataset, usage, use_flip)
% iCub-Transformations trainval set 
% set opts.imdb_train opts.roidb_train 
% or set opts.imdb_test opts.roidb_train

% change to point to your devkit install
icub_dev                      = icub_devkit();

switch usage
    case {'train'}
        dataset.imdb_train    = {  imdb_from_icub(icub_dev, 'train', use_flip)}; %ELISA  todo
        dataset.roidb_train   = cellfun(@(x) x.roidb_func(x), dataset.imdb_train, 'UniformOutput', false); %ELISA  todo
    case {'TASK2_train'}
        dataset.TASK2.imdb_train    = {  imdb_from_icub(icub_dev, 'TASK2_train', use_flip)}; %ELISA  todo
        dataset.TASK2.roidb_train   = cellfun(@(x) x.roidb_func(x), dataset.TASK2.imdb_train, 'UniformOutput', false); %ELISA  todo
    case {'TASK1_train'}
        dataset.TASK1.imdb_train    = {  imdb_from_icub(icub_dev, 'TASK1_train', use_flip)}; %ELISA  todo
        dataset.TASK1.roidb_train   = cellfun(@(x) x.roidb_func(x), dataset.TASK1.imdb_train, 'UniformOutput', false); %ELISA  todo
    case {'test'}
        error('only supports one source test currently');  
    otherwise
        error('usage = ''train'' or ''test''');
end

end
