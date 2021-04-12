function Trackmate_in_Matlab_fun(videofolder)

    addpath 'C:\Users\Administrator\Documents\Fiji.app\scripts'
    dirname = dir([videofolder,'*.mp4']);
    videoname = dirname.name(1:end-4);
    fprintf('%s\t\t%s\n','folder:',dirname.folder)
    fprintf('%s\t%s\n','filename:',dirname.name);
    fprintf('%s\t\t%f %s\n','bytes:',dirname.bytes/1024^3,'GB');

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

    firstImage = back(:,:);
    windowStack = ij.ImageStack(size(firstImage,2),size(firstImage,1));

    fprintf('Loading images...\n');
    nImg = min(vr.Duration*vr.FrameRate,15000);
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
    map.put('THRESHOLD', 1.2);
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

    fprintf(fileID,'%s\n',settings.toString());
    %-------------------
    % Instantiate plugin
    %-------------------

    trackmate = TrackMate(model, settings);
    trackmate.setNumThreads(40); % As many threads as you want.

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
    pause(1);
    ij.IJ.run("Quit","");
    fclose(fileID);
    exit();
end