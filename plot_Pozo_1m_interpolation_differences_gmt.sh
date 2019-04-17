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

convert -quality 100 -density 300 ${POSTSCRIPT9::-3}.png ${POSTSCRIPT10::-3}.png +append figures/Pozo_catchment_zoom_D_IDWP2_IDWP3b.png

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

convert -quality 100 -density 300 figures/Pozo_catchment_zoom_D_triangulation_IDW.png figures/Pozo_catchment_zoom_D_IDWP2_IDWP3b.png -append figures/Pozo_catchment_zoom_D_triangulation_triangulation_IDW_IDWP2_IDWP3.png
