function quicklook_gui_imap_lo_l1c(cdf_file)
% QUICKLOOK_GUI_IMAP_LO_L1C  Interactive quicklook GUI for IMAP-Lo L1C
% quickmap CDF files (imap_lo_l1c_quickmap_YYYYMMDD-repointNNNNN_vNNN_XXXX.cdf)
%
% Usage:
%   quicklook_gui_imap_lo_l1c                     % prompts for a file
%   quicklook_gui_imap_lo_l1c('path/to/file.cdf')  % opens with a file preloaded
%
% Requires the NASA SPDF CDF-MATLAB reader (spdfcdfread / spdfcdfinfo) on
% the path -- add it yourself before calling this, e.g.:
%   addpath('/path/to/matlab_cdf391_patch-arm64')
%
% Controls:
%   - File field / Browse: pick the CDF
%   - Variable dropdown: any 3D (esa_level x lat x lon) variable in the file
%   - ESA level: "All" (multi-panel) or a single level (big single panel)
%   - Log color scale checkbox
%   - Colormap dropdown

if nargin < 1 || isempty(cdf_file)
    [f, p] = uigetfile('*.cdf', 'Select an IMAP-Lo L1C quickmap CDF');
    if isequal(f, 0)
        return
    end
    cdf_file = fullfile(p, f);
end

%% ---- Build UI ----
fig = uifigure('Name', 'IMAP-Lo L1C Quickmap Quicklook', 'Position', [80 80 1450 850]);

ctrl = uipanel(fig, 'Position', [10 800 1430 45], 'BorderType', 'none');

uilabel(ctrl, 'Position', [0 10 30 22], 'Text', 'File:');
fileField = uieditfield(ctrl, 'text', 'Position', [35 10 550 22], 'Value', cdf_file, 'Editable', 'off');
browseBtn = uibutton(ctrl, 'push', 'Position', [590 10 70 22], 'Text', 'Browse...');

uilabel(ctrl, 'Position', [680 10 55 22], 'Text', 'Variable:');
varDD = uidropdown(ctrl, 'Position', [735 10 140 22]);

uilabel(ctrl, 'Position', [885 10 60 22], 'Text', 'ESA level:');
esaDD = uidropdown(ctrl, 'Position', [945 10 90 22]);

logCB = uicheckbox(ctrl, 'Position', [1045 10 100 22], 'Text', 'Log scale', 'Value', false);

uilabel(ctrl, 'Position', [1150 10 65 22], 'Text', 'Colormap:');
cmapDD = uidropdown(ctrl, 'Position', [1215 10 100 22], ...
    'Items', {'jet','parula','viridis','turbo','hot'}, 'Value', 'jet');

axPanel = uipanel(fig, 'Position', [10 10 1430 780], 'BorderType', 'none');

% App state stored on the figure for use across callbacks
data = struct();
fig.UserData = data;

browseBtn.ButtonPushedFcn = @(~,~) onBrowse();
varDD.ValueChangedFcn = @(~,~) redraw();
esaDD.ValueChangedFcn = @(~,~) redraw();
logCB.ValueChangedFcn = @(~,~) redraw();
cmapDD.ValueChangedFcn = @(~,~) redraw();

loadFile(cdf_file);

%% ---- Nested callback functions ----
    function onBrowse()
        [f, p] = uigetfile('*.cdf', 'Select an IMAP-Lo L1C quickmap CDF');
        if isequal(f, 0)
            return
        end
        newFile = fullfile(p, f);
        fileField.Value = newFile;
        loadFile(newFile);
    end

    function loadFile(fname)
        try
            info = spdfcdfinfo(fname);
        catch ME
            uialert(fig, sprintf('Could not read CDF:\n%s', ME.message), 'Read error');
            return
        end

        zvars = info.Variables(:,1);

        % Read coordinate/index variables
        esa_level = double(spdfcdfread(fname, 'Variables', 'esa_level', 'CombineRecords', true));
        ecl_lat   = double(spdfcdfread(fname, 'Variables', 'ecl_lat',   'CombineRecords', true));
        ecl_lon   = double(spdfcdfread(fname, 'Variables', 'ecl_lon',   'CombineRecords', true));
        esa_level = esa_level(:); ecl_lat = ecl_lat(:); ecl_lon = ecl_lon(:);

        nEsa = numel(esa_level); nLat = numel(ecl_lat); nLon = numel(ecl_lon);

        % Find candidate 3D map variables: those depending on esa_level/lat/lon
        candidates = {};
        for k = 1:numel(zvars)
            vname = zvars{k};
            try
                att = spdfcdfinfo(fname); %#ok<NASGU> % (info already has attrs below)
            catch
            end
            try
                vattrs = getVarAttrs(info, vname);
            catch
                vattrs = struct();
            end
            if isfield(vattrs, 'DEPEND_0') && strcmpi(vattrs.DEPEND_0, 'esa_level')
                candidates{end+1} = vname; %#ok<AGROW>
            end
        end
        if isempty(candidates)
            % fallback: just offer all zvars with matching 3D size
            candidates = zvars;
        end

        d = fig.UserData;
        d.fname = fname;
        d.info = info;
        d.esa_level = esa_level;
        d.ecl_lat = ecl_lat;
        d.ecl_lon = ecl_lon;
        d.nEsa = nEsa; d.nLat = nLat; d.nLon = nLon;
        d.candidates = candidates;
        fig.UserData = d;

        varDD.Items = candidates;
        if any(strcmp(candidates, 'flux'))
            varDD.Value = 'flux';
        else
            varDD.Value = candidates{1};
        end

        esaItems = ['All', arrayfun(@(x) sprintf('%d', x), esa_level, 'UniformOutput', false)'];
        esaDD.Items = esaItems;
        esaDD.Value = 'All';

        redraw();
    end

    function attrs = getVarAttrs(info, vname)
        attrs = struct();
        idx = find(strcmp(info.Variables(:,1), vname), 1);
        if isempty(idx) || ~isfield(info, 'VariableAttributes')
            return
        end
        va = info.VariableAttributes;
        fn = fieldnames(va);
        for i = 1:numel(fn)
            tbl = va.(fn{i});
            row = find(strcmp(tbl(:,1), vname), 1);
            if ~isempty(row)
                attrs.(fn{i}) = tbl{row,2};
            end
        end
    end

    function redraw()
        d = fig.UserData;
        if ~isfield(d, 'fname')
            return
        end
        varname = varDD.Value;

        raw = double(spdfcdfread(d.fname, 'Variables', varname, 'CombineRecords', true));
        sz = size(raw);
        dims = [d.nEsa d.nLat d.nLon];
        dimOrder = zeros(1,3);
        szTmp = sz;
        for k = 1:3
            idx = find(szTmp == dims(k), 1);
            if isempty(idx)
                uialert(fig, sprintf('Variable "%s" is not a %dx%dx%d map array.', ...
                    varname, dims(1), dims(2), dims(3)), 'Shape mismatch');
                return
            end
            dimOrder(k) = idx;
            szTmp(idx) = -1;
        end
        V = permute(raw, dimOrder); % [nEsa x nLat x nLon]
        V(V <= -1e30) = NaN; % fill value

        cla(axPanel, 'reset'); %#ok<NASGU>
        delete(axPanel.Children);

        cmapName = cmapDD.Value;
        if strcmp(cmapName, 'viridis') && ~exist('viridis', 'file')
            cmapName = 'parula'; % fallback if viridis() not installed
        end

        lon_ext = [d.ecl_lon; d.ecl_lon(1)+360];
        dlat = d.ecl_lat(2) - d.ecl_lat(1);
        lat_ext = [d.ecl_lat; d.ecl_lat(end) + dlat];
        [Lon, Lat] = meshgrid(lon_ext, lat_ext);

        useLog = logCB.Value;

        if strcmp(esaDD.Value, 'All')
            nEsa = d.nEsa;
            nCols = ceil(sqrt(nEsa));
            nRows = ceil(nEsa / nCols);
            tl = tiledlayout(axPanel, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
            for i = 1:nEsa
                ax = nexttile(tl);
                Z = squeeze(V(i,:,:));
                plotMap(ax, Lon, Lat, Z, useLog, cmapName);
                title(ax, sprintf('ESA %d', d.esa_level(i)), 'FontSize', 9);
            end
            title(tl, strrep(varname, '_', '\_'), 'FontWeight', 'bold');
        else
            i = find(d.esa_level == str2double(esaDD.Value), 1);
            ax = uiaxes(axPanel, 'Position', [40 40 1350 700]);
            Z = squeeze(V(i,:,:));
            plotMap(ax, Lon, Lat, Z, useLog, cmapName);
            title(ax, sprintf('%s -- ESA level %d', strrep(varname,'_','\_'), d.esa_level(i)));
        end
    end

    function plotMap(ax, Lon, Lat, Z, useLog, cmapName)
        Z_ext = [Z, Z(:,1)];
        Z_ext = [Z_ext; Z_ext(end,:)];
        if useLog
            Z_ext(Z_ext <= 0) = NaN;
            Z_ext = log10(Z_ext);
        end
        pcolor(ax, Lon, Lat, Z_ext);
        shading(ax, 'flat');
        colormap(ax, cmapName);
        cb = colorbar(ax);
        if useLog
            cb.Label.String = 'log_{10}(value)';
        else
            cb.Label.String = 'value';
        end
        xlabel(ax, 'Ecliptic Longitude [deg]');
        ylabel(ax, 'Ecliptic Latitude [deg]');
        axis(ax, 'tight');
        ax.FontSize = 8;
    end

end
