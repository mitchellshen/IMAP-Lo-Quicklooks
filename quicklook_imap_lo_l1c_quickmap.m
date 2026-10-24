%% quicklook_imap_lo_l1c_quickmap.m
% Quicklook plotter for IMAP-Lo L1C quickmap CDF files
% (imap_lo_l1c_quickmap_YYYYMMDD-repointNNNNN_vNNN_XXXX.cdf)
%
% Requires the NASA SPDF CDF-MATLAB reader (spdfcdfread / spdfcdfinfo),
% which ships with MATLAB's CDF support (or download from
% https://spdf.gsfc.nasa.gov/pub/software/cdf/)
%
% Usage: edit `cdf_file` below and run.

clear; clc; close all;

%% ---- Settings ----
% cdf_file = 'imap_lo_l1c_quickmap_20251109-repoint00043_v001_0001.cdf';
addpath('/Users/mitchellshen/Library/CloudStorage/Dropbox-Personal/Dust_experiment/matlab_cdf391_patch-arm64')
cdf_file = '/Users/mitchellshen/Downloads/imap_lo_l1c_quickmap_20251109-repoint00043_v001.0001.cdf';
var_to_plot = 'counts';     % 'flux','counts','exposure','signal_to_noise','rate', etc.

%% ---- Read CDF ----
info = spdfcdfinfo(cdf_file);

flux        = spdfcdfread(cdf_file, 'Variables', var_to_plot,     'CombineRecords', true);
esa_level   = spdfcdfread(cdf_file, 'Variables', 'esa_level',     'CombineRecords', true);
ecl_lat     = spdfcdfread(cdf_file, 'Variables', 'ecl_lat',       'CombineRecords', true);
ecl_lon     = spdfcdfread(cdf_file, 'Variables', 'ecl_lon',       'CombineRecords', true);

flux = double(flux);
esa_level = double(esa_level(:));
ecl_lat = double(ecl_lat(:));
ecl_lon = double(ecl_lon(:));

% flux comes back as [nLon x nLat x nEsa] or [nEsa x nLat x nLon] depending
% on reader/majority handling -- force it to [nEsa x nLat x nLon] explicitly:
sz = size(flux);
nEsa = numel(esa_level); nLat = numel(ecl_lat); nLon = numel(ecl_lon);
dimOrder = zeros(1,3);
dims = [nEsa nLat nLon];
for k = 1:3
    dimOrder(k) = find(sz == dims(k), 1);
    sz(dimOrder(k)) = -1; % mark used, in case of duplicate sizes
end
flux = permute(flux, dimOrder);   % now [nEsa x nLat x nLon]

% Replace fill values with NaN
fillval = -1e31;
flux(flux <= fillval/10) = NaN;   % generous threshold catches -1e31 fills

%% ---- Quicklook: one panel per ESA level ----
figure('Color','w','Position',[100 100 1400 800]);
nRows = 2; nCols = ceil(nEsa/nRows);

% Pad grid by one wrap-around column/row so pcolor doesn't drop the last
% row/col of data (pcolor/surf only draw N-1 x M-1 faces)
lon_ext = [ecl_lon; ecl_lon(1)+360];
lat_ext = [ecl_lat; ecl_lat(end) + (ecl_lat(2)-ecl_lat(1))];
[Lon, Lat] = meshgrid(lon_ext, lat_ext);

for i = 1:nEsa
    subplot(nRows, nCols, i);
    Z = squeeze(flux(i,:,:));           % [nLat x nLon]
    Z_ext = [Z, Z(:,1)];                % wrap lon
    Z_ext = [Z_ext; Z_ext(end,:)];      % pad lat

    pcolor(Lon, Lat, Z_ext);
    shading flat;
    colormap(jet);
    cb = colorbar;
    cb.Label.String = 'Flux [1/(cm^2 s sr keV)]';
    xlabel('Ecliptic Longitude [deg]');
    ylabel('Ecliptic Latitude [deg]');
    title(sprintf('ESA level %d', esa_level(i)));
    axis tight;
    set(gca,'FontSize',9);
end

sgtitle(strrep(cdf_file, '_', '\_'), 'FontSize', 13, 'FontWeight','bold');

%% ---- Optional: save figure ----
% exportgraphics(gcf, strrep(cdf_file, '.cdf', '_quicklook.png'), 'Resolution', 200);
