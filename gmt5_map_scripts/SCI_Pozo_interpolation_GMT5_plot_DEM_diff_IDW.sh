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

POSTSCRIPT8=figures/Pozo_catchment_zoom_D_idwpoint2grid.ps
TITLE="1m: dtm_interp minus pdal:point2grid IDW"
DEM_POZO_DIFF_IDW=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_c2.tif SUB = $DEM_POZO_DIFF_IDW
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDW -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT8
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT8
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT8
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT8
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT8
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT8
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage  $POSTSCRIPT8 ${POSTSCRIPT8::-3}.png

POSTSCRIPT9a=figures/Pozo_catchment_zoom_D_idwP1S0.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=1, smoothing=0"
DEM_POZO_DIFF_IDWP1=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP1
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT9a
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT9a
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT9a
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT9a
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT9a
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT9a
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT9a ${POSTSCRIPT9a::-3}.png

convert -quality 100 -density 300 ${POSTSCRIPT8::-3}.png ${POSTSCRIPT9a::-3}.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_IDWpoints2grid_IDWP1S0.png

POSTSCRIPT9=figures/Pozo_catchment_zoom_D_idwP2.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=2, smoothing=0"
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
TITLE="1m: dtm_interp minus gdal_grid IDW, power=3, smoothing=0"
DEM_POZO_DIFF_IDWP3=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP3
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP3 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT10
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT10
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT10
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT10
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT10
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT10
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT10 ${POSTSCRIPT10::-3}.png

convert -quality 100 -density 300 ${POSTSCRIPT9a::-3}.png ${POSTSCRIPT9::-3}.png ${POSTSCRIPT10::-3}.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_IDWP1_IDWP2_IDWP3.png

#Next, plot with smoothing factor
POSTSCRIPT11=figures/Pozo_catchment_zoom_D_idwP1S1.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=1, smoothing=1"
DEM_POZO_DIFF_IDWP1S1=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s1_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s1_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP1S1
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S1 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT11
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT11
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT11
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT11
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT11
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT11
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT11 ${POSTSCRIPT11::-3}.png

POSTSCRIPT12=figures/Pozo_catchment_zoom_D_idwP1S2.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=1, smoothing=2"
DEM_POZO_DIFF_IDWP1S2=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s2_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s2_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP1S2
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S2 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT12
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT12
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT12
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT12
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT12
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT12
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT12 ${POSTSCRIPT12::-3}.png

convert -quality 100 -density 300 figures/Pozo_catchment_zoom_D_idwP1S0.png figures/Pozo_catchment_zoom_D_idwP1S1.png figures/Pozo_catchment_zoom_D_idwP1S2.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_IDWP1S0_IDWP1S1_IDWP1S2.png

#Next, plot difference between IDWP1S0 minus IDWP1S1 and IDWP1S2
POSTSCRIPT13=figures/Pozo_catchment_zoom_D_idwP1S0_minus_idwP1S1.ps
TITLE="1m: gdal_grid IDW-P1S0 minus gdal_grid IDW, power=1, smoothing=1"
DEM_POZO_DIFF_IDWP1S0_MINUS_IDWP1S1=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s0_minus_idwp1s1_invdistnn_1m_diff.nc
gmt grdmath idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m.tif idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s1_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP1S0_MINUS_IDWP1S1
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S0_MINUS_IDWP1S1 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT13
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT13
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT13
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT13
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT13
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT13
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT13 ${POSTSCRIPT13::-3}.png

POSTSCRIPT14=figures/Pozo_catchment_zoom_D_idwP1S0_minus_idwP1S2.ps
TITLE="1m: gdal_grid IDW-P1S0 minus gdal_grid IDW, power=1, smoothing=2"
DEM_POZO_DIFF_IDWP1S0_MINUS_IDWP1S2=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s0_minus_idwp1s2_invdistnn_1m_diff.nc
gmt grdmath idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m.tif idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s2_invdistnn_1m.tif SUB = $DEM_POZO_DIFF_IDWP1S0_MINUS_IDWP1S2
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S0_MINUS_IDWP1S1 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT14
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT14
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT14
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT14
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT14
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT14
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT14 ${POSTSCRIPT14::-3}.png

