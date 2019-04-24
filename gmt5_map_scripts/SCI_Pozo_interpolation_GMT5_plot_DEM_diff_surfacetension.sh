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

OVERVIEW_WIDTH=10
OVERVIEW_SCALE=1:4500
OVERVIEW_REGION=236000/237000/3764000/3764500
OVERVIEW_XSTEPS=0.04
OVERVIEW_YSTEPS=0.04
CPT="seis_zoom.cpt"
gmt makecpt -D -D -Cseis -T-1/1/0.25 > $CPT

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
convert -quality 100 -density 300 figures/Pozo_catchment_zoom_D_blockmean_blockmedian.png figures/Pozo_catchment_zoom_D_surfacet035c01_surfacet025c01.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_blockmean_blockmedian_surfacet035c01_surfacet025c01.png
