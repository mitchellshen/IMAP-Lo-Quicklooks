# IMAP-Lo Quicklooks

MATLAB scripts for quicklooks and first-look analysis of IMAP-Lo data:

- ENA sky maps, from L3 CDF products and from CSV exports
- interstellar neutral (ISN) rates and model output
- GLOWS survival-probability inputs
- the star sensor
- L1B instrument validation
- scripts from the 2024 ground calibration

The scripts are meant to be opened in MATLAB and run section by section.

## Contents

### ENA sky maps

| Script | What it does |
|---|---|
| `ilo_ENA_CDF_v3d5.m` | **Current.** Reads an L3 (or L2) ENA map CDF and draws a Mollweide map with the ribbon reference arc and the Voyager 1/2, nose and tail markers. It also produces cross-ribbon cuts and stacked profiles with propagated statistical uncertainties, LOS ram-pressure maps, ribbon-vs-rest sums, and a ribbon-centred polar map. |
| `ilo_ENA_CDF_v0.m` – `v3d4.m` | Earlier versions; see the version history below. v3d4 produced the ribbon profiles in the first IMAP-Lo ENA paper (submitted to ApJS). |
| `ilo_ENA_CSV_v2.m` | **Current CSV version.** Same map style, made from CSV map exports (`map_flux_esa#`, `map_func_esa#`, `map_rate_esa#`). Also handles the bootstrap- and sputtering-corrected maps and the Year-2 science-plan exposure and difference maps. |
| `ilo_ENA_CSV.m`, `ilo_ENA_CSV_v1.m` | Earlier CSV versions. |

### Generic CDF quicklooks

| Script | What it does |
|---|---|
| `quicklook_gui_imap_lo.m` | GUI for any lat/lon map CDF (L1C quickmaps, L2/L3 maps). It finds the map variables and their selectable dimensions (energy, epoch, ESA level) from the `DEPEND_*` attributes. |
| `quicklook_gui_imap_lo_l1c.m` | GUI for L1C quickmaps (ESA level × latitude × longitude). |
| `quicklook_imap_lo_l1c_quickmap.m` | Script version: one panel per ESA level for a single L1C quickmap file. |

### Interstellar neutrals

| Script | What it does |
|---|---|
| `ilo_ISN.m` | Daily ISN rate CSVs (`data_YD_<yyyydoy>_esa<n>.csv`) for pivots 75°, 90° and 105°. Plots rate vs time and vs orbital angle, fits the peaks, estimates the cone centre, and compares with the SWAPI pickup-ion density. Earth's ecliptic longitude comes from SPICE (MICE). |
| `ilo_ISN_model.m` | ISN model output (`.dat`; He, H, O, Ne; primary and secondary populations). Builds a file index, plots flux and energy vs spin angle per repoint and pivot, and makes pseudo sky maps. |

### GLOWS

| Script | What it does |
|---|---|
| `ilo_GLOWS_SP.m` | GLOWS L3e CDFs used for survival probabilities. Plots scalar variables vs time, every 2-D variable per file, and the first slice of 3-D variables. |

### Star sensor

| Script | What it does |
|---|---|
| `ilo_star_pipeline_v1.m` | **Current.** L1B prostar CDFs, keeping the highest version per repoint, with the pivot angle taken from the matching L1B NHK file. Plots amplitude vs NEP angle for each file, daily mean curves, and a time × angle spectrogram, with optional PNG export. |
| `ilo_star_pipeline.m` | Earlier version. |
| `ilo_star_validation_v2.m` | **Current.** Compares L1A star with L1B prostar data for selected repoints and runs an autocorrelation test. |
| `ilo_star_validation_v1.m` | Earlier version. |

### Instrument and L1B validation

| Script | What it does |
|---|---|
| `ilo_inst_validation.m` | Checks the L1B instrument-status summary against L1A/L1B NHK and SHK: TOF and anode thresholds, MCP/PAC voltages, deflection and PMT, IFB/PCC, characterization test, SHCOARSE and epoch. |
| `ilo_l1b_validation_v1.m` | Loads one repoint's L1B DE, DE rates, histogram rates, status, monitor rates, NHK and SHK. The later sections are unfinished. |

### Ground calibration (2024)

| Script | What it does |
|---|---|
| `ilo_ESA_swp_v3.m` | **Current.** ESA U+/U− voltage sweeps with the 930H beam: binned silver triple counts from the instrument NHK and sniffer CSVs. |
| `ilo_ESA_swp_v1.m`, `ilo_ESA_swp_v2.m` | Earlier versions. |
| `ilo_troubleshoot.m` | Ground-test housekeeping: MCP voltage set point and monitors from the `ILO_IFB` and `ILO_TOF` CSVs, matched in time. |

## Requirements

- MATLAB R2022a or newer (the scripts use `clim`, `exportgraphics`, `turbo` and `tiledlayout`).
- Mapping Toolbox, for the Mollweide maps (`axesm`, `surfm`, `plotm`, `textm`).
- Statistics and Machine Learning Toolbox, for `nansum`/`nanmean` in the ENA and ISN scripts.
- Signal Processing Toolbox, for `xcorr` in `ilo_star_validation_v2.m`.
- CDF readers:
  - The ENA CDF and GLOWS scripts use MATLAB's built-in `cdfread`.
  - The star, validation, L1C and GUI scripts use the NASA SPDF CDF patch for MATLAB (`spdfcdfread`, `spdfcdfinfo`).
- MICE (SPICE for MATLAB) with the `naif0012.tls` and `de440s.bsp` kernels, for `ilo_ISN.m`.
- `bluewhitered` from the MATLAB File Exchange, for the science-plan difference maps in `ilo_ENA_CSV_v1.m` and `v2.m`.

## Running a script

1. Set the data paths at the top of the script (`fld`, `cdf_name`, or the data folders). They are currently hardcoded to the author's machine.
2. Set the options in the `USER SWITCH` block, for example `esa_step`, `quantity`, `flip_view`, `view_mode`, `slice_view`, `save` and `save_fig`.
3. Run section by section (Run Section, Ctrl+Enter).
   - In the ENA scripts, the `Profiles`, `WOW` and `WOWOW` sections at the bottom read a separate Excel file of saved profiles.
   - Run `WOW` before `WOWOW`. Running the whole file from the top stops at `WOWOW`.

## Data conventions

L3 map file names follow `imap_lo_l3_<source>-<product>-h-<frame>-<sp>-ram-hae-6deg-6mo_<date>_v<version>.cdf`:

| Part | Values |
|---|---|
| `<source>` | `ilo` = pivot-combined map (75°, 90° and 105°); `l075`, `l090`, `l105` = a single pivot angle |
| `<product>` | `ena…` = intensity map (`ena_intensity`); `spx…` = spectral-index map (`ena_spectral_index`); a `Msk` suffix = masked product |
| `<frame>` | `hf` = heliospheric frame; `sf` = spacecraft frame |
| `<sp>` | `sp` = survival-probability corrected; `nsp` = not corrected |

- **Grid:** 60 × 30 pixels at 6°, with centres at 3…357° longitude and −87…87° latitude, in HAE ecliptic coordinates.
- **Fill values:** −1e31 marks pixels with no exposure or removed by the mask.
- **Zeros:** a zero-intensity pixel has exposure > 0 and σ = 0. A zero count is a measurement in these low-count data, so the analysis keeps zeros.
- **v002 reprocessing:** the 2026-07-31 v002 pivot-combined maps add the asymmetric systematic errors (`ena_intensity_sys_err_plus/minus`). Everything else is identical to v001.

## Map and analysis conventions (`ilo_ENA_CDF_v3d5.m`)

- **`flip_view = true`** gives the outside-looking-in view.
- **`view_mode`** is `'flat'` (ecliptic frame, IBEX heritage) or `'nose'` (oblique, with the nose at the map centre).
- **Ribbon reference arc:** Dayeh et al. (2019), centre (218.33°, 40.38°), radius 74.81°. It is defined once as `RIB` at the top of the script and used by every section.
- **Markers:**
  - Voyager 1 (255.0°, 35.0°)
  - Voyager 2 (290.4°, −32.2°)
  - nose (259.20°, 5.12°)
  - tail (79.20°, −5.12°)
- **Pixel centres vs corners:** `lat`/`lon` are the `surfm` cell corners, used only for drawing. Sampling, the ribbon mask and the polar map use the pixel centres (`lat_ctr`/`lon_ctr`).

### Cross-ribbon profiles

1. **Cuts:** 45 cuts perpendicular to the reference arc (every 16th of 721 arc points), sampled at s = −36…36° in 6° steps. +s points away from the ribbon centre.
2. **Sampling:** values are bilinearly interpolated at pixel centres, and the statistical uncertainty is propagated through the same weights (`interp2_stat_uncert`). Zeros are kept.
3. **Stacking:** the stacked profile is the mean over cuts, with uncertainty sqrt(Σσ²)/N.
4. **Export:** with `save = true` the script writes `<quantity>_ave_esa<k>_v3d5.csv`, with columns `s_cut_deg`, `average_intensity`, `average_stat_uncert` and `N_profiles`.
5. **Fitting:** done outside the script (Gaussian + constant on |s| ≤ 18° in the paper).

## Version history of `ilo_ENA_CDF`

| Version | Changes |
|---|---|
| v0 | Copy of the CSV script, still reading CSV maps |
| v1 | Reads L3 CDF maps with `cdfread`; quantity switch (`flux`, `bg`, `survival`); automatic matching of the energy/longitude/latitude dimensions |
| v2 | Correct sign of the half-pixel shift for `surfm` drawing |
| v3d0 | LOS ram-pressure maps |
| v3d1 | Ribbon-vs-rest sums |
| v3d2 | Reorganized ribbon analysis; header points to the 2026-07-31 v002 maps |
| v3d3 | Cut sampling with propagated statistical uncertainties (`interp2_stat_uncert`); profile and figure export; option to read L2 maps |
| v3d4 | `'flat'`/`'nose'` view modes; `surfm` vertex grid (`ena_map_grid`) and frame-limit fixes |
| v3d5 | 2019 reference arc in every section; pixel-centre sampling; zeros kept; polar map uses the true azimuth; +s outward in both views; labels follow `flip_view` |

## Known issues and plans

- Paths are hardcoded and versions live in file names. The plan is a local config file and one file per tool, with the history kept in git.
- Most scripts start with `warning('off','all')`, which also hides useful warnings.
- The star and validation scripts read CDF variables by position, not by name.
- `ilo_star_pipeline_v1.m` stops if a repoint has no matching NHK file.
- `ilo_ISN.m`:
  - `addpath('~/Users/mitchellshen/mice/...')` does not point to `/Users/mitchellshen/mice`.
  - `savepath` rewrites the saved MATLAB path on every run.
- In the ENA CDF scripts, the colour limits and colour-bar label assume `quantity = 'flux'`.
- The ribbon-centred polar map in v0–v3d3, `ilo_ENA_CSV.m` and `ilo_ENA_CSV_v1.m` pairs values with the wrong coordinates. v3d5 is the first version with a correct polar map.
