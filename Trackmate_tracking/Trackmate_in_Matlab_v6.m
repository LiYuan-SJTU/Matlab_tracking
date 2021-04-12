clear;close all;
profile on;
addpath 'C:\Users\Administrator\Documents\Fiji.app\scripts'
videofolder = 'D:\20210331\0\';
dirname = dir([videofolder,'Basler*.mp4']);
videoname = dirname.name(1:end-4);

% ---------------------------------------
% Import Fiji and TrackMate classes
% ---------------------------------------
if exist('IJM','var')
    ij.IJ.run("Quit","");
else
    ImageJ;
end

fileID = fopen([videofolder,'Log_v6.txt'],'w');

import java.util.HashMap
import ij.*
import ImagePlus.*
import fiji.plugin.trackmate.*
import fiji.plugin.trackmate.detection.*
import fiji.plugin.trackmate.tracking.sparselap.*
import fiji.plugin.trackmate.tracking.*
import fiji.plugin.trackmate.visualization.hyperstack.*
import fiji.plugin.trackmate.providers.*
import fiji.plugin.trackmate.features.*
import fiji.plugin.trackmate.features.spot.*
import fiji.plugin.trackmate.action.*
import fiji.plugin.trackmate.io.*
import fiji.plugin.trackmate.features.track.*
import fiji.plugin.trackmate.util.*

% ---------------------------------------
% Pick a source image
% ---------------------------------------

% Get currently selected image
vr=VideoReader([videofolder,videoname,'.mp4']);
back=CreateBackground(vr,videoname);
vr.CurrentTime = 0;

