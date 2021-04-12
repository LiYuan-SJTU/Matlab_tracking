function Trackmate_Velocity(videofolder)
    parpool;
    fprintf('%s\n',videofolder);
    fprintf('Rereading results...\n');
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
    % ft = fittype( 'smoothingspline' );
    % opts1 = fitoptions( 'Method', 'SmoothingSpline' );
    % opts1.SmoothingParam = 0.012;
    % parfor_progress(trackIDs);
    parfor ii = 1:trackIDs

        [~, xData] = prepareCurveData(RawResults(ii).FrameNum,RawResults(ii).Position(:,1));
        [tData, yData] = prepareCurveData(RawResults(ii).FrameNum,RawResults(ii).Position(:,2));
        % parfor_progress;

        v_x0 = csaps(tData,xData,0.012,tData);
        v_x1 = csaps(tData,xData,0.012,tData-0.2);
        v_x = (v_x0-v_x1)/0.2;
        v_y0 = csaps(tData,yData,0.012,tData);
        v_y1 = csaps(tData,yData,0.012,tData-0.2);
        v_y = (v_y0-v_y1)/0.2;

        theta0 = atan2(v_y,v_x);
        theta1 = unwrap(theta0);

        w0 = csaps(tData,theta1,0.012,tData);
        w1 = csaps(tData,theta1,0.012,tData-0.2);
        w = (w0-w1)/0.2;

        RawResults(ii).Velocity = [v_x,v_y];
        RawResults(ii).Angular = [theta1,w];

    end
    save([videofolder,'TrackMate_Raw6.mat'],'RawResults');
    % parfor_progress(0);
    exit();
end
