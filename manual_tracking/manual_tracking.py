# Trackmate with manual detection and automatic tracking in jython scriptimport sys
from math import pi
from math import sqrt
from random import shuffle

from java.awt import Color

from ij import WindowManager
from ij.measure import ResultsTable
from ij.plugin.frame import RoiManager

from fiji.plugin.trackmate import Logger
from fiji.plugin.trackmate import Model
from fiji.plugin.trackmate import SelectionModel
from fiji.plugin.trackmate import Settings
from fiji.plugin.trackmate import Spot
from fiji.plugin.trackmate import SpotCollection
from fiji.plugin.trackmate import TrackMate
from fiji.plugin.trackmate.detection import ManualDetectorFactory
from fiji.plugin.trackmate.tracking import LAPUtils
from fiji.plugin.trackmate.providers import SpotAnalyzerProvider
from fiji.plugin.trackmate.providers import EdgeAnalyzerProvider
from fiji.plugin.trackmate.providers import TrackAnalyzerProvider
from fiji.plugin.trackmate.tracking.sparselap import SparseLAPTrackerFactory
from fiji.plugin.trackmate.visualization.hyperstack import HyperStackDisplayer
from fiji.plugin.trackmate.gui import TrackMateGUIController
from org.jfree.chart.renderer.InterpolatePaintScale import Jet






def spots_from_results_table( results_table, frame_interval ):
	""" 
	Creates a spot collection from a results table in ImageJ.
	Requires the current results table, in which the results from 
	particle analysis should be. We need at least the center
	of mass, the area and the slice to be specified there.
	We also query the frame interval to properly generate the 
	POSITION_T spot feature.
	"""
	
	frames = results_table.getColumnAsDoubles( results_table.getColumnIndex( 'Slice' ) )
	xs = results_table.getColumnAsDoubles( results_table.getColumnIndex( 'XM' ) )
	ys = results_table.getColumnAsDoubles( results_table.getColumnIndex( 'YM' ) )
	z = 0.
	# Get radiuses from area.
	areas = results_table.getColumnAsDoubles( results_table.getColumnIndex( 'Area' ) )
	spots = SpotCollection()

	for i in range( len( xs ) ):
		x = xs[ i ]
		y = ys[ i ]
		frame = frames[ i ]
		area = areas[ i ]
		t = ( frame - 1 ) * frame_interval
		radius = sqrt( area / pi )
		quality = i # Store the line index, to later retrieve the ROI.
		spot = Spot( x, y, z, radius, quality )
		spot.putFeature( 'POSITION_T', t )
		spots.add( spot, int( frame ) )
		
	return spots


def create_trackmate( imp, results_table ):
	"""
	Creates a TrackMate instance configured to operated on the specified
	ImagePlus imp with cell analysis stored in the specified ResultsTable
	results_table.
	"""
	
	cal = imp.getCalibration()
	
	# TrackMate.
	
	# Model.
	model = Model()
	model.setLogger( Logger.IJ_LOGGER )
	model.setPhysicalUnits( cal.getUnit(), cal.getTimeUnit() )
	
	# Settings.
	settings = Settings()
	settings.setFrom( imp )
	
	# Create the TrackMate instance.
	trackmate = TrackMate( model, settings )
	
	# Add ALL the feature analyzers known to TrackMate, via
	# providers. 
	# They offer automatic analyzer detection, so all the 
	# available feature analyzers will be added. 
	# Some won't make sense on the binary image (e.g. contrast)
	# but nevermind.
	
	spotAnalyzerProvider = SpotAnalyzerProvider()
	for key in spotAnalyzerProvider.getKeys():
		print( key )
		settings.addSpotAnalyzerFactory( spotAnalyzerProvider.getFactory( key ) )
	
	edgeAnalyzerProvider = EdgeAnalyzerProvider()
	for  key in edgeAnalyzerProvider.getKeys():
		print( key )
		settings.addEdgeAnalyzer( edgeAnalyzerProvider.getFactory( key ) )
	
	trackAnalyzerProvider = TrackAnalyzerProvider()
	for key in trackAnalyzerProvider.getKeys():
		print( key )
		settings.addTrackAnalyzer( trackAnalyzerProvider.getFactory( key ) )
	
	trackmate.getModel().getLogger().log( settings.toStringFeatureAnalyzersInfo() )
	trackmate.computeSpotFeatures( True )
	trackmate.computeEdgeFeatures( True )
	trackmate.computeTrackFeatures( True )
	
	# Skip detection and get spots from results table.
	spots = spots_from_results_table( results_table, cal.frameInterval )
	model.setSpots( spots, False )
	
	# Configure detector. We put nothing here, since we already have the spots 
	# from previous step.
	settings.detectorFactory = ManualDetectorFactory()
	settings.detectorSettings = {}
	settings.detectorSettings[ 'RADIUS' ] = 1.
	
	# Configure tracker
	settings.trackerFactory = SparseLAPTrackerFactory()
	settings.trackerSettings = LAPUtils.getDefaultLAPSettingsMap()
	settings.trackerSettings[ 'LINKING_MAX_DISTANCE' ] 		= 10.0
	settings.trackerSettings[ 'GAP_CLOSING_MAX_DISTANCE' ]	= 10.0
	settings.trackerSettings[ 'MAX_FRAME_GAP' ]				= 3
	
	settings.initialSpotFilterValue = -1.

	return trackmate



