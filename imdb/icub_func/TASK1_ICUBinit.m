clear ICUBopts

% dataset

ICUBopts.dataset='iCubWorld-Transformations_devkit';

% get devkit directory with forward slashes
devkitroot=strrep(fileparts(fileparts(mfilename('fullpath'))),'\','/');

% change this path to point to your copy of the iCubWorld-Transformations data
ICUBopts.datadir=[devkitroot '/datasets/']; %ELISA to check

% change this path to a writable directory for your results
ICUBopts.resdir=[devkitroot '/results/' ICUBopts.dataset '/'];

% change this path to a writable local directory for the example code
ICUBopts.localdir=[devkitroot '/local/' ICUBopts.dataset '/'];

% initialize the training set

ICUBopts.trainset='train'; % use train for development
% ICUBopts.trainset='trainval'; % use train+val for final challenge

% initialize the test set

ICUBopts.testset='val'; % use validation data for development test set
% ICUBopts.testset='test'; % use test  set for final challenge

% initialize main challenge paths

ICUBopts.annopath=[ICUBopts.datadir ICUBopts.dataset '/Annotations/%s.xml'];
ICUBopts.imgpath=[ICUBopts.datadir ICUBopts.dataset '/Images/%s.jpg'];
ICUBopts.imgsetpath=[ICUBopts.datadir ICUBopts.dataset '/ImageSets/%s.txt'];
fprintf(ICUBopts.imgsetpath);
ICUBopts.clsimgsetpath=[ICUBopts.datadir ICUBopts.dataset '/ImageSets/Main/%s_%s.txt'];
ICUBopts.clsrespath=[ICUBopts.resdir 'Main/%s_cls_' ICUBopts.testset '_%s.txt'];
ICUBopts.detrespath=[ICUBopts.resdir 'Main/%s_det_' ICUBopts.testset '_%s.txt'];

% initialize segmentation task paths

%ICUBopts.seg.clsimgpath=[ICUBopts.datadir ICUBopts.dataset '/SegmentationClass/%s.png'];
%ICUBopts.seg.instimgpath=[ICUBopts.datadir ICUBopts.dataset '/SegmentationObject/%s.png'];

%ICUBopts.seg.imgsetpath=[ICUBopts.datadir ICUBopts.dataset '/ImageSets/Segmentation/%s.txt'];

%ICUBopts.seg.clsresdir=[ICUBopts.resdir 'Segmentation/%s_%s_cls'];
%ICUBopts.seg.instresdir=[ICUBopts.resdir 'Segmentation/%s_%s_inst'];
%ICUBopts.seg.clsrespath=[ICUBopts.seg.clsresdir '/%s.png'];
%ICUBopts.seg.instrespath=[ICUBopts.seg.instresdir '/%s.png'];

% initialize layout task paths

%ICUBopts.layout.imgsetpath=[ICUBopts.datadir ICUBopts.dataset '/ImageSets/Layout/%s.txt'];
%ICUBopts.layout.respath=[ICUBopts.resdir 'Layout/%s_layout_' ICUBopts.testset '.xml'];

% initialize action task paths

%ICUBopts.action.imgsetpath=[ICUBopts.datadir ICUBopts.dataset '/ImageSets/Action/%s.txt'];
%ICUBopts.action.clsimgsetpath=[ICUBopts.datadir ICUBopts.dataset '/ImageSets/Action/%s_%s.txt'];
%ICUBopts.action.respath=[ICUBopts.resdir 'Action/%s_action_' ICUBopts.testset '_%s.txt'];

% initialize the VOC challenge options

% classes

ICUBopts.classes={... %ELISA todo
%     '__background__'
    'soapdispenser5'
    'ringbinder4'
    'flower7'
%     'perfume1'
%     'hairclip2'
%     'hairbrush3'
%     'sunglasses7' 
%     'sodabottle2'
%     'ovenglove7'
%     'remote7'
};

ICUBopts.nclasses=length(ICUBopts.classes);	

% poses

ICUBopts.poses={...
    'Unspecified'
    'Left'
    'Right'
    'Frontal'
    'Rear'};

ICUBopts.nposes=length(ICUBopts.poses);

% layout parts

%ICUBopts.parts={...
%    'head'
%    'hand'
%    'foot'};    

%ICUBopts.nparts=length(ICUBopts.parts);

%ICUBopts.maxparts=[1 2 2];   % max of each of above parts

% actions

%ICUBopts.actions={...    
%    'other'             % skip this when training classifiers
%    'jumping'
%    'phoning'
%    'playinginstrument'
%    'reading'
%    'ridingbike'
%    'ridinghorse'
%    'running'
%    'takingphoto'
%    'usingcomputer'
%    'walking'};

%ICUBopts.nactions=length(ICUBopts.actions);

% overlap threshold

ICUBopts.minoverlap=0.5;

% annotation cache for evaluation

ICUBopts.annocachepath=[ICUBopts.localdir '%s_anno.mat']; %ELISA to check what it is

% options for example implementations

ICUBopts.exfdpath=[ICUBopts.localdir '%s_fd.mat'];