convert -quality 100 -density 300 ${POSTSCRIPT13::-3}.png ${POSTSCRIPT14::-3}.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_idwP1S0_minus_idwP1S1_idwP1S2.png

#Next, plot difference between IDWP1S0 minus pdal-point2grid
POSTSCRIPT15=figures/Pozo_catchment_zoom_D_idwP1S0_minus_idwpoint2grid.ps
TITLE="1m: gdal_grid IDW-P1S0 minus pdal:point2grid IDW"
DEM_POZO_DIFF_IDWP1S0_MINUS_IDWPOINTS2GRID=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s0_minus_idwp1s1_invdistnn_1m_diff.nc
gmt grdmath idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m.tif idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2_idw_1m_c2.tif SUB = $DEM_POZO_DIFF_IDWP1S0_MINUS_IDWPOINTS2GRID
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S0_MINUS_IDWP1S1 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT15
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT15
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT15
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT15
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT15
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT15
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT15 ${POSTSCRIPT15::-3}.png

#Plot IDW with radius = grid size x sqrt(2)
POSTSCRIPT16=figures/Pozo_catchment_zoom_D_idwP1S0r141.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=1, smoothing=0, r=1.414m"
DEM_POZO_DIFF_IDWP1S0R141=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s0r141_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1r1.414_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP1S0R141
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S0R141 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT16
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT16
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT16
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT16
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT16
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT16
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT16 ${POSTSCRIPT16::-3}.png

POSTSCRIPT17=figures/Pozo_catchment_zoom_D_idwP2S0r141.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=2, smoothing=0, r=1.414m"
DEM_POZO_DIFF_IDWP2S0R141=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2s0r141_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2r1.414_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP2S0R141
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP2S0R141 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT17
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT17
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT17
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT17
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT17
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT17
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT17 ${POSTSCRIPT17::-3}.png

POSTSCRIPT18=figures/Pozo_catchment_zoom_D_idwP3S0r141.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=3, smoothing=0, r=1.414m"
DEM_POZO_DIFF_IDWP3S0R141=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3s0r141_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3r1.414_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP3S0R141
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP3S0R141 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT18
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT18
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT18
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT18
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT18
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT18
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT18 ${POSTSCRIPT18::-3}.png

convert -quality 100 -density 300 ${POSTSCRIPT16::-3}.png ${POSTSCRIPT17::-3}.png ${POSTSCRIPT18::-3}.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_IDWP1_to_P2_R141m.png

#Plot IDW with radius = grid size x sqrt(2) x 2
POSTSCRIPT19=figures/Pozo_catchment_zoom_D_idwP1S0r2828.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=1, smoothing=0, r=2.828m"
DEM_POZO_DIFF_IDWP1S0R282=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s0r2828_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1r1.414_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP1S0R282
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S0R282 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT19
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT19
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT19
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT19
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT19
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT19
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT19 ${POSTSCRIPT19::-3}.png

POSTSCRIPT20=figures/Pozo_catchment_zoom_D_idwP2S0r2828.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=2, smoothing=0, r=2.828m"
DEM_POZO_DIFF_IDWP2S0R282=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2s0r2828_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp2r1.414_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP2S0R282
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP2S0R282 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT20
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT20
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT20
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT20
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT20
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT20
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT20 ${POSTSCRIPT20::-3}.png

POSTSCRIPT21=figures/Pozo_catchment_zoom_D_idwP3S0r2828.ps
TITLE="1m: dtm_interp minus gdal_grid IDW, power=3, smoothing=0, r=2.828m"
DEM_POZO_DIFF_IDWP3S0R282=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3s0r2828_invdistnn_1m_diff.nc
gmt grdmath $POZO_DEM idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp3r1.414_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP3S0R282
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP3S0R282 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT21
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT21
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT21
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT21
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT21
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT21
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT21 ${POSTSCRIPT21::-3}.png