% jpg_stack = dir([folder,'*.jpg']);
% firstImage = imread([jpg_stack(1).folder,'\',jpg_stack(1).name]);
% windowStack = ij.ImageStack(size(firstImage,2),size(firstImage,1));
firstImage = back(:,:);
windowStack = ij.ImageStack(size(firstImage,2),size(firstImage,1));

fprintf('Loading images...\n');
% nImg = min(length(jpg_stack),6000);
nImg = min(vr.Duration*vr.FrameRate,15000);
% for ii = 1:nImg
% 	currImg = ij.IJ.openImage([jpg_stack(ii).folder,'\',jpg_stack(ii).name]);
%     windowStack.addSlice(currImg.getProcessor());
% end
% ip = currImg.getProcessor();
warning('off');
k = 0;
while hasFrame(vr)
    if k>=nImg
        break;
    end
    k = k+1;
    img0 = readFrame(vr);
    img1 = double(img0(:,:,1))./double(back);
    img1(isnan(img1)) = 1;
    img1(img1>1) = 1;
    img2 = 1-img1(:,:);
    javaImage = ij.ImagePlus('',im2java(img2));
    windowStack.addSlice(javaImage.getProcessor());
end
% ip = javaImage.getProcessor();
% imp1 = ij.ImagePlus('title',ip);
imp2 = ij.ImagePlus('title',windowStack);

% width, height, nChannels, nSlices, nFrames
dims = imp2.getDimensions();

% nChannels, nSlices, nFrames
imp2.setDimensions(dims(3), dims(5), dims(4));
imp2.getCalibration().frameInterval = 1;

% -------------------------
% Instantiate model object
% -------------------------
   
model = Model();
   
% Set logger
model.setLogger(Logger.IJ_LOGGER)
   
% ------------------------
%  Prepare settings object
% ------------------------
      
settings = Settings();
settings.setFrom(imp2);

% Configure detector - We use a java map
settings.detectorFactory = LogDetectorFactory();
map = HashMap();
map.put('DO_SUBPIXEL_LOCALIZATION', true);
map.put('RADIUS', 4.);
map.put('TARGET_CHANNEL', 1);
map.put('THRESHOLD', 1.5);
map.put('DO_MEDIAN_FILTERING', false);
settings.detectorSettings = map;

% Configure tracker - We want to allow splits and fusions
settings.trackerFactory = SparseLAPTrackerFactory();
settings.trackerSettings = LAPUtils.getDefaultLAPSettingsMap(); % almost good enough
% settings.trackerSettings.put('ALLOW_TRACK_SPLITTING', false);
% settings.trackerSettings.put('ALLOW_TRACK_MERGING', false);
settings.trackerSettings.put('LINKING_MAX_DISTANCE',20.0);
settings.trackerSettings.put('GAP_CLOSING_MAX_DISTANCE',15.0);
settings.trackerSettings.put('MAX_FRAME_GAP',java.lang.Integer(3));

% trackAnalyzerProvider = TrackAnalyzerProvider();
% for key = 0:trackAnalyzerProvider.getKeys().size-1
%     settings.addTrackAnalyzer(trackAnalyzerProvider.getFactory(trackAnalyzerProvider.getKeys().get(key)));
% end
% 
% settings.addTrackAnalyzer(TrackSpeedStatisticsAnalyzer())
% settings.addTrackAnalyzer(TrackDurationAnalyzer());
% settings.addTrackAnalyzer(TrackLocationAnalyzer());

fprintf(fileID,'%s\n',settings.toString());
%-------------------
% Instantiate plugin
%-------------------
     
trackmate = TrackMate(model, settings);
trackmate.setNumThreads(32); % As many threads as you want.
        
%--------
% Process
%--------
fprintf('Processing...\n');

ok = trackmate.checkInput();
if ~ok
    display(trackmate.getErrorMessage());
end
  
ok = trackmate.process();
if ~ok
    display(trackmate.getErrorMessage());
end

fprintf(fileID,'%s\n',string(ij.IJ.getLog()));

%----------------
% Display results
%----------------
fprintf(fileID,'%s\n',strcat('Found ',num2str(model.getTrackModel().nTracks(true)),' tracks.'));
     
% Echo results
fprintf('Echoing results...\n');
file = java.io.File([videofolder,'RawResults_test.xml']);
fiji.plugin.trackmate.action.ExportTracksToXML.export(model, settings, file);
ij.IJ.run("Quit","");

filename=[videofolder,'RawResults_test.xml'];
opts = delimitedTextImportOptions("NumVariables", 6);

opts.DataLines = [3, Inf];
opts.Delimiter = " ";

opts.VariableNames = ["Var1", "t", "x", "y", "z", "Var6"];
opts.SelectedVariableNames = ["x", "y", "t"];
opts.VariableTypes = ["string", "double", "double", "double", "string", "string"];

opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts.ConsecutiveDelimitersRule = "join";
opts.LeadingDelimitersRule = "ignore";

opts = setvaropts(opts, ["Var1", "z", "Var6"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Var1", "z", "Var6"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, ["x", "y", "t"], "TrimNonNumeric", true);
opts = setvaropts(opts, ["x", "y", "t"], "ThousandsSeparator", ",");

Tracks = readtable(filename, opts);

Tracks = table2array(Tracks);

clear opts
Tracks(sum(isnan(Tracks),2)==3,:)=[];

nanpos=[find(isnan(Tracks(:,2)));length(Tracks)+1];
trackIDs = length(nanpos)-1;

RawResults(1:trackIDs) = struct('Position',[],...
    'FrameNum',[],'Velocity',[],'Angular',[]);

for ii = 1:trackIDs
    RawResults(ii).Position = Tracks(nanpos(ii)+1:nanpos(ii+1)-1,1:2);
    RawResults(ii).FrameNum = Tracks(nanpos(ii)+1:nanpos(ii+1)-1,3);
end

fprintf('Sorting results...\n');
ft = fittype( 'smoothingspline' );
opts1 = fitoptions( 'Method', 'SmoothingSpline' );
opts1.SmoothingParam = 0.012;
for ii = 1:trackIDs
    [~, xData] = prepareCurveData(RawResults(ii).FrameNum,RawResults(ii).Position(:,1));
    [tData, yData] = prepareCurveData(RawResults(ii).FrameNum,RawResults(ii).Position(:,2));

    % Fit model to data.
    [fitresult_x, ~] = fit( tData, xData, ft, opts1 );
    [fitresult_y, ~] = fit( tData, yData, ft, opts1 );
    v_x = (fitresult_x(tData)-fitresult_x(tData-0.2))/0.2;
    v_y = (fitresult_y(tData)-fitresult_y(tData-0.2))/0.2;
    
    theta0 = atan2(v_y,v_x);
    theta1 = unwrap(theta0);

    [fitresult_w, ~] = fit( tData, theta1, ft, opts1 );
    
    w = (fitresult_w(tData)-fitresult_w(tData-0.2))/0.2;
    RawResults(ii).Velocity = [v_x,v_y];
    RawResults(ii).Angular = [theta1,w];
    
end
save([videofolder,'TrackMate_Raw6.mat'],'RawResults');

profile viewer;
fclose(fileID);
% profsave;
exit();