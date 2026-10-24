function quicklook_gui_imap_lo(cdf_file)
% QUICKLOOK_GUI_IMAP_LO  Generic interactive quicklook GUI for IMAP-Lo
% map-style CDF files (L1C quickmaps, L3 ENA intensity / spectral-index /
% survival-probability maps, etc.)
%
% Unlike a product-specific script, this GUI does NOT hardcode variable
% names like "esa_level" or "ecl_lat". Instead it reads each variable's
% DEPEND_0..DEPEND_3 attributes to find:
%   - which two dependencies are the map axes (name contains "lat"/"lon")
%   - which other dependencies exist (energy, epoch, esa_level, ...) and
%     exposes those as dropdown selectors, built dynamically per variable
%
% Usage:
%   quicklook_gui_imap_lo                     % prompts for a file
%   quicklook_gui_imap_lo('path/to/file.cdf')  % opens with a file preloaded
%
% Requires the NASA SPDF CDF-MATLAB reader (spdfcdfread / spdfcdfinfo) on
% the path, e.g.:
%   addpath('/path/to/matlab_cdf391_patch-arm64')

if nargin < 1 || isempty(cdf_file)
    [f, p] = uigetfile('*.cdf', 'Select an IMAP-Lo map CDF');
    if isequal(f, 0), return; end
    cdf_file = fullfile(p, f);
end

%% ---- Build UI ----
fig = uifigure('Name', 'IMAP-Lo Quicklook (generic)', 'Position', [80 80 1450 880]);

ctrl = uipanel(fig, 'Position', [10 830 1430 45], 'BorderType', 'none');
uilabel(ctrl, 'Position', [0 10 30 22], 'Text', 'File:');
fileField = uieditfield(ctrl, 'text', 'Position', [35 10 460 22], 'Value', cdf_file, 'Editable', 'off');
browseBtn = uibutton(ctrl, 'push', 'Position', [500 10 70 22], 'Text', 'Browse...');

uilabel(ctrl, 'Position', [590 10 55 22], 'Text', 'Variable:');
varDD = uidropdown(ctrl, 'Position', [645 10 220 22]);

logCB = uicheckbox(ctrl, 'Position', [880 10 100 22], 'Text', 'Log scale', 'Value', false);

uilabel(ctrl, 'Position', [985 10 65 22], 'Text', 'Colormap:');
cmapDD = uidropdown(ctrl, 'Position', [1050 10 100 22], ...
    'Items', {'jet','parula','turbo','hot','cool'}, 'Value', 'jet');

saveBtn = uibutton(ctrl, 'push', 'Position', [1160 10 90 22], 'Text', 'Save PNG...');

% Row 2: dynamic selector slots (rebuilt per variable)
selRow = uipanel(fig, 'Position', [10 785 1430 40], 'BorderType', 'none');
sel1Label = uilabel(selRow, 'Position', [0 8 90 22], 'Text', '', 'Visible', 'off');
sel1DD    = uidropdown(selRow, 'Position', [95 8 160 22], 'Visible', 'off');
sel2Label = uilabel(selRow, 'Position', [280 8 90 22], 'Text', '', 'Visible', 'off');
sel2DD    = uidropdown(selRow, 'Position', [375 8 160 22], 'Visible', 'off');
infoLabel = uilabel(selRow, 'Position', [560 8 850 22], 'Text', '', 'FontColor', [0.4 0.4 0.4]);

axPanel = uipanel(fig, 'Position', [10 10 1430 770], 'BorderType', 'none');

browseBtn.ButtonPushedFcn = @(~,~) onBrowse();
varDD.ValueChangedFcn     = @(~,~) onVarChanged();
sel1DD.ValueChangedFcn    = @(~,~) redraw();
sel2DD.ValueChangedFcn    = @(~,~) redraw();
logCB.ValueChangedFcn     = @(~,~) redraw();
cmapDD.ValueChangedFcn    = @(~,~) redraw();
saveBtn.ButtonPushedFcn   = @(~,~) onSave();

loadFile(cdf_file);

%% ================= Nested callbacks =================

    function onBrowse()
        [f, p] = uigetfile('*.cdf', 'Select an IMAP-Lo map CDF');
        if isequal(f, 0), return; end
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
        mapVars = struct('name', {}, 'deps', {});

        for k = 1:numel(zvars)
            vname = zvars{k};
            attrs = getVarAttrs(info, vname);
            deps = getDepends(attrs);
            if isempty(deps), continue; end
            isLat = cellfun(@(d) ~isempty(regexpi(d,'lat','once')), deps);
            isLon = cellfun(@(d) ~isempty(regexpi(d,'lon','once')), deps);
            if any(isLat) && any(isLon)
                mapVars(end+1) = struct('name', vname, 'deps', {deps}); %#ok<AGROW>
            end
        end

        if isempty(mapVars)
            uialert(fig, 'No lat/lon-dependent map variables found in this file.', 'No map variables');
            return
        end

        d = struct();
        d.fname = fname;
        d.info = info;
        d.mapVars = mapVars;
        fig.UserData = d;

        varDD.Items = {mapVars.name};
        % prefer common "primary" names if present
        prefer = {'flux','ena_intensity','ena_spectral_index','counts'};
        chosen = mapVars(1).name;
        for p = 1:numel(prefer)
            if any(strcmp({mapVars.name}, prefer{p}))
                chosen = prefer{p};
                break
            end
        end
        varDD.Value = chosen;

        onVarChanged();
    end

    function attrs = getVarAttrs(info, vname)
        attrs = struct();
        if ~isfield(info, 'VariableAttributes'), return; end
        va = info.VariableAttributes;
        fn = fieldnames(va);
        for i = 1:numel(fn)
            tbl = va.(fn{i});
            if isempty(tbl), continue; end
            row = find(strcmp(tbl(:,1), vname), 1);
            if ~isempty(row)
                attrs.(fn{i}) = tbl{row,2};
            end
        end
    end

    function deps = getDepends(attrs)
        % Returns cell array of DEPEND_0, DEPEND_1, ... values, in order,
        % skipping any that are absent.
        deps = {};
        for i = 0:3
            fn = sprintf('DEPEND_%d', i);
            if isfield(attrs, fn) && ~isempty(attrs.(fn))
                v = attrs.(fn);
                if iscell(v), v = v{1}; end
                deps{end+1} = v; %#ok<AGROW>
            end
        end
    end

    function onVarChanged()
        d = fig.UserData;
        vname = varDD.Value;
        idx = find(strcmp({d.mapVars.name}, vname), 1);
        deps = d.mapVars(idx).deps;

        isLat = cellfun(@(x) ~isempty(regexpi(x,'lat','once')), deps);
        isLon = cellfun(@(x) ~isempty(regexpi(x,'lon','once')), deps);
        latName = deps{find(isLat,1)};
        lonName = deps{find(isLon,1)};
        rawSelectorNames = deps(~isLat & ~isLon);

        d.currentVar = vname;
        d.latName = latName;
        d.lonName = lonName;

        % Load coordinate values for lat/lon and every candidate selector dim
        d.lat = double(spdfcdfread(d.fname, 'Variables', latName, 'CombineRecords', true)); d.lat = d.lat(:);
        d.lon = double(spdfcdfread(d.fname, 'Variables', lonName, 'CombineRecords', true)); d.lon = d.lon(:);

        % Only keep selector dims that have more than one value -- a
        % size-1 dependency (e.g. epoch or energy in some L3 products)
        % gets squeezed out of the data array by the CDF reader anyway,
        % so it isn't meaningfully "selectable" and is dropped here.
        selectorNames = {};
        selectorVals = {};
        for s = 1:numel(rawSelectorNames)
            try
                v = spdfcdfread(d.fname, 'Variables', rawSelectorNames{s}, 'CombineRecords', true);
                v = v(:);
            catch
                v = [];
            end
            if numel(v) > 1
                selectorNames{end+1} = rawSelectorNames{s}; %#ok<AGROW>
                selectorVals{end+1} = v; %#ok<AGROW>
            end
        end
        d.selectorNames = selectorNames;
        d.selectorVals = selectorVals;

        fig.UserData = d;

        % --- Configure selector slot 1 (supports "All") ---
        if numel(selectorNames) >= 1
            items1 = formatSelectorItems(selectorNames{1}, d.selectorVals{1});
            sel1Label.Text = selectorNames{1};
            sel1DD.Items = ['All', items1];
            sel1DD.Value = 'All';
            sel1Label.Visible = 'on'; sel1DD.Visible = 'on';
        else
            sel1Label.Visible = 'off'; sel1DD.Visible = 'off';
        end

        % --- Configure selector slot 2 (single-select only) ---
        if numel(selectorNames) >= 2
            items2 = formatSelectorItems(selectorNames{2}, d.selectorVals{2});
            sel2Label.Text = selectorNames{2};
            sel2DD.Items = items2;
            sel2DD.Value = items2{1};
            sel2Label.Visible = 'on'; sel2DD.Visible = 'on';
        else
            sel2Label.Visible = 'off'; sel2DD.Visible = 'off';
        end

        if numel(selectorNames) > 2
            infoLabel.Text = sprintf(['Note: variable has %d extra dependencies beyond lat/lon; ' ...
                'only the first two ("%s","%s") are selectable here -- the rest default to index 1.'], ...
                numel(selectorNames), selectorNames{1}, selectorNames{2});
        else
            infoLabel.Text = '';
        end

        redraw();
    end

    function items = formatSelectorItems(name, vals)
        if isempty(vals)
            items = {'1'};
            return
        end
        if ~isempty(regexpi(name, 'epoch|time', 'once')) && isnumeric(vals) && all(vals > 7e5)
            % looks like a MATLAB datenum
            items = arrayfun(@(x) datestr(x, 'yyyy-mm-dd'), vals, 'UniformOutput', false);
        elseif isnumeric(vals)
            items = arrayfun(@(x) sprintf('%.3g', x), vals, 'UniformOutput', false);
        else
            items = cellstr(string(vals));
        end
        items = items(:)';
    end

    function redraw()
        d = fig.UserData;
        if ~isfield(d, 'currentVar'), return; end

        raw = double(spdfcdfread(d.fname, 'Variables', d.currentVar, 'CombineRecords', true));
        raw = squeeze(raw); % drop any size-1 dims (epoch, energy=1, etc.)

        % Only the dependencies that actually survive squeezing -- i.e.
        % lat, lon, and the pre-filtered (>1-value) selector dims -- need
        % to be matched against raw's actual dimensions.
        allDeps = [d.selectorNames, {d.lonName, d.latName}];
        depSizes = zeros(1, numel(allDeps));
        for i = 1:numel(d.selectorNames)
            depSizes(i) = numel(d.selectorVals{i});
        end
        depSizes(end-1) = numel(d.lon);
        depSizes(end)   = numel(d.lat);

        % Match each dependency to a data dimension by size (robust to
        % row-major/column-major reader differences)
        dimOrder = zeros(1, numel(allDeps));
        szTmp = size(raw);
        if numel(szTmp) < numel(allDeps)
            szTmp = [szTmp, ones(1, numel(allDeps)-numel(szTmp))];
        end
        for i = 1:numel(allDeps)
            cand = find(szTmp == depSizes(i), 1);
            if isempty(cand)
                uialert(fig, sprintf('Could not match dependency "%s" (size %d) to data array dimensions.', ...
                    allDeps{i}, depSizes(i)), 'Shape mismatch');
                return
            end
            dimOrder(i) = cand;
            szTmp(cand) = -1;
        end
        V = permute(raw, dimOrder); % now dims ordered as: [selectors..., lon, lat]

        V(V <= -1e29) = NaN; % generic fill-value catch (-1e30, -9.999e30, etc.)

        latIdxDim = numel(allDeps);       % last dim = lat (by construction above)
        lonIdxDim = numel(allDeps) - 1;   % second-to-last = lon
        nSelDims = numel(allDeps) - 2;    % = numel(d.selectorNames)

        % Build a subscript template; selector dims fixed to chosen index
        % (or looped over for "All")
        subs = repmat({1}, 1, numel(allDeps));
        subs{lonIdxDim} = ':';
        subs{latIdxDim} = ':';

        for s = 3:nSelDims
            subs{s} = 1; % any selector beyond the first two: fixed at index 1
        end
        if nSelDims >= 2
            i2 = find(strcmp(sel2DD.Items, sel2DD.Value), 1);
            if isempty(i2), i2 = 1; end
            subs{2} = i2;
        end

        cla(axPanel); %#ok<NASGU>
        delete(axPanel.Children);

        cmapName = cmapDD.Value;
        useLog = logCB.Value;

        lon_ext = [d.lon; d.lon(1)+360];
        dlat = d.lat(2) - d.lat(1);
        lat_ext = [d.lat; d.lat(end) + dlat];
        [Lon, Lat] = meshgrid(lon_ext, lat_ext);

        if nSelDims >= 1 && strcmp(sel1DD.Value, 'All')
            n1 = depSizes(1);
            nCols = ceil(sqrt(n1));
            nRows = ceil(n1 / nCols);
            tl = tiledlayout(axPanel, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
            for i1 = 1:n1
                subs{1} = i1;
                Z = squeeze(V(subs{:}));
                Z = orientLatLon(Z, size(V,lonIdxDim), size(V,latIdxDim));
                ax = nexttile(tl);
                plotMap(ax, Lon, Lat, Z, useLog, cmapName);
                title(ax, formatTileTitle(d.selectorNames, 1, i1, d), 'FontSize', 9);
            end
            title(tl, strrep(d.currentVar, '_', '\_'), 'FontWeight', 'bold');
        else
            if nSelDims >= 1
                i1 = find(strcmp(sel1DD.Items, sel1DD.Value), 1) - 1; % -1 for 'All' offset
                subs{1} = max(i1, 1);
            end
            Z = squeeze(V(subs{:}));
            Z = orientLatLon(Z, size(V,lonIdxDim), size(V,latIdxDim));
            ax = uiaxes(axPanel, 'Position', [40 30 1350 700]);
            plotMap(ax, Lon, Lat, Z, useLog, cmapName);
            title(ax, strrep(d.currentVar, '_', '\_'));
        end
    end

    function Z = orientLatLon(Z, nLonExpected, nLatExpected)
        % squeeze() can leave [nLat x nLon] or [nLon x nLat] depending on
        % how many singleton dims were removed -- force [nLat x nLon].
        if size(Z,1) == nLonExpected && size(Z,2) == nLatExpected
            Z = Z.';
        end
    end

    function s = formatTileTitle(selectorNames, slotIdx, i1, d)
        if slotIdx <= numel(selectorNames)
            items = sel1DD.Items; % 'All' + values
            s = sprintf('%s = %s', selectorNames{slotIdx}, items{i1+1});
        else
            s = '';
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
        cb.Label.String = ternary(useLog, 'log_{10}(value)', 'value');
        xlabel(ax, 'Longitude [deg]');
        ylabel(ax, 'Latitude [deg]');
        axis(ax, 'tight');
        ax.FontSize = 8;
    end

    function out = ternary(cond, a, b)
        if cond, out = a; else, out = b; end
    end

    function onSave()
        d = fig.UserData;
        if ~isfield(d, 'currentVar')
            return
        end
        [~, base] = fileparts(d.fname);
        defaultName = sprintf('%s_%s_quicklook.png', base, d.currentVar);
        [f, p] = uiputfile('*.png', 'Save quicklook as', defaultName);
        if isequal(f, 0), return; end
        exportgraphics(axPanel, fullfile(p, f), 'Resolution', 200);
    end

end