convert -quality 100 -density 300 ${POSTSCRIPT19::-3}.png ${POSTSCRIPT20::-3}.png ${POSTSCRIPT21::-3}.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_IDWP1_to_P2_R2828m.png

convert -quality 100 -density 300 figures/Pozo_catchment_zoom_D_idwP1S0.png figures/Pozo_catchment_zoom_D_idwP1S0r141.png figures/Pozo_catchment_zoom_D_idwP1S0r2828.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_IDWP1_r070mr1414mr2828.png

#Compare different radii for the same power parameter.
POSTSCRIPT22=figures/Pozo_catchment_zoom_D_idwP1S0r070mr1414m.ps
TITLE="1m: IDW (P=1,S=0,r=0.707) minus IDW (P=1,S=0,r=1.414m)"
DEM_POZO_DIFF_IDWP1S0R070R1414=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s0r070mr1414m_invdistnn_1m_diff.nc
gmt grdmath idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m_diff.nc idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1r1.414_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP1S0R070R1414
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S0R070R1414 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT22
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT22
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT22
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT22
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT22
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT22
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT22 ${POSTSCRIPT22::-3}.png

POSTSCRIPT23=figures/Pozo_catchment_zoom_D_idwP1S0r070mr2828m.ps
TITLE="1m: IDW (P=1,S=0,r=0.707) minus IDW (P=1,S=0,r=2828m)"
DEM_POZO_DIFF_IDWP1S0R070R2828=idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1s0r070mr2828m_invdistnn_1m_diff.nc
gmt grdmath idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1_invdistnn_1m_diff.nc idw/SCI_Pozo_100m_buffer_catchment_UTM11N_NAD83_cl2.xyz_idwp1r2.828_invdistnn_1m_c.tif SUB = $DEM_POZO_DIFF_IDWP1S0R070R2828
gmt grdimage -Q -R$OVERVIEW_REGION $DEM_POZO_DIFF_IDWP1S0R070R1414 -I$POZO_DEM_HS -C$CPT -Jx$OVERVIEW_SCALE -V -K --COLOR_BACKGROUND=white > $POSTSCRIPT23
gmt psxy -Wthin,darkblue -R -J < profile-xy-trace_long_profile.txt -O -K >> $POSTSCRIPT23
gmt psxy -Wthick,black -R -J $POZO_BOUNDARY -O -K >> $POSTSCRIPT23
gmt pscoast -R -Ju11S/$OVERVIEW_SCALE -V -N1 -K -O -Df -Bx0.1m -By0.1m --FONT_ANNOT_PRIMARY=10p --FORMAT_GEO_MAP=ddd:mmF >> $POSTSCRIPT23
gmt psbasemap -R -J -O -K -B+t"$TITLE" --FONT_ANNOT_PRIMARY=9p -LjRB+c19:23N+f+w0.1k+l1:4,000+u+o0.2i --FONT_LABEL=10p >> $POSTSCRIPT23
gmt psscale -R$OVERVIEW_REGION -V -J -DjTRC+o1.5c/0.3c/+w6c/0.3c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Bx1.0 -By+lMeter --FONT=10p --FONT_ANNOT_PRIMARY=10p -O -K >> $POSTSCRIPT23
convert -rotate 90 -quality 100 -density 300 -flatten -fuzz 1% -trim +repage $POSTSCRIPT23 ${POSTSCRIPT23::-3}.png

convert -quality 100 -density 300 ${POSTSCRIPT22::-3}.png ${POSTSCRIPT23::-3}.png -splice 0x25 -background "#ffffff" -append figures/Pozo_catchment_zoom_D_IDWP1_minus_IDWP1_r070mr1414m.png