def process( trackmate ):
	"""
	Execute the full process BUT for the detection step.
	"""
	# Check settings.
	ok = trackmate.checkInput()
	# Initial filtering
	print( 'Spot initial filtering' )
	ok = ok and trackmate.execInitialSpotFiltering()
	# Compute spot features.
	print( 'Computing spot features' )
	ok = ok and trackmate.computeSpotFeatures( True ) 
	# Filter spots.
	print( 'Filtering spots' )
	ok = ok and trackmate.execSpotFiltering( True )
	# Track spots.
	print( 'Tracking' )
	ok = ok and trackmate.execTracking()
	# Compute track features.
	print( 'Computing track features' )
	ok = ok and trackmate.computeTrackFeatures( True )
	# Filter tracks.
	print( 'Filtering tracks' )
	ok = ok and trackmate.execTrackFiltering( True )
	# Compute edge features.
	print( 'Computing link features' )
	ok = ok and trackmate.computeEdgeFeatures( True )

	return ok


def display_results_in_GUI( trackmate ):
	"""
	Creates and show a TrackMate GUI to configure the display 
	of the results. 

	This might not always be desriable in e.g. batch mode, but 
	this allows to save the data, export statistics in IJ tables then
	save them to CSV, export results to AVI etc...
	"""
	
	gui = TrackMateGUIController( trackmate )

	# Link displayer and GUI.
	
	model = trackmate.getModel()
	selectionModel = SelectionModel( model)
	displayer = HyperStackDisplayer( model, selectionModel, imp )
	gui.getGuimodel().addView( displayer )
	displaySettings = gui.getGuimodel().getDisplaySettings()
	for key in displaySettings.keySet():
		displayer.setDisplaySettings( key, displaySettings.get( key ) )
	displayer.render()
	displayer.refresh()
	
	gui.setGUIStateString( 'ConfigureViews' )



def color_rois_by_track( trackmate, rm ):
	"""
	Colors the ROIs stored in the specified ROIManager rm using a color
	determined by the track ID they have.
	
	We retrieve the IJ ROI that matches the TrackMate Spot because in the
	latter we stored the index of the spot in the quality feature. This
	is a hack of course. On top of that, it supposes that the index of the 
	ROI in the ROIManager corresponds to the line in the ResultsTable it 
	generated. So any changes to the ROIManager or the ResultsTable is 
	likely to break things.
	"""
	model = trackmate.getModel()
	track_colors = {}
	track_indices = [] 
	for i in model.getTrackModel().trackIDs( True ):
		track_indices.append( i )
	shuffle( track_indices )
	
	index = 0
	for track_id in track_indices:
		color = Jet.getPaint( float(index) / ( len( track_indices) - 1 ) )
		track_colors[ track_id ] = color
		index = index + 1
	
	spots = model.getSpots()
	for spot in spots.iterable( True ):
		q = spot.getFeature( 'QUALITY' ) # Stored the ROI id.
		roi_id = int( q )
		roi = rm.getRoi( roi_id )
	
		# Get track id.
		track_id = model.getTrackModel().trackIDOf( spot )
		if track_id is None:
			color = Color.GRAY
		else:
			color = track_colors[ track_id ] 
			
		roi.setFillColor( color )



#------------------------------
# 			MAIN 
#------------------------------

# Get current image.
imp = WindowManager.getCurrentImage()

# Remove overlay if any.
imp.setOverlay( None )

# Get results table.
results_table = ResultsTable.getResultsTable()

# Create TrackMate instance.
trackmate = create_trackmate( imp, results_table )

#-----------------------
# Process.
#-----------------------

ok = process( trackmate )
if not ok:
	sys.exit(str(trackmate.getErrorMessage()))

#-----------------------
# Display results.
#-----------------------

# Create the GUI and let it control display of results.
display_results_in_GUI( trackmate )

# Color ROI by track ID!
rm = RoiManager.getInstance()
color_rois_by_track( trackmate, rm )


Solution5

Reply
