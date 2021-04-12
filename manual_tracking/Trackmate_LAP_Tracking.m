% function Manual_Tracking(foldername)
profile on;
% foldername = pwd;
addpath 'C:\Users\Administrator\Documents\Fiji.app\scripts'
% 
% fprintf('Spot Detecting...\n');
% % [results_table,fps] = SpotDetection(foldername);
% 
% fprintf('Loading spots...\n');
% 
% % load([foldername,'\RawResults_spot.mat'],'RawResults','fps');
% 
if exist('IJM','var')
    ij.IJ.run("Quit","");
else
    ImageJ;
end

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
% 
% fileID = fopen([foldername,'Log_v6.txt'],'w');
% 
% 
% % ----------
% %   MAIN
% % ----------
% 
imp = ij.ImagePlus();
imp.getCalibration().frameInterval = 1/fps;
% clear RawResults;
fprintf('Converting the spots data...\n');
frames = vertcat(results_table.Frame);
xyData = vertcat(results_table.Centroid);
xs = xyData(:,1);
ys = xyData(:,2);
z = 0;
areas = vertcat(results_table.Area);
spots = SpotCollection();
spots.setNumThreads(20);
for ii = 1:length(xs)
    x = xs(ii);
    y = ys(ii);
    frame = frames(ii);
    area = areas(ii);
    t = (frame-1)*1/fps;
    radius = sqrt(area/pi);
    quality = ii;
    spot = Spot(x,y,z,radius,quality);
    spot.putFeature('POSITION_T',java.lang.Double(t));
    spots.add(spot,java.lang.Integer(frame-1));
end
spots.setVisible(true);
fprintf('Setting...\n');
cal = imp.getCalibration();

model = Model();
model.setLogger(Logger.IJ_LOGGER);
model.setPhysicalUnits(cal.getUnit(),cal.getTimeUnit());

settings = Settings();
settings.setFrom(imp);

model.setSpots(spots,false);

settings.detectorFactory = ManualDetectorFactory();
map = HashMap();
% map.put('RADIUS', 4.);
settings.detectorSettings = map;

settings.trackerFactory = SparseLAPTrackerFactory();
settings.trackerSettings = LAPUtils.getDefaultLAPSettingsMap(); % almost good enough
% settings.trackerSettings.put('ALLOW_TRACK_SPLITTING', false);
% settings.trackerSettings.put('ALLOW_TRACK_MERGING', false);
settings.trackerSettings.put('LINKING_MAX_DISTANCE',20.0);
settings.trackerSettings.put('GAP_CLOSING_MAX_DISTANCE',15.0);
settings.trackerSettings.put('MAX_FRAME_GAP',java.lang.Integer(3));

% fprintf(fileID,'%s\n',settings.toString());

trackmate = TrackMate(model,settings);

fprintf('Processing LAP...\n');
ok = trackmate.checkInput();
% ok = ok && trackmate.execInitialSpotFiltering();
% ok = ok && trackmate.computeSpotFeatures( true ); 
% ok = ok && trackmate.execSpotFiltering( true );
ok = ok && trackmate.execTracking();
ok = ok && trackmate.computeTrackFeatures( true );
ok = ok && trackmate.execTrackFiltering( true );
ok = ok && trackmate.computeEdgeFeatures( true );

if ~ok
    display(trackmate.getErrorMessage());
end

% fprintf(fileID,'%s\n',string(ij.IJ.getLog()));

% fprintf(fileID,'%s\n',strcat('Found ',num2str(model.getTrackModel().nTracks(true)),' tracks.'));
fprintf('Echoing results...\n');

file = java.io.File([foldername,'RawResults_test.xml']);
fiji.plugin.trackmate.action.ExportTracksToXML.export(model, settings, file);
pause(1);
ij.IJ.run("Quit","");
% fclose(fileID);
profile viewer;
% exit();
% end
