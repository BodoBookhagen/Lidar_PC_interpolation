---
title: "Interpolating Lidar Point Clouds"
subtitle: "Various interpolation methods of lidar point-cloud data using computative efficient approaches"
subject: "Geomorphology"
date: "April 2019"
author: "Bodo Bookhagen ([bodo.bookhagen@uni-potsdam.de](bodo.bookhagen@uni-potsdam.de)), Taylor Smith ([tasmith@uni-potsdam.de](tasmith@uni-potsdam.de))"
keywords: [Point Cloud, Interpolation, Classification, lidar, geomorphology, IDW, nearest neighbor, blockmean, blockmedian]
titlepage: true
titlepage-rule-height: 2
toc-own-page: false
listings-disable-line-numbers: true
disable-header-and-footer: true
logo: "figures/pozotitle.png"
logo-width: 250
footer-left: "none"
...

# Preparing Point Cloud Data

## Ground classification
The original (pre-classified) files from the USGS data / opentopography website were reclassified using LASTools [lasground](https://rapidlasso.com/lastools/lasground/). Note that this is a commercial software that requires a license. Tests indicate that ground-classification with [pdal](https://pdal.io/) and the [Progressive Morphological Filter (PMF)](Vhttps://pdal.io/stages/filters.pmf.html#filters-pmf) provides similar results. In short, the steps were:

```bash
cd /raid/lidar_research/lidar_data/usgs_channel_islands/processed/SANTA_CRUZ
mkdir cl2_july2018
cd cl2_july2018

mkdir tiles
wine /opt/LAStools/bin/lastile.exe -set_classification 0 -flag_as_withheld -tile_size 500 -buffer 10 -cores 8 -i ../unclass_og/ARRA*.laz -olaz -odir tiles

# quick overview by thinning file (keep lowest points)
wine /opt/LAStools/bin/lasthin.exe -sparse -step 30 -lowest -i tiles/*.laz -olaz -merged -olaz -o SCI_ARRA_noise_30m_lowest.laz
wine /opt/LAStools/bin/blast2dem.exe -hillshade -utm 11N -nad83 -meter -elevation_meter -merged -step 30 -i SCI_ARRA_5m_lowest.laz -o dtm_interp/SCI_USGS_UTM11_NAD83_lowest5m_30m_HS.tif
wine /opt/LAStools/bin/blast2dem.exe -utm 11N -nad83 -meter -elevation_meter -merged -step 30 -i SCI_ARRA_5m_lowest.laz -o dtm_interp/SCI_USGS_UTM11_NAD83_lowest5m_30m.tif
gdalinfo -hist -stats dtm_interp/SCI_USGS_UTM11_NAD83_lowest5m_30m.tif
gdalinfo -hist -stats dtm_interp/SCI_USGS_UTM11_NAD83_lowest5m_30m_HS.tif

mkdir tilesn
wine /opt/LAStools/bin/lasnoise.exe -cores 12 -i tiles/22*.laz -step_xy 2 -step_z 1 -isolated 5 -olaz -odir tilesn -odix n
wine /opt/LAStools/bin/lasnoise.exe -cores 12 -i tiles/23*.laz -step_xy 2 -step_z 1 -isolated 5 -olaz -odir tilesn -odix n
wine /opt/LAStools/bin/lasnoise.exe -cores 12 -i tiles/24*.laz -step_xy 2 -step_z 1 -isolated 5 -olaz -odir tilesn -odix n
wine /opt/LAStools/bin/lasnoise.exe -cores 12 -i tiles/25*.laz -step_xy 2 -step_z 1 -isolated 5 -olaz -odir tilesn -odix n
wine /opt/LAStools/bin/lasnoise.exe -cores 12 -i tiles/26*.laz -step_xy 2 -step_z 1 -isolated 5 -olaz -odir tilesn -odix n

#Here we are using a custom classification with medium-aggressive settings including high offset, medium standard dev, and medium spike: CHANNELS do not come out good, but little vegetation
#Tests indicate that this is LIKELY BEST CANDIDATE for channel extraction. There is some vegetation, but channels are clear
mkdir ground_overlap
wine /opt/LAStools/bin/lasground.exe -cores 12 -i tilesn/22*n.laz -by_flightline -wilderness -extra_fine -offset 0.25 -stddev 20 -spike 0.5 -bulge 0.5 -olaz -odir ground_overlap -odix g 2>&1 | tee lasground_output_22n.out
wine /opt/LAStools/bin/lasground.exe -cores 12 -i tilesn/23*n.laz -by_flightline -wilderness -extra_fine -offset 0.25 -stddev 20 -spike 0.5 -bulge 0.5 -olaz -odir ground_overlap -odix g 2>&1 | tee lasground_output_22n.out
wine /opt/LAStools/bin/lasground.exe -cores 12 -i tilesn/24*n.laz -by_flightline -wilderness -extra_fine -offset 0.25 -stddev 20 -spike 0.5 -bulge 0.5 -olaz -odir ground_overlap -odix g 2>&1 | tee lasground_output_22n.out
wine /opt/LAStools/bin/lasground.exe -cores 12 -i tilesn/25*n.laz -by_flightline -wilderness -extra_fine -offset 0.25 -stddev 20 -spike 0.5 -bulge 0.5 -olaz -odir ground_overlap -odix g 2>&1 | tee lasground_output_22n.out
wine /opt/LAStools/bin/lasground.exe -cores 12 -i tilesn/26*n.laz -by_flightline -wilderness -extra_fine -offset 0.25 -stddev 20 -spike 0.5 -bulge 0.5 -olaz -odir ground_overlap -odix g 2>&1 | tee lasground_output_22n.out

#instead of processing chunks of tiles, one could also use the -lof - list of files options.
```

For this example, we only process a subset of the data from the Pozo catchment. We clip the Pozo catchment with a shapefile `SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp` and generate an output LAZ file `SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.laz`.

```bash
cd /raid-everest/lidar_research/lidar_data/usgs_channel_islands/
cd processed/SANTA_CRUZ/cl2_july2018/
ls -1 ground_overlap/*ng.laz > SCI_ground_overlap_filelist.lst
wine /opt/LAStools/bin/lasclip.exe -lof SCI_ground_overlap_filelist.lst -olaz -drop_withheld -o SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.laz -keep_class 2 -merged -poly SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
```

## Export to ASCII
```bash
conda activate PC_py3
```

Convert ground-classified LAS/LAZ to ASCII for GMT processing and compress with `bzip2`, but using [parallel bzip2 (pbzip2)](https://linuxconfig.org/how-to-perform-a-faster-data-compression-with-pbzip2):

```bash
wine /opt/LAStools/bin/las2las.exe -i SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.laz -o SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz -oparse xyz
#head -100 SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz >SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_100rows.xyz
pbzip2 -7 SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz
```

## Prepare DEM
In order to provide best results and produce overlapping grids, you would want to clip the DEM with a shapefile - this way you ensure that all grids will have the same dimensions. You can clip every output grid with the same shapefile stored in CLIP_SHAPEFILE.

We extract the subset from the interpolated DTM using [blast2dem](https://rapidlasso.com/blast/blast2dem/).
```bash
gdalwarp /raid-everest/lidar_research/lidar_data/usgs_channel_islands/processed/SANTA_CRUZ/cl2_july2018/dtm_interp/SCI_USGS_UTM11_NAD83_g_1m.tif dtm_interp/Pozo_USGS_UTM11_NAD83_g_1m.tif -cutline SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
```


Set ```$DATA_BASEDIR``` variable:
```bash
export DATA_BASEDIR=/home/bodo/Dropbox/California/SCI/Pozo/pc_interpolation
```

If the DEM exists already, you can clip it with the shapefile to generate a clipped version that is aligned to integer UTM coordinates (`-tap`):
```bash
DEM_GRID_IN=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1m.tif
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
export CLIP_SHAPEFILE=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $DEM_GRID_IN $DEM_GRID -co COMPRESS=DEFLATE -co ZLEVEL=7
```

A map of Pozo and the zoom-in area can be generated with GMT5. See the script [SCI_Pozo_interpolation_GMT5_plot_DEM_overview_zoom.sh](SCI_Pozo_interpolation_GMT5_plot_DEM_overview_zoom.sh) that can be run with 

`. gmt5_map_scripts/SCI_Pozo_interpolation_GMT5_plot_DEM_overview_zoom.sh`.

The output figures are stored in the subfolder `figures` and is shown in Figure \ref{DEM:overview}.

![Map view of the Pozo catchment and the zoom-in area in the central part of the catchment.\label{DEM:overview}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_topo_overview_zoom_map.png)

# Interpolation of grids with [GMT](http://gmt.soest.hawaii.edu/) and [gdal_grid](https://www.gdal.org/gdal_grid.html)

## Interpolate with GMT 6
[GMT6](http://gmt.soest.hawaii.edu/doc/latest/GMT_Docs.html) has useful interpolation routines with additional output options as compared to GMT5. In addition, you could call these routines directly from Python (not shown in this manual).

GMT6 either has to be compiled from source or installed via anaconda/miniconda. Here, we use [miniconda](https://docs.conda.io/en/latest/miniconda.html):
```bash
conda config --prepend channels conda-forge/label/dev
conda create -y -c conda-forge/label/cf201901 -n gmt6 gmt=6* python=3* scipy pandas numpy matplotlib scikit-image gdal spyder
```

And start the environment:
```bash
source activate gmt6
```

To keep command lines short, we set the ```$DATA_BASEDIR``` variable:
```bash
export DATA_BASEDIR=/home/bodo/Dropbox/California/SCI/Pozo/pc_interpolation
```

Make sure, the DEM exist as NetCDF file:
```bash
gmt grdconvert $DEM_GRID=gd/1/0/-9999 $DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.nc
```

### GMT blockmean
See [http://gmt.soest.hawaii.edu/doc/5.3.2/blockmean.html](http://gmt.soest.hawaii.edu/doc/5.3.2/blockmean.html)

```bash
mkdir $DATA_BASEDIR/blockmean
```

```bash
BLOCKMEAN_GRID=$DATA_BASEDIR/blockmean/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1m
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt blockmean -R$DEM_GRID -C -G${BLOCKMEAN_GRID}%s.nc -Az,s
```

Convert the NetCDF files to a compress geotiff:
```bash
cd $DATA_BASEDIR/blockmean
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1mz.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1mz.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1ms.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1ms.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
cd ..
```

A map of the `gmt blockmean` data is generated with [gmt5](http://gmt.soest.hawaii.edu/). See the script in the section GMT5 as an example with an output shown in Figures \ref{gmt:blockmean} and combined with blockmedian in Figure \ref{gmt:blockmean_blockmedian}.

![Map view of the LAStools-triangulated minus gmt:blockmean interpolation of the zoomed-in part of the Pozo catchment\label{gmt:blockmean}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_blockmean.png)


### GMT blockmedian
[http://gmt.soest.hawaii.edu/doc/5.3.2/blockmedian.html](http://gmt.soest.hawaii.edu/doc/5.3.2/blockmedian.html)

```bash
cd $DATA_BASEDIR/
mkdir $DATA_BASEDIR/blockmedian
```

```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
BLOCKMEDIAN_GRID=$DATA_BASEDIR/blockmedian/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmedian_1m
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt blockmedian -R$DEM_GRID -C -G${BLOCKMEDIAN_GRID}%s.nc -Az,s
```

Convert the NetCDF files to a compress geotiff:
```bash
cd $DATA_BASEDIR/blockmedian
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmedian_1mz.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmedian_1mz.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmedian_1ms.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmedian_1ms.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
cd ..
```

![Map view of the LAStools-triangulated minus gmt:blockmedian interpolation of the zoomed-in part of the Pozo catchment.\label{gmt:blockmedian}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_blockmedian.png)

The gmt:blockmean and gmt:blockmedian interpolated map (see Figure \ref{gmt:blockmean_blockmedian}).

![Combined map views of the LAStools-triangulated minus gmt:blockmean and minus gmt:blockmedian interpolation of the zoomed-in part of the Pozo catchment.\label{gmt:blockmean_blockmedian}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_blockmean_blockmedian.png)


### GMT Green spline
**Not working yet, takes a long time for large points**

Greenspline uses the Green’s function G(x; x’) for the chosen spline and geometry to interpolate data at regular [or arbitrary] output locations.
See [http://gmt.soest.hawaii.edu/doc/latest/greenspline.html](http://gmt.soest.hawaii.edu/doc/latest/greenspline.html) for more information.
Here, we use a minimum curvature spline (`-Sc`) and continuos curvature spline (`-St0.3`) and we only retain the largest eigenvalue when solving the linear system for the spline coefficients by SVD (`-Cn`).

```bash
cd $DATA_BASEDIR/
mkdir $DATA_BASEDIR/greenspline
```

```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
GREENSPLINE_GRID=$DATA_BASEDIR/greenspline/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_greenspline_mincurv_1m.tif
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt greenspline -R$DEM_GRID -C50+feigenvalue.txt -D1 -Sc -G${GREENSPLINE_GRID}%s.nc

GREENSPLINE_GRID=$DATA_BASEDIR/greenspline/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_greenspline_curvsplinetension_1m.nc
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt greenspline -R$DEM_GRID -Cn -D1 -St0.3 -G${GREENSPLINE_GRID}%s.nc
```

### GMT Triangulate
Uses Delauny Triangulation Delaunay, i.e., the algorithm finds how the points should be connected to give the most equilateral triangulation possible. For more information see [http://gmt.soest.hawaii.edu/doc/latest/triangulate.html](http://gmt.soest.hawaii.edu/doc/latest/triangulate.html). This is very similar to the interpolation performed by [blast2dem](https://rapidlasso.com/blast/blast2dem/).  The actual algorithm used in the triangulations is that of Watson [1982].


```bash
cd $DATA_BASEDIR/
mkdir $DATA_BASEDIR/triangulation
```

```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
TRIANGULATION_GRID=$DATA_BASEDIR/triangulation/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_triangulation_1m.nc
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt triangulate -R$DEM_GRID -G${TRIANGULATION_GRID}
```

Convert the NetCDF files to a compressed geotiff:
```bash
cd $DATA_BASEDIR/triangulation
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_triangulation_1m.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_triangulation_1m.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
cd ..
```

![Map view of the LAStools-triangulated minus gmt:blockmedian interpolation of the zoomed-in part of the Pozo catchment.\label{gmt:triangulation}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_triangulation.png)

The DEM difference gmt:triangulation interpolated map (see Figure \ref{gmt:triangulation}).


### GMT Surface
Gridding points using adjustable tension continuous curvature splines. Surface reads randomly-spaced (x,y,z) triples from standard input [or table] and produces a binary grid file of gridded values z(x,y) by solving: (1 - T) * L (L (z)) + T * L (z) = 0, where T is a tension factor between 0 and 1, and L indicates the Laplacian operator. For more information see [http://gmt.soest.hawaii.edu/doc/latest/surface.html](http://gmt.soest.hawaii.edu/doc/latest/surface.html). Here

```bash
cd $DATA_BASEDIR/
mkdir $DATA_BASEDIR/surface
```

```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
SURFACE_GRID=$DATA_BASEDIR/surface/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension025_c01_1m.nc
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt surface -R$DEM_GRID -G${SURFACE_GRID} -M1c -T0.25 -C0.1
```

Convert the NetCDF files to a compress geotiff:
```bash
cd $DATA_BASEDIR/surface
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension025_c01_1m.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension025_c01_1m.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
cd ..
```

Using Tension=0.35:
```bash
cd $DATA_BASEDIR
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
SURFACE_GRID=$DATA_BASEDIR/surface/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension035_c01_1m.nc
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt surface -R$DEM_GRID -G${SURFACE_GRID} -M0c -T0.35 -C0.1
```

Convert the NetCDF files to a compress geotiff:
```bash
cd $DATA_BASEDIR/surface
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension035_c01_1m.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension035_c01_1m.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
cd ..
```

![Map view of the LAStools-triangulated minus gmt:surface tension interpolation (t=0.25 and t=0.35) for the Pozo zoom-in area.\label{gmt:surfacetensions}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_surfacet035c01_surfacet025c01.png)

The DEM difference of surface tension of the Pozo catchment and the area of interest is shown in Figure \ref{gmt:surfacetensions}.


### GMT NearestNeighbor interpolation
**This is currently not working**

[http://gmt.soest.hawaii.edu/doc/latest/nearneighbor.html](http://gmt.soest.hawaii.edu/doc/latest/nearneighbor.html)

The average value is computed as a weighted mean of the nearest point from each sector inside the search radius. The weighting function used is w(r) = 1 / (1 + d ^ 2), where d = 3 * r / search_radius and r is distance from the node. Distances (-S) are grid-cell size * sqrt(2) / 2 (`-S0.707e`):

```bash
export DATA_BASEDIR=/home/bodo/Dropbox/California/SCI/Pozo/pc_interpolation
cd $DATA_BASEDIR/
mkdir $DATA_BASEDIR/nearneighbor
```

```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
NEARNEIGHBOR_GRID=$DATA_BASEDIR/nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gmtnearneighbor_1m.nc
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt nearneighbor -R$DEM_GRID -G${NEARNEIGHBOR_GRID} -S0.707e -nn -N2+m2
```

Convert the NetCDF files to a compress geotiff:
```bash
cd $DATA_BASEDIR/nearneighbor
gdal_translate -of GTIFF SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gmtnearneighbor_1m.nc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gmtnearneighbor_1m.tif -a_srs epsg:26911 -co COMPRESS=DEFLATE -co ZLEVEL=7
cd ..
```


## Interpolate with [gdal_grid](https://www.gdal.org/gdal_grid.html)
### NearestNeighbor interpolation using [gdal_grid](https://www.gdal.org/gdal_grid.html)
The above described approach with gmt does not appear to work well. Better to use a [gdal_grid](https://www.gdal.org/gdal_grid.html) with `gdal_grid nearest` approach:

First, you have to set the variables for import/export from gdal:
```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
# get x,y bounds
export minx=`gmt grdinfo -C $DEM_GRID |cut -f 2`
export maxx=`gmt grdinfo -C $DEM_GRID |cut -f 3`
export nx=`gmt grdinfo -C $DEM_GRID |cut -f 10`
export boundsx="$minx $maxx"
export miny=`gmt grdinfo -C $DEM_GRID |cut -f 4`
export maxy=`gmt grdinfo -C $DEM_GRID |cut -f 5`
export ny=`gmt grdinfo -C $DEM_GRID |cut -f 11`
export boundsy="$miny $maxy"
export boundsyr="$maxy $miny"
```
Next, prepare the file to be read by gdal_grid:

First, add column header with x, y, z to column file containing data:
```bash
cp -rv SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.csv
pbzip2 -7 SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz
sed -i '1s/^/x y z\n/' SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.csv
```

Next, Generate a VRT file `SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.vrt` that contains information about the file to be read:
```bash
<OGRVRTDataSource>
    <OGRVRTLayer name="SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2">
        <SrcDataSource>CSV:SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.csv</SrcDataSource>
        <SrcLayer>SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2</SrcLayer>
        <LayerSRS>EPSG:26911</LayerSRS>
        <GeometryType>wkbPoint</GeometryType>
        <GeometryField encoding="PointFromColumns" x="x" y="y" z="z"/>
    </OGRVRTLayer>
</OGRVRTDataSource>
```

Next, perform the actual interpolation and clip output with `gdalwarp`:
```bash
PC_IN=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2
NEARNEIGHBOR_GRID=$DATA_BASEDIR/nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gdalnearneighbor_1m.tif
#We follow the definition of points2grid and assume a radius of spatial resolution * sqrt(2) / 2
R_M=0.707
export CLIP_SHAPEFILE=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a nearest:radius1=$R_M:radius2=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${NEARNEIGHBOR_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000

gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $NEARNEIGHBOR_GRID ${NEARNEIGHBOR_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
```

If needed, one can convert to NetCDF GMT grid:

```bash
gmt grdconvert ${NEARNEIGHBOR_GRID::-4}_c.tif=gd/1/0/-9999 ${NEARNEIGHBOR_GRID}.nc
```

![Map view of the LAStools-triangulated minus gdal_grid:nearneighbor interpolation for the Pozo zoom-in area.\label{gmt:gdalnearneighbor}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_gdalnearneighbor.png)

The DEM difference of gdal_grid:nearneighbor of the Pozo catchment and the area of interest is shown in Figure \ref{gmt:gdalnearneighbor}.


You may want to consider using a larger radius (R=1.414) to avoid nodata areas:
```bash
PC_IN=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2
NEARNEIGHBOR_GRID=$DATA_BASEDIR/nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gdalnearneighbor_R1.414_1m.tif
#We follow the definition of points2grid and assume a radius of spatial resolution * sqrt(2) / 2
R_M=1.414
export CLIP_SHAPEFILE=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a nearest:radius1=$R_M:radius2=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${NEARNEIGHBOR_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000

gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $NEARNEIGHBOR_GRID ${NEARNEIGHBOR_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
```

If needed, one can convert to NetCDF GMT grid:

```bash
gmt grdconvert ${NEARNEIGHBOR_GRID::-4}_c.tif=gd/1/0/-9999 ${NEARNEIGHBOR_GRID}.nc
```

### Interpolate IDW using [gdal_grid](https://www.gdal.org/gdal_grid.html)
Interpolate using [gdal_grid](https://www.gdal.org/gdal_grid.html) with `gdal_grid invdistnn`. For details see section "NearestNeighbor interpolation using gdal_grid".

Here, we assume there exists already a CSV and VRT file:

```bash
export DATA_BASEDIR=/home/bodo/Dropbox/California/SCI/Pozo/pc_interpolation
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
# get x,y bounds
export minx=`gmt grdinfo -C $DEM_GRID |cut -f 2`
export maxx=`gmt grdinfo -C $DEM_GRID |cut -f 3`
export nx=`gmt grdinfo -C $DEM_GRID |cut -f 10`
export boundsx="$minx $maxx"
export miny=`gmt grdinfo -C $DEM_GRID |cut -f 4`
export maxy=`gmt grdinfo -C $DEM_GRID |cut -f 5`
export ny=`gmt grdinfo -C $DEM_GRID |cut -f 11`
export boundsy="$miny $maxy"
export boundsyr="$maxy $miny"

PC_IN=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdist_1m.tif
#We follow the definition of points2grid and assume a radius of spatial resolution * sqrt(2) / 2
R_M=0.707
```

**NOTE that the next command is the standard way to run IDW, but not the most efficient way. Do not use this, unless you have too much time at hand. Please look at option #1 and #2 below to speed up processing for a large number of points**

```bash
gdal_grid -zfield "z" -a invdist:power=2.0:smoothin=0.0:radius1=$R_M:radius2=$R_M:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
```

Not necessary, but just in case:
```bash
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

Speeding up processing, option #1: Use a maximum point number 24 (adjust this for larger radii):
```bash
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdist_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -clipsrc $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -zfield "z" -a invdist:power=2.0:smoothin=0.0:radius1=$R_M:radius2=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
```

Not necessary, but just in case:
```bash
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

Speeding up processing, option #2: Use a maximum point number and the `invdistnn` algorithm and power=1, 2, 3. By defining a higher power value, more emphasis will be put on the nearest points (i.e., their weights are higher). Thus, nearby data to the pixel center will have the most influence.

```bash
#Power = 1
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=1.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc

#Power = 2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=2.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc

#Power = 3
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=3.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

![Map view of the LAStools-triangulated minus gdal_grid:idw (power=1, 2 and 3 with radius = 0.707m) interpolation for the Pozo zoom-in area.\label{gmt:gdalidw}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWP2_IDWP3.png)

The DEM difference of gdal_grid:idw (power=1, 2, 3) of the Pozo catchment and the area of interest is shown in Figure \ref{gmt:gdalidw}.

#### IDW with larger radii (r=1.414m) to avoid nodata areas
Using the above described approach, we perform the same calculation, but with a larger radius (grid size times sqrt(2), R=1.414):

```bash
export DATA_BASEDIR=/home/bodo/Dropbox/California/SCI/Pozo/pc_interpolation
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
# get x,y bounds
export minx=`gmt grdinfo -C $DEM_GRID |cut -f 2`
export maxx=`gmt grdinfo -C $DEM_GRID |cut -f 3`
export nx=`gmt grdinfo -C $DEM_GRID |cut -f 10`
export boundsx="$minx $maxx"
export miny=`gmt grdinfo -C $DEM_GRID |cut -f 4`
export maxy=`gmt grdinfo -C $DEM_GRID |cut -f 5`
export ny=`gmt grdinfo -C $DEM_GRID |cut -f 11`
export boundsy="$miny $maxy"
export boundsyr="$maxy $miny"
PC_IN=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdist_1m.tif
R_M=1.414

#Power = 1
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1r1.414_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=1.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=48:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc

#Power = 2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2r1.414_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=2.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=48:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc

#Power = 3
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3r1.414_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=3.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=48:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

![Map view of the LAStools-triangulated minus gdal_grid:idw (power=1, 2, 3) with radius = 1.414m) interpolation for the Pozo zoom-in area.\label{gmt:gdalidw_p1s0123r1414}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWP1_to_P2_R141m.png)

#### IDW with larger radii (r=2.828m) to avoid nodata areas
Using the above described approach, we perform the same calculation, but with a larger radius (grid size times sqrt(2) * 2, R=2.828):

```bash
export DATA_BASEDIR=/home/bodo/Dropbox/California/SCI/Pozo/pc_interpolation
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
# get x,y bounds
export minx=`gmt grdinfo -C $DEM_GRID |cut -f 2`
export maxx=`gmt grdinfo -C $DEM_GRID |cut -f 3`
export nx=`gmt grdinfo -C $DEM_GRID |cut -f 10`
export boundsx="$minx $maxx"
export miny=`gmt grdinfo -C $DEM_GRID |cut -f 4`
export maxy=`gmt grdinfo -C $DEM_GRID |cut -f 5`
export ny=`gmt grdinfo -C $DEM_GRID |cut -f 11`
export boundsy="$miny $maxy"
export boundsyr="$maxy $miny"
PC_IN=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdist_1m.tif
R_M=2.828

#Power = 1
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1r2.828_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=1.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=96:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc

#Power = 2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2r2.828_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=2.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=96:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc

#Power = 3
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3r2.828_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=3.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=96:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

![Map view of the LAStools-triangulated minus gdal_grid:idw (power=1, 2, 3) with radius = 2.828m) interpolation for the Pozo zoom-in area.\label{gmt:gdalidw_p1s0123r2828}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWP1_to_P2_R2828m.png)

![Map view of the LAStools-triangulated minus gdal_grid:idw (power=1, with radii r=0.70m, r=1.41m, r=2.828m) interpolation for the Pozo zoom-in area.\label{gmt:gdalidw_p1s0123r070mr1414mr2828}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWP1_r070mr1414mr2828.png)

![Map view of gdal_grid:idw (power=1, with radius r=0.70m) minus gdal_grid:idw (power=1, with radius r=1.41m) interpolation for the Pozo zoom-in area.\label{gdalidw_p1s0123r070mr1414m}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWP1_minus_IDWP1_r070mr1414m.png)


#### IDW with power=1 and smoothing=1 and 2
In addition to the above example, we explore the smoothing parameter and its effect on the point-cloud data from Pozo. The previous examples rely on no smooth (smoothing=0).


```bash
#Power = 1 and Smoothing = 1
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s1_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=1.0:smoothin=1.0:radius=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc

#Power = 1 and Smoothing = 2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s2_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=1.0:smoothin=2.0:radius=$R_M:min_points=3:max_points=24:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

The comparison of smoothing is shown versus the main DEM (Figure \ref{gmt:gdalidw_p1s0123}) and versus each other (IDW with power=1, smoothing=0 minus IDW with power=1, smoothing=1 and smoothin=2) (Figure {gmt:gdalidw_p1s0_minus_s12}).

![Map view of the LAStools-triangulated minus gdal_grid:idw (power=1, smoothing=0, 1, 2)) interpolation for the Pozo zoom-in area.\label{gmt:gdalidw_p1s0123}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWP1S0_IDWP1S1_IDWP1S2.png)

![Map view of the DEM interpolated with gdal_grid:idw (power=1, smoothing=0) minus gdal_grid:idw (power=1, smoothing=1 and smoothing=2).\label{gmt:gdalidw_p1s0_minus_s12}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_idwP1S0_minus_idwP1S1_idwP1S2.png)

The generation of this maps is shown in GMT5 script [gmt5_map_scripts/SCI_Pozo_interpolation_GMT5_plot_DEM_diff_IDW.sh](gmt5_map_scripts/SCI_Pozo_interpolation_GMT5_plot_DEM_diff_IDW.sh).

### IDW Interpolation via [pdal](https://pdal.io/) with writers.gdal
This uses [writers.gdal](https://pdal.io/stages/writers.gdal.html) following the [Points2Grid](https://opentopography.org/otsoftware/points2grid) approach. We set the radius to resolution * sqrt(2) / 2 (0.707 m) to generate comparable results to the `gdal_grid` approach described above.

**Note that this implementation of points2grid uses a 3x3 moving window to fill in voids/NaNs and thus does not have NaN cells as the `gdal_grid` approach described above.**

**The advantage of the points2grid implementation is that it can read and pipe a large number of points.**

Generate a pipeline along these lines:
```bash
mkdir $DATA_BASEDIR/idw
```

File `SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_pipeline.json`:
```bash
{
  "pipeline":[
    "SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.laz",
    {
      "resolution": 1,
      "radius": 0.707
      "gdaldriver": "GTiff",
      "gdalopts": "COMPRESS=DEFLATE, ZLEVEL=7, GDAL_NUM_THREADS=ALL CPUS",
      "data_type": "float",
      "output_type": "mean, idw, count, stdev",
      "filename":"idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m.tif"
    }
  ]
}
```

Run with:
```bash
pdal pipeline SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_pipeline.json
```

You will need to clip the file to have the same size as the input file:
```bash
CLIP_SHAPEFILE=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
# get x,y bounds
export minx=`gmt grdinfo -C $DEM_GRID |cut -f 2`
export maxx=`gmt grdinfo -C $DEM_GRID |cut -f 3`
export nx=`gmt grdinfo -C $DEM_GRID |cut -f 10`
export miny=`gmt grdinfo -C $DEM_GRID |cut -f 4`
export maxy=`gmt grdinfo -C $DEM_GRID |cut -f 5`
export ny=`gmt grdinfo -C $DEM_GRID |cut -f 11`
export boundste="$minx $miny $maxx $maxy"

#-cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline
gdalwarp -multi -te $boundste -ts $nx $ny -t_srs epsg:26911 idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m.tif idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7

gdal_translate -b 2 idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_c.tif idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_c2.tif
```

![Map view of the LAStools-triangulated minus pdal:Points2Grid interpolation for the Pozo zoom-in area.\label{gmt:pdalidw}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_idwpoint2grid.png)

![Map view of the LAStools-triangulated minus pdal:Points2Grid and gdal_grid (power=1, smoothing=0) interpolation for the Pozo zoom-in area.\label{pdalidw_idwp1s0}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWpoints2grid_IDWP1S0.png)


The DEM difference of pdal:Points2Grid of the Pozo catchment and the area of interest is shown in Figure \ref{gmt:pdalidw} and \ref{pdalidw_idwp1s0}. The comparison between gdal_grid:idwP1S0 and pdalidw is shown in Figure \ref{gmt:idwP1S0_minus_pdalidw}.

![Map view of the gdal_grid:IDW (power=1, smoothing=0) minus pdal:Points2Grid interpolation for the Pozo zoom-in area.\label{gmt:idwP1S0_minus_pdalidw}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_idwP1S0_minus_idwpoint2grid.png)

# Plot with GMT5
Below, we provide a simple [GMT](http://gmt.soest.hawaii.edu/) Version 5 (GMT5) shell script to plot the DEM difference data. There are several GMT5 scripts for different purposes.

|GMT5 Script and Link | Purpose | Output Map |
|:--- | --- | --- |
[SCI_Pozo_interpolation_GMT5_plot_DEM_overview_zoom.sh](gmt5_map_scripts/SCI_Pozo_interpolation_GMT5_plot_DEM_overview_zoom.sh) | Plot Pozo overview DEM and zoom-in area | Figure \ref{DEM:} |
[SCI_Pozo_interpolation_GMT5_plot_DEM_diff_blockmean_blockmedian.sh](gmt5_map_scripts/) | | Figure \ref{DEM:} |
[SCI_Pozo_interpolation_GMT5_plot_DEM_diff_surfacetension.sh](gmt5_map_scripts/) | | Figure \ref{DEM:} |
[SCI_Pozo_interpolation_GMT5_plot_DEM_diff_IDW.sh](gmt5_map_scripts/) | | Figure \ref{DEM:} |
[SCI_Pozo_interpolation_GMT5_plot_DEM_diff_nearneighbor.sh](gmt5_map_scripts/) | | Figure \ref{DEM:} |
[SCI_Pozo_interpolation_GMT5_plot_DEM_diff_triangulation.sh](gmt5_map_scripts/) | | Figure \ref{DEM:} |

The GMT5 script for plotting the DEM and overview is shown here:
```{.bash include=gmt5_map_scripts/SCI_Pozo_interpolation_GMT5_plot_DEM_overview_zoom.sh}
```
