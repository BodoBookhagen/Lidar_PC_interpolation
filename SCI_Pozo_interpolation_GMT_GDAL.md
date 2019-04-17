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


#MEDIUM classification with high offset, medium standard dev, and medium spike: CHANNELS do not come out good, but little vegetation
###LIKELY BEST CANDIDATE For channel extraction. There is some vegetation, but channels are clear
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
cd /raid-everest/lidar_research/lidar_data/usgs_channel_islands/processed/SANTA_CRUZ/cl2_july2018/
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

![Map view of the Pozo catchment and the zoom-in area.\label{DEM:overview}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_topo_overview_zoom_map.png)

The DEM of the Pozo catchment and the area of interest is shown in Figure \ref{DEM:overview}.

# Interpolation of grids with GMT and GDAL

## Interpolate with GMT 6
```bash
conda config --prepend channels conda-forge/label/dev
conda create -y -c conda-forge/label/cf201901 -n gmt6 gmt=6* python=3* scipy pandas numpy matplotlib scikit-image gdal spyder
```

And start the environment:
```bash
source activate gmt6
```

Set ```$DATA_BASEDIR``` variable:
```bash
export DATA_BASEDIR=/home/bodo/Dropbox/California/SCI/Pozo/pc_interpolation
```

Make sure, the DEM exist as NetCDF file:
```bash
gmt grdconvert $DEM_GRID=gd/1/0/-9999 $DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.nc
```

### blockmean
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

A map of the blockmean data is generated with [gmt](http://gmt.soest.hawaii.edu/):
```bash
### GMT V 5 file!
gmt gmtset MAP_FRAME_PEN    1
gmt gmtset MAP_FRAME_WIDTH    0.1
gmt gmtset MAP_FRAME_TYPE     plain
gmt gmtset FONT_TITLE    Helvetica-Bold
gmt gmtset FONT_LABEL    Helvetica-Bold 14p
gmt gmtset PS_PAGE_ORIENTATION    landscape
gmt gmtset PS_MEDIA    A4
gmt gmtset FORMAT_GEO_MAP    D
gmt gmtset MAP_DEGREE_SYMBOL degree
gmt gmtset PROJ_LENGTH_UNIT cm
gmt gmtset MAP_FRAME_AXES WESNZ

POZO_DEM=dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.nc
POZO_DEM_HS=${POZO_DEM::-3}_HS.nc
gmt grd2cpt $POZO_DEM -E25 -Cdem2 > dem2_color.cpt
#additional color tables are: -Cdem1, -Cdem3, -Cdem4
if [ ! -e $POZO_DEM_HS ]
then
    echo "generate hillshade $DEM_GRID_HS"
    #more fancy hillshading:
    gmt grdgradient $POZO_DEM -Em315/45+a -Ne0.8 -G$POZO_DEM_HS
fi

POZO_BOUNDARY=/raid2/bodo/Dropbox/California/SCI/SCI_Pozo_catchment_UTM11N_NAD83.gmt

### Plotting DEM differences
OVERVIEW_SCALE=1:4500
OVERVIEW_REGION=236000/237000/3764000/3764500
OVERVIEW_XSTEPS=0.04
OVERVIEW_YSTEPS=0.04
CPT="seis_zoom.cpt"
gmt makecpt -D -D -Cseis -T-1/1/0.1 > $CPT
#gmt makecpt -Q -D -Cseis -T-1/1/0.1 > $CPT


POSTSCRIPT3=figures/Pozo_catchment_zoom_D_blockmean.ps
TITLE="1m: dtm_interp minus blockmean"
DEM_POZO_DIFF_BLOCKMEAN=blockmean/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1mz_diff.nc
gmt grdmath $POZO_DEM blockmean/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1mz.tif SUB = $DEM_POZO_DIFF_BLOCKMEAN
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_BLOCKMEAN -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT3 
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT3
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT3
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT3
gmt psbasemap -R -J -O -K -B+t"$TITLE"  --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT3
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT3
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim  $POSTSCRIPT3 ${POSTSCRIPT3::-3}.png 
```

![Map view of the LAStools-triangulated minus gmt:blockmean interpolation of the zoomed-in part of the Pozo catchment\label{gmt:blockmean}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_blockmean.png)

The gmt:blockmean interpolated map (see Figure \ref{gmt:blockmean})

### blockmedian
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


![Map view of the LAStools-triangulated minus gmt:blockmedian interpolation of the zoomed-in part of the Pozo catchment\label{gmt:blockmedian}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_blockmedian.png)

The gmt:blockmedian interpolated map (see Figure \ref{gmt:blockmedian}).

### Green's function
**Not working yet, takes a long time for large points**

[http://gmt.soest.hawaii.edu/doc/latest/greenspline.html](http://gmt.soest.hawaii.edu/doc/latest/greenspline.html)
```bash
cd $DATA_BASEDIR/
mkdir $DATA_BASEDIR/greenspline
```

```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
GREENSPLINE_GRID=$DATA_BASEDIR/greenspline/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_greenspline_mincurv_1m.tif
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt greenspline -R$DEM_GRID -C -D1 -Sc -G${GREENSPLINE_GRID}%s.nc
GREENSPLINE_GRID=$DATA_BASEDIR/greenspline/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_greenspline_curvsplinetension_1m.nc
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt greenspline -R$DEM_GRID -C -D1 -St0.3 -G${GREENSPLINE_GRID}%s.nc
```

### Triangulation
Delauny Triangulation

[http://gmt.soest.hawaii.edu/doc/latest/triangulate.html](http://gmt.soest.hawaii.edu/doc/latest/triangulate.html)


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

![Map view of the LAStools-triangulated minus gmt:blockmedian interpolation of the zoomed-in part of the Pozo catchment\label{gmt:blockmedian}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_triangulation.png)

The DEM difference gmt:triangulation interpolated map (see Figure \ref{gmt:blockmedian}).



### Surface
[http://gmt.soest.hawaii.edu/doc/latest/surface.html](http://gmt.soest.hawaii.edu/doc/latest/surface.html)

```bash
cd $DATA_BASEDIR/
mkdir $DATA_BASEDIR/surface
```

```bash
DEM_GRID=$DATA_BASEDIR/dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.tif
SURFACE_GRID=$DATA_BASEDIR/surface/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension025_c01_1m.nc
pbzip2 -dc SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz.bz2 | gmt surface -R$DEM_GRID -G${SURFACE_GRID} -M0c -T0.25 -C0.1
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


### NearestNeighbor interpolation with GMT using ```gmt nearneighbor```
**This is currently not working**
[http://gmt.soest.hawaii.edu/doc/latest/nearneighbor.html](http://gmt.soest.hawaii.edu/doc/latest/nearneighbor.html)
The average value is computed as a weighted mean of the nearest point from each sector inside the search radius. The weighting function used is w(r) = 1 / (1 + d ^ 2), where d = 3 * r / search_radius and r is distance from the node. Distances (-S) are grid-cell size * sqrt(2)

For a grid-cell size of 1m, the radius is 0.5, so `-S0.707e`:

```bash
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
The above described approach with gmt does not appear to work well. Better to use a [gdal_grid](https://www.gdal.org/gdal_grid.html) approach:

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

Next, perform the actual interpolation and clip output with ```gdalwarp```:
```bash
PC_IN=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2
NEARNEIGHBOR_GRID=$DATA_BASEDIR/nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gdalnearneighbor_1m.tif
R_M=0.707
export CLIP_SHAPEFILE=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a nearest:radius1=$R_M:radius2=$R_M:min_points=3:max_points=1000:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${NEARNEIGHBOR_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000

gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $NEARNEIGHBOR_GRID ${NEARNEIGHBOR_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
```

If needed, one can convert to NetCDF GMT grid:

```bash
gmt grdconvert ${NEARNEIGHBOR_GRID::-4}_c.tif=gd/1/0/-9999 ${NEARNEIGHBOR_GRID}.nc
```

![Map view of the LAStools-triangulated minus gdal_grid:nearneighbor interpolation for the Pozo zoom-in area.\label{gmt:gdalnearneighbor}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_gdalnearneighbor.png)

The DEM difference of gdal_grid:nearneighbor of the Pozo catchment and the area of interest is shown in Figure \ref{gmt:gdalnearneighbor}.


### Interpolate IDW using [gdal_grid](https://www.gdal.org/gdal_grid.html)
Interpolate using [gdal_grid](https://www.gdal.org/gdal_grid.html). For details see section "NearestNeighbor interpolation using gdal_grid".
Here, we assume there exists already a CSV and VRT file:

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

PC_IN=SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_1m.tif
R_M=0.707
```

**NOTE that the next command is the standard way to run IDW, but not the most efficient way. Please look at option #1 and #2 below to speed up processing for a large number of points**

```bash
gdal_grid -zfield "z" -a invdist:power=2.0:smoothin=0.0:radius1=$R_M:radius2=$R_M:min_points=3:max_points=1000:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
```

Not necessary, but just in case:
```bash
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7 
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

Speeding up processing, option #1: Use a maximum point number:
```bash
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -clipsrc $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -zfield "z" -a invdist:power=2.0:smoothin=0.0:radius1=$R_M:radius2=$R_M:min_points=3:max_points=1000:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
```

Not necessary, but just in case:
```bash
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

Speeding up processing, option #2: Use a maximum point number and the `invdistnn` algorithm:
```bash
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=2.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=1000:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
```

Not necessary, but just in case:
```bash
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

Using algorithm `invdistnn` with power=3
```bash
IDW_GRID=$DATA_BASEDIR/idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3_invdistnn_1m.tif
export CLIP_SHAPEFILE=/home/bodo//Dropbox/California/SCI/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83.shp
gdal_grid -zfield "z" -a invdistnn:power=3.0:smoothin=0.0:radius=$R_M:min_points=3:max_points=1000:nodata=-9999 -txe $boundsx -tye $boundsyr -outsize $nx $ny -of GTiff -ot Float32 -l ${PC_IN} ${PC_IN}.vrt ${IDW_GRID} -co COMPRESS=DEFLATE -co ZLEVEL=7 --config GDAL_NUM_THREADS ALL_CPUS --config GDAL_CACHEMAX 2000
```

Not necessary, but just in case:
```bash
gdalwarp -cutline $CLIP_SHAPEFILE -cl SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83 -crop_to_cutline -tap -multi -tr 1 1 -t_srs epsg:26911 $IDW_GRID ${IDW_GRID::-4}_c.tif -co COMPRESS=DEFLATE -co ZLEVEL=7
gmt grdconvert ${IDW_GRID::-4}_c.tif=gd/1/0/-9999 ${IDW_GRID::-4}_c.nc
```

![Map view of the LAStools-triangulated minus gdal_grid:idw (power=2 and 3) interpolation for the Pozo zoom-in area.\label{gmt:gdalidw}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_IDWP2_IDWP3.png)

The DEM difference of gdal_grid:idw (power=2 and 3) of the Pozo catchment and the area of interest is shown in Figure \ref{gmt:gdalidw}.

### IDW Interpolation via [pdal](https://pdal.io/) with writers.gdal
This uses [writers.gdal](https://pdal.io/stages/writers.gdal.html) following the [Points2Grid](https://opentopography.org/otsoftware/points2grid) approach.

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

The DEM difference of pdal:Points2Grid of the Pozo catchment and the area of interest is shown in Figure \ref{gmt:gdalidw}.


# Plot with GMT 5
Below, we provide a simple [GMT](http://gmt.soest.hawaii.edu/) Version 5 (GMT5) shell script to plot the DEM difference data. We zoom in to a smaller area to provide a better view of the changes of the DEMs

This script will generate the above shown maps, but also many more. 

![Map view of the LAStools-triangulated minus various interpolated DEMs for the Pozo zoom-in area.\label{DEM_interp1}](/raid-cachi/bodo/Dropbox/California/SCI/Pozo/pc_interpolation/figures/Pozo_catchment_zoom_D_triangulation_triangulation_IDW_IDWP2_IDWP3.png)

The DEM differences of various interpolated DEMs of the Pozo catchment and the area of interest is shown in Figure \ref{DEM_interp1}.


Command file to plot all DEM differences for a small area of Pozo catchment. The GMT shell file can be downloaded from: []().

```bash
#!/bin/bash
### GMT V 5 file!
gmt gmtset MAP_FRAME_PEN    1
gmt gmtset MAP_FRAME_WIDTH    0.1
gmt gmtset MAP_FRAME_TYPE     plain
gmt gmtset FONT_TITLE    Helvetica-Bold
gmt gmtset FONT_LABEL    Helvetica-Bold 14p
gmt gmtset PS_PAGE_ORIENTATION    landscape
gmt gmtset PS_MEDIA    A4
gmt gmtset FORMAT_GEO_MAP    D
gmt gmtset MAP_DEGREE_SYMBOL degree
gmt gmtset PROJ_LENGTH_UNIT cm
gmt gmtset MAP_FRAME_AXES WESNZ

# MAP Parameters
#

#data are in /home/bodo/Dropbox/California/SCI/Pozo

#Pozo_USGS_UTM11_NAD83_g_05m.tif
#Pozo_USGS_UTM11_NAD83_g_5m.tif
#Pozo_USGS_UTM11_NAD83_g_10m.tif
#Pozo_USGS_UTM11_NAD83_g_30m.tif
#cd /home/bodo/Dropbox/California/SCI/Pozo/dtm_interp/
#convert to compressed NetCDF format (GMT)
#gdal_translate -co COMPRESS=DEFLATE -of NetCDF Pozo_USGS_UTM11_NAD83_g_05m.tif Pozo_USGS_UTM11_NAD83_g_05m.nc
#gdal_translate -co COMPRESS=DEFLATE -of NetCDF Pozo_USGS_UTM11_NAD83_g_1m.tif Pozo_USGS_UTM11_NAD83_g_1m.nc
#gdal_translate -co COMPRESS=DEFLATE -of NetCDF Pozo_USGS_UTM11_NAD83_g_5m.tif Pozo_USGS_UTM11_NAD83_g_5m.nc
#gdal_translate -co COMPRESS=DEFLATE -of NetCDF Pozo_USGS_UTM11_NAD83_g_10m.tif Pozo_USGS_UTM11_NAD83_g_10m.nc
#gdal_translate -co COMPRESS=DEFLATE -of NetCDF Pozo_USGS_UTM11_NAD83_g_30m.tif Pozo_USGS_UTM11_NAD83_g_30m.nc

POZO_DEM=dtm_interp/Pozo_USGS_UTM11_NAD83_g_1mc.nc
POZO_DEM_HS=${POZO_DEM::-3}_HS.nc
gmt grd2cpt $POZO_DEM -E25 -Cdem2 > dem2_color.cpt
#additional color tables are: -Cdem1, -Cdem3, -Cdem4
if [ ! -e $POZO_DEM_HS ]
then
    echo "generate hillshade $DEM_GRID_HS"
    #more fancy hillshading:
    gmt grdgradient $POZO_DEM -Em315/45+a -Ne0.8 -G$POZO_DEM_HS
fi


SCI_ORTHOIMAGE_R=/raid2/bodo/Dropbox/California/SCI/SCI_Pozo_orthophoto_1m_UTM11N_NAD83_R.nc
SCI_ORTHOIMAGE_R_HISTEQ=${SCI_ORTHOIMAGE_R::-3}_histeq.nc
if [ ! -e $SCI_ORTHOIMAGE_R_HISTEQ ]
then
    echo "calculate histogram equalization for $SCI_ORTHOIMAGE_R_HISTEQ (color coding )"
    gmt grdhisteq $SCI_ORTHOIMAGE_R -G$SCI_ORTHOIMAGE_R_HISTEQ -N
fi

SCI_ORTHOIMAGE_B=/raid2/bodo/Dropbox/California/SCI/SCI_Pozo_orthophoto_1m_UTM11N_NAD83_B.nc
SCI_ORTHOIMAGE_B_HISTEQ=${SCI_ORTHOIMAGE_B::-3}_histeq.nc
if [ ! -e $SCI_ORTHOIMAGE_B_HISTEQ ]
then
    echo "calculate histogram equalization for $SCI_ORTHOIMAGE_B_HISTEQ (color coding )"
    gmt grdhisteq $SCI_ORTHOIMAGE_B -G$SCI_ORTHOIMAGE_B_HISTEQ -N
fi

SCI_ORTHOIMAGE_G=/raid2/bodo/Dropbox/California/SCI/SCI_Pozo_orthophoto_1m_UTM11N_NAD83_G.nc
SCI_ORTHOIMAGE_G_HISTEQ=${SCI_ORTHOIMAGE_G::-3}_histeq.nc
if [ ! -e $SCI_ORTHOIMAGE_G_HISTEQ ]
then
    echo "calculate histogram equalization for $SCI_ORTHOIMAGE_G_HISTEQ (color coding )"
    gmt grdhisteq $SCI_ORTHOIMAGE_G -G$SCI_ORTHOIMAGE_G_HISTEQ -N
fi

#Boundary (polygon) of SCI: /home/bodo/Dropbox/California/SCI/SCI_boundary_clip_UTM11N_NAD83.shp
#convert to GMT format
#ogr2ogr -f GMT SCI_boundary_clip_UTM11N_NAD83.gmt /home/bodo/Dropbox/California/SCI/SCI_boundary_clip_UTM11N_NAD83.shp
SCI_BOUNDARY=/raid-cachi/bodo/Dropbox/California/SCI/SCI_boundary_clip_UTM11N_NAD83.gmt

#Pozo catchment
#ogr2ogr -f GMT SCI_Pozo_catchment_UTM11N_NAD83.gmt /home/bodo/Dropbox/California/SCI/SCI_Pozo_catchment_UTM11N_NAD83.shp
POZO_BOUNDARY=/raid2/bodo/Dropbox/California/SCI/SCI_Pozo_catchment_UTM11N_NAD83.gmt

#Preparing stream network:
#extracted stream from Matlab scripts (Neely et al., 2017) stored in SCI_1m_noveg_DTM_UTM11_NAD83_shapefiles.zip
#unzip  SCI_1m_noveg_DTM_UTM11_NAD83_shapefiles.zip
#SCI_FAC=shapefiles/SCI_1m_noveg_DTM_UTM11_NAD83_all_MS_proj.shp

### Image-specific definitions
#For an example see: http://gmt.soest.hawaii.edu/doc/5.4.2/gallery/ex28.html#example-28

#width of map in cm:
OVERVIEW_WIDTH=10
OVERVIEW_SCALE=1:22500
OVERVIEW_REGION=$POZO_DEM
#OVERVIEW_REGION=236652.03/237152.03/3764517.98/3765017.98
OVERVIEW_XSTEPS=0.04
OVERVIEW_YSTEPS=0.04
echo "Creating map for Pozo"
POSTSCRIPT1=figures/Pozo_catchment_topo_overview_map.ps
TITLE="Pozo catchment, Santa Cruz Island, California, 1-m Lidar DEM"
CPT="dem2_color.cpt"
gmt grdimage -Q -R$OVERVIEW_REGION $POZO_DEM -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT1 
# Overlay geographic data and coregister by using correct region and gmt projection with the same scale
#add shoreline from Lidar data
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT1
gmt psxy -Wthin,black -R$OVERVIEW_REGION -Jx$OVERVIEW_SCALE $SCI_BOUNDARY -O -K >> $POSTSCRIPT1
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT1
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx1m -By1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT1
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w1k+l1:22,500+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT1
gmt psscale -R -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx100 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O >> $POSTSCRIPT1
#convert to pdf and PNG
#convert -rotate 90 -quality 100 -density 300 $POSTSCRIPT1 ${POSTSCRIPT1::-3}.pdf 
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT1 ${POSTSCRIPT1::-3}.png 

### Creating second map showing focus area in Pozo
OVERVIEW_WIDTH=10
OVERVIEW_SCALE=1:4500
OVERVIEW_REGION=236000/237000/3764000/3764500
OVERVIEW_XSTEPS=0.04
OVERVIEW_YSTEPS=0.04
echo "Creating zoom-in map for Pozo"
POSTSCRIPT2=figures/Pozo_catchment_topo_zoom_map.ps
TITLE="Zoom in of Pozo, 1-m Lidar DEM"
CPT="dem2_color_zoom.cpt"
gmt grd2cpt $POZO_DEM -R$OVERVIEW_REGION -E25 -Cdem2 > $CPT
gmt grdimage -Q -R$OVERVIEW_REGION $POZO_DEM -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT2 
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT2
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT2
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT2
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,500+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT2
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx50 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT2
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT2 ${POSTSCRIPT2::-3}.png 

convert -quality 100 -density 300 ${POSTSCRIPT1::-3}.png ${POSTSCRIPT2::-3}.png -append figures/Pozo_catchment_topo_overview_zoom_map.png

### Plotting DEM differences
OVERVIEW_SCALE=1:4500
OVERVIEW_REGION=236000/237000/3764000/3764500
OVERVIEW_XSTEPS=0.04
OVERVIEW_YSTEPS=0.04
CPT="seis_zoom.cpt"
gmt makecpt -D -D -Cseis -T-1/1/0.25 > $CPT
#gmt makecpt -Q -D -Cseis -T-1/1/0.1 > $CPT


POSTSCRIPT3=figures/Pozo_catchment_zoom_D_blockmean.ps
TITLE="1m: dtm_interp minus blockmean"
DEM_POZO_DIFF_BLOCKMEAN=blockmean/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1mz_diff.nc
gmt grdmath $POZO_DEM blockmean/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmean_1mz.tif SUB = $DEM_POZO_DIFF_BLOCKMEAN
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_BLOCKMEAN -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT3 
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT3
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT3
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT3
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT3
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT3
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT3 ${POSTSCRIPT3::-3}.png 

POSTSCRIPT4=figures/Pozo_catchment_zoom_D_blockmedian.ps
TITLE="1m: dtm_interp minus blockmedian"
DEM_POZO_DIFF_BLOCKMEDIAN=blockmedian/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmedian_1mz_diff.nc
gmt grdmath $POZO_DEM blockmedian/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_blockmedian_1mz.tif SUB = $DEM_POZO_DIFF_BLOCKMEDIAN
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_BLOCKMEDIAN -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT4
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT4
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT4
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT4
gmt psbasemap -R -J -O -K -B+t"$TITLE"  --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT4
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT4
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT4 ${POSTSCRIPT4::-3}.png 

convert -quality 100 -density 300 ${POSTSCRIPT3::-3}.png ${POSTSCRIPT4::-3}.png +append figures/Pozo_catchment_zoom_D_blockmean_blockmedian.png

POSTSCRIPT5=figures/Pozo_catchment_zoom_D_surfacet035c01.ps
TITLE="1m: dtm_interp minus surface (T0.35, c0.1)"
DEM_POZO_DIFF_SURFACET035C01=surface/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension035_c01_1m_diff.nc
gmt grdmath $POZO_DEM surface/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension035_c01_1m.tif SUB = $DEM_POZO_DIFF_SURFACET035C01
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_SURFACET035C01 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT5
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT5
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT5
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT5
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT5
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT5
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT5 ${POSTSCRIPT5::-3}.png 

POSTSCRIPT6=figures/Pozo_catchment_zoom_D_surfacet025c01.ps
TITLE="1m: dtm_interp minus surface (T0.25, c0.1)"
DEM_POZO_DIFF_SURFACET025C01=surface/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension025_c01_1m_diff.nc
gmt grdmath $POZO_DEM surface/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_surface_tension025_c01_1m.tif SUB = $DEM_POZO_DIFF_SURFACET025C01
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_SURFACET025C01 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT6
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT6
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT6
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT6
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT6
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT6
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT6 ${POSTSCRIPT6::-3}.png 

convert -quality 100 -density 300 ${POSTSCRIPT5::-3}.png ${POSTSCRIPT6::-3}.png +append figures/Pozo_catchment_zoom_D_surfacet035c01_surfacet025c01.png
convert -quality 100 -density 300 figures/Pozo_catchment_zoom_D_blockmean_blockmedian.png figures/Pozo_catchment_zoom_D_surfacet035c01_surfacet025c01.png -append figures/Pozo_catchment_zoom_D_blockmean_blockmedian_surfacet035c01_surfacet025c01.png

POSTSCRIPT7=figures/Pozo_catchment_zoom_D_triangulation.ps
TITLE="1m: dtm_interp minus triangulation"
DEM_POZO_DIFF_TRIANGULATION=triangulation/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_triangulation_1m_diff.nc
gmt grdmath $POZO_DEM triangulation/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_triangulation_1m.tif SUB = $DEM_POZO_DIFF_TRIANGULATION
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_TRIANGULATION -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT7
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT7
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT7
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT7
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT7
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT7
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT7 ${POSTSCRIPT7::-3}.png 

POSTSCRIPT8=figures/Pozo_catchment_zoom_D_idwpoint2grid.ps
TITLE="1m: dtm_interp minus point2grid IDW"
DEM_POZO_DIFF_IDW=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_c2.tif SUB = $DEM_POZO_DIFF_IDW
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDW -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT8
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT8
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT8
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT8
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT8
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT8
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT8 ${POSTSCRIPT8::-3}.png 

convert -quality 100 -density 300 ${POSTSCRIPT7::-3}.png ${POSTSCRIPT8::-3}.png  +append figures/Pozo_catchment_zoom_D_triangulation_IDW.png

POSTSCRIPT9=figures/Pozo_catchment_zoom_D_idwP2.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=2"
DEM_POZO_DIFF_IDWP2=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP2
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP2 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT9
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT9
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT9
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT9
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT9
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT9
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT9 ${POSTSCRIPT9::-3}.png 

POSTSCRIPT10=figures/Pozo_catchment_zoom_D_idwP3.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=3"
DEM_POZO_DIFF_IDWP3=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP3
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP3 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT10
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT10
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT10
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT10
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT10
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT10
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT10 ${POSTSCRIPT10::-3}.png 

convert -quality 100 -density 300 ${POSTSCRIPT9::-3}.png ${POSTSCRIPT10::-3}.png +append figures/Pozo_catchment_zoom_D_IDWP2_IDWP3.png

convert -quality 100 -density 300 figures/Pozo_catchment_zoom_D_triangulation_IDW.png figures/Pozo_catchment_zoom_D_IDWP2_IDWP3.png -append figures/Pozo_catchment_zoom_D_triangulation_IDW_IDWP2_IDW_P3.png

POSTSCRIPT11=figures/Pozo_catchment_zoom_D_gmtnearneighbor.ps
TITLE="1m: dtm_interp minus gmt nearneighbor"
DEM_POZO_DIFF_GMTNEARNEIGHBOR=nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gmtnearneighbor_1m_diff.nc
gmt grdmath $POZO_DEM nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gmtnearneighbor_1m.tif SUB = $DEM_POZO_DIFF_GMTNEARNEIGHBOR
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_GMTNEARNEIGHBOR -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT11
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT11
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT11
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT11
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT11
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT11
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT11 ${POSTSCRIPT11::-3}.png 

POSTSCRIPT12=figures/Pozo_catchment_zoom_D_gdalnearneighbor.ps
TITLE="1m: dtm_interp minus gdal nearneighbor"
DEM_POZO_DIFF_GDALNEARNEIGHBOR=nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gdalnearneighbor_1m_diff.nc
gmt grdmath $POZO_DEM nearneighbor/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_gdalnearneighbor_1m_c.tif SUB = $DEM_POZO_DIFF_GDALNEARNEIGHBOR
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_GDALNEARNEIGHBOR -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT12
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT12
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT12
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT12
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT12
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT12
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT12 ${POSTSCRIPT12::-3}.png 
```
