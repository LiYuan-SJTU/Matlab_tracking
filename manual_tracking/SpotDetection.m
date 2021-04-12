function [RawResults,fps] = SpotDetection(foldername)

    videoname = dir([foldername,'\Basler*.mp4']);
    if isempty(videoname)
        videoname = dir([foldername,'\*.mp4']);
    end

    fprintf('%s\t\t%s\n','folder:',videoname.folder)
    fprintf('%s\t%s\n','filename:',videoname.name);
    fprintf('%s\t\t%f %s\n','bytes:',videoname.bytes/1024^3,'GB');

    vr = VideoReader(videoname.name);
    back=CreateBackground(vr,videoname.name(1:end-4));
    nImg = vr.Duration*vr.FrameRate;
    fps = vr.FrameRate;
    RawRr = struct('Area',[],'Centroid',[],'EquivDiameter',[],'Frame',[]);
    parfor ii = 1:nImg
        img0 = read(vr,ii);
        img1 = mean(double(img0)./double(back),3);
        img1(isnan(img1)) = 1;
        img1(img1>1) = 1;
        img2 = imbinarize(1-img1,0.12);
        bw = gpuArray(bwareaopen(img2,3));
        s = regionprops(bw,{'Area','Centroid','EquivDiameter'});
        for jj = 1:length(s)
            s(jj).Frame = ii;
        end
        RawRr = [RawRr;s];
        
    end
    RawResults = gather(RawRr(2:end));
%     save('RawResults_spot.mat','RawResults','fps','-v7.3');
end