%% MAIN
% ilo_ENA_CDF v3d5 (2026-10-24). Changes from v3d4 (map figures unchanged):
%  1. One ribbon reference arc for every section (RIB, below): Dayeh et al.
%     2019 weighted centre (218.33, 40.38) deg, radius 74.81 deg. The polar
%     map used Funsten 2010 (221, 39; r = 71.6) before.
%  2. Analysis samples pixel CENTRES (lat_ctr/lon_ctr). lat/lon remain the
%     surfm cell corners, for drawing only. The cross-ribbon cuts, ribbon
%     mask and polar map were half a pixel off before.
%  3. Analysis keeps zero-intensity pixels: in the L3 maps they have
%     exposure > 0 and sigma = 0, so they are measured zeros, not gaps.
%     The display still hides them.
%  4. Polar map: true azimuth about the centre, with coordinates and values
%     taken from the same 30x60 grid.
%  5. Meridian labels follow flip_view.
%  6. LOS ram pressure: a pixel with no data at any ESA step is NaN in the
%     full-range sum (nansum returned 0).
%  7. The profile CSV export ends in _v3d5 so it doesn't overwrite v3d4's.
%  8. Cross-ribbon cuts: +s always points away from the ribbon centre. With
%     flip_view = false the profiles came out mirrored (s -> -s).

close all; clearvars; clc; format long; warning('off','all')

%%% earlier version %%%
% fld = '/Users/mitchellshen/CAVA_IDL/IMAP-Lo June 10th 2026 Maps/l3/2025/11/';
% cdf_name = 'imap_lo_l3_ilo-enasbsMsk-h-hf-sp-ram-hae-6deg-6mo_20251125_v001';
% cdf_name = 'imap_lo_l3_l090-enasbs-h-hf-sp-ram-hae-6deg-6mo_20251125_v001';
% cdf_name = 'imap_lo_l3_l090-enasbsMsk-h-hf-sp-ram-hae-6deg-6mo_20251125_v001';

%%% updated version including asymmetric systematic uncertainties %%%
% fld = '/Users/mitchellshen/CAVA_IDL/IMAP-Lo July 31st 2026 Reprocessed Combined Maps/';
% cdf_name = 'imap_lo_l3_ilo-enasbsMsk-h-hf-sp-ram-hae-6deg-6mo_20251125_v002';

%%% L2 raw SC frame data
% fld = '/Users/mitchellshen/CAVA_IDL/IMAP-Lo June 10th 2026 Maps/l2/2025/11/';
% cdf_name = 'imap_lo_l2_l090-enansnbs-h-sf-nsp-ram-hae-6deg-6mo_20251125_v001';

% fld = '/Users/mitchellshen/CAVA_IDL/IMAP-Lo June 10th 2026 Maps/l2/2025/12/';
% cdf_name = 'imap_lo_l2_l075-enansnbs-h-sf-nsp-ram-hae-6deg-6mo_20251211_v001';

fld = '/Users/mitchellshen/CAVA_IDL/IMAP-Lo June 10th 2026 Maps/l2/2025/12/';
cdf_name = 'imap_lo_l2_l105-enansnbs-h-sf-nsp-ram-hae-6deg-6mo_20251209_v001';

cdf_file = [fld cdf_name '.cdf'];

%==================== USER SWITCH ====================%
flip_view = true;   % true = outside-looking-in style
view_mode = 'nose';  % 'flat' = ecliptic frame, straight parallels (IBEX heritage)
                     % 'nose' = oblique, Nose at the exact map centre
ovc       = [1 1 1]; % overlay colour for ribbon curves, marker faces and text.
                     % [1 1 1] white reads well on turbo; use [0 0 0] black on
                     % light colormaps. Marker EDGES stay white either way.
slice_view= false;
rate      = true;  % kept only for downstream colorbar/clim branching (see below)
save      = false; 
save_fig  = false;
esa_step  = 3;       % index into the file's 'energy' variable (1..7 for this product)
epoch_idx = 1;       % which time record to plot, if the CDF has more than one
quantity  = 'flux';  % 'flux' -> ena_intensity, 'bg' -> bg_intensity, 'survival' -> survival_probability
esa_volt  = {'16','30','56','106','200','404','787'};  % fallback labels only; real energy is read from the file below

%==================== RIBBON REFERENCE (v3d5) ====================%
% Best-known ribbon reference arc: weighted centre and radius of the IBEX-Hi
% ribbon fits averaged over 0.7-4.3 keV and 2009-2017 (Dayeh et al. 2019).
% Every section below (guide, cuts, ribbon-vs-rest, polar map) uses RIB.
RIB = struct('lon0', 218.33, 'lat0', 40.38, 'r_mid', 74.81, 'width', 36);

%==================== READ DATA (FROM CDF) ====================%
% This CDF (a 6-month IMAP-Lo survival-corrected ENA map) stores:
%   longitude, latitude   -> pixel-CENTER coordinates (deg); the L3 maps are
%                             60 longitude x 30 latitude bins at 6 deg
%                             (centres 3..357 and -87..87)
%   energy                -> 7 energy passband centers (keV), DEPEND_1 of ena_intensity
%   ena_intensity, bg_intensity, survival_probability, ena_intensity_stat_uncert, ...
%                          -> DEPEND_0..3 = [epoch, energy, longitude, latitude]
%
% cdfread's returned array dimension order for a given MATLAB/CDF library
% version isn't something I can verify without running MATLAB myself, so
% instead of hard-coding [energy, lon, lat] we MATCH each returned
% dimension's length against numel(energy)/numel(longitude)/numel(latitude).
% Those three are 7 / 60 / 30 here -- all different -- so the match is
% unambiguous and self-correcting even if the library's convention changes.

switch quantity
    case 'flux',     zvar = 'ena_intensity';
    case 'bg',       zvar = 'bg_intensity';
    case 'survival', zvar = 'survival_probability';
    otherwise, error('Unknown quantity "%s". Use flux, bg, or survival.', quantity);
end

vars = {'longitude','latitude','energy','energy_label', zvar, 'ena_intensity_stat_uncert'};
raw  = cdfread(cdf_file, 'Variables', vars, 'CombineRecords', true);

lon_c        = double(raw{1}(:)).';     % pixel-center longitude (deg)
lat_c        = double(raw{2}(:)).';     % pixel-center latitude  (deg)
energy_kev   = double(raw{3}(:));       % energy passband centers (keV)
energy_label = raw{4};

Zraw = double(raw{5});   % selected quantity, all epochs/energies/pixels
Eraw = double(raw{6});   % ena_intensity_stat_uncert, same shape as Zraw

% Drop/select the record (epoch) dimension. cdfread with CombineRecords
% puts records along dim 1. If there's only one record, that dim may
% already be singleton/absent, so index only when it's actually present.
n_records = size(Zraw, 1);
if ndims(Zraw) == 4 && n_records > 1
    Zraw = squeeze(Zraw(epoch_idx, :, :, :));
    Eraw = squeeze(Eraw(epoch_idx, :, :, :));
else
    Zraw = squeeze(Zraw);
    Eraw = squeeze(Eraw);
end

% Auto-detect [energy, longitude, latitude] order and permute to that order
n_e = numel(energy_kev); n_o = numel(lon_c); n_a = numel(lat_c);
sz  = size(Zraw);
dim_e = find(sz == n_e, 1);
dim_o = find(sz == n_o, 1);
dim_a = find(sz == n_a, 1);
if isempty(dim_e) || isempty(dim_o) || isempty(dim_a)
    error(['Could not match %s dimensions [%s] to numel(energy)=%d, ' ...
           'numel(longitude)=%d, numel(latitude)=%d. Run size(Zraw) and ' ...
           'cdfinfo(cdf_file) to inspect manually.'], ...
           zvar, num2str(sz), n_e, n_o, n_a);
end
Zraw = permute(Zraw, [dim_e dim_o dim_a]);   % -> [energy x lon x lat]
Eraw = permute(Eraw, [dim_e dim_o dim_a]);

% Select the requested energy/ESA step, giving a [lon x lat] slice
Zsel = squeeze(Zraw(esa_step, :, :));
Esel = squeeze(Eraw(esa_step, :, :));

% Rest of the pipeline below expects Z, E as [lat x lon] (rows=lat, cols=lon)
Z = Zsel.';
E = Esel.';

% No explicit FILLVAL masking needed: fill values in this product are
% large negative numbers. The display mask further below (Z > 0) drops them
% along with zeros; the analysis copies Z_all/E_all (v3d5) drop fills and
% NaNs but keep zeros, which are measured values (exposure > 0).

try
    if iscell(energy_label)
        lbl = strtrim(char(energy_label{esa_step}));
    else
        lbl = strtrim(energy_label(esa_step, :));
    end
catch
    lbl = '(unavailable)';
end
fprintf('Loaded %s\n', cdf_name);
fprintf('  quantity = %s, esa_step = %d (energy = %.4f keV, label = %s)\n', ...
    quantity, esa_step, energy_kev(esa_step), lbl);

% surfm's 'flat' shading treats grid vertex (lat(i),lon(j)) as a pixel's
% SOUTH-WEST corner and fills the cell to its north-east. The CDF gives
% pixel CENTERS, so we shift each by half a bin width (south, west) to
% turn centers into SW-corner edges. (With flip_view negating longitude,
% "west before the flip" becomes "right on screen after the flip" --
% i.e. this is the half-pixel-down / half-pixel-right correction.)
dlon = min(diff(sort(unique(lon_c))));   % longitude bin width (deg)
dlat = min(diff(sort(unique(lat_c))));   % latitude  bin width (deg)
fprintf('  bin width: dlon = %.3f deg, dlat = %.3f deg\n', dlon, dlat);

lat = lat_c - dlat/2;
lon = lon_c + dlon/2;

fprintf('  grid: %d longitude bins x %d latitude bins\n', numel(lon), numel(lat));

%==================== LONGITUDE SETUP ====================%
% Convert to [-180,180)
lon = mod(lon + 180, 360) - 180;

%==================== MAP CENTRE ====================%
% view_mode (set in the USER SWITCH block) picks the origin latitude.
%   'flat' -> 0        : ecliptic frame. Parallels are straight, meridians are
%                        symmetric ellipse arcs, constant-longitude data gaps
%                        render as true meridians. IBEX heritage.
%   'nose' -> 5.116296 : oblique Mollweide, sphere rotated so the Nose lands
%                        dead centre. Parallels sag and constant-longitude gaps
%                        lean -- that is inherent to the rotation, not a bug.
%                        Also note the frame seam leaves the geographic
%                        meridian above +85 deg latitude, so expect a small
%                        clipped wedge in the topmost latitude row at the seam.
% Everything else (edge registration, seam roll, frame limits) is identical in
% both modes -- they are bug fixes, not a style choice.
switch lower(view_mode)
    case 'flat', lat_center = 0;
    case 'nose', lat_center = 5.116296;
    otherwise,   error('view_mode must be ''flat'' or ''nose'' (got ''%s'').', view_mode);
end
lon_center = 105;

% Flip data/view if desired
if flip_view
    lon = -lon;
end

% Sort longitude and reorder data
[lon, isrt] = sort(lon);
Z = Z(:, isrt);
if ~isempty(E)
    E = E(:, isrt);
end

% v3d5: pixel-CENTRE coordinates, in the same wrapped/flipped frame and the
% same column order as Z/E. lat/lon above are surfm cell CORNERS, half a
% pixel off the centres, so they are for drawing only. Everything that
% samples or classifies pixels (cuts, ribbon mask, polar map) uses these.
lat_ctr = lat_c;
lon_ctr = mod(lon_c + 180, 360) - 180;
if flip_view
    lon_ctr = -lon_ctr;
end
lon_ctr = mod(lon_ctr + 180, 360) - 180;
lon_ctr = lon_ctr(isrt);   % Z/E column order (can wrap at the seam, so not always ascending)

%==================== MASK NO-DATA ====================%
% v3d5: analysis copies keep zero-intensity pixels. In the L3 maps a zero
% has exposure > 0 and stat uncertainty 0, i.e. it is a measured zero, not
% a gap. Dropping zeros biased the stacked profiles high and removed most
% cuts at ESA 5-7. Fills (-1e31) and NaNs are still excluded. The display
% mask below is unchanged, so the map figures look the same as in v3d4.
Z_all = Z;
E_all = E;
valid_all = isfinite(Z_all) & (Z_all >= 0);
Z_all(~valid_all) = NaN;
if ~isempty(E_all)
    E_all(~valid_all) = NaN;
end

Zmask = ~isnan(Z) & (Z > 0);
Z(~Zmask) = NaN;
if ~isempty(E)
    E(~Zmask) = NaN;
end

[Lon, Lat] = meshgrid(lon, lat);   % surfm cell-CORNER grid (not centres; analysis uses lat_ctr/lon_ctr)

%==================== MAP VERTEX GRID ====================%
% FIX (v3d4): built here, before axesm, because it may nudge the map centre
% so the frame seam falls on a cell boundary. See ena_map_grid at end of file.
[LatV, LonV, C, A, lon_center_eff] = ...
    ena_map_grid(Z, lat, lon, flip_view, lon_center, true);

%==================== FIGURE ====================%
figure(1);
set(gcf, 'Color', [1 1 1]);
ax = axesm('mollweid', ...
    'Origin',[lat_center lon_center_eff 0], ...
    'FLatLimit', [-90 90], ...     % FIX (v3d4): was MapLatLimit/MapLonLimit,
    'FLonLimit', [-180 180], ...   % which both write to Origin and can
    'Frame', 'on', ...             % silently override it. F*Limit sets the
    'Grid', 'on', ...              % frame only.
    'MeridianLabel', 'off', ...   % turn OFF automatic labels
    'ParallelLabel', 'off', ...
    'MLineLocation', 30, ...
    'PLineLocation', 30, ...
    'GLineWidth', 1.0, ...
    'Gcolor', [1 0.6 0], ...
    'FEdgeColor', [0 0 0.5], ...
    'FontSize', 12);

% mlabel on
% setm(ax, 'MLabelParallel', 0, 'FontColor', [1 1 1])

axis off
tightmap

% White outside globe, dark inside globe
set(ax, 'Color', 'none')
% setm(ax, 'FFaceColor', [0.25 0 0.35]) % dark purple
setm(ax, 'FFaceColor', [0 0 0])


%==================== PLOT MAP ====================%
% FIX (v3d4): the old wrap-pad scheme fed cell EDGES to surfm as vertices and
% let 'FaceColor','flat' silently drop the last row/column, then papered over
% it by duplicating rows. LatV/LonV/C now come from ena_map_grid, which does
% the edge bookkeeping and the seam roll properly. (E_ext was built here but
% never used anywhere in the script, so it is gone.)
h = surfm(LatV, LonV, C);
set(h, ...
    'EdgeColor', 'none', ...
    'FaceColor', 'flat', ...
    'FaceAlpha', 'flat', ...
    'AlphaData', A, ...
    'AlphaDataMapping', 'none');

set(gca, 'ColorScale', 'linear')
colormap("turbo")

% title(sprintf('%s | E = %.3f keV (step %d)', quantity, energy_kev(esa_step), esa_step), 'FontSize', 18);
% title(sprintf('%s | E = %.3f keV (step %d)', quantity, energy_kev(esa_step), esa_step), 'FontSize', 18);
title(sprintf('E = %.3f keV (ESA-%d)', energy_kev(esa_step), esa_step), 'FontSize', 18);

%==================== MANUAL MERIDIAN LABELS ====================%
lablat = 0;   % latitude where labels sit (equator)

meridians = -180:30:180;

for k = 1:numel(meridians)
    m = meridians(k);

    % Flip label meaning relative to plotted meridian, only when the view
    % is flipped (v3d5: labels were mirrored with flip_view = false)
    if flip_view
        val = -m;
    else
        val = m;
    end

    % Wrap into [-180,180]
    val = mod(val + 180, 360) - 180;

    % Format as signed degree (recommended)
    if abs(val) == 180
        txt = '180°';
    elseif val == 0
        txt = '0°';
    else
        txt = sprintf('%d°', val);
    end

    textm(lablat, m, txt, ...
        'Color', ovc, ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle');
end

%==================== COLORBAR ====================%
cb = colorbar('southoutside');
if ~rate
cb.Label.String = sprintf( ...
    'Intensity (counts cm^{-2} s^{-1} sr^{-1} keV^{-1}) [ECLIPJ2000] at E = %.3f keV', ...
    energy_kev(esa_step));
else
cb.Label.String = sprintf( ...
    'Rate (counts s^{-1}) [ECLIPJ2000] at E = %.3f keV', ...
    energy_kev(esa_step));
end
cb.FontSize = 14;

if ~rate
switch esa_step
    case 1
        clim([0 2e5])
    case 2
        clim([0 1e5])
    case 3
        clim([0 3e4])
    case 4
        clim([0 6e3])
    case 5
        clim([0 1500])
    case 6
        clim([0 600])
    case 7
        clim([0 300])
end
else
    
end


% Ribbon analysis
%==================== IBEX RIBBON GUIDE ====================%

% Funsten et al. 2010 centered on (221, 39)
% and is 36 degrees wide (radius 71.6 degrees with +/- 18 degrees around it). 
% It is for illustrations to guide the eye on ribbon estimate boundaries only
% We also used it in McComas papers for 5-yr and 7-yr of IBEX observations.

% Later on, an updated trace used the weighted center from 
% different Ribbon fits instead, averaged over all energies (0.7–4.3 keV) 
% and all nine years of IBEX-Hi data (2009–2017), 
% from our 2019 paper on the ribbon variations. These are:
% Center ( b_lon_ecl = 218.33, b_lat_ecl = 40.38) and radius=74.81



% Ribbon centre and radius: RIB (Dayeh et al. 2019), defined at the top.
% Funsten 2013 kept for reference only: lon0 = 219.20, lat0 = 39.90, r_mid = 74.50
lon0  = RIB.lon0;
lat0  = RIB.lat0;
width = RIB.width;

% ribbon radii
r_mid = RIB.r_mid;
r_in  = r_mid - width./2;
r_out = r_mid + width./2;

% angle around circle
az = linspace(0,360,721);

% generate circle points
[lat_mid, lon_mid] = smallcircle_deg(lat0, lon0, r_mid, az);
[lat_in , lon_in ] = smallcircle_deg(lat0, lon0, r_in , az);
[lat_out, lon_out] = smallcircle_deg(lat0, lon0, r_out, az);

% Voyager dots
lon_v1 = mod(255.0 + 180, 360) - 180;
lat_v1 =  35.0;
lon_v2 = mod(290.4 + 180, 360) - 180;
lat_v2 = -32.2;

% Nose and Tail
lon_nose = mod(259.200622 + 180, 360) - 180;
lat_nose =  5.116296;
lon_tail = mod( 79.200622 + 180, 360) - 180;
lat_tail = -5.116296;

% lons = np.array([259.200622, 255.499300, 289.800000, 79.200622, 221,150.,0.0, 41, 250.624523, 70.624523])
% lats = np.array([5.116296, 34.999941, -35.600000, -5.116296, 39, 0.0, 0.0, -39, -41.242979, 41.242979])
% labels=[ 'Nose', 'V1','V2','Tail', 'RibC','Stbd', 'Port','DwnB','ULSR', 'DLSR']


% 🔥 IMPORTANT: match your map convention
if flip_view
    lon_mid = -lon_mid;
    lon_in  = -lon_in;
    lon_out = -lon_out;
    lon_v1  = -lon_v1;
    lon_v2  = -lon_v2;
    lon_nose= -lon_nose;
    lon_tail= -lon_tail;
    lon0    = -lon0;
end

% wrap again after flipping
lon_mid = mod(lon_mid + 180, 360) - 180;
lon_in  = mod(lon_in  + 180, 360) - 180;
lon_out = mod(lon_out + 180, 360) - 180;
lon_v1  = mod(lon_v1  + 180, 360) - 180;
lon_v2  = mod(lon_v2  + 180, 360) - 180;
lon_nose= mod(lon_nose  + 180, 360) - 180;
lon_tail= mod(lon_tail  + 180, 360) - 180;
lon0    = mod(lon0    + 180, 360) - 180;

% plot ribbon
plotm(lat_mid, lon_mid, '-',  'Color', ovc, 'LineWidth', 2)
plotm(lat_in , lon_in , '--', 'Color', ovc, 'LineWidth', 1.5)
plotm(lat_out, lon_out, '--', 'Color', ovc, 'LineWidth', 1.5)


% [lat_mid, lon_mid] = smallcircle_deg(lat0, lon0, r_mid, az); NO NEED

%==================== RIBBON  MARKERS ====================%

plotm(lat0, lon0, 'wo', ...
    'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat0, lon0, 'RC', ...
    'Color',ovc,'FontSize',12,'FontWeight','bold', ...
    'HorizontalAlignment','right','VerticalAlignment','bottom')

%==================== VOYAGER MARKERS ====================%

plotm(lat_v1, lon_v1, 'wo', ...
    'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_v1, lon_v1, '  V1', ...
    'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','right', 'VerticalAlignment','bottom')

plotm(lat_v2, lon_v2, 'wo', ...
    'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_v2, lon_v2, '  V2', ...
    'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','right', 'VerticalAlignment','top')

%==================== Nose/Tail MARKERS ====================%
plotm(lat_nose, lon_nose, 'wo', ...
    'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_nose, lon_nose-3, '  Nose', ...
    'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','left', 'VerticalAlignment','bottom')
   %'HorizontalAlignment','right', 'VerticalAlignment','bottom')

plotm(lat_tail, lon_tail, 'wo', ...
    'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_tail, lon_tail, '  Tail', ...
    'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','right', 'VerticalAlignment','top')

%==================== CROSS-RIBBON CUTS ====================%

% keep everything except lon in [-140, -90]
% use = ~(lon_mid >= 60 & lon_mid <= 130) & ...   
%       (lat_mid >= -90 & lat_mid <= 90);
      % ~(lon_mid >= -180 & lon_mid <= -140) &
use = (lat_mid >= -90 & lat_mid <= 90);

% keep only points that have neighbors for tangent estimation
idx_full = find(use);
idx_full = idx_full(idx_full > 1 & idx_full < numel(lon_mid));

% optional downsampling after selection
s_cnt = 16;
idx_use = idx_full(1:s_cnt:end);

% cut distances in degrees across ribbon
% s_cut = lat0-90-12-3:6:lat0+90-24-3;   % inward/outward from ribbon centerline
% s_cut = lat0-75:6:lat0;
s_cut = -(width):6:(width);

all_cut_lat = cell(size(idx_use));
all_cut_lon = cell(size(idx_use));

for ii = 1:numel(idx_use)
    i = idx_use(ii);

    % neighboring points to estimate tangent
    p_prev = sph2cart_unit(lon_mid(i-1), lat_mid(i-1));
    p_here = sph2cart_unit(lon_mid(i),   lat_mid(i));
    p_next = sph2cart_unit(lon_mid(i+1), lat_mid(i+1));

    % local tangent along ribbon
    t = p_next - p_prev;
    t = t / norm(t);

    % local radial direction on sphere
    r = p_here / norm(p_here);

    % local normal within tangent plane, perpendicular to ribbon
    n = cross(r, t);
    n = n / norm(n);

    % build cut by rotating p_here around axis = t
    lat_cut = nan(size(s_cut));
    lon_cut = nan(size(s_cut));

    % v3d5: make +s point AWAY from the ribbon centre in either view. The
    % rotation sense about t flips with the mirrored (flip_view) frame, so
    % with flip_view = false the profiles came out mirrored (s -> -s).
    % lon0/lat0 are the ribbon centre in the plotted frame (set above).
    [lon_t, lat_t] = cart2sph_deg(rotate_about_axis(p_here, t, deg2rad(1)));
    if angdist_deg(lat_t, lon_t, lat0, lon0) < r_mid
        s_sign = -1;
    else
        s_sign = 1;
    end

    for j = 1:numel(s_cut)
        p_cut = rotate_about_axis(p_here, t, s_sign*deg2rad(s_cut(j)));
        [lon_cut(j), lat_cut(j)] = cart2sph_deg(p_cut);
    end

    all_cut_lat{ii} = lat_cut;
    all_cut_lon{ii} = lon_cut;

    % overlay cut on map
    if slice_view
        plotm(lat_cut, lon_cut, 'm-', 'LineWidth', 1.5)
    end
end

%

%==================== SAMPLE DATA ALONG CUTS ====================%
% v3d5: sample at pixel CENTRES and keep measured zeros.
%
% v3d4 sampled on lat/lon, the surfm cell CORNERS (lat_c - dlat/2,
% lon_c + dlon/2). surfm draws Z(i,j) on the cell whose corner is
% (lat(i), lon(j)), so the map is right; an interpolant, though, reads
% the same numbers as the LOCATION of Z(i,j). The cuts were therefore
% sampled half a pixel off, which moved the stacked-profile peak by 2-3 deg
% on the ilo hf-sp map. v3d4 also treated zeros as missing; because the
% bilinear sample needs all four neighbours, that dropped most cuts at
% ESA 5-7 and biased the profile high.
%
% Intensity is bilinearly interpolated. The native 1-sigma statistical
% uncertainties are propagated through the SAME bilinear weights in
% variance space, rather than interpolating sigma itself:
%
%       I_q       = sum_k w_k I_k
%       sigma_q^2 = sum_k w_k^2 sigma_k^2
lat_sci = lat_ctr(:).';
lon_sci = lon_ctr(:).';
Z_sci   = Z_all;
E_sci   = E_all;

% The interpolator needs ascending coordinates. lon_ctr is in the map's
% column order, which can wrap at the seam, so sort it here and keep the
% maps aligned with it.
if any(diff(lat_sci) < 0)
    [lat_sci, ilat_sci] = sort(lat_sci);
    Z_sci = Z_sci(ilat_sci,:);
    E_sci = E_sci(ilat_sci,:);
end

if any(diff(lon_sci) < 0)
    [lon_sci, ilon_sci] = sort(lon_sci);
    Z_sci = Z_sci(:,ilon_sci);
    E_sci = E_sci(:,ilon_sci);
end

% Same validity criterion for intensity and statistical uncertainty.
% Zeros are kept; their sigma is 0 in the L3 maps.
valid_native = isfinite(Z_sci) & (Z_sci >= 0) & ...
               isfinite(E_sci) & (E_sci >= 0);
Z_sci(~valid_native) = NaN;
E_sci(~valid_native) = NaN;

all_cut_vals = cell(size(idx_use));
all_cut_errs = cell(size(idx_use));

for ii = 1:numel(idx_use)
    lat_cut = all_cut_lat{ii};
    lon_cut = all_cut_lon{ii};

    % Bilinear intensity interpolation + formal propagation of the native
    % statistical uncertainty through the interpolation weights.
    [vals_cut, errs_cut] = interp2_stat_uncert( ...
        lon_sci, lat_sci, Z_sci, E_sci, lon_cut, lat_cut);

    all_cut_vals{ii} = vals_cut;
    all_cut_errs{ii} = errs_cut;
end

%==================== PLOT INDIVIDUAL CUTS ====================%
figure(2); 
hold on
for ii = 1:numel(all_cut_vals)
    plot(s_cut, all_cut_vals{ii}, '-', 'LineWidth', 2)
end
grid on; box on;
set(gca, 'YScale', 'linear')
xlabel('Angular distance across ribbon (deg)')
ylabel('Intensity')
title('Individual Cross-Ribbon Profiles')

%==================== STACKED AVERAGE PROFILE ====================%
nCuts = numel(all_cut_vals);
nS    = numel(s_cut);

P  = nan(nCuts, nS);
Pe = nan(nCuts, nS);

for ii = 1:nCuts
    P(ii,:)  = all_cut_vals{ii};
    Pe(ii,:) = all_cut_errs{ii};
end

% A point contributes only when BOTH its intensity and propagated
% statistical uncertainty are valid.
valid = isfinite(P) & isfinite(Pe);

P_use  = P;
Pe_use = Pe;
P_use(~valid)   = NaN;
Pe_use(~valid)  = NaN;

% Number of valid cuts contributing at each angular-distance bin.
N_profile = sum(valid, 1);

% Arithmetic mean of the cut intensities.
ave_profile = mean(P_use, 1, 'omitnan');

% Statistical uncertainty on the arithmetic mean, assuming the
% contributing cut measurements are statistically independent:
%
%       sigma_mean = sqrt(sum_i sigma_i^2) / N
%
ave_profile_err = sqrt(sum(Pe_use.^2, 1, 'omitnan')) ./ N_profile;

% Optional summed profile and its propagated statistical uncertainty.
sum_profile     = sum(P_use, 1, 'omitnan');
sum_profile_err = sqrt(sum(Pe_use.^2, 1, 'omitnan'));

% Do not report a bin when no valid cut contributes.
ave_profile(N_profile == 0)     = NaN;
ave_profile_err(N_profile == 0) = NaN;
sum_profile(N_profile == 0)     = NaN;
sum_profile_err(N_profile == 0) = NaN;

%==================== AVERAGE PROFILE ====================%
figure(3); 
plot(s_cut, ave_profile, 'ko-', ...
    'LineWidth', 2, 'MarkerFaceColor', 'k')
set(gca, 'YScale', 'linear')
xlabel('Angular distance across ribbon (deg)')
ylabel('Average Intensity')
title('Stacked Ribbon Profile (Average)')
grid on; box on;

%==================== AVERAGE + STATISTICAL UNCERTAINTY ====================%
figure(4);
errorbar(s_cut, ave_profile, ave_profile_err, 'ko-', ...
    'LineWidth', 1.5, 'MarkerFaceColor', 'k', 'CapSize', 8)
set(gca, 'YScale', 'linear')
xlabel('Angular distance across ribbon (deg)')
ylabel('Average Intensity')
title('Stacked Ribbon Profile (Mean \pm 1\sigma_{stat})')
grid on; box on;

%==================== STACKED PROFILE IMAGE ====================%
figure(5);
imagesc(1:nCuts, s_cut, P')
set(gca, 'YDir', 'reverse')
colormap("turbo")
colorbar
xlabel('Cut index along ribbon')
ylabel('Angular distance across ribbon (deg)')
set(gca, 'ColorScale', 'linear')

figure(1)

%==================== SAVE PROFILE ====================%
if save
    T = table(s_cut(:), ave_profile(:), ave_profile_err(:), N_profile(:), ...
        'VariableNames', {'s_cut_deg', 'average_intensity', ...
                          'average_stat_uncert', 'N_profiles'});
    writetable(T, [fld quantity '_ave_esa' num2str(esa_step) '_v3d5.csv']);   % v3d5 suffix: centres + zeros kept
end

%==================== SAVE FIGURES ====================%

if save_fig
    fig_name = [fld quantity '_map_esa' num2str(esa_step)];
    % High-resolution PNG
    exportgraphics(figure(1), ...
        [fig_name '.png'], ...
        'Resolution', 600);
    % Vector PDF for publication
    exportgraphics(figure(1), ...
        [fig_name '.pdf'], ...
        'ContentType', 'vector');
end

%% LOS RAM PRESSURE (per pixel)
%==================== LOS RAM PRESSURE ====================%
% Implements:
%   P_ram . LOS = (2*pi*m^2*u_R^2/n_H) *
%       Integral_Emin^Emax (dE_o/E_o) j_o,ENA(E_o) (|v_o|+u_R)^2 / [sigma(E_p)*|v_o|]
%
% v_o = sqrt(2*E_o/m)                observer-frame speed
% v_p = |v_o| + u_R                  plasma-frame speed (radially inward assumption)
% E_p = m*v_p^2/2                    plasma-frame energy (keV, used only inside sigma())
% sigma(E) = Lindsay & Stebbings (2005) H+/H charge-exchange cross section,
%            valid ~0.005-600 keV:
%   sigma(E)[cm^2] = 1e-16*(1-exp(-67.3/E))^4.5*(4.15-0.531*ln(E))^2,  E in keV
%
% Implemented as a Riemann sum over the 7 discrete, non-overlapping ESA
% energy channels rather than a continuous integral: channel j
% contributes integrand(E_j) * (dE_j/E_j), where dE_j is that channel's
% full energy width (energy_delta_plus + energy_delta_minus from the
% CDF). Summing all 7 channels approximates the full-range integral;
% each channel alone gives its individual per-step contribution.
%
% ---- UNITS (worked out explicitly, in CGS: g, cm, s, erg) ----
% Dimensional analysis of the RHS: [m^2][u_R^2]/[n_H] * [j][kinematic
% bracket], with steradians dimensionless (sr=1, not a real physical
% unit) gives, after full cancellation:
%   g^2 * (cm/s)^2 / cm^-3  *  (cm^-2 s^-1 erg^-1) * (cm^-1 s^-1)
%     = g^2 cm^2 s^-4 erg^-1  =  g/s^2  =  erg/cm^2
% i.e. energy/area = pressure*length, exactly the "P_ram . LOS" the
% formula names -- PROVIDED every quantity is in truly consistent CGS,
% which requires j in cm^-2 s^-1 sr^-1 erg^-1 (per erg), NOT per keV.
%
% *** TWO BUGS FOUND AND FIXED (both confirmed against literature/an
% actual Galli et al. 2024 ApJ 971:2 comparison, whose Table 1-6 and
% Figure 9 give real ΔP*l values of order 1-500 pdyne*AU/cm^2):
%  1) j must be converted from the CDF's native per-keV to per-erg
%     (divide by keV2erg) for the CGS cancellation above to hold.
%  2) The Lindsay & Stebbings sigma(E) formula's E argument is itself
%     in keV, NOT eV as I originally (incorrectly) assumed -- verified
%     by checking sigma(1 keV) ~ 1.7e-15 cm^2 against the ~2e-15 cm^2
%     commonly quoted in the literature for H+/H at 1 keV. Passing E in
%     eV instead crushes sigma by ~1e7 (since it sits inside a
%     1/E exponential), which was the dominant source of the earlier
%     ~1e9-1e11 overestimate the person flagged after Figure-9/Table
%     comparison. ***
%
% The raw CGS result (erg/cm^2) is then converted to pdyne*AU/cm^2
% (picodyne * astronomical-unit / cm^2 -- a natural choice since
% dyne/cm^2 * AU = dyne*AU/cm^2 is dimensionally pressure*length, and
% "pico" keeps the numbers a convenient size) via:
%   1 erg/cm^2 = 1 dyne/cm = (1 cm)/(1 AU) dyne*AU/cm^2
%              = 1e12 * (1 cm)/(1 AU) pdyne*AU/cm^2

% ---- free/assumed model parameters: set these for your analysis ----
u_R_kms = 100;     % radial/bulk plasma speed, km/s (Galli et al. 2024's
                    % primary "dynamic" case; they also quote a
                    % stationary case at u_R=0, and 40-200 km/s as the
                    % plausible heliosheath range per Zirnstein et al. 2021)
n_H_cm3 = 0.10;     % assumed neutral H density, cm^-3

% ---- physical constants (CGS) ----
m_H_g   = 1.6726e-24;      % hydrogen atom mass, g
eV2erg  = 1.602177e-12;    % 1 eV in erg
keV2erg = 1e3*eV2erg;      % 1 keV in erg
kms2cms = 1e5;             % km/s -> cm/s
AU_cm   = 1.495978707e13;  % 1 AU in cm

erg_to_pdyneAU = 1e12 * (1/AU_cm);   % erg/cm^2 -> pdyne*AU/cm^2, ~=0.066846

u_R = u_R_kms * kms2cms;   % cm/s

sigma_LS05 = @(E_kev) 1e-16 .* (1 - exp(-67.3./E_kev)).^4.5 .* ...
                     (4.15 - 0.531.*log(E_kev)).^2;   % cm^2, E_kev in keV (NOT eV --
                     % verified against literature: sigma(1 keV) ~ 1.7e-15 cm^2,
                     % matching the ~2e-15 cm^2 commonly quoted for H+/H at 1 keV;
                     % passing E in eV here instead silently crushes sigma by ~1e7,
                     % which was the dominant source of the previous huge overestimate)



% ---- per-channel energy bin widths (keV), read from the CDF ----
% NOTE: cdfread's output for a single-variable request isn't always
% wrapped in a cell (this varies by MATLAB/CDF-library version), so
% unwrap defensively rather than assuming edp{1} always works.
edp_raw = cdfread(cdf_file, 'Variables', {'energy_delta_plus'},  'CombineRecords', true);
edm_raw = cdfread(cdf_file, 'Variables', {'energy_delta_minus'}, 'CombineRecords', true);
if iscell(edp_raw), edp_raw = edp_raw{1}; end
if iscell(edm_raw), edm_raw = edm_raw{1}; end
dE_kev = double(edp_raw(:)) + double(edm_raw(:));   % full width per ESA step, keV

% ---- per-channel kinematics (same for every pixel) ----
E_o_erg = energy_kev(:) * keV2erg;           % [7x1]
v_o     = sqrt(2*E_o_erg ./ m_H_g);          % cm/s
v_p     = v_o + u_R;                         % cm/s
E_p_kev = (0.5*m_H_g.*v_p.^2) ./ keV2erg;    % keV -- input to sigma_LS05
sigma_p = sigma_LS05(E_p_kev);               % cm^2

kin_factor = (v_p.^2) ./ (sigma_p .* v_o);   % [7x1] = (|v_o|+u_R)^2/(sigma(E_p)*|v_o|)
prefactor  = 2*pi * m_H_g^2 * u_R^2 / n_H_cm3;

% ---- per-pixel, per-channel contribution ----
% Zraw ([energy x lon x lat], cm^-2 s^-1 sr^-1 keV^-1) was built in the
% READ DATA section above and is untouched by the esa_step selection.
% Convert to per-erg here -- this is the unit fix described above.
j_full = Zraw / keV2erg;   % now cm^-2 s^-1 sr^-1 erg^-1, but still in the CDF's
                            % ORIGINAL (unsorted, unflipped) longitude order
j_full = j_full(:, isrt, :);   % reorder lon axis with the SAME isrt used above for
                                % Z (LONGITUDE SETUP section) so this matches the
                                % final sorted/flip_view'd 'lon' vector used for
                                % plotting -- without this, the pressure maps were
                                % misaligned/mirrored relative to the flux map
j_full(~(j_full >= 0)) = NaN;  % v3d5: drop fills/NaN but keep measured zeros (zero pressure)

dP_step = nan(size(j_full));   % [7 x nlon x nlat], units: erg/cm^2 per channel
for jstep = 1:numel(energy_kev)
    dP_step(jstep,:,:) = prefactor * kin_factor(jstep) * ...
        (dE_kev(jstep)/energy_kev(jstep)) * j_full(jstep,:,:);
end

P_ram_step_erg = permute(dP_step, [3 2 1]);      % [lat x lon x 7], erg/cm^2 -- per-ESA-step maps
P_ram_full_erg = squeeze(nansum(dP_step, 1)).';  % [lat x lon], erg/cm^2      -- summed over all 7
P_ram_full_erg(squeeze(all(isnan(dP_step), 1)).') = NaN;   % v3d5: no data at any step -> NaN, not 0

P_ram_step = P_ram_step_erg * erg_to_pdyneAU;    % [lat x lon x 7], pdyne*AU/cm^2
P_ram_full = P_ram_full_erg * erg_to_pdyneAU;    % [lat x lon],      pdyne*AU/cm^2

fprintf('LOS ram pressure: u_R = %g km/s, n_H = %g cm^-3, output units: pdyne*AU/cm^2\n', u_R_kms, n_H_cm3);

%---- plot each ESA step, then the full-range sum, in the same Mollweide/ribbon style ----%
for jstep = 1:numel(energy_kev)
    plot_ena_mollweide(P_ram_step(:,:,jstep), lat, lon, flip_view, lat_center, lon_center, ...
        sprintf('LOS Ram Pressure | E = %.3f keV (step %d)', energy_kev(jstep), jstep), ...
        'P_{ram}\cdotLOS (pdyne\cdotAU/cm^2)', 20+jstep, ovc, RIB);
end
plot_ena_mollweide(P_ram_full, lat, lon, flip_view, lat_center, lon_center, ...
    'LOS Ram Pressure | Full energy range (sum of 7 steps)', ...
    'P_{ram}\cdotLOS (pdyne\cdotAU/cm^2)', 30, ovc, RIB);


%% RIBBON vs REST SUMS (per ESA step)
%==================== RIBBON vs REST SUMS ====================%
% Classify every pixel as inside vs outside the IBEX ribbon annulus
% (same Dayeh et al. 2019 reference arc as the overlay, RIB:
% center + inner/outer radii) and compare LOS ram pressure
% inside vs outside, per ESA step and for the full range.
%
% NOTE ON "SUM": a plain pixel-count sum will almost always be
% dominated by the "rest of sky" bucket simply because it has far more
% pixels than the thin ribbon annulus -- that's a pixel-count effect,
% not necessarily a physical one. So alongside the raw sum, this also
% reports the per-pixel MEAN (fairer for "is the ribbon enhanced"), the
% pixel counts themselves, and a solid-angle-weighted sum using the
% CDF's own 'solid_angle' variable (exact sr per pixel) as the most
% physically meaningful "total in this region" estimate.

% ---- ribbon geometry (matches the overlay in IBEX RIBBON GUIDE below) ----
rib_lon0  = RIB.lon0;    % deg, Dayeh et al. 2019
rib_lat0  = RIB.lat0;    % deg
rib_width = RIB.width;   % deg
rib_rmid  = RIB.r_mid;   % deg
rib_rin   = rib_rmid - rib_width/2;
rib_rout  = rib_rmid + rib_width/2;

rib_lon0_plot = rib_lon0;
if flip_view
    rib_lon0_plot = -rib_lon0_plot;
end
rib_lon0_plot = mod(rib_lon0_plot + 180, 360) - 180;   % match 'lon' convention

% ---- angular distance of every pixel from the ribbon center ----
[LonG, LatG] = meshgrid(lon_ctr, lat_ctr);   % v3d5: pixel centres; [nlat x nlon], same column order as P_ram_step
rho = acosd( sind(LatG).*sind(rib_lat0) + ...
             cosd(LatG).*cosd(rib_lat0).*cosd(LonG - rib_lon0_plot) );

ribbon_mask = (rho >= rib_rin) & (rho <= rib_rout);
rest_mask   = ~ribbon_mask;

% ---- pull per-pixel solid angle (sr) from the CDF for weighted sums ----
try
    sa_raw = cdfread(cdf_file, 'Variables', {'solid_angle'}, 'CombineRecords', true);
    if iscell(sa_raw), sa_raw = sa_raw{1}; end
    sa_raw = double(squeeze(sa_raw));               % native [lon x lat] or [lat x lon], unknown order yet
    % auto-orient to [lat x lon] the same way Zraw was auto-oriented
    if isequal(size(sa_raw), [numel(lon_c) numel(lat_c)])
        solid_angle_map = sa_raw.';                 % -> [lat x lon]
    else
        solid_angle_map = sa_raw;                   % already [lat x lon]
    end
    solid_angle_map = solid_angle_map(:, isrt);      % match the same lon reorder as everything else
    have_solid_angle = true;
catch
    warning('Could not read solid_angle from CDF; skipping solid-angle-weighted sums.');
    have_solid_angle = false;
end

n_rib  = sum(ribbon_mask(:));
n_rest = sum(rest_mask(:));

fprintf('\n==== Ribbon vs rest, LOS Ram Pressure (ribbon = %.1f-%.1f deg from [lat0=%.2f, lon0=%.2f]) ====\n', ...
    rib_rin, rib_rout, rib_lat0, rib_lon0_plot);
fprintf('Pixel counts: ribbon = %d, rest = %d\n', n_rib, n_rest);
fprintf('%-6s | %12s %12s %20s\n', 'Step', 'Pram sum(rib)', 'sum(rest)', 'mean(rib)/mean(rest)');

rib_pram_mean_step  = nan(1, numel(energy_kev));
rest_pram_mean_step = nan(1, numel(energy_kev));

for jstep = 1:numel(energy_kev)
    Pmap = P_ram_step(:,:,jstep);

    p_rib_sum = nansum(Pmap(ribbon_mask));   p_rib_mean = nanmean(Pmap(ribbon_mask));
    p_rest_sum = nansum(Pmap(rest_mask));    p_rest_mean = nanmean(Pmap(rest_mask));

    rib_pram_mean_step(jstep)  = p_rib_mean;
    rest_pram_mean_step(jstep) = p_rest_mean;

    fprintf('%-6d | %12.4g %12.4g %20.3f\n', ...
        jstep, p_rib_sum, p_rest_sum, p_rib_mean/p_rest_mean);
end

p_rib_sum = nansum(P_ram_full(ribbon_mask));  p_rib_mean = nanmean(P_ram_full(ribbon_mask));
p_rest_sum = nansum(P_ram_full(rest_mask));   p_rest_mean = nanmean(P_ram_full(rest_mask));
fprintf('%-6s | %12.4g %12.4g %20.3f\n', 'Full', p_rib_sum, p_rest_sum, p_rib_mean/p_rest_mean);

if have_solid_angle
    fprintf('\n-- solid-angle-weighted (sum of Pram*sr, more physically meaningful than a raw pixel sum) --\n');
    fprintf('%-6s | %12s %12s\n', 'Step', 'Pram*sr(rib)', 'Pram*sr(rest)');
    for jstep = 1:numel(energy_kev)
        Pmap = P_ram_step(:,:,jstep);
        p_rib_sa  = nansum(Pmap(ribbon_mask).*solid_angle_map(ribbon_mask));
        p_rest_sa = nansum(Pmap(rest_mask).*solid_angle_map(rest_mask));
        fprintf('%-6d | %12.4g %12.4g\n', jstep, p_rib_sa, p_rest_sa);
    end
    fprintf('%-6s | %12.4g %12.4g\n', 'Full', ...
        nansum(P_ram_full(ribbon_mask).*solid_angle_map(ribbon_mask)), ...
        nansum(P_ram_full(rest_mask).*solid_angle_map(rest_mask)));
end

%---- quick visual: per-step ribbon vs rest mean pressure ----%
figure(40); set(gcf,'Color','w');
bar(categorical(string(round(energy_kev,3))), [rib_pram_mean_step(:) rest_pram_mean_step(:)])
legend('Ribbon (mean)','Rest of sky (mean)','Location','best')
ylabel('P_{ram}\cdotLOS (pdyne\cdotAU/cm^2)')
xlabel('Energy (keV)')
title('LOS Ram Pressure: ribbon vs rest, per ESA step')
set(gca,'YScale','log'); grid on

figure(1)



%% Profiles
% 1. File path
file = '/Users/mitchellshen/Library/CloudStorage/Dropbox-Personal/IMAP_ILO/SCI_ENA/p90maps_ribbon/map_ave_flux_combo.xlsx';

% 2. Import as table (robust)
opts = detectImportOptions(file);
opts.VariableNamingRule = 'preserve';   % keep original column names
T = readtable(file, opts);

% 3. Inspect data
disp('Column names:')
disp(T.Properties.VariableNames)

disp('First few rows:')
head(T)

% 4. Extract columns (EDIT names if needed)
% >>> CHANGE these names based on your actual column headers <<<
% s_cut       = T.s_cut;         % e.g., angular distance
% ave_profile = T.ave_profile;   % e.g., averaged intensity

% Ensure column vectors
M = table2array(T);

figure('Color',[1 1 1])   % FIXED version of your earlier error
for i = 2: 8 %size(M,2)
    plot(M(:,1), M(:,i), 'LineWidth', 2); hold on;
end
% for i = 9: 15 %size(M,2)
%     plot(M(:,1), M(:,i), 'LineStyle', '-.', 'LineWidth', 2); hold on;
% end
set(gca,'YScale','linear')
xlabel('Angular distance across ribbon (deg)')
ylabel('Average Intensity')
title('Stacked Ribbon Profile (Average)')
grid on
box on

% 6. Export to CSV
outTable = table(s_cut, ave_profile);
writetable(outTable, 'ribbon_profile.csv');

disp('CSV exported: ribbon_profile.csv')

% 7. OPTIONAL: If file is actually a 2D flux map
% Uncomment if your Excel is a grid instead of columns
% M = readmatrix(file);
% figure
% imagesc(M)
% set(gca,'YDir','normal')
% colorbar
% title('ENA Flux Map')

%% WOWOW
x = x_all;
n_esa = size(Y_resid, 2);

A_rib_fit   = nan(1, n_esa);
mu_rib_fit  = nan(1, n_esa);
sig_rib_fit = nan(1, n_esa);

Y_ribbon_fit = nan(size(Y_resid));

mu_fix = 0;
fit_half_width = 22;

sigma_grid = linspace(6, 15, 200);

for j = 1:n_esa

    yres = Y_resid(:,j);

    good = isfinite(x) & isfinite(yres) & (yres > 0);
    xg = x(good);
    yg = yres(good);

    fit_mask = xg >= -fit_half_width & xg <= fit_half_width;
    x_fit = xg(fit_mask);
    y_fit = yg(fit_mask);

    if numel(x_fit) < 5
        warning('ESA%d residual does not have enough points for ribbon fitting.', j);
        continue
    end

    best_sse = inf;
    best_A = nan;
    best_sigma = nan;

    for k = 1:numel(sigma_grid)
        sigma_try = sigma_grid(k);

        g = exp(-((x_fit - mu_fix).^2) ./ (2*sigma_try^2));

        A_try = sum(y_fit .* g) / sum(g.^2);

        y_try = A_try .* g;

        sse = sum((y_fit - y_try).^2);

        if sse < best_sse
            best_sse = sse;
            best_A = A_try;
            best_sigma = sigma_try;
        end
    end

    gfull = exp(-((x - mu_fix).^2) ./ (2*best_sigma^2));

    y_rib_full = nan(size(x));
    local_plot_mask = abs(x - mu_fix) <= 25;
    y_rib_full(local_plot_mask) = best_A .* gfull(local_plot_mask);

    A_rib_fit(j)   = best_A;
    mu_rib_fit(j)  = mu_fix;
    sig_rib_fit(j) = best_sigma;

    Y_ribbon_fit(:,j) = y_rib_full;
end

disp('Fixed-center, bounded-width ribbon proxy Gaussian parameters:')
for j = 1:n_esa
    fprintf('ESA%d: A = %.4g, mu = %.3f deg, sigma = %.3f deg\n', ...
        j, A_rib_fit(j), mu_rib_fit(j), sig_rib_fit(j));
end

clr = lines(n_esa);

figure('Color','w')
for j = 1:n_esa
    yres = Y_resid(:,j);
    yrib = Y_ribbon_fit(:,j);

    good_res = isfinite(x) & isfinite(yres) & yres > 0;
    good_fit = isfinite(x) & isfinite(yrib) & yrib > 0;

    semilogy(x(good_res), yres(good_res), '.', 'Color', clr(j,:), 'MarkerSize', 14); hold on
    semilogy(x(good_fit), yrib(good_fit), '-', 'Color', clr(j,:), 'LineWidth', 2.5);
end
xlabel('Slice deg')
ylabel('Residual after ISN subtraction')
title('Fixed-center, bounded-width ribbon proxy Gaussian fits')
grid on
box on
xlim([-90 110])
legend('ESA1 resid','ESA1 rib fit','ESA2 resid','ESA2 rib fit','ESA3 resid','ESA3 rib fit', ...
       'ESA4 resid','ESA4 rib fit','ESA5 resid','ESA5 rib fit','ESA6 resid','ESA6 rib fit', ...
       'ESA7 resid','ESA7 rib fit','Location','eastoutside')


%% WOW

x_all = M(:,1);
Y_all = M(:,2:8);

n_esa = size(Y_all, 2);

A_fit     = nan(1, n_esa);
mu_fit    = nan(1, n_esa);
sigma_fit = nan(1, n_esa);

Y_isn   = nan(size(Y_all));
Y_resid = nan(size(Y_all));

gauss_fun = @(p, xx) p(1) .* exp(-((xx - p(2)).^2) ./ (2*p(3)^2));

for j = 1:n_esa

    x = x_all;
    y = Y_all(:,j);

    good = isfinite(x) & isfinite(y) & y > 0;
    xg = x(good);
    yg = y(good);

    fit_mask = xg >= -65 & xg <= -10;
    x_fit = xg(fit_mask);
    y_fit = yg(fit_mask);

    if numel(x_fit) < 5
        warning('ESA%d does not have enough points for fitting.', j);
        continue
    end

    A0 = max(y_fit);
    mu0 = -33;
    sigma0 = 12;
    p0 = [A0, mu0, sigma0];

    objfun = @(p) ...
        sum((y_fit - gauss_fun([p(1), p(2), abs(p(3))], x_fit)).^2) ...
        + 1e6 * (p(2) + 33).^2;

    p_best = fminsearch(objfun, p0);

    A     = p_best(1);
    mu    = p_best(2);
    sigma = abs(p_best(3));

    y_isn_full = nan(size(y));
    y_isn_full(good) = gauss_fun([A, mu, sigma], xg);

    y_resid_full = y - y_isn_full;

    A_fit(j) = A;
    mu_fit(j) = mu;
    sigma_fit(j) = sigma;

    Y_isn(:,j) = y_isn_full;
    Y_resid(:,j) = y_resid_full;
end

disp('Fitted Gaussian parameters:')
for j = 1:n_esa
    fprintf('ESA%d: A = %.4g, mu = %.3f deg, sigma = %.3f deg\n', ...
        j, A_fit(j), mu_fit(j), sigma_fit(j));
end

clr = lines(n_esa);

figure('Color','w')
for j = 1:n_esa
    y = Y_all(:,j);
    yfit = Y_isn(:,j);

    good_data = isfinite(x_all) & isfinite(y) & y > 0;
    good_fit  = isfinite(x_all) & isfinite(yfit) & yfit > 0;

    semilogy(x_all(good_data), y(good_data), '.', 'Color', clr(j,:), 'MarkerSize', 14); hold on
    semilogy(x_all(good_fit),  yfit(good_fit), '-', 'Color', clr(j,:), 'LineWidth', 2.5);
end
xlabel('Slice deg')
ylabel('Signal')
title('All ESA curves with ISN Gaussian fits')
grid on
box on
xlim([-90 110])
legend('ESA1 data','ESA1 fit','ESA2 data','ESA2 fit','ESA3 data','ESA3 fit', ...
       'ESA4 data','ESA4 fit','ESA5 data','ESA5 fit','ESA6 data','ESA6 fit', ...
       'ESA7 data','ESA7 fit','Location','eastoutside')

figure('Color','w')
for j = 1:n_esa
    yres = Y_resid(:,j);
    good = isfinite(x_all) & isfinite(yres);
    plot(x_all(good), yres(good), '-', 'Color', clr(j,:), 'LineWidth', 1.8); hold on
end
yline(0,'k--','LineWidth',1.2)
xlabel('Slice deg')
ylabel('Residual = Data - ISN Gaussian')
title('Residuals for all ESA curves')
grid on
box on
xlim([-90 110])
legend('ESA1','ESA2','ESA3','ESA4','ESA5','ESA6','ESA7','Location','eastoutside')

figure('Color','w')
for j = 1:n_esa
    yres = Y_resid(:,j);
    good = isfinite(x_all) & isfinite(yres) & yres > 0;
    semilogy(x_all(good), yres(good), '-', 'Color', clr(j,:), 'LineWidth', 2); hold on
end
xlabel('Slice deg')
ylabel('Positive residual')
title('Positive residuals after ISN subtraction')
grid on
box on
xlim([-90 110])
legend('ESA1','ESA2','ESA3','ESA4','ESA5','ESA6','ESA7','Location','eastoutside')

%%
% Assume:
% M(:,1) = slice angle (deg)
% M(:,5) = ESA4

x = M(:,1);
y = M(:,5);

% Keep valid positive data
good = isfinite(x) & isfinite(y) & y > 0;
x = x(good);
y = y(good);

% Select fitting region (ISN-dominated side)
fit_mask = x >= -65 & x <= -10;
x_fit = x(fit_mask);
y_fit = y(fit_mask);

% Gaussian model: y = A * exp(-(x-mu)^2/(2*sigma^2))
gauss_fun = @(p, xx) p(1) .* exp(-((xx - p(2)).^2) ./ (2*p(3)^2));

% Initial guess (center near -33 deg)
A0     = max(y_fit);
mu0    = -33;
sigma0 = 12;
p0 = [A0, mu0, sigma0];

% Objective function with penalty to keep center near -33
objfun = @(p) ...
    sum((y_fit - gauss_fun([p(1), p(2), abs(p(3))], x_fit)).^2) ...
    + 1e6 * (p(2) + 33).^2;

% Fit
p_best = fminsearch(objfun, p0);

A     = p_best(1);
mu    = p_best(2);
sigma = abs(p_best(3));

% Evaluate Gaussian over full range
y_isn = gauss_fun([A, mu, sigma], x);

% Residual (subtract ISN component)
y_resid = y - y_isn;

% Plot ESA4 and Gaussian fit
figure('Color','w')
semilogy(x, y, 'kx-', 'LineWidth', 1.5, 'MarkerSize', 8); hold on
semilogy(x, y_isn, 'm-', 'LineWidth', 3)
xlabel('Slice deg')
ylabel('ESA4')
title('ESA4 with ISN Gaussian Fit')
legend('ESA4 data', 'ISN Gaussian fit', 'Location', 'best')
grid on
box on
xlim([-90 110])

% Plot residual (linear scale)
figure('Color','w')
plot(x, y_resid, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 6); hold on
yline(0, 'k--', 'LineWidth', 1.2)
xlabel('Slice deg')
ylabel('Residual = ESA4 - ISN Gaussian')
title('Residual after subtracting ISN contribution')
grid on
box on
xlim([-90 110])

% Plot everything together (log scale, positive residual only)
figure('Color','w')
semilogy(x, y, 'k.-', 'LineWidth', 1.2, 'MarkerSize', 14); hold on
semilogy(x, y_isn, 'm-', 'LineWidth', 3)

mask_pos = y_resid > 0;
semilogy(x(mask_pos), y_resid(mask_pos), 'r.-', 'LineWidth', 1.5, 'MarkerSize', 14)

xlabel('Slice deg')
ylabel('Signal')
title('ESA4, ISN fit, and residual (positive only)')
legend('ESA4', 'ISN Gaussian', 'Residual (>0)', 'Location', 'best')
grid on
box on
xlim([-90 110])

% Print fitted parameters
fprintf('ISN Gaussian fit parameters for ESA4:\n');
fprintf('A     = %.4g\n', A);
fprintf('mu    = %.3f deg\n', mu);
fprintf('sigma = %.3f deg\n', sigma);

%% HRC
%==================== RIBBON-CENTERED POLAR SKY MAP ====================%

% Ribbon centre: RIB (Dayeh et al. 2019). v3d4 used Funsten 2010 (221, 39)
% here while every other section used the 2019 centre.
lon0 = RIB.lon0;
lat0 = RIB.lat0;

% wrap to [-180,180]
lon0 = mod(lon0 + 180, 360) - 180;

% match your map convention
if flip_view
    lon0 = -lon0;
end
lon0 = mod(lon0 + 180, 360) - 180;

%--- flatten map ---%
% v3d5: pixel centres and the zero-keeping analysis copy, both 30x60 in the
% same column order (v3d4 used the surfm corner grid, half a pixel off).
[LonC, LatC] = meshgrid(lon_ctr, lat_ctr);
lonv = LonC(:);
latv = LatC(:);
Zv   = Z_all(:);

good = isfinite(Zv) & Zv >= 0;
lonv = lonv(good);
latv = latv(good);
Zv   = Zv(good);

%==================== CORE TRANSFORM ====================%

% radial distance
rho = acosd( sind(latv).*sind(lat0) + ...
             cosd(latv).*cosd(lat0).*cosd(lonv - lon0) );

% Azimuth about the ribbon centre (v3d5). v3d4 used phi = -(lon - lon0),
% which is not an azimuth: points due north and due south of the centre
% both landed at phi = 0. azimuth_about_center gives the position angle in
% the tangent plane (from local east toward north); subtracting 90 deg keeps
% the old orientation (north of the centre at phi = 0, east at -90).
phi = azimuth_about_center(latv, lonv, lat0, lon0) - 90;
phi = mod(phi + 180, 360) - 180;


%==================== BIN TO GRID ====================%

phi_edges = -180:6:180;
rho_edges = 0:6:180;

phi_cent = (phi_edges(1:end-1) + phi_edges(2:end))/2;
rho_cent = (rho_edges(1:end-1) + rho_edges(2:end))/2;

Zpol = nan(numel(rho_cent), numel(phi_cent));

ibin_phi = discretize(phi, phi_edges);
ibin_rho = discretize(rho, rho_edges);

for ir = 1:numel(rho_cent)
    for ip = 1:numel(phi_cent)
        use = (ibin_rho == ir) & (ibin_phi == ip);
        if any(use)
            Zpol(ir, ip) = median(Zv(use), 'omitnan');
        end
    end
end

%==================== PLOT ====================%

[PhiGrid, RhoGrid] = meshgrid(phi_cent, rho_cent);

X = RhoGrid .* cosd(PhiGrid);
Y = RhoGrid .* sind(PhiGrid);

figure
pcolor(X, Y, Zpol)
shading flat
set(gca,'ColorScale','linear')
colormap(turbo)

axis equal
axis([-185 185 -185 185])
axis off
hold on

% outer boundary
th = linspace(0,360,721);
plot(180*cosd(th), 180*sind(th), 'k-', 'LineWidth', 1.5)

% radial circles
for rr = 45:45:135
    plot(rr*cosd(th), rr*sind(th), 'k--', 'LineWidth', 0.8)
end

% spokes
for aa = 0:30:330
    plot([0 180*cosd(aa)], [0 180*sind(aa)], 'k--', 'LineWidth', 0.8)
end

% azimuth labels
for aa = 0:30:330
    xt = 200*cosd(aa);
    yt = 200*sind(aa);
    text(xt, yt, sprintf('%d', aa), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', ...
        'FontSize',16);
end

% ribbon guide: reference arc radius (RIB)
r_mid = RIB.r_mid;
plot(r_mid*cosd(th), r_mid*sind(th), 'k-', 'LineWidth', 2)

%==================== V1 / V2 / RC ====================%

% Voyager directions
lon_v1 = 255.0; lat_v1 = 35.0;
lon_v2 = 290.4; lat_v2 = -32.2;

% wrap
lon_v1 = mod(lon_v1 + 180, 360) - 180;
lon_v2 = mod(lon_v2 + 180, 360) - 180;

% match map convention
if flip_view
    lon_v1 = -lon_v1;
    lon_v2 = -lon_v2;
end
lon_v1 = mod(lon_v1 + 180, 360) - 180;
lon_v2 = mod(lon_v2 + 180, 360) - 180;

% --- RC ---
plot(0, 0, 'mo', 'MarkerFaceColor','w', 'MarkerSize',8)
text(0, 0, ' RC', ...
    'Color','m','FontSize',14,'FontWeight','bold', ...
    'HorizontalAlignment','left','VerticalAlignment','bottom')

% --- V1 ---
rho_v1 = acosd( sind(lat_v1).*sind(lat0) + ...
                cosd(lat_v1).*cosd(lat0).*cosd(lon_v1 - lon0) );

phi_v1 = azimuth_about_center(lat_v1, lon_v1, lat0, lon0) - 90;   % v3d5: same azimuth as the map
phi_v1 = mod(phi_v1 + 180, 360) - 180;

x_v1 = rho_v1 * cosd(phi_v1);
y_v1 = rho_v1 * sind(phi_v1);

plot(x_v1, y_v1, 'mo', 'MarkerFaceColor','w', 'MarkerSize',8)
text(x_v1, y_v1, ' V1', ...
    'Color','m','FontSize',14,'FontWeight','bold', ...
    'HorizontalAlignment','left','VerticalAlignment','bottom')

% --- V2 ---
rho_v2 = acosd( sind(lat_v2).*sind(lat0) + ...
                cosd(lat_v2).*cosd(lat0).*cosd(lon_v2 - lon0) );

phi_v2 = azimuth_about_center(lat_v2, lon_v2, lat0, lon0) - 90;   % v3d5: same azimuth as the map
phi_v2 = mod(phi_v2 + 180, 360) - 180;

x_v2 = rho_v2 * cosd(phi_v2);
y_v2 = rho_v2 * sind(phi_v2);

plot(x_v2, y_v2, 'mo', 'MarkerFaceColor','w', 'MarkerSize',8)
text(x_v2, y_v2, ' V2', ...
    'Color','m','FontSize',14,'FontWeight','bold', ...
    'HorizontalAlignment','left','VerticalAlignment','bottom')

%==================== COLORBAR ====================%

title('Ribbon-centered polar sky map', 'FontSize', 18)

cb = colorbar;
cb.Label.Interpreter = 'none';
cb.Label.String = sprintf( ...
    'Intensity (counts cm^{-2} s^{-1} sr^{-1} keV^{-1}) [ECLIPJ2000] at E = %.3f keV', ...
    energy_kev(esa_step));
cb.FontSize = 14;




%% Functions

function plot_ena_mollweide(Zmap, lat, lon, flip_view, lat_center, lon_center, ...
    title_str, cbar_label, fig_num, ovc, rib)
% Mollweide map + IBEX ribbon guide/markers, factored out of the main
% script so it can be reused for the LOS ram pressure maps (same
% projection, wrap-padding, and overlay style as the primary flux plot;
% does NOT include the cross-ribbon-cut/profile analysis). No clim() is
% applied here since the pressure ranges are model-dependent -- add one
% manually if you want to fix the color scale across figures.
%
% Zmap, lat, lon must already be on the same [lat x lon] grid / edge
% convention used elsewhere in this script (i.e. lat/lon already shifted
% to SW-corner edges, see the half-pixel correction earlier).

% FIX (v3d4): same edge/seam handling as the main map. 'false' keeps this
% function's original mask convention (~isnan & ~= 0) rather than (> 0),
% since the ram-pressure maps are not sign-restricted.
if nargin < 10 || isempty(ovc), ovc = [1 1 1]; end   % overlay colour
if nargin < 11 || isempty(rib)   % v3d5: ribbon reference arc (Dayeh et al. 2019)
    rib = struct('lon0', 218.33, 'lat0', 40.38, 'r_mid', 74.81, 'width', 36);
end

[LatV, LonV, C, A, lon_center_eff] = ...
    ena_map_grid(Zmap, lat, lon, flip_view, lon_center, false);

figure(fig_num);
set(gcf, 'Color', [1 1 1]);
ax = axesm('mollweid', ...
    'Origin',[lat_center lon_center_eff 0], ...
    'FLatLimit', [-90 90], ...     % FIX (v3d4): see note on the main axesm call
    'FLonLimit', [-180 180], ...
    'Frame', 'on', ...
    'Grid', 'on', ...
    'MeridianLabel', 'off', ...
    'ParallelLabel', 'off', ...
    'MLineLocation', 30, ...
    'PLineLocation', 30, ...
    'GLineWidth', 1.0, ...
    'Gcolor', [1 0.6 0], ...
    'FEdgeColor', [0 0 0.5], ...
    'FontSize', 12);
axis off
tightmap
set(ax, 'Color', 'none')
setm(ax, 'FFaceColor', [0 0 0])

h = surfm(LatV, LonV, C);
set(h, 'EdgeColor', 'none', 'FaceColor', 'flat', ...
    'FaceAlpha', 'flat', 'AlphaData', A, 'AlphaDataMapping', 'none');
set(gca, 'ColorScale', 'linear')
colormap("turbo")
title(title_str, 'FontSize', 16);

% Manual meridian labels
lablat = 0;
meridians = -180:30:180;
for k = 1:numel(meridians)
    m = meridians(k);
    if flip_view, val = -m; else, val = m; end   % v3d5: follow flip_view
    val = mod(val + 180, 360) - 180;
    if abs(val) == 180
        txt = '180°';
    elseif val == 0
        txt = '0°';
    else
        txt = sprintf('%d°', val);
    end
    textm(lablat, m, txt, 'Color', ovc, 'FontSize', 12, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

cb = colorbar('southoutside');
cb.Label.String = cbar_label;
cb.FontSize = 12;

% IBEX ribbon guide: reference arc rib (Dayeh et al. 2019)
lon0 = rib.lon0; lat0 = rib.lat0; width = rib.width;
r_mid = rib.r_mid; r_in = r_mid - width/2; r_out = r_mid + width/2;
az = linspace(0,360,721);
[lat_mid, lon_mid] = smallcircle_deg(lat0, lon0, r_mid, az);
[lat_in , lon_in ] = smallcircle_deg(lat0, lon0, r_in , az);
[lat_out, lon_out] = smallcircle_deg(lat0, lon0, r_out, az);

lon_v1 = mod(255.0 + 180, 360) - 180; lat_v1 =  35.0;
lon_v2 = mod(290.4 + 180, 360) - 180; lat_v2 = -32.2;
lon_nose = mod(259.200622 + 180, 360) - 180; lat_nose =  5.116296;
lon_tail = mod( 79.200622 + 180, 360) - 180; lat_tail = -5.116296;

if flip_view
    lon_mid = -lon_mid; lon_in = -lon_in; lon_out = -lon_out;
    lon_v1 = -lon_v1; lon_v2 = -lon_v2;
    lon_nose = -lon_nose; lon_tail = -lon_tail; lon0 = -lon0;
end
lon_mid = mod(lon_mid + 180, 360) - 180;
lon_in  = mod(lon_in  + 180, 360) - 180;
lon_out = mod(lon_out + 180, 360) - 180;
lon_v1  = mod(lon_v1  + 180, 360) - 180;
lon_v2  = mod(lon_v2  + 180, 360) - 180;
lon_nose= mod(lon_nose+ 180, 360) - 180;
lon_tail= mod(lon_tail+ 180, 360) - 180;
lon0    = mod(lon0    + 180, 360) - 180;

plotm(lat_mid, lon_mid, '-',  'Color', ovc, 'LineWidth', 2)
plotm(lat_in , lon_in , '--', 'Color', ovc, 'LineWidth', 1.5)
plotm(lat_out, lon_out, '--', 'Color', ovc, 'LineWidth', 1.5)

plotm(lat0, lon0, 'wo', 'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat0, lon0, 'RC', 'Color',ovc,'FontSize',12,'FontWeight','bold', ...
    'HorizontalAlignment','right','VerticalAlignment','bottom')

plotm(lat_v1, lon_v1, 'wo', 'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_v1, lon_v1, '  V1', 'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','right', 'VerticalAlignment','bottom')

plotm(lat_v2, lon_v2, 'wo', 'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_v2, lon_v2, '  V2', 'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','right', 'VerticalAlignment','top')

plotm(lat_nose, lon_nose, 'wo', 'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_nose, lon_nose-3, '  Nose', 'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','left', 'VerticalAlignment','bottom')

plotm(lat_tail, lon_tail, 'wo', 'MarkerFaceColor',ovc, 'MarkerSize',6)
textm(lat_tail, lon_tail, '  Tail', 'Color',ovc,'FontSize',12,'FontWeight','bold',...
    'HorizontalAlignment','right', 'VerticalAlignment','top')

end

function [lat2, lon2] = smallcircle_deg(lat1, lon1, radius_deg, az_deg)
% Generate a small circle on a sphere (degrees)

lat2 = asind( sind(lat1).*cosd(radius_deg) + ...
              cosd(lat1).*sind(radius_deg).*cosd(az_deg) );

lon2 = lon1 + atan2d( sind(az_deg).*sind(radius_deg).*cosd(lat1), ...
                      cosd(radius_deg) - sind(lat1).*sind(lat2) );

% wrap to [-180,180]
lon2 = mod(lon2 + 180, 360) - 180;
end

%
function v = sph2cart_unit(lon_deg, lat_deg)
lon = deg2rad(lon_deg);
lat = deg2rad(lat_deg);
v = [cos(lat).*cos(lon), cos(lat).*sin(lon), sin(lat)];
end

function [lon_deg, lat_deg] = cart2sph_deg(v)
v = v ./ norm(v);
lat_deg = asind(v(3));
lon_deg = atan2d(v(2), v(1));
lon_deg = mod(lon_deg + 180, 360) - 180;
end

function v_rot = rotate_about_axis(v, k, theta)
% Rodrigues rotation
k = k / norm(k);
v_rot = v*cos(theta) + cross(k, v)*sin(theta) + k*dot(k, v)*(1-cos(theta));
v_rot = v_rot / norm(v_rot);
end

function d = angdist_deg(lat1, lon1, lat2, lon2)
d = acosd( sind(lat1).*sind(lat2) + cosd(lat1).*cosd(lat2).*cosd(lon1-lon2) );
end

function phi = azimuth_about_center(lat, lon, lat0, lon0)
% azimuth around the center, measured in the local tangent plane

rc = sph2cart_unitvec(lon0, lat0);

east  = [-sind(lon0), cosd(lon0), 0];
north = [-sind(lat0).*cosd(lon0), -sind(lat0).*sind(lon0), cosd(lat0)];

v = sph2cart_unitvec(lon, lat);
proj = v - (v*rc.') .* rc;

x = proj*east.';
y = proj*north.';

phi = atan2d(y, x);
end

function v = sph2cart_unitvec(lon_deg, lat_deg)
lon = deg2rad(lon_deg);
lat = deg2rad(lat_deg);

x = cos(lat).*cos(lon);
y = cos(lat).*sin(lon);
z = sin(lat);

v = [x(:), y(:), z(:)];
end

function [Vq, Sq] = interp2_stat_uncert(x, y, V, S, xq, yq)
%INTERP2_STAT_UNCERT Bilinear interpolation with uncertainty propagation.
%
%   [Vq,Sq] = interp2_stat_uncert(x,y,V,S,xq,yq)
%
% x  : longitude pixel centers [1 x Nx], sorted ascending, degrees
% y  : latitude  pixel centers [1 x Ny], sorted ascending, degrees
% V  : intensity map [Ny x Nx]
% S  : native 1-sigma statistical-uncertainty map [Ny x Nx]
% xq : query longitudes, degrees
% yq : query latitudes, degrees
%
% The interpolated value is
%       Vq = sum_k w_k V_k
% and, for independent native-pixel statistical errors,
%       Sq = sqrt(sum_k w_k^2 S_k^2).
%
% Longitude is treated as periodic across the +/-180 degree seam.
% All four surrounding native pixels are required for a true bilinear
% estimate; otherwise the query point is returned as NaN.

    x = x(:).';
    y = y(:).';

    if size(V,1) ~= numel(y) || size(V,2) ~= numel(x)
        error('V must have size [numel(y) x numel(x)].');
    end
    if ~isequal(size(S), size(V))
        error('S must have the same size as V.');
    end
    if ~isequal(size(xq), size(yq))
        error('xq and yq must have the same size.');
    end

    original_size = size(xq);
    xqv = xq(:);
    yqv = yq(:);

    Vqv = nan(size(xqv));
    Sqv = nan(size(xqv));

    % Periodic longitude padding.  This allows a query close to the
    % +/-180 deg seam to interpolate between the last and first columns.
    x_ext = [x(end)-360, x, x(1)+360];
    V_ext = [V(:,end), V, V(:,1)];
    S_ext = [S(:,end), S, S(:,1)];

    for iq = 1:numel(xqv)
        xx = mod(xqv(iq) + 180, 360) - 180;
        yy = yqv(iq);

        if ~isfinite(xx) || ~isfinite(yy) || yy < y(1) || yy > y(end)
            continue
        end

        % Locate bracketing longitude centers in the periodic grid.
        ix2 = find(x_ext >= xx, 1, 'first');
        if isempty(ix2) || ix2 == 1
            continue
        end
        ix1 = ix2 - 1;

        % Locate bracketing latitude centers.
        iy2 = find(y >= yy, 1, 'first');
        if isempty(iy2)
            continue
        elseif iy2 == 1
            % Exactly on the first latitude center cannot have a lower
            % bracketing center for bilinear interpolation.  Accept an
            % exact-center query by using the next cell with ty = 0.
            if abs(yy - y(1)) < 100*eps(max(1,abs(y(1)))) && numel(y) >= 2
                iy1 = 1;
                iy2 = 2;
            else
                continue
            end
        else
            iy1 = iy2 - 1;
        end

        x1 = x_ext(ix1);
        x2 = x_ext(ix2);
        y1 = y(iy1);
        y2 = y(iy2);

        % If query is exactly on the uppermost latitude center, use the
        % final latitude cell with ty = 1.
        if iy2 == numel(y) && abs(yy-y(end)) < 100*eps(max(1,abs(y(end))))
            iy1 = numel(y)-1;
            iy2 = numel(y);
            y1 = y(iy1);
            y2 = y(iy2);
        end

        if x2 == x1 || y2 == y1
            continue
        end

        tx = (xx - x1) / (x2 - x1);
        ty = (yy - y1) / (y2 - y1);

        % Numerical tolerance at exact pixel centers/edges.
        if tx < -1e-12 || tx > 1+1e-12 || ty < -1e-12 || ty > 1+1e-12
            continue
        end
        tx = min(max(tx,0),1);
        ty = min(max(ty,0),1);

        w = [(1-tx)*(1-ty), ...
              tx   *(1-ty), ...
             (1-tx)*ty,     ...
              tx   *ty];

        vals = [V_ext(iy1,ix1), V_ext(iy1,ix2), ...
                V_ext(iy2,ix1), V_ext(iy2,ix2)];
        sigs = [S_ext(iy1,ix1), S_ext(iy1,ix2), ...
                S_ext(iy2,ix1), S_ext(iy2,ix2)];

        if ~all(isfinite(vals)) || ~all(isfinite(sigs))
            continue
        end

        Vqv(iq) = sum(w .* vals);
        Sqv(iq) = sqrt(sum((w .* sigs).^2));
    end

    Vq = reshape(Vqv, original_size);
    Sq = reshape(Sqv, original_size);
end


%==================== v3d4: SHARED MAP GRID BUILDER ====================%

function [LatV, LonV, C, A, lon_center_out] = ...
    ena_map_grid(Zmap, lat, lon, flip_view, lon_center, positive_only)
% Turn the script's SW-corner edge vectors into a vertex grid that surfm can
% render without dropping cells.
%
% Three things this fixes, none of which the old wrap-padding handled:
%
%  1. surfm with 'FaceColor','flat' uses C(i,j) for the face between vertices
%     (i,j) and (i+1,j+1) and discards the last row and column of C. So the
%     vertex arrays must be EDGES (nlat+1 x nlon+1) with C padded to match.
%
%  2. 'lon' comes from lon_c + dlon/2, i.e. the cell UPPER edges. flip_view
%     negates them, which turns them into lower edges -- the two errors
%     cancel. Without the flip the map is shifted one whole bin, so handle
%     both cases explicitly.
%
%  3. The map seam sits at lon_center - 180. If the longitude array has to
%     wrap anywhere in its interior, surfm kills BOTH faces touching the
%     wrapped vertex, leaving a two-cell black swath at the limb. Cure: make
%     the array monotonic in frame coordinates (lon - lon_center) by rolling
%     it to start at the seam, and inset both ends so no vertex sits exactly
%     on the frame. The roll is only exact if the seam lands on a cell
%     boundary, so subdivide by the smallest integer that makes it so.

if nargin < 6, positive_only = true; end

lat  = lat(:).';
lon  = lon(:).';
dlat = median(diff(lat));
dlon = median(diff(lon));

% ---- cell LOWER edges ----
if flip_view
    lon_lo = lon;          % flip already turned upper edges into lower edges
else
    lon_lo = lon - dlon;
end
lat_e  = [lat, lat(end) + dlat];
lon_e0 = lon_lo(1);

% ---- subdivide so the seam lands on a cell boundary ----
seam = lon_center - 180;
ref  = 1;
while ref <= 12
    f = (seam - lon_e0) / (dlon/ref);
    if abs(f - round(f)) < 1e-9, break; end
    ref = ref + 1;
end
if ref > 12
    ref  = 2;
    step = dlon/ref;
    seam = lon_e0 + round((seam - lon_e0)/step)*step;
    warning('ena_map_grid:seamSnap', ...
        ['No small subdivision puts the seam on a cell boundary; ' ...
         'snapping seam to %.4f deg (map centre %.4f deg).'], seam, seam+180);
end
step           = dlon/ref;
lon_center_out = seam + 180;

% ---- subdivide, then roll to the seam ----
Zf    = repelem(Zmap, 1, ref);
nfine = size(Zf, 2);
lon_e = lon_e0 + (0:nfine)*step;
lon_c = lon_e(1:end-1) + step/2;

[~, is] = sort(mod(lon_c - seam, 360));
Zf      = Zf(:, is);

lon_e = seam + (0:nfine)*step;          % monotonic in frame coords, -180 -> +180
lon_e([1 end]) = lon_e([1 end]) + [1e-6, -1e-6];   % keep both ends off the frame

% ---- latitude refinement ----
% In 'nose' mode the map's south vertex corresponds to geographic lat -85,
% which falls INSIDE the bottom 6-deg row. That row's lower vertices are
% degenerate (they all collapse onto the limb), so its faces cannot reach the
% vertex and leave a hole at the bottom tip. Splitting the rows puts the vertex
% in a normal, non-degenerate row. No effect in 'flat' mode, where the grid
% pole and the map vertex already coincide. repelem copies values, so the map
% still reads at its native latitude resolution.
reflat = 4;                                   % e.g. 6 deg -> 1.5 deg
Zf     = repelem(Zf, reflat, 1);
lat_e  = lat_e(1) + (0:size(Zf,1)) * (dlat/reflat);

% ---- vertex grid, colour padded to vertex size ----
[LonV, LatV] = meshgrid(lon_e, lat_e);
C = nan(size(LonV));
C(1:end-1, 1:end-1) = Zf;

if positive_only
    A = double(~isnan(C) & C > 0);
else
    A = double(~isnan(C) & C ~= 0);
end
C(A == 0) = NaN;
end
