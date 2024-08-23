clear all;
close all;

filename = 'violet.mov';

v = VideoReader(filename);

vidWidth = v.Width;
vidHeight = v.Height;
frameRate = v.FrameRate;
num_frames = v.NumFrames;

video = struct('cdata', zeros(vidHeight, vidWidth, 3, 'uint8'), 'colormap', []);

% read all frames
for i = 1:num_frames
    video(i).cdata = readFrame(v);
end

%set here a non-linearity value NL
NL  = 10; %5%3; 

% define the ROI (top-left corner and size)
roi_x = 800; % x-coordinate of the top-left corner
roi_y = 385; % y-coordinate of the top-left corner
roi_width = 180;
roi_height = 105;

% initialize the array to store mean pixel values
mean_pixel_values = zeros(num_frames, 1);

% process each frame
for f = 1:num_frames
    % extract the ROI from the frame
    roi = video(f).cdata(roi_y:(roi_y+roi_height-1), roi_x:(roi_x+roi_width-1), :);

    Imgfft = sfft(imresize(rgb2gray(roi), [160 160]));
    [siz1,siz2] = size(Imgfft);
    
    %Debugging statements
    siz1;
    siz2;
 
    %create DoG Filter
    SpatDog = fspecial('gaussian',siz1,0.15) - fspecial('gaussian',siz2,0.49);
    FreqDog = sfft(SpatDog);
    multip = abs(FreqDog).*Imgfft;
    inv_1 = isfft(multip);
    
	% NL-DoG:
    % Non-linear application applied on top of the DOG filter
    Z = (sigmf(inv_1, [NL 0])*2)-1;
    Z = real(Z);
    
    %%refback = refback + im2double(Z);
	
   
    figure;
	%imagesc(Z);
    %imshow(im2double(Z));


    % % convert the ROI to grayscale
    % gray_roi = Z;
    % 
    % % compute the mean pixel value of the ROI
    % mean_pixel_values(f) = mean(gray_roi(:));
    % 
    % % debugging: Display the ROI
    % figure(1);
    % imshow(video(f).cdata);
    % hold on;
    % rectangle('Position', [roi_x, roi_y, roi_width, roi_height], 'EdgeColor', 'r', 'LineWidth', 2);
    % hold off;
    % title(sprintf('Frame %d', f));
    % pause(0.1); % pause to visualize the ROI
end

% aggregate mean pixel values per second
num_seconds = floor(num_frames / frameRate);
mean_sec = zeros(num_seconds, 1);

for s = 1:num_seconds
    start_idx = (s-1) * frameRate + 1;
    end_idx = s * frameRate;
    mean_sec(s) = mean(mean_pixel_values(start_idx:end_idx));
end

% plot the mean pixel values per frame
figure;
plot(mean_pixel_values);
title('Mean Pixel Value per Frame for ROI');
xlabel('Frames');
ylabel('Mean Pixel Value');
grid on;

% plot the mean pixel values per second
% figure;
% plot(mean_sec);
% title('Mean Pixel Value per Second');
% xlabel('Time (s)');
% ylabel('Mean Pixel Value');
% grid on;

% detrend the mean pixel values per second to remove linear tren
detrended_data = detrend(mean_sec);

% plot the detrended data
figure;
plot(detrended_data);
title('Detrended Data');
xlabel('Time (s)');
ylabel('Mean Pixel Value');
grid on;


% perform FFT on the detrended data to get
% a frequency spectrum of the detrended data
% allowing us to analyze the frequency components present in the ROI 
% of the video frames
figure
Y = fft(detrended_data);
Fs = 26;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
L = 26;             % Length of signal
t = (0:L-1)*T;        % Time vector
plot(Fs/L*(0:L-1),Y);
title('Reference Function');
grid on;


% design a bandpass filter 
% the normal resting heart rate for infants is typically between 120 to 160 beats 
% per minute (bpm), which translates to a frequency range of 2 to 2.67 Hz.
% not necessary because the frequency range is limited in this video (0-26
% Hz); overkill in such a short range, you end up overselecting with a
% filter signal worse than the original


% adaptive phase shifting (beamforming)
% shift by approximately 10 Hz in original frequency
Y_shifted = circshift(Y, 10);

% adjust the frequency range after the phase shift
% adjusted frequency range (from 0 to 36 Hz)
f_new = (0:(L-1)) * (1.4 / L);  

% manual array modification
Y_shifted(1:16) = Y(11:26);


% plot the phase-shifted result with normalized frequency axis
figure;
Fs = 1.4;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
t = (0:L-1)*T;        % Time vector
plot(f_new, Y_shifted);
title('Windowed, Phase-Shifted and Normalized HR');
xlabel('Normalized Freq (Hz)');
ylabel('Amplitude');
grid on;

 
