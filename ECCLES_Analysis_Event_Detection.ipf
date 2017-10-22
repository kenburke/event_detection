#pragma rtGlobals=1		// Use modern global access method.
#include "CollectFileDefaults"		// This file defines a procedure, SetDefaultPaths, that defines the following variables:
								// DefaultDataPath	--  for reading saved data files
								// AnalysisFilePath	--  for analysis descriptor files
								// CrunchFilePath		--  for crunch descriptor files
								
#include "AnalysisSettings"		// This file sets any global variables that the user reliably wants to be set.
								//   e.g., set average titles to specific titles, turn zeroing on or off; set average sweep ranges to default values, etc.
								//  The file must be present even if you don't set globals in it.
								
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
//                  Data Analysis From Disk Files           Rev 2.0 (Crunch v.1; Epoch v.1)
//
//                      for IGOR 3.13b with NIDAQ Tools
//
//                      Dan Feldman 
//			
//			EDIT by KJBurke (14/10/2014)
//				v 5.4
//				-- FUNCTIONAL CHANGES: 
//					--expanded size of CommandPulse to 5 options + DC
//				-- TECHNICAL CHANGES 
//					-- modified CommandPulseTable and associated waves
//					-- modified Read_Sweep and similar functions to increase number
//						of bytes read for CommandPulse by FBinRead function (/F=3or5)
//
//			EDIT by KJBurke (05/15/2015)
//				v 5.4.3
//				-- FUNCTIONAL CHANGES
//					--added "temperature_wave" which is built every time you do "--Analyses--" > "Run..." 
//						(can be displayed/analyzed with "display temperature_wave" or "WaveStats temperature_wave")
//					--expanded to allow export of arbitrary wave
//
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 


// Global variable definitions
String/G DefaultDataPath				// default path for reading saved data files
String/G AnalysisFilePath				// default path for reading analysis descriptor files
String/G CrunchFilePath				// default path for reading/writing crunch descriptor files
String/G expPathRaw = "C:Data:Default:"	// default path for exporting files
String/G expPathCust = "C:Data:Default:"

Variable/G no_samples				// number of DAQ samples per sweep
Variable/G kHz 						// DAQ sample rate in kHz
Make/D/N=2000 display_wave1				// Copy of wave for display
Make/N=1 sweeptimes					// Wave to record time of all sweeps in expt.
Variable/G gZERO=0 					// Flag for zeroing sweeps during acquisition
Variable/G sweepnumber				// current sweep number.
String/G Expt						// name of current experiment or cell
Variable/G refnum=0					// reference number for access open disk sweep file.
String/G Pathname					// name of path for saving data to disk
Variable/G DCoffset					// for turning on & off trace zeroing
Variable/G temperature
Make/N=0 temperature_wave

// Globals for setting time axis on analysis plots
Variable/G left_value
Variable/G right_value

// Globals for file reading & writing				// This program reads BOTH ECCLES files and earlier "classic" Igor sweep files.
String/G separator = "|"							// Single char for coding of x, y, expt names
Variable/G ECCLES_fheader_magicnumber = 11		// Codes for writing & reading to binary files
Variable/G ECCLES_wheader_magicnumber = 12
Variable/G ECCLES_sweep_magicnumber = 13
Variable/G classic_fheader_magicnumber = 1		// Codes for writing & reading to binary files
Variable/G classic_wheader_magicnumber = 2
Variable/G classic_sweep_magicnumber = 3
Variable/G fversion = 0							// sweep file format.  0= not valid Igor file.  1 = classic Igor sweep file.  2= ECCLES sweep file.
Variable/G disk_sweep_time
Variable/G first_sweep_time
Variable/G disk_sweep_no
Variable/G current_wheader_ptr		// this pointer contains the byte address of the current waveheader
String/G ydataname
String/G xdataname
String/G exptname
String/G extension = ".ibt"
Make/N=2 path_mode					// 1 or 2 indicating whether path is a current clamp recording (1) or a voltage clamp recording (2)
Variable/G sweep_mode				// 0 = OFF;  1= current clamp;  2= voltage clamp
String/G RecModeStr	= "No Sweep"				// String version of sweep_mode.  "I clamp"  "V clamp"  "Linescan"

// Globals for reconstructing amplifier command output waves
Make/N=6 command_pulse_flag = 0					// special entry [5] is DC/continuous current injection
Make/N=5 command_pulse_start = 0
Make/N=6 command_pulse_value = 0					// special entry [5] is DC/continuous current injection
Make/N=5 command_pulse_duration = 0
Make/N=3000 CommandWaveOut = 0

// Globals for calculating average sweeps
Make/T/N=11 AvgRange					// string containing sweep ranges to build averages
Make/N=11 average_exists
Make/N=11 avgDCoffset
Make/T/N=11 avgtitle
Variable/G max_averages
max_averages = 11
String/G RangeStr0="A-B;C-D;E"				// string ranges for user input of averages
String/G RangeStr1="A-B;C-D;E"
String/G RangeStr2="A-B;C-D;E"
String/G RangeStr3="A-B;C-D;E"
String/G RangeStr4="A-B;C-D;E"
String/G RangeStr5="A-B;C-D;E"
String/G RangeStr6="A-B;C-D;E"
String/G RangeStr7="A-B;C-D;E"
String/G RangeStr8="A-B;C-D;E"
String/G RangeStr9="A-B;C-D;E"
String/G RangeStr10="A-B;C-D;E"
String/G RTitleStr0=""							// title strings for averages
String/G RTitleStr1=""
String/G RTitleStr2=""
String/G RTitleStr3=""
String/G RTitleStr4=""
String/G RTitleStr5=""
String/G RTitleStr6=""
String/G RTitleStr7=""
String/G RTitleStr8=""
String/G RTitleStr9=""
String/G RTitleStr10=""


// Globals for keeping track of analyses
Variable/G number_of_analyses
String/G analysismenulist				// for making popupmenu
Make/N=10 analmenureference				// index for making analysis popupmenu
Variable/G show_anal_cursors			// toggle for showing anal cursors or not
Variable/G firstanalsweep				// start sweep for doing analyses
Variable/G lastanalsweep				// end sweep for doing analyses
Variable/G current_analysis_number	// for controlling analysis window cursors

Make/N=30 analysis_on				// 0 or 1 for is analysis being used?
Make/N=30 analysis_display			// should analysis window be created?
Make/T/N=30 analysis_name			// title
Make/T/N=30 analysis_type			// type of analysis:  AMPL, PKTOPK, IHOLD, etc.
Make/N=30 analysis_path				// path--not used here, but included for compatibility with analysis descriptor files used during collection
Make/N=30 analysis_cursor0			// 1st coord of analysis window
Make/N=30 analysis_cursor1			// 2nd coord of analysis window
Make/N=30 analysis_y0				// lower y axis bound for graph setup
Make/N=30 analysis_y1				// upper y axis bound for graph setup


// ANALYSIS TYPES CURRENTLY SUPPORTED:
//		AMPL: absolute amplitude
//		IHOLD: also absolute amplitude
//		RSERIES:  calculated from transient and step size
//		RINPUT:  calculated from step size and whether it is a current or voltage recording
//		PKTOPK:  peak-to-peak amplitude within a specified window
//		SUB:  calculated ANAL0-ANAL1, where ANAL0=analysis number in analysis_cursor0
//				and ANAL1=the analysis number in analysis_cursor1
//		SLOPE:  slope between two x-values (in seconds) using IGOR curve-fit routine
//		TIMEOFAPPK:  calculates time of occurrence of peak of AP (where AP=largest depolarization within anal. window)
//		EPSPPK: calculates mean amplitude of 35 pts around max positive potential within the anal window (assumes positive going pk)
//           FIELDPK:  calculates mean amplitude of 35 pts around max negative field within the anal. window. (assumes negative going pk)
//		TIMEOFNEGPK:  calculates time (in s) of negative-going peak within the anal. window.
//		LATENCY:  calculates time of positive- or negative going latency, defined as 2 consecutive points > 2 s.d. away from mean of
//				initial 2 ms of analysis window.


Variable/G stepsize = -5				// For calculating Rin and Rseries  	(in mV or pA)			

// Globals for keeping track of marks on analysis graphs
Make/N=5 mark_exists				// does a given mark exist?
Make/N=5 MarkSweep				// sweep number at which to place each mark
Variable/G Mark0Sweep
Variable/G Mark1Sweep
Variable/G Mark2Sweep
Variable/G Mark3Sweep
Variable/G Mark4Sweep

// Globals for saving sweeps for crunches -- NEW CRUNCH ROUTINES
Make/T/N=2 sourcewavename
Make/T/N=2 diskwavename 
Variable/G crunch_bline_start 
Variable/G crunch_bline_end 
Variable/G crunch_post_start 
Variable/G crunch_post_end 
String/G crunchpathstring

// Globals for crunching across experiments -- OLD CRUNCH ROUTINES
Variable/G crunch_type = 0						// 0 = slope;  1 = netamp;  2= absamp
Variable/G crunch_no_files=0
String/G crunchfilenamestr=" "
Make/T/N=0 crunch_file
Make/N=0 crunch_sweep0
Make/N=0 crunch_sweep1
Make/N=0 crunch_bline0
Make/N=0 crunch_bline1
Make/N=0 crunch_anal0
Make/N=0 crunch_anal1
Make/N=0 crunch_align
Make/N=0 crunch_binsize
Make/N=0 crunch_included			// on-off 1-0 for including a cell in the crunch.  Not saved to disk.
Make/D/N=0 crunch_mean
Make/D/N=0 crunch_stdev
Make/N=0 crunch_n
Variable/G max_crunch_bins
Variable/G crunch_zero_bin			// this is the bin where all the aligned sweeps are.
Variable/G crunch_normalize=1
Make/N=0 crunch_align_offset			// for aligning cells in a crunch
Make/N=0 crunch_align_firstn

// Globals for epoch analysis
String/G epoch_analysis_list			// analysis numbers to calculate values for
Make/T/N=12 EpochRange=""			// Must be initialized to be blank
String/G epoch_range0="A-B;C-D;E"		// sweep range for epoch 0
String/G epoch_range1=""			// sweep range for epoch 1
String/G epoch_range2=""			// sweep range for epoch 2
String/G epoch_range3=""			// sweep range for epoch 3
String/G epoch_range4=""			// sweep range for epoch 4
String/G epoch_range5=""			// sweep range for epoch 5
String/G epoch_range6=""			// sweep range for epoch 6
String/G epoch_range7=""			// sweep range for epoch 7
String/G epoch_range8=""			// sweep range for epoch 8
String/G epoch_range9=""			// sweep range for epoch 9
String/G epoch_range10=""		// sweep range for epoch 10
String/G epoch_range11=""		// sweep range for epoch 11
String/G epoch_temprange

// Globals for mEPSC analysis
Variable/G Kernel_Amp = -20							// in pA, not very important
Variable/G tau_one = 2								// in ms, VERY IMPORTANT
Variable/G tau_two = 6								// in ms, ''
String/G Deconv_Target_Wavename = "display_wave1"	// default trace to be deconvolved is current sweep
String/G Deconv_Output_Wavename = "deltas"			// default name for deconvolved event train
Variable/G Event_Max = 100							// max num events
Variable/G Event_Threshold = 3.5						// in S.D.
Variable/G minimum_time_spacing = 1					// in ms
Variable/G peak_smoothing = 2
Variable/G hard_min_amp = 2							// in pA
Variable/G bline_range = 1							// in samples (for averaging)
Variable/G peak_range = 1							// in samples (for averaging)
Variable/G peak_offset = 0								// in ms (to adjust suspected peak location)
Variable/G events_on = 1
Variable/G peaks_on = 0							// toggles for default display of mini events
Variable/G detection_start = 0						//start and end times for detection range, in seconds
Variable/G detection_end = 1
Variable/G empKerDur = 25						// duration of window for empirical kernel, in ms
Variable/G empKerSmooth = 5						// amount of smoothing for empirical kernel, in samples
Variable/G gRadioVal = 1							//used for checking what type of kernel to use
Variable/G mRadioVal = 1							//used for checking whether to find a minimum or maximum
Variable/G blineSubOn = 0							// trendline adjustment, in case there's drift in holding current in a sweep
Make peakPositionsX
Make peakPositionsY
Make/N=4 W_coef = {0,0,0,0}


// Start the experiment
	
Initialize_General_Variables( )
User_Initialization()							// This calls the procedure found in "AnalysisSettings.ipf" to set any variables the user wants set.
	
// set up sweep window
Make_Sweep_Window()
// Make Command Wave window
Display_Command_Waves()

// set up main control panel	
NewPanel/W=(0,0,1020,75) as "Control Bar"
DoWindow/C Control_Bar						// Name it Control_Bar

// define all controls on Control Panel
Button bQuit, pos={15,5}, size = {50,50}, proc=bQuitProc, title="Quit"
SetVariable setvar_path pos={85,8}, size={200,25}, title="Path", value=pathname, fsize=10, proc=newpathproc
SetVariable setvar_expt pos={85,30}, size={200,25}, noproc, title="File name", proc=NewFileProc, value=Expt, fsize=10
Button bReadWave, pos={360,10}, size={80,50}, proc=bReadWaveProc, title="Read Sweep"
Button bNextWave, pos={460,10}, size={100,20}, proc=bNextWaveProc, title="Next Sweep"
Button bPrevWave, pos={460,40}, size={100,20}, proc=bPrevWaveProc, title="Prev Sweep"
SetVariable setvar_sweep_no pos={85, 55}, size={200,25}, title="Sweep no.", value=disk_sweep_no, fsize=10, proc=GetSweep	
Button bLayout pos={720,5}, size={80,30}, proc=bLayoutProc,title="Print Layout"
Button bSHOW, pos={720,40},size={80,30},proc=bShowAnalCursors,title="SHOW cursors"
SetVariable setvar_stepsize size={105,20}, noproc, pos={855,10}, title="Step (mV)", value=stepsize, fsize = 9

// Current sweep window
NewPanel/W=(1028,0,1200,75) as "Current Sweep"
DoWindow/C Sweep_Description_Window
ValDisplay vdSweep, pos = {10, 10}, fsize=14, size = {100, 50}, title = "Sweep", value=disk_sweep_no
SetDrawEnv fsize=12
DrawText 10,60, "Rec. Mode" 
TitleBox tbMode, pos = {75,40}, fsize=14, size = {100, 40}, variable = RecModeStr


// -------- Everything should now run on its own.

//-----------------------  Additional Initialization routines for linescan analysis--KB


String/G line_folder =  "C:Kevin:2P Imaging:Spine Hunting:"	// name of path for linescans of interest
String/G ms_per_line = "2.24"				// Default for Prairie linescans set for ~2 ms, or 32 µsec dwell at 64 pixels at 32x zoom
String/G GR_max = "2"				// Value for 250 uM 5F, 20 594 estimated for new GaAsP PMTs, both on green, multialk on red

//--------------------------------------------------------Macros----------------------------------------------------------//

Macro Set_Control_Panel_Color()

	ModifyPanel cbRGB=(500,500,65535)
End

Macro Arrange_Crunch_Table()
	
	ModifyTable size=9,width(Point)=30
	ModifyTable size(crunch_included)=8,width(crunch_included)=36,title(crunch_included)="Include?";DelayUpdate
	ModifyTable size(crunch_file)=8, width(crunch_file)=90,title(crunch_file)="Filename (no path/ext.)";DelayUpdate
	ModifyTable size(crunch_sweep0)=8,width(crunch_sweep0)=40,title(crunch_sweep0)="StSweep";DelayUpdate
	ModifyTable size(crunch_sweep1)=8,width(crunch_sweep1)=40,title(crunch_sweep1)="EndSweep";DelayUpdate
	ModifyTable size(crunch_bline0)=8,width(crunch_bline0)=40,title(crunch_bline0)="StBline";DelayUpdate
	ModifyTable size(crunch_bline1)=8,width(crunch_bline1)=40,title(crunch_bline1)="EndBline";DelayUpdate
	ModifyTable size(crunch_anal0)=8,width(crunch_anal0)=40,title(crunch_anal0)="AnalWin0";DelayUpdate
	ModifyTable size(crunch_anal1)=8,width(crunch_anal1)=40,title(crunch_anal1)="AnalWin1";DelayUpdate
	ModifyTable size(crunch_align)=8,width(crunch_align)=40,title(crunch_align)="AlignSweep";DelayUpdate
	ModifyTable size(crunch_binsize)=8,width(crunch_binsize)=40,title(crunch_binsize)="BinSize"

EndMacro
		
		
Macro Arrange_Analysis_Table()
	
	ModifyTable size=9,width(Point)=30
	ModifyTable size(analysis_on)=8,width(analysis_on)=36,title(analysis_on)="On?";DelayUpdate
	ModifyTable size(analysis_display)=8,width(analysis_display)=36,title(analysis_display)="Show?";DelayUpdate
	ModifyTable size(analysis_name)=8, width(analysis_name)=90,title(analysis_name)="Name";DelayUpdate
	ModifyTable size(analysis_type)=8,width(analysis_type)=40,title(analysis_type)="TYPE";DelayUpdate
	ModifyTable size(analysis_path)=8,width(analysis_path)=40,title(analysis_path)="Path";DelayUpdate
	ModifyTable size(analysis_cursor0)=8,width(analysis_cursor0)=50,title(analysis_cursor0)="St.Window";DelayUpdate
	ModifyTable size(analysis_cursor1)=8,width(analysis_cursor1)=40,title(analysis_cursor1)="EndWindow";DelayUpdate

EndMacro

Macro ReversalPotentialCalculator(Current_at_0mV, Current_at_10mV)
	Variable Current_at_0mV
	Variable Current_at_10mV
	
	Print 10* (  Current_at_0mV / (Current_at_0mV - Current_at_10mV)  )
EndMacro


Menu "Macros"
	"Prev_Sweep/F11"
	"Next_Sweep/F12"
end

Function Prev_Sweep()
	SVAR Expt = Expt
	
	Find_Previous_Sweep(Expt)
	Read_Sweep(Expt)
end

Function Next_Sweep()
	SVAR Expt = Expt
	
	Find_Next_Sweep(Expt)
	Read_Sweep(Expt)
end

// --------------------------------------------------------- Menus ---------------------------------------------------------- //

Menu "--Average--"
	"Average Sweeps...", Select_Avg_Proc()
End

Menu "--Analyses--"
	"Load New Analysis File", Reload_Analysis()
	"Run...", Run_Analysis()
	Submenu "Standard Analysis"
		"Select Analysis...", Select_Analysis()
		"Reset All", Reset_Analyses()
		"Time Axis...", Adjust_Time_Axis()
		"Write Results", Write_Analysis_Results()
		"Epoch Calculator", Epoch_Calculator_Dialog()
		"Identify Analysis Sweep", SetUpCursorProc()
		"Spike Analysis Toolbox", Spike_toolbox_window()
	end
	Submenu "CRUNCH"
		"Save Analyses for CRUNCH", SetUpWavesToSaveForCrunch()
		"OLD Crunch ROUTINES", Make_Crunch_Dialog()
	end
	Submenu "Event Detection, Mini's"
		"Mini EPSC Analysis", Start_Event_Detection()
	end
	Submenu "Export"
		"Export Panel", Make_Export_Window()
	end
	Submenu "Ca Imaging"
		"Calcium Imaging Analysis Panel", Make_Linescan_Input_Window()
		"Sort Linescans into Subfolders", FileSortWindow()		
	end
End

Menu "--Mark--"
	"New Mark", Make_Mark()
	"Edit Mark", Edit_Mark()
	"Delete...", Delete_Marks()
End

Function DummyProc()

	print "Not a valid menu choice"
End

Menu "--Display--"
	"Show Current Injection Window", 	Display_Command_Waves()
	"Make Stim Protocol Graph",Make_Stim_Protocol_Graph()
End


//----------------------------------------------------------Initialization Routine -----------------------------------------//

Function Initialize_General_Variables()

	SVAR Pathname = Pathname
	SVAR Expt = Expt
	Wave display_wave1 = display_wave1
	NVAR disk_sweep_no = disk_sweep_no
	SVAR Exptname = Exptname
	SVAR ydataname = ydataname
	SVAR xdataname = xdataname
	Wave average_exists = average_exists
	Wave avgDCoffset = avgDCoffset
	Wave/T avgtitle=avgtitle
	NVAR current_average_number = current_average_number
	NVAR max_averages = max_averages
	NVAR left_value = left_value
	NVAR right_value = right_value
 	NVAR show_anal_cursors = show_anal_cursors
 	SVAR DefaultDataPath = DefaultDataPath	
 	SVAR crunchpathstring = crunchpathstring
 	SVAR CrunchFilePath = CrunchFilePath	
 	Wave average_exists = average_exists
 	Wave path_mode = path_mode
 	variable num
 	string cmdstr
 	
 	// Define all the analysis waves to hold analysis results
 	num = 0
	do
		cmdstr = "Make/N=0 analysis"+num2str(num)
		execute cmdstr
		num += 1
	while (num < 30)

 	SetDefaultPaths()					// procedure defined in "CollectFileDefaults.ipf"
 									//  Sets DefaultDataPath, AnalysisFilePath, CrunchFilePath
 	crunchpathstring = CrunchFilePath
	Pathname = DefaultDataPath
	disk_sweep_no =1
	display_wave1 = 0

	Expt = "Untitled"
	ydataname = "";  xdataname = "";  Exptname = "--no experiment--"
	
	path_mode = 0						// ASSUME current recording.  I need to have this stored with data in disk file!
	
	left_value = 0							// initial values for time axis of analysis graphs
	right_value = 20						// ditto
	
	NewPathProc("",0,"","")							// set the savepath symbolic path from pathname
	
	average_exists = 0
	current_average_number = 0
	avgDCoffset = 0		
	max_averages = 11

	show_anal_cursors = 1		
End




Function ReInitialize()
 
	Delete_All_Averages("")
	Delete_All_Marks("")
	DoWindow/K Mark_Window
	Reset_Analyses()

	Initialize_General_Variables()
End


Function Initialize_Analyses()

	Wave/T analysis_name = analysis_name
 	Wave analysis_cursor0 = analysis_cursor0
 	Wave analysis_cursor1 = analysis_cursor1
 	Wave analysis_path = analysis_path
 	Wave/T analysis_type = analysis_type
 	Wave analysis_on = analysis_on
 	Wave analysis_display = analysis_display
 	Wave analysis_y0 = analysis_y0
 	Wave analysis_y1 = analysis_y1
 	NVAR number_of_analyses = number_of_analyses
 	SVAR AnalysisFilePath = AnalysisFilePath				// Set by SetDefaultPaths(), above
 	
 	Make/N=30 inp0				// temporary input waves.  Max 30 analyses
 	Make/N=30 inp1
	Make/T/N=30 inp2
	Make/T/N=30 inp3
	Make/N=30 inp4
	Make/N=30 inp5
	Make/N=30 inp6
	Make/N=30 inp7
	Make/N=30 inp8
	Make/N=30 inp9
	
 	
 	String cmdstr
 	
 	cmdstr ="NewPath/O/Q analysissetup \""+AnalysisFilePath+"\""			//  Set global from default directory file
 	Execute cmdstr
 	print "Preparing to load waves from setup file"
 	LoadWave/J/P=analysissetup/K=0/N=inp 
 	print "Loading complete"
 	
	// set number_of_analyses
	variable end_detected=0
	number_of_analyses = 0
	do
		if (inp0[number_of_analyses] == -1)		// analysis_on
			end_detected = 1
		endif
		if (number_of_analyses > 30)
			end_detected =1
			DoAlert 0, "There may have been a problem loading the analysis setup file."
		endif
		number_of_analyses += 1
	while (!end_detected)
	number_of_analyses -= 1

	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_on"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_display"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_name"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_type"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_path"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_cursor0"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_cursor1"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_y0"
	Execute cmdstr
	cmdstr="Redimension/N="+num2str(number_of_analyses)+" analysis_y1"
	Execute cmdstr
	
 	Analysis_on = inp0
 	Analysis_display = inp1
 	Analysis_name = inp2
 	Analysis_type = inp3
 	Analysis_path = inp4				//Note: i'm skipping analysis channel=inp5
 	analysis_cursor0=inp6
 	analysis_cursor1=inp7
 	analysis_y0 = inp8
 	analysis_y1 = inp9
 	 
 	Killwaves inp0, inp1, inp2, inp3, inp4, inp5, inp6, inp7, inp8, inp9
 	
 End
 				
Function Reload_Analysis()			// called when user wants to load in a new analysis parameter file.

	variable num
	string cmdstr
	// get rid of old analysis windows
	
	num = 0
	do
		cmdstr = "DoWindow/K analysis_window"+num2str(num)				// delete all the analysis windows.
		execute cmdstr
		num += 1
	while (num < 30)
	
	// allow user to load in a new analysis parameter file.
	
	Initialize_Analyses()
		
	SetUpAnalysisWindows()
	
End

Function bZEROProc(ctrlName2) : buttoncontrol
	string ctrlName2		// ctrlName2 is "bZERO" when called for DC -> zero switch
						// ctrlName2 is "bDC" when called for zero -> DC switch
	
	NVAR gZERO = gZERO
	NVAR DCoffset = DCoffset
	Wave display_wave1 = display_wave1
	variable i1
	string avgwave, cmdstr
	NVAR max_averages = max_averages
	wave avgDCoffset = avgDCoffset
	wave average_exists = average_exists
	
	if ( cmpstr(ctrlName2, "bZERO") == 0)
		gZERO = 1										// turn zeroing on
		Button $ctrlName2, title="DC",rename=bDC						// rechristen the button DC
		DCoffset = mean (display_wave1,0,pnt2x(display_wave1,9))		// zero the current wave
		display_wave1 -= DCoffset
		i1 = 0
		do
			if (average_exists[i1] == 1)								// zero all the average sweeps
				avgwave = "Average_"+num2str(i1)
				avgDCoffset[i1] = mean($avgwave,0,pnt2x($avgwave,9))
				cmdstr = avgwave + "-=avgDCoffset["+num2str(i1)+"]"
				Execute cmdstr
			endif
			i1 += 1
		while (i1 < max_averages)
	else
		gZERO = 0										// turn zeroing off
		Button $ctrlName2, title="Zero B'line", rename=bZERO			// rechristen ZERO
		display_wave1 += DCoffset									// remove DC offset from current wave
		i1 = 0
		do														// unzero all the average sweeps
			if (average_exists[i1] == 1)
				avgwave = "Average_"+num2str(i1)
				cmdstr = avgwave + "+=avgDCoffset["+num2str(i1)+"]"
				Execute cmdstr
			endif
			i1 += 1
		while (i1 < max_averages)
		DCoffset = 0	
	endif
End

Function bHideSweepProc(ctrlname) : buttoncontrol
	string ctrlname
	
	if ( cmpstr(ctrlName, "bHideSweep") == 0)			// if user wants to hide the sweep
		RemoveFromGraph/Z display_wave1
		Button $ctrlName, title="Show Swp",rename=bShowSweep						// rechristen the button bShowSweep
	endif
	
	if (cmpstr(ctrlName, "bShowSweep") == 0)			// if user wants to display sweep
		AppendToGraph/C=(52224,0,0) display_wave1
		Button $ctrlName, title="Hide Swp", rename = bHideSweep
	endif
End

	
Function bShowAnalCursors(ctrlname) : buttoncontrol
	string ctrlname
	NVAR show_anal_cursors = show_anal_cursors
	
	DoWindow/F Control_Bar
	if ( cmpstr(ctrlname,"bSHOW") == 0)		// if user wants to show cursors
		show_anal_cursors = 1
		Button $ctrlname, title= "HIDE cursors", rename = bHIDE
		Draw_Analysis_Cursors(1)
	else										// user wants to hide cursors
		show_anal_cursors = 0
		Button $ctrlname, title="SHOW cursors", rename = bSHOW
		Draw_Analysis_Cursors(0)
	endif
End

Function NewPathProc(dum1, dum2, dum3, dum4)	
	string dum1
	variable dum2
	string dum3
	string dum4							// this function is called if the user changes the pathname for saving data

	SVAR pathname = pathname
	
	NewPath/O savepath pathname		// overwrites the path if it exists.
	
End

Function bQuitProc(dummy) : buttoncontrol
	string dummy
	Button bQuit, rename=bReally, title = "Really?"
	Button bYesQuit, pos = {70,10}, size = {25, 15}, title="Yes", proc=bYesQuitProc
	Button bNoQuit, pos= {70, 30}, size= {25,15}, title="No", proc=bNoQuitProc
End

Function bYesQuitProc(dummy) : buttoncontrol
	string dummy
	bNoQuitProc("")
	CleanUp()
	Execute "quit/N"			// quit without saving -- when programming, you must save changes manually--
							// run CleanUp() first, then save changes, then type "Quit" on command line
							// and answer "yes" to save changes.
End

Function bNoQuitProc(dummy) : buttoncontrol
	string dummy
	Button bReally, title = "Quit", rename=bQuit
	KillControl bYesQuit
	KillControl bNoQuit
End

//---------------------------------------------------- Sweep Window ----------------------------------------------------------//

Function Make_Sweep_Window() : Graph
	NVAR sweepnumber = sweepnumber
	NVAR sweep0time = sweep0time
	Wave sweeptimes = sweeptimes
	SVAR ydataname = ydataname
	SVAR xdataname = xdataname
	SVAR exptname = exptname
	NVAR show_anal_cursors = show_anal_cursors

	
	string commandstr
	
	PauseUpdate; Silent 1		// building window...
	Display /W=(360,125,760,435) display_wave1 as "Sweep"
	DoWindow/C Sweep_window					// name it Sweep_window
	ModifyGraph wbRGB=(65280,65280,65280),gbRGB=(65280,65280,65280)
	Label left "mV"
	Label bottom "Time (sec)"
	SetAxis/E=1 left -40,20
	SetAxis bottom 0,0.1
	SetDrawLayer UserFront
	ModifyGraph axoffset(left)=-1, zero(left)=1
	
	textbox /A=MT/X=-10/F=0/E "Sweep \{disk_sweep_no} -- \{secs2time(disk_sweep_time,3)} -- \{temperature} ¡C"		//KJB edit to add temp data
	Button bZERO, pos={440,8}, size={60,20},title="Zero B'line",proc=bZEROProc		// Trace zeroing control
	Button bShowSweepCursors, pos ={440,32}, size={60,20}, title="Cursors", proc=bAdjust_Anal_Cursors_FrontEnd
	Button bHideSweep, pos={350,8}, size={100,20}, title = "Hide swp", proc=bHideSweepProc	     // allow user to remove sweep from graph

	commandstr = "Label left \""+ydataname+"\""
	execute commandstr
	commandstr = "Label bottom \""+xdataname+"\""
	execute commandstr
		
	// Make_Step_Window()
		
	if (show_anal_cursors == 1)
		Draw_Analysis_Cursors(1)											
	endif
End


Function Make_Step_Window()

	Wave display_wave1 = display_wave1
	
	PauseUpdate; Silent 1		// building window...
	Display/W=(500,340,760.5,500) display_wave1 as "Step"
	DoWindow/C Step_window				// name it
	ModifyGraph wbRGB=(64000,64000,0),gbRGB=(65535,65535,65535)  					// yellow!
	Label left "pA"
	Label bottom "time (msec)"
	SetAxis/E=1 left -100,200
	SetAxis bottom 0.29,0.4
	SetDrawLayer UserFront
	ModifyGraph axoffset(left)=-1, zero(left)=1
	ModifyGraph tick=2, btlen=2, lblMargin =1							// various things to conserve space
	ModifyGraph margin(bottom)=25, margin(top)=10, margin(right)=10		// more things to conserve space
	ModifyGraph margin(left)=25, tloffset(left) = 2							// ditto
End



//----------------------------------------- Functions Controlling Analysis Cursors ----------------------------------------------------//

Function Draw_Analysis_Cursors(flag1)
	variable flag1								// 1 to draw cursors, 0 to erase them
	
	NVAR number_of_analyses = number_of_analyses
	Wave analysis_cursor0=analysis_cursor0
	Wave analysis_cursor1=analysis_cursor1
	Wave analysis_on=analysis_on
	Wave/T analysis_type = analysis_type
	Wave/T analysis_name = analysis_name
	
	Variable i1=0
	
	DoWindow/F Step_window					// erase step window
	SetDrawLayer/K Userback
	
	DoWindow/F Sweep_window				// erase sweep window	
	SetDrawLayer/K Userback

	if (flag1 == 1)
		do
			if ((analysis_on[i1]==1) %& ((cmpstr(analysis_type[i1],"SUB") != 0) %& (cmpstr(analysis_type[i1],"DIV") != 0)))		// if analysis is active
																													// and it's not type SUB or DIV
				DoWindow/F sweep_window
				SetDrawLayer UserBack			
				SetDrawEnv xcoord = bottom, ycoord = prel, linethick=2,save
				DrawLine analysis_cursor0[i1],0.75+(.02*i1),analysis_cursor1[i1],0.75+(0.02*i1)
				SetDrawEnv textxjust=0, textyjust=2,fsize=10
				DrawText analysis_cursor0[i1], 0.77+(.02*i1),analysis_name[i1]
			endif
			i1 += 1
		while (i1 < number_of_analyses)
	endif
	
End

Function bShow_Anal_Cursors(ctrlstring)				// called from control bar button or Menu
	string ctrlstring
	
	NVAR show_anal_cursors = show_anal_cursors
	
	if (show_anal_cursors == 0)
		show_anal_cursors = 1
	else
		show_anal_cursors = 0
	endif
	Draw_Analysis_Cursors(show_anal_cursors)
	
End


// (These are called from the Menu)

Function Select_Analysis()
	NewPanel/W=(375,15,535,85) as "Add Analysis"
	DoWindow/C Add_Analysis_Window
	
	Button bAddNewAnalysis, pos={10,15}, size={40,40}, title = "NEW", proc = AddNewAnalProc
	Button bCloseSelectAnalWindow, pos={110,15}, size={40,40}, title="Close", proc=CloseSelectAnalWindowProc
	Button bUpdateAnalyses, pos={60,15},size={40,40},title="Update",proc=UpdateAnalysesProc
	
	// put up a table so user can edit analysis parameters.
	Edit/w=(105,115,520,285) analysis_on, analysis_display, analysis_name, analysis_type, analysis_path, analysis_cursor0, analysis_cursor1 as "Analysis List"
	DoWindow/C Analysis_Table
	Execute "Arrange_Analysis_Table()"
	
End

Function UpdateAnalysesProc(dummy)
	string dummy
	
	// User has altered the analysis list.  Update display of analysis cursors to reflect this.  Also add/remove appropriate
	// analysis windows.  ADD THIS FUNCTION IN THE FUTURE.
	
	NVAR show_anal_cursors = show_anal_cursors
	
	if (show_anal_cursors == 1)
		Draw_Analysis_Cursors(1)
	endif
	
	DoAlert 0, "Use Make_Analysis_Window(number) to add new analysis window."
	
End

Function AddNewAnalProc(dummy) : buttoncontrol
	string dummy
	
	NVAR number_of_analyses = number_of_analyses
	string cmdstr
	
	number_of_analyses += 1
	
	cmdstr = "Redimension/N="+num2str(number_of_analyses)+" analysis_on"
 	Execute cmdstr
 	cmdstr = "Redimension/N="+num2str(number_of_analyses)+" analysis_name"
 	Execute cmdstr
	cmdstr = "Redimension/N="+num2str(number_of_analyses)+" analysis_type"
 	Execute cmdstr
 	cmdstr = "Redimension/N="+num2str(number_of_analyses)+" analysis_path"
 	Execute cmdstr
 	cmdstr = "Redimension/N="+num2str(number_of_analyses)+" analysis_cursor0"
 	Execute cmdstr
 	cmdstr = "Redimension/N="+num2str(number_of_analyses)+" analysis_cursor1"
 	Execute cmdstr
 	
End

Function CloseSelectAnalWindowProc(dummy) : buttoncontrol
	string dummy
	
	DoWindow/K Add_Analysis_Window
	DoWindow/K Analysis_Table
End

Function bAdjust_Anal_Cursors_FrontEnd(ctrlName)	
	string ctrlName
	
	// This procedure is called when user clicks Cursors button on Sweep or Step windows.
	//  If called by bShowSweepCursors, this procedure will call Adjust_Anal_Cursors(0)
	//  If called by bShowStepCursors, this procedure will call Adjust_Anal_Cursors(2)
	//  This is for compatibility with the collect program, which uses path0=sweep, path2=step
	
	If (cmpstr(ctrlName,"bShowSweepCursors")==0)
		Adjust_Anal_Cursors(0)
	endif
	if (cmpstr(ctrlName,"bShowStepCursors")==0)
		Adjust_Anal_Cursors(2)
	endif
End

Function Adjust_Anal_Cursors(path) 	// allows user to graphically change analysis windows using cursors
	variable path						// path = 0 means path0;  path = 1 means path1; path=2 means STEP window (path0)
									// in the analysis program, treat 0 and 1 as identical and referring to sweep window.  
									// treat path 2 as unique, referring to step window.
	Wave/T analysis_name = analysis_name
	Wave/T analysis_type = analysis_type
	NVAR number_of_analyses= number_of_analyses
	Wave analysis_path = analysis_path
	Wave analysis_on = analysis_on
	Wave analmenureference=analmenureference
	SVAR analysismenulist=analysismenulist
	
	// create popupmenu listing relevant analyses
	
	variable i1 = 0
	variable j1 = 0
	analysismenulist = ""
	Redimension/N=0 analmenureference			// start off with empty LUT
	do
		if ((analysis_on[i1] == 1) %& (analysis_path[i1]==path) %& ((cmpstr(analysis_type[i1],"SUB") != 0) %& (cmpstr(analysis_type[i1],"DIV") != 0)))
			analysismenulist += analysis_name[i1]				// no cursors to adjust if type is SUB or DIV
			Redimension/N=(j1+1) analmenureference				// increase size of LUT
			analmenureference[j1]=i1							// create LUT for popupmenu
			j1 += 1
			if (i1 < (number_of_analyses-1))
				analysismenulist += ";"
			endif
		endif
		i1 += 1
	while (i1<number_of_analyses)
	print analysismenulist
	
	if (path==0)
		Popupmenu Analchoices, mode=1, win=Sweep_window, pos = {290,50}, proc=AnalChoicesProc, title="Analysis:",value=#"analysismenulist"
	endif
	if (path==2)
		Popupmenu Analchoices, mode=1, win=Step_window, pos = {220,50}, proc=AnalChoicesProc, title="Analysis:",value=#"analysismenulist"
	endif
End


Function AnalChoicesProc(ctrlName, popNum, popStr) : PopUpMenuControl			// for adjusting analysis cursors
	string ctrlName
	Variable popNum
	String popStr
	
	Wave/T analysis_name = analysis_name
	Wave analysis_path = analysis_path
	Wave analysis_cursor0=analysis_cursor0
	Wave analysis_cursor1=analysis_cursor1
	String commandstr, wavestr
	Wave analmenureference = analmenureference
	
	Variable analysis_number
	
	// Erase the popupmenu
	KillControl Analchoices
	
	popNum -= 1		
	analysis_number = analmenureference[popNum]			// Look up the chosen analysis from the LUT	
	
	// On the appropriate window.... //
	if ((analysis_path[analysis_number] == 0) %| (analysis_path[analysis_number] == 1) )			// ** UNIQUE FOR ANALYSIS PROG ** //
		DoWindow/F sweep_window
		Button bACCEPT, pos={460,64}, size={40,20}, title="Accept", proc=bACCEPTProc
		Button bREVERT, pos ={460,88}, size={40,20}, title="Revert", proc=bREVERTProc
		wavestr = wavename("sweep_window",0,3)				// put cursor on first wave displayed in the window
	endif

	print "analysis_number", analysis_number, "path: ", analysis_path[analysis_number]
	
	if (analysis_path[analysis_number] == 2)				// assumes STEP is associated with path 0
		DoWindow/F step_window
		Button bACCEPT, pos={260,64}, size={40,20}, title="Accept", proc=bACCEPTProc
		Button bREVERT, pos ={260,88}, size={40,20}, title="Revert", proc=bREVERTProc
		wavestr=wavename("step_window",0,3)
	endif
	
	// ... draw the current analysis window.  //
	SetDrawLayer UserFront
	SetDrawEnv fsize=10, linethick=1, xcoord=bottom, save
	DrawLine analysis_cursor0[analysis_number],0.1,analysis_cursor0[analysis_number],0.9				// draw in cursor0 position
	DrawLine analysis_cursor1[analysis_number],0.1,analysis_cursor1[analysis_number],0.9				// draw in cursor1 position
	commandstr = "TextBox/F=0/N=label/A=LT \"" + analysis_name[analysis_number] +"\""
	Execute commandstr

	// put up user cursors for changing //	
	commandstr = "Cursor A, "+wavestr+", analysis_cursor0["+num2str(analysis_number)+"]"
	Execute commandstr
	commandstr = "Cursor B, "+wavestr+", analysis_cursor1["+num2str(analysis_number)+"]"
	Execute commandstr
	
	NVAR current_analysis_number = current_analysis_number			// save the analysis number as global
	current_analysis_number = analysis_number
	
End


Function bACCEPTProc(dummy) : buttoncontrol				// user wants to accept cursor positions for new analysis window //
	string dummy
	
	NVAR current_analysis_number = current_analysis_number	
	Wave analysis_cursor0 = analysis_cursor0			
	Wave analysis_cursor1 = analysis_cursor1
	
	analysis_cursor0[current_analysis_number]=xcsr(A)
	analysis_cursor1[current_analysis_number]=xcsr(B)
	
	Cursor/K A
	Cursor/K B
	
	KillControl bACCEPT
	KillControl bREVERT
	
	// remove old cursor position and label //
	TextBox/K/N=label
	SetDrawLayer/K UserFront
	Draw_Analysis_Cursors(1)
	
End

Function bREVERTProc (dummy): buttoncontrol					// user wants to ignore cursors and leave analysis window intact
	string dummy
	
	Cursor/K A
	Cursor/K B
					
	KillControl bACCEPT
	KillControl bREVERT
	
	TextBox/K/N=label
	SetDrawLayer/K UserFront
	
End
	

// ---------------------------------------------------- Functions to average sweeps and display them -----------------------------------------------//

Function Select_Avg_Proc()
	
	Wave average_exists = average_exists
	variable num, xpos, ypos
	string namestr, valstr
	
	NewPanel/W=(350,90,590,350) as "Make Average"
	DoWindow/C Make_Avg_Window
	
	num = 0; ypos = 10
	do	
		namestr = "Avg"+num2str(num)
		Checkbox $namestr, pos={15,(ypos)}, size={30,15}, title = num2str(num), value = average_exists[num], proc = Avg_checked
		
		namestr = "Range"+num2str(num)
		valstr = "RangeStr"+num2str(num)
		Setvariable $namestr, pos ={55, (ypos-1)}, size = {80,10}, fsize = 9, value=$valstr, disable = (1-average_exists[num]), proc=SetRange, title=" "
		
		namestr = "RTitle"+num2str(num)
		valstr = "RTitleStr"+num2str(num)
		Setvariable $namestr, pos = {145, (ypos-1)}, size = {80,10}, fsize = 9, value = $valstr, disable = (1-average_exists[num]), proc = SetRTitle, title = " "
		
		num += 1
		ypos += 20
		
	while (num < 11)			// currently supports Avg0 - Avg10

	Button bClose, pos = {165,235}, size = {60, 20}, title = "Close", proc=bMake_Average_Proc
	Button bDeleteAll, pos={85,235},size={70,20},title="Delete All", proc=Delete_All_Averages
	Button bAvgOK, pos={10,235},size={60,20},title="OK", proc=bMake_Average_Proc
End


Function Avg_Checked(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	
	Wave average_exists = average_exists
	String namestr
	variable average_number
	
	// This procedure is called whenever the user checks or unchecks a box to select an average.
	
	if (strlen(ctrlName) == 4)						// single digit average number
		average_number = str2num(ctrlName[3])				// which average number was checked?
	endif
	if (strlen(ctrlName) == 5)						// double digit average number
		average_number = str2num(ctrlName[3,4])				// which average number was checked?
	endif
	
	average_exists[average_number] = checked
	
	if (checked == 0) 									// if the user just unchecked the box, delete the average
		Delete_Average(average_number)
	endif
	
	// update controls in the Make_Avg_Window

	namestr = "Avg"+num2str(average_number)
	Checkbox $namestr, win=Make_Avg_Window, value = average_exists[average_number]
		
	namestr = "Range"+num2str(average_number)
	Setvariable $namestr, win=Make_Avg_Window, disable = (1-average_exists[average_number])
		
	namestr = "RTitle"+num2str(average_number)
	Setvariable $namestr, win = Make_Avg_Window, disable = (1-average_exists[average_number])

End

	
Function SetRange(ctrlName, varNum, varStr, varName)			// this is called whenever user sets a sweep range
	String ctrlName											// for creating an average.
	Variable varNum
	String varStr
	String varName
	
	Wave/T AvgRange = AvgRange
	Variable average_number
	
	// determine which average number was adjusted
	
	if (strlen(ctrlName) == 6)						// single digit Range number
		average_number = str2num(ctrlName[5])				
	endif
	if (strlen(ctrlName) == 7)						// double digit Range number
		average_number = str2num(ctrlName[5,6])				
	endif

	// Save the entered string into AvgRange
	AvgRange[average_number] = varStr

End

Function SetRTitle(ctrlName, varNum, varStr, varName)			// this is called whenever user sets a title
	String ctrlName											// for an average.
	Variable varNum
	String varStr
	String varName
	
	Wave/T avgtitle = avgtitle
	Variable average_number
	
	// determine which average number was adjusted
	if (strlen(ctrlName) == 7)						// single digit RangeTitle number
		average_number = str2num(ctrlName[6])				
	endif
	if (strlen(ctrlName) == 8)						// double digit RangeTitle number
		average_number = str2num(ctrlName[6,7])				
	endif

	// copy the Range Title into the avgtitle wave
	avgtitle[average_number] = Varstr
		
End


Function bMake_Average_Proc(ctrlName)							// Called when user hits "OK" on Make_Average_Window
	string ctrlName											// This makes & displays all desired sweep averages
	
	Wave/T AvgRange = AvgRange					// string description of sweep ranges for averages.  Format:  X-Y; Z; B-C
	Wave average_exists = average_exists				// list of existing averages
	Wave avgDCoffset = avgDCoffset
	Wave/T avgtitle = avgtitle
	NVAR max_averages = max_averages
	SVAR Expt = Expt
	NVAR gZERO = gZERO

	variable i1, returnval, current_average_number, posn, hyphen, semi, len, startswp, endswp, numswps, singleswp
	string avgname, sourcename, cmdstr

	if (cmpstr(ctrlName, "bClose")==0)					// if user hit "close"
		DoWindow/K Make_Avg_Window
		Return 0
	endif
	
	// User hit Make -- make all averages
	current_average_number = 0
	do
		if (average_exists[current_average_number]==1)
	
			avgname = "Average_"+num2str(current_average_number)
						
			// Calculate this average
			len = strlen(AvgRange[current_average_number])
			posn = 0
			numswps = 0
			do	
				singleswp = 0															// for each semi-separated subrange in the string:
				semi = strsearch((AvgRange[current_average_number]),";",posn)				// find semi
				if (semi == -1)															// if no semi, treat as if semi at end of string
					semi = len
				endif
				hyphen = strsearch((AvgRange[current_average_number]),"-",posn)				// find hyphen
				if ((hyphen > 0) %& (hyphen < semi))
					startswp = str2num((AvgRange[current_average_number])[posn, hyphen-1])		// determine start & end sweeps for this subrange of range string
					endswp = str2num((AvgRange[current_average_number])[hyphen+1, semi-1])	
				else		// there was no hyphen -- user only input a single sweep number
					startswp = str2num((AvgRange[current_average_number])[posn, semi-1])
					singleswp = 1
				endif
				Find_Sweep(startswp,Expt)												// read first sweep of the subrange
				Read_Sweep(Expt)
				if (numswps == 0)
					Duplicate/O/D display_wave1, $avgname
				else
					cmdstr = avgname + "+= display_wave1"
					execute cmdstr
				endif
				numswps += 1
				if (singleswp == 0)					// if user entered a sweep range, calc sum for that range
					i1 = startswp+1
					do
						returnval = Find_Next_Sweep(Expt)										// read subsequent sweeps in this subrange
						if (returnval > 0)
							Read_Sweep(Expt)
							cmdstr = avgname + "+= display_wave1"
							execute cmdstr
							numswps += 1
						endif
						i1 += 1
					while ( (i1 < endswp+1) %& (returnval >0) )										// end of this subrange or couldn't find sweep
				endif			// sweep range
				posn = semi + 1															// ready to look at next subrange
			while ((posn < len) %& (returnval > 0))											// until all subranges are done.
			cmdstr = avgname + " /= "+num2str(numswps)					// calculate average
			execute cmdstr
			print "Made Average_"+num2str(current_average_number), "sweeps: ", numswps
			
			if (gZERO == 1)											// if DC zeroing is on, zero the average wave //
				cmdstr = "avgDCoffset["+num2str(current_average_number)+"]= mean("+avgname+",0,pnt2x("+avgname+",9))"
				Execute cmdstr
				cmdstr = avgname + "-=avgDCoffset["+num2str(current_average_number)+"]"
				Execute cmdstr
			endif
	
			// Delete old avg trace if currently displayed, and then display new trace with label.
			DoWindow/F Sweep_window
			RemoveFromGraph/Z $avgname
			AppendToGraph/B/L/C=(0,0,0) $avgname
			cmdstr ="Tag/F=0/P=1/X=10/Y=-10 "+avgname+", "+num2str(.02+(.004*current_average_number))+", "
			if (strlen(avgtitle[current_average_number]) >0)
				cmdstr += "\" " + avgtitle[current_average_number]+"\""
			else
				cmdstr += "\" " + AvgRange[current_average_number]+"\""
			endif
			execute cmdstr
		
		endif  		// if average_exists
	
		current_average_number += 1
	while (current_average_number < max_averages)
End


Function Delete_Average(avg_number)
	Variable avg_number
	
	Wave average_exists = average_exists
	string cmdstr
	string avgwave
	wave avgDCoffset = avgDCoffset
	
	avgwave = "Average_"+num2str(avg_number)
	
	DoWindow/F Sweep_window
	RemoveFromGraph/Z $avgwave
	average_exists[avg_number] = 0
	avgDCoffset[avg_number] = 0
	KillWaves/Z $avgwave
	
End

Function Delete_All_Averages(dummy)
	string dummy

	Variable i1=0
	NVAR max_averages = max_averages
	
	do
		Delete_Average(i1)
		i1 += 1
	while (i1 <= max_averages)

End


//-------------------------------------------------------- Functions to Create Analysis Windows -----------------------------------------------------------//
	
Function Make_Analysis_Window(analysis_number) : Graph
	Variable analysis_number
	
	Wave/T analysis_name = analysis_name
	Wave path_mode = path_mode
	Wave/T analysis_type = analysis_type
	Wave analysis_path = analysis_path
	Wave analysis_y0 = analysis_y0
	Wave analysis_y1 = analysis_y1
	String windowname
	String cmdstr, cmdstr2, labelstr
	variable real_path
	variable topposition
	
	Windowname=UniqueName("Analysis_Window",6,analysis_number)			// 6 denotes a graph
	
	if (analysis_path[analysis_number] == 2)			// for any analyses derived from STEP window
		real_path = 0
	else
		real_path = analysis_path[analysis_number]
	endif
	if ((cmpstr(analysis_type[analysis_number],"IHOLD")==0) %| (cmpstr(analysis_type[analysis_number],"RSERIES")==0) %| (cmpstr(analysis_type[analysis_number],"RINPUT")==0) )

		topposition = 250+(15*analysis_number)
		labelstr = num2str(65+topposition)				// bottom yval 
		cmdstr2 = "ModifyGraph margin(bottom)=15"
	else
		topposition = 100+(15* analysis_number)
		labelstr = num2str(100+topposition)				// bottom yval
		cmdstr2 = "ModifyGraph margin(bottom)=25"
	endif
	cmdstr="Display/W=(4,"+num2str(topposition)+",354,"+labelstr+") analysis"+num2str(analysis_number)+" vs sweeptimes"				//** UNIQUE TO ANAL **//
	Execute cmdstr
	cmdstr = "DoWindow/C "+Windowname
	Execute cmdstr
	cmdstr = "SetAxis/E=0 left, "+num2str(analysis_y0[analysis_number])+", "+num2str(analysis_y1[analysis_number])
	Execute cmdstr
	
	SetAxis/E=0 bottom, 0, 30
	ModifyGraph mode[0]=3, marker[0]=16, rgb[0]=(0,0,0), msize[0]=1		// set display prop
	ModifyGraph zero=1, zeroThick=0.2
	ModifyGraph tick=2, btlen=2, lblMargin =1, fsize=8							// various things to conserve space
	Execute cmdstr2													// use appropriate bottom margin 
	ModifyGraph margin(top)=10, margin(right)=10						// more things to conserve space
	ModifyGraph margin(left)=30, tloffset(left) = 2							// ditto
	ModifyGraph grid(left)=1											// add y axis grid
	Label bottom "Time (min)"
	labelstr = yaxislabel(analysis_type[analysis_number],path_mode[real_path])					// figure out correct y axis label
	cmdstr="Label left \""+labelstr+"\""
	Execute cmdstr
	cmdstr="Textbox/F=0/A=LT \""+analysis_name[analysis_number]+"\""
	Execute cmdstr
	Textbox/C/N=text0/X=2.00/Y=-3.00
End
	
Function/S yaxislabel(analtype, analmode)
	string analtype
	variable analmode				// 1 = voltage, 2 = current
	
		
	if ((cmpstr(analtype,"AMPL")==0)	%| (cmpstr(analtype,"SUB")==0)  %| (cmpstr(analtype,"IHOLD")==0)  %| (cmpstr(analtype, "EPSPPK")==0) )	
		if (analmode == 1)
			return "mV"					// These are all the straight amplitude measurements
		endif
		if (analmode == 2)
			return "pA"
		endif			
	endif
	if (cmpstr(analtype,"DIV")==0)			// no units for DIV
		return ""
	endif
	if (cmpstr(analtype,"SLOPE")==0)
		if (analmode == 1)
			return "mV/msec"
		endif
		if (analmode == 2)
			return "pA/msec"
		endif				
	endif
	if (cmpstr(analtype,"RSERIES")==0)
		return "Mohm"			
	endif
	if (cmpstr(analtype,"RINPUT")==0)
		return "Mohm"			
	endif	
	if (cmpstr(analtype,"TIMEOFAPPK")==0)
		return "AP latency (ms)"
	endif
	if (cmpstr(analtype,"FIELDPK")==0)
	  	return "mV"
	endif
	if (cmpstr(analtype,"TIMEOFNEGPK")==0)
		return ("sec")
	endif
	if (cmpstr(analtype,"LATENCY")==0)
		return ("sec")
	endif
	
End

Function SetUpAnalysisWindows()			// set up windows for each active analysis
	Wave analysis_display = analysis_display
	NVAR number_of_analyses = number_of_analyses
	
	variable i1
	
	i1 = 0
	do
		if (analysis_display[i1]>=1)					// note:  no access window, just analysis windows
			Make_Analysis_Window(i1)
		endif
		i1 += 1
	while (i1 < number_of_analyses)
End

		
Function Bring_Analysis_To_Front(analnumber)
	variable analnumber
	
	Wave analysis_display = analysis_display
	
	string cmdstr

	if (analysis_display[analnumber]==1)	
		cmdstr = "DoWindow/F analysis_window"+num2str(analnumber)
		execute cmdstr
	endif

End

Function Adjust_Time_Axis()				// This allows user to set the time range for all analysis windows
										// at once, so it doesn't have to be done by hand for each window.
	
	NewPanel/W=(510,90,640,243) as "Analysis Time Axis"
	DoWindow/C Time_Window
	
	DrawText 16,21,"Time axis bounds"	
	SetVariable setvar_left size={85,20}, noproc, pos={20,30}, title="Left", value=left_value, fsize =10
	SetVariable setvar_right size={85,20}, noproc, pos={20,60}, title="Right", value=right_value, fsize =10
	Button bCalc_Time, pos = {20,90}, size ={88,20}, proc=bCalc_Time_Axis, title = "Set Full Scale"
	Button bOK_TIME, pos={35,120},size={60,20},proc=bSet_Time_Axis,title="OK"
	
End

Function bCalc_Time_Axis(dummy)		// This procedure calculates left and right values of time axis to equal full scale for the anal. sweep range.
	string dummy
	
	Wave sweeptimes = sweeptimes
	NVAR firstanalsweep = firstanalsweep
	NVAR lastanalsweep = lastanalsweep
	NVAR left_value = left_value
	NVAR right_value = right_value
	
	// calculate time in minutes associated with first and last analysis sweep.
	left_value = floor(sweeptimes[0])
	right_value = floor(sweeptimes[lastanalsweep-firstanalsweep]+1)
	
	// now hit OK button so user doesn't have to.
	bSet_Time_Axis("")
	
End

Function bSet_Time_Axis(dummy)			// This procedure called when user hits OK button on Time_Window
	string dummy
	
	String cmdstr1, cmdstr2
	Wave analysis_on = analysis_on
	Wave analysis_display = analysis_display
	NVAR number_of_analyses = number_of_analyses
	NVAR right_value = right_value
	NVAR left_value = left_value
	
	variable i1=0
	
	DoWindow/K Time_Window

	cmdstr1 = "SetAxis/E=0 bottom, "+num2str(left_value)+", "+num2str(right_value)
	
	do
		if ((analysis_on[i1]==1) %& (analysis_display[i1]>=1))
			cmdstr2="DoWindow/F analysis_window"+num2str(i1)
			execute cmdstr2
			execute cmdstr1
		endif
		i1 += 1
	while (i1 < number_of_analyses)
									
End

Function Make_Stim_Protocol_Graph()
	// This function takes displays average_0, average_1, and average_2, and displays them in a 
	// stereotyped format.  It is useful for summarizing the stimulus protocol (baseline, pairing, test)
	// used in a particular experiment.  The resulting window is named "Stim_Protocol_Window"
	
	if (WinType("Stim_Protocol_Window")==0)
		// graph doesn't exist
		Execute "duplicate/o average_0 bline"
		Execute "bline += 60"
		Execute "duplicate/o average_1 pairing"
		Execute "duplicate/o average_2 post"
		Execute "post -= 60"
		Display/W=(3,100,170,300) bline, pairing, post
		DoWindow/C Stim_Protocol_Window
		ModifyGraph fSize=7
		ModifyGraph tick=2, btlen=2, lblMargin =1, fsize=8																			
		ModifyGraph margin(top)=10, margin(right)=10						
		ModifyGraph margin(left)=20, tloffset(left) = 2	
		SetAxis/E=0 bottom, 0, 0.6
		SetAxis/E=0 left -80,160
		ModifyGraph rgb=(0,0,0)
		Textbox/N=text0/F=0/A=MT "\\Z08 Stimulation Protocol"
		Textbox/N=text1/F=0/A=MC "\\Z07 Baseline"
		Textbox/N=text2/F=0/A=RC "\\Z07 Pairing"
		Textbox/N=text3/F=0/A=MB "\\Z07 Post"
	else
		Execute "bline = average_0 + 60"
		Execute "pairing = average_1"
		Execute "post = average_2 - 60"
	endif
	
End

//----------------------------------------------- Routines to Place Marks on Analysis Windows --------------------------------------//


Function Make_Mark()
	// This is a first-pass attempt.
	
	Wave Mark_exists = mark_exists				// 0/1 denoting if a mark exists already
	Wave MarkSweep = MarkSweep				// sweep numbers associated with the marks
	NVAR Mark0Sweep = Mark0Sweep
	NVAR Mark1Sweep = Mark1Sweep
	NVAR Mark2Sweep = Mark2Sweep
	NVAR Mark3Sweep = Mark3Sweep
	NVAR Mark4Sweep = Mark4Sweep
	
	NewPanel/W=(510,90,680,238) as "Marks"
	DoWindow/C Mark_Window
	
	Checkbox Mark0, pos={20,15}, size={30,15}, title = "0", value = mark_exists[0], proc = Mark_checked
	Checkbox Mark1, pos={20,35}, size={30,15}, title = "1", value = mark_exists[1], proc = Mark_checked
	Checkbox Mark2, pos={20,55}, size={30,15}, title = "2", value = mark_exists[2], proc = Mark_checked
	Checkbox Mark3, pos={20,75}, size={30,15}, title = "3", value = mark_exists[3], proc = Mark_checked
	Checkbox Mark4, pos={20,95}, size={30,15}, title = "4", value = mark_exists[4], proc = Mark_checked
	
	Mark0Sweep = MarkSweep[0]				// again, setvar won't accept object that is subscripted, so I am
	Mark1Sweep = MarkSweep[1]				// forced to use a kludge.
	Mark2Sweep = MarkSweep[2]
	Mark3Sweep = MarkSweep[3]
	Mark4Sweep = MarkSweep[4]
	
	if (mark_exists[0])
		Setvariable MarkSweep0, pos ={55,14}, size = {80,10}, fsize = 9, value=Mark0Sweep, proc=SetMarkSweep, title=" "
	endif
	if (mark_exists[1])
		Setvariable MarkSweep1, pos ={55,34}, size = {80,10}, fsize = 9, value=Mark1Sweep, proc=SetMarkSweep, title=" "
	endif
	if (mark_exists[2])
		Setvariable MarkSweep2, pos ={55,54}, size = {80,10}, fsize = 9, value=Mark2Sweep, proc=SetMarkSweep, title = " "
	endif
	if (mark_exists[3])
		Setvariable MarkSweep3, pos ={55,74}, size = {80,10}, fsize = 9, value=Mark3Sweep, proc=SetMarkSweep, title = " "
	endif
	if (mark_exists[4])
		Setvariable MarkSweep4, pos ={55,94}, size = {80,10}, fsize = 9, value=Mark4Sweep, proc=SetMarkSweep, title = " "
	endif

	Button bMarkOK, pos={15,120},size={60,20},title="OK", proc=bMarkOKProc
End

Function Mark_Checked(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	
	// This procedure is called whenever the user checks or unchecks a box to select a mark.
	
	Variable mark_number = str2num(ctrlName[4])
	
	// update the average_exists variable 
	Wave mark_exists = mark_exists
	
	mark_exists[mark_number] = checked
	
	Redraw_All_Marks()
	
	// now redraw the Make_Avg_Window so that the range box will be added or deleted according to the checkbox.
	DoWindow/K Mark_Window
	Make_Mark()
	
End		// mark_checked()

Function SetMarkSweep(ctrlName, varNum, varStr, varName)			// this is called whenever user sets a sweep number
	String ctrlName												// for a mark
	Variable varNum
	String varStr
	String varName									// in future, allow alternative entry of either times or sweep numbers
	
	Wave MarkSweep = MarkSweep
	
	// determine which average number was adjusted
	
	Variable mark_number = str2num(ctrlName[9])
		
	MarkSweep[mark_number] = varNum				// set the result into the correct wave
	
	//print "Mark #", mark_number, " Sweep ", MarkSweep[mark_number]
		
	// Draw or redraw the mark at this sweep number on all current analysis windows.  In the future, allow user
	// to have set a toggle saying whether this should be done in all analysis windows
	// or in a particular window.
	
	Redraw_All_Marks()
	
End

Function Redraw_All_Marks()

	Wave analysis_on = analysis_on
	Wave analysis_display = analysis_display
	Wave sweeptimes = sweeptimes
	Wave MarkSweep = MarkSweep
	NVAR firstanalsweep = firstanalsweep
	Wave mark_exists = mark_exists
	NVAR number_of_analyses = number_of_analyses
	
	Variable w1, mark
	
	// erase and redraw all marks
	
		w1 = 0
		do
		if ((analysis_on[w1]==1) %& (analysis_display[w1]==1))
			Bring_Analysis_To_Front(w1)
			SetDrawLayer/K ProgFront				// erase old marks
			SetDrawLayer ProgFront	
	
			mark = 0							// draw in each mark that exists
			do
				if (mark_exists[mark]==1)
					SetDrawEnv xcoord = bottom, ycoord = prel
					DrawLine sweeptimes[MarkSweep[mark]-firstanalsweep], 1, sweeptimes[MarkSweep[mark]-firstanalsweep], 0
					//print "draw called"
				endif
				mark += 1
			while (mark < 5)
		endif
		w1 += 1
		while (w1 < number_of_analyses)
	
End

Function bMarkOKProc(dummy)
	string dummy
	
	// This procedure called when user is done creating/modifying marks
	
	DoWindow/K Mark_Window
	
End

Function Edit_Mark()

	Make_Mark()					// This should accomplish the same purpose.
End

Function Delete_Marks()				// called from Menu

	Make_Mark()
	// add an additional button, "Delete All"
	
	DoWindow/F Mark_Window
	Button bDeleteAll, pos={85,120},size={70,20},title="Delete All", proc=Delete_All_Marks
End

Function Delete_All_Marks(dummy)
	string dummy
	
	Delete_Mark(-1)
	DoWindow/K Mark_Window
	Make_Mark()
	
End

	
Function Delete_Mark(number)
	variable number								// delete the specified mark.  If mark_number = -1, delete them all.

	Wave mark_exists = mark_exists
	Variable i1
	
	if (number > -1)
		mark_exists[number] = 0
	else
		i1 = 0
		do
			mark_exists[i1]=0
			i1 += 1
		while (i1 < 5)
	endif
	
	Redraw_All_Marks()
	
End

//---------------------------------------------- Routines to Calculate and Display Amplifier Command Waves -----------------------------//

Function Display_Command_Waves()

	Wave channel_mode = channel_mode
	
	Make_Command_Waves()			// calculate amplifier output command wave
	if (WinType("Ampl_Command_Waveform") == 0 )		// if window doesn't currently exist, make it
		Edit_Command_Wave(0)			// purpose is to allow user to adjust amp & duration of positive current injection to get one spike.
	endif

End

Function Make_Command_Waves()
	
	// This function will calculate the command output waves from user-entered parameters supplied previously.
	
	Wave CommandWaveOut = CommandWaveOut
	Wave command_pulse_flag = command_pulse_flag						// flag indicating whether each of 5 possible output elements (pulses) in command wave is on
	Wave command_pulse_value = command_pulse_value					// magnitude of command pulse
	Wave command_pulse_start = command_pulse_start						// time (in ms) from sweep onset to start each command pulse
	Wave command_pulse_duration= command_pulse_duration				// duration (in ms) of each command pulse
	NVAR no_samples = no_samples
	NVAR kHz = kHz
	string outstr
	variable i1, pulse_number, scale, chan
	NVAR sweep_mode = sweep_mode
	
	// This ensures that length & scaling match that of other output waves -- necessary for DAC to work.
	Redimension/N=(no_samples) CommandWaveOut
	setscale /p x, 0, 0.001/kHz, "sec", CommandWaveOut

	// start with 0 values
	CommandWaveOut = (command_pulse_flag[5] * command_pulse_value[5])			// DC/continuous current injection
	
	// Calculate the CommandWave
	pulse_number = 0			// now add all pulses, iteratively.	
	do
		if (command_pulse_flag[pulse_number] == 1)
			i1 = (command_pulse_start[pulse_number] * kHz)		// point number corresponding to start time in ms
			do
				CommandWaveOut[i1] += (command_pulse_value[pulse_number])		// add this pulse onto existing pulses in command wave
				i1 += 1
			while (i1 < ((command_pulse_start[pulse_number] + command_pulse_duration[pulse_number]) * kHz))		// point number corresponding to start+duration in ms
		endif
		pulse_number += 1
	while (pulse_number < 5)
	if (command_pulse_flag[5] * command_pulse_value[5] == 0)
		CommandWaveOut[no_samples-1] = 0				// if no DC/continuous output is desired, final point must be zero
	endif	
End
	
Function Edit_Command_Wave(chan)
	variable chan			// which channel's command wave to display
	// This function will allow user to set flag, value, start & duration of each pulse, as well as Iclamp scale factor and Vclampscale factor.

	Wave CommandWaveOut = CommandWaveOut
	NVAR sweep_mode
	string cmdstr
	
	// CommandWaveOut0
	Display/W=(360,460,760,560) CommandWaveOut				// graphical display of output wave
	DoWindow/C CommandOut	
	label left, "Buffer output value"
	string labelstr = "Step ("
	if (sweep_mode == 1)		// current clamp
		labelstr += "pA)"
	else
		labelstr += "mV)"
	endif
	
	Button bCloseAmlCmdWindow, pos = {350, 7}, size={60, 20}, fsize=10, title = "Close", proc=bCloseAmplCommandProc
	Make_Command_Pulse_Table(0)
	
End

Function Make_Command_Pulse_Table(channel)
	variable channel	
	
	NVAR sweep_mode = sweep_mode
	
	Edit/W=(765,460,950,560)  command_pulse_flag, command_pulse_value, command_pulse_start, command_pulse_duration
	DoWindow/C CommandPulseTable
	execute "ModifyTable size=9,width=45, width(command_pulse_flag)=20, width(Point)=20"
	execute "ModifyTable title(Point)=\"#\""
	execute "ModifyTable title(command_pulse_flag)=\"ON?\""
	if (sweep_mode == 1)		// current clamp
		execute "ModifyTable title(command_pulse_value)=\"pA\""
	endif
	if (sweep_mode ==2)		// voltage clamp
		execute "ModifyTable title(command_pulse_value)=\"mV\""
	endif
	execute "ModifyTable title(command_pulse_start)=\"Onset\""
	execute "ModifyTable title(command_pulse_duration)=\"Duration\""
		
End


Function bCloseAmplCommandProc(ctrlName)
	string ctrlName
	
	DoWindow/K CommandOut
	DoWindow/K CommandPulseTable
	
End

//----------------------------------------------------------- Data Analysis Routines -------------------------------------------------------------//


Function Run_Analysis()

	// Get rid of any old analyses
	Reset_Analyses()
	
	// Prompt user for beginning and end sweeps
	NewPanel/W=(300,125,455,250) as "Sweep Range"
	DoWindow/C Sweep_Range_Window
	
	// Allow user to change the sweep range //
	SetVariable setvarFirst title="First sweep", pos={20,10}, size={110,30}, limits={0,5000,1}, fsize=9, value=firstanalsweep, noproc
	SetVariable setvarLast title="Last sweep", pos={20,45}, size={110,30}, limits={0,5000,1}, fsize=9, value=lastanalsweep, noproc
	Button bRunAnalysisOK pos={10,80}, size = {60,30}, title = "OK", fsize = 10, proc = bRunAnalysisOKProc
	Button bCANCEL5 pos={80, 80}, size = {60,30}, title= "CANCEL", fsize = 10, proc=bCANCEL5Proc
	
End

Function Reset_Analyses()
	NVAR sweepnumber = sweepnumber
	NVAR number_of_analyses = number_of_analyses
	string cmdstr
	variable i1=0
	
	do
		cmdstr="Redimension/N=0 analysis"+num2str(i1)
		execute cmdstr
		i1 += 1
	while (i1 < number_of_analyses)

	sweepnumber = 0
	
End

Function bRunAnalysisOKProc(dummy)
	string dummy
	
	NVAR firstanalsweep = firstanalsweep
	NVAR lastanalsweep = lastanalsweep
	Variable i1
	SVAR Expt = Expt
	NVAR sweepnumber = sweepnumber
	NVAR disk_sweep_time = disk_sweep_time
	
	NVAR temperature = temperature					// to also display temperature (Ken Burke, 4/14/2015)
	Wave temperature_wave = temperature_wave
	
	// Erase sweep range window
	DoWindow/K Sweep_Range_Window
	
	if (firstanalsweep > lastanalsweep)
		DoAlert 0, "Invalid sweep range."
		Return 0
	endif
	
	// Read through the sweeps, calling analysis_master with each one
	
	sweepnumber = 0
	
	i1 = firstanalsweep
	Find_Sweep(i1,Expt)
	Read_Sweep(Expt)
	
	Analysis_Master()
	
	sweepnumber += 1
	
	if (lastanalsweep > firstanalsweep)
		Redimension/N=0 temperature_wave
		do
			i1 += 1
			Find_Next_Sweep(Expt)
			Read_Sweep(Expt)
			Analysis_Master()

			InsertPoints numpnts(temperature_wave), 1, temperature_wave
			temperature_wave[numpnts(temperature_wave)] = temperature

			sweepnumber += 1
		while (i1 < lastanalsweep)
	endif
	
	// set time axis on analysis graphs to full scale
	bCalc_Time_Axis("")
	
End

Function bCANCEL5Proc(dummy) : buttoncontrol				// user wants to cancel average changes
	string dummy

	// Erase avg_window
	DoWindow/K Sweep_Range_Window
	
End


Function Analysis_Master()			// This function should be called after reading a sweep, to perform all required analyses
						 			// on that sweep and update the analysis windows.
	
	Wave analysis_on = analysis_on
	Variable a1=0
	NVAR number_of_analyses=number_of_analyses

	// call the appropriate analysis routines.  Do this more intelligently in the future //
	do
		if (analysis_on[a1] == 1)
			Perform_Analysis(a1)
		endif
		a1 += 1
	while (a1 < number_of_analyses)
	
End

Function Perform_Analysis (analysisnumber)			
	Variable analysisnumber
	NVAR sweepnumber = sweepnumber
	Wave sweeptimes = sweeptimes
	Wave display_wave1 = display_wave1
	Wave/T analysis_type = analysis_type
	SVAR Expt = Expt
	Wave analysis_cursor0 = analysis_cursor0
	Wave analysis_cursor1 = analysis_cursor1
	NVAR Stepsize = stepsize					
	NVAR disk_sweep_time = disk_sweep_time
		
	string cmdstr
	variable min1, max1, sample, endpt, minposn, maxposn, maxrange, minrange
	variable cpnt, direction, finished					// for latency calc.
	
	Insertpoints (sweepnumber +1), 1, sweeptimes
	sweeptimes[sweepnumber] = (disk_sweep_time)/60			// cast into absolute experiment minutes

	string sourcewave = "display_wave1"			// UNIQUE FOR ANAL -- ONLY PATH0, NO PATH1
	string resultswave = "analysis"+num2str(analysisnumber)
	
	// ABSOLUTE AMPLITUDE OR HOLDING CURRENT (same calculation)
	if ((cmpstr(analysis_type[analysisnumber],"AMPL") == 0)	%| (cmpstr(analysis_type[analysisnumber],"IHOLD")==0) )			
		NVAR DCoffset = DCoffset
		NVAR gZERO=gZERO
		InsertPoints (sweepnumber + 1), 1, $resultswave
		cmdstr=resultswave+"["+num2str(sweepnumber)+"]=mean("+sourcewave+",analysis_cursor0["+num2str(analysisnumber)+"], analysis_cursor1["+num2str(analysisnumber)+"])"
		if (gZERO==1)
			cmdstr+="+ DCoffset"
		endif
			Execute cmdstr
		// Save $resultswave if desired
	endif


	//  INPUT RESISTANCE  Compute as net amplitude of late window re msec 0-2 of trace.  Calculate for step size used.
	// again, assume path 0!!!!   Special note:  For voltage clamp experiments, Rin=Vcommand/(Iwindow-Ihold).  
	//  For current clamp experiments, Rin=1 / (Vwindow-Vhold) / Icommand
	
	if (cmpstr(analysis_type[analysisnumber],"RINPUT") == 0)		 		
		NVAR sweep_mode = sweep_mode			// 0 = OFF;  1 = CURRENT CLAMP;  2 = VOLTAGE CLAMP
		Wave path_mode = path_mode
		variable temp1, temp2
			
		InsertPoints (sweepnumber+ 1), 1, $resultswave
		
		temp1 = mean(display_wave1,analysis_cursor0[analysisnumber], analysis_cursor1[analysisnumber])
		temp2 = mean(display_wave1,0,.002)		// ie, the baseline I or V
		temp1 -= temp2							// subtract off baseline
		if (sweep_mode == -1)		// classic file, mode was not stored for each sweep
			sweep_mode = path_mode[0]		// use the whole-file mode set by user at file load.
		endif
		if (sweep_mode == 1)		// this is a current clamp recording
			cmdstr=resultswave+"["+num2str(sweepnumber)+"] = 1000 * "+num2str(temp1) +"/"+ num2str(Stepsize)
		endif
		if (sweep_mode == 2)		// this is a voltage clamp recording
			cmdstr=resultswave+"["+num2str(sweepnumber)+"] = 1000 * "+num2str(Stepsize)+"/"+num2str(temp1)
		endif
		execute cmdstr
		// Save if desired
	endif
	
	// PK to PK amplitude or RSERIES (similar calculations)
	if ((cmpstr(analysis_type[analysisnumber],"PKTOPK") == 0)	%| (cmpstr(analysis_type[analysisnumber],"RSERIES") == 0)	)
		
		Duplicate $sourcewave, tempwave
		Sample = x2pnt(tempwave,analysis_cursor0[analysisnumber])
		min1 = tempwave[sample]
		max1 = min1
		endpt = x2pnt(tempwave, analysis_cursor1[analysisnumber])
		Do
			if (tempwave[sample] < min1)
				min1 = tempwave[sample]
			endif
			if (tempwave[sample] > max1)
				max1 = tempwave[sample]
			endif
			sample += 1
		while (sample <= endpt)

		InsertPoints (sweepnumber + 1), 1, $resultswave
		if (cmpstr(analysis_type[analysisnumber],"PKTOPK")==0)				// for peak to peak 
			cmdstr=resultswave+"["+num2str(sweepnumber)+"]="+num2str((min1-max1))
		else																// for Rseries calc based on stepsize
			cmdstr = resultswave+"["+num2str(sweepnumber)+"] = abs("+num2str(Stepsize)+") / ("+num2str(max1)+"-"+num2str(min1)+") * 1000"
			// This calculation is valid only for V clamp mode, but that's the only mode where we measure Rseries.
		endif
		Execute cmdstr
		
		Killwaves tempwave
		
		// Save $resultswave if desired
	endif
	
	// SUBTRACT TWO CHANNELS //
	if (cmpstr(analysis_type[analysisnumber],"SUB") == 0)		// subtract two analyses.  NOTE these anals MUST BE
															// LOWER in the analysis list!!!!
		// the convention is, result = ANAL0 - ANAL1, where
		// ANAL0 = analysisnumber in analysis_cursor0 entry
		// ANAL1 = analysisnumber in analysis_cursor1 entry
	
		InsertPoints (sweepnumber+1), 1, $resultswave
		cmdstr=resultswave+"["+num2str(sweepnumber)+"]=analysis"+num2str(analysis_cursor0[analysisnumber])+"["+num2str(sweepnumber)+"] - analysis"+num2str(analysis_cursor1[analysisnumber])+"["+num2str(sweepnumber)+"]"
		execute cmdstr
	
	endif
	
		// DIVIDE TWO CHANNELS //
	if (cmpstr(analysis_type[analysisnumber],"DIV") == 0)		// subtract two analyses.  NOTE these anals MUST BE
														// LOWER in the analysis list!!!!
		// the convention is, result = ANAL1 / ANAL0, where
		// ANAL0 = analysisnumber in analysis_cursor0 entry
		// ANAL1 = analysisnumber in analysis_cursor1 entry
	
		InsertPoints (sweepnumber+1), 1, $resultswave
		cmdstr=resultswave+"["+num2str(sweepnumber)+"]=analysis"+num2str(analysis_cursor1[analysisnumber])+"["+num2str(sweepnumber)+"] / analysis"+num2str(analysis_cursor0[analysisnumber])+"["+num2str(sweepnumber)+"]"
		execute cmdstr
	
	endif

	
	// SLOPE //
	if (cmpstr(analysis_type[analysisnumber],"SLOPE") == 0)		
		
		InsertPoints (sweepnumber+1), 1, $resultswave
		// do the calc here.
		cmdstr = "Curvefit/Q line, "+sourcewave+"("+num2str(analysis_cursor0[analysisnumber])+","+num2str(analysis_cursor1[analysisnumber])+")"
		execute cmdstr
		cmdstr = resultswave+"["+num2str(sweepnumber)+"] = W_Coef[1]/1000"			// convert sec to msec
		execute cmdstr
	endif
	
	// TIME OF ACTION POTENTIAL PEAK //
	// This routine calculates the time of occurrance of the peak of the AP, within the analysis window specified.
	// The returned value is ms from the start of the sweep.
	// Note that the max voltage value is detected without checking that it was actually an AP!!!!!  (could solve this with
	// a user-supplied minimum threshold for AP detection in a future version).
	
	if (cmpstr(analysis_type[analysisnumber],"TIMEOFAPPK")==0)
		InsertPoints (sweepnumber+1), 1, $resultswave
		WaveStats/Q/R=(analysis_cursor0[analysisnumber],analysis_cursor1[analysisnumber]) $sourcewave	// find max between the cursors
		cmdstr = resultswave+"["+num2str(sweepnumber)+"] = "+num2str(V_maxloc)+" * 1000"							// location of ymax --convert to msec
		execute cmdstr
	endif
	
	// FIELD POTENTIAL PEAK //
	//  This routine calculates maximal (negative) field amplitude, within the analysis window specified.  It can be used 
	//  when peak latency may shift slightly--a condition in which a fixed amplitude window would confound latency and amplitude.
	//  The mean value of 5 consecutive sample points centered on the maximal amplitude is returned.
	//  Note that this routine does not subtract baseline amplitude;  therefore it assumes fields are recorded AC coupled.
	
	if (cmpstr(analysis_type[analysisnumber],"FIELDPK")==0)
		InsertPoints (sweepnumber+1), 1, $resultswave
		WaveStats/Q/R=(analysis_cursor0[analysisnumber],analysis_cursor1[analysisnumber]) $sourcewave	// find min between the cursors
		minposn = x2pnt($sourcewave,V_minloc)
		WaveStats/Q/R=[minposn-17,minposn+17] $sourcewave							// Calculate mean of 35 pts around minimum
		cmdstr = resultswave+"["+num2str(sweepnumber)+"] = "+num2str(V_avg)							
		execute cmdstr
	endif
	
	// PEAK OF A POSITIVE-GOING EPSP //
	//  This routine calculates maximal (positive) potential amplitude occurring anywhere within the defined analysis window.
	
	if (cmpstr(analysis_type[analysisnumber],"EPSPPK")==0)
		InsertPoints (sweepnumber +1), 1, $resultswave
		WaveStats/Q/R=(analysis_cursor0[analysisnumber],analysis_cursor1[analysisnumber]) $sourcewave	// find max between the cursors
		maxposn = x2pnt($sourcewave,V_maxloc)
		WaveStats/Q/R=[maxposn-17,maxposn+17] $sourcewave							// Calculate mean of 35 pts around minimum
		cmdstr = resultswave+"["+num2str(sweepnumber)+"] = "+num2str(V_avg)
		execute cmdstr
	endif
	
	// TIME OF NEGATIVE-GOING FIELD PK
	//  This routine calculates time of field peak within the defined analysis window
	if (cmpstr(analysis_type[analysisnumber],"TIMEOFNEGPK")==0)
		InsertPoints (sweepnumber +1), 1, $resultswave
		WaveStats/Q/R=(analysis_cursor0[analysisnumber],analysis_cursor1[analysisnumber]) $sourcewave	// find min between the cursors
		cmdstr = resultswave+"["+num2str(sweepnumber)+"] = "+num2str(V_minloc)
		execute cmdstr
	endif
	
	// LATENCY
	// This routine calculates latency of either a positive-going or a negative-going waveform.  ** The analysis window must be
	// broad, so that there is at least 4 ms of baseline within the window, before the suspected latency.
	//  The routine will calculate mean +/- s.d. of "noise" within the first 2 ms of the window.  it will then report the time (x-position)
	//  of the first of two consecutive points that are greater than (mean+ 2 * s.d) or are less than (mean - 2*s.d.)
	if (cmpstr(analysis_type[analysisnumber],"LATENCY")==0)
		InsertPoints (sweepnumber +1), 1, $resultswave
		WaveStats/Q/R=(analysis_cursor0[analysisnumber],analysis_cursor0[analysisnumber]+.002) $sourcewave	// find stats of bline epoch
		maxrange = V_avg + 2* V_sdev
		minrange = V_avg - 2* V_sdev
		cpnt = x2pnt($sourcewave, analysis_cursor0[analysisnumber])
		direction = 0
		finished = 0
			do
				if (display_wave1[cpnt] > maxrange)
					if (direction == 1)
						finished = 1
					else
						direction = 1				// this potential is positive-going
					endif
				endif
				if (display_wave1[cpnt] < minrange)
					if (direction == -1)
						finished = 1
					else
						direction = -1				// this potential is negative-going
					endif
				endif
				if ((display_wave1[cpnt] >= minrange) %& (display_wave1[cpnt] <= maxrange))
					direction = 0
				endif
				print "cpnt = ", cpnt, "val: ", display_wave1[cpnt], "maxrange = ", maxrange, "minrange = ", minrange, "direction = ", direction
				cpnt += 1
			while ((finished == 0) %| (cpnt < analysis_cursor1[analysisnumber]))
			print "exited loop.  finished = ", finished, "direction = ", direction, " cpnt = ", cpnt 
		if (finished == 0)
			cmdstr = resultswave+"["+num2str(sweepnumber)+"] = 0.0"			// Use 0.0 to signal no latency detected.
		 	execute cmdstr
		else
			cmdstr = resultswave+"["+num2str(sweepnumber)+"] = "+num2str(pnt2x($sourcewave, cpnt-2))			// Use 0.0 to signal no latency detected.
		 	execute cmdstr
		 	print "latency = ", pnt2x($sourcewave, cpnt-2)
		 endif
	endif
	// save sweeptimes if desired
	// Save/o/p=savepath sweeptimes as Expt+"times.ibw"
	
End

//-----------------------------------------------------  NEW Crunch Routines  ----------------------------------------------------------//
//
//    These routines will SAVE analysis waves to disk for later crunch analysis.
//

Function SetUpWavesToSaveForCrunch()

	NVAR crunch_bline_start = crunch_bline_start
	NVAR crunch_post_end = crunch_post_end
	NVAR firstanalsweep = firstanalsweep
	NVAR lastanalsweep = lastanalsweep
	
	Edit/W=(120, 225, 440, 400) sourcewavename, diskwavename
	DoWindow/C Crunch_Save_Table
	ModifyTable width(Point)=20
	ModifyTable width(sourcewavename)=131
	ModifyTable width(diskwavename)=131
	
	NewPanel/W = (600, 300, 900, 500) as "Crunch Save Dialog"
	DoWindow/C Crunch_Save_Dialog
	
	crunch_bline_start = firstanalsweep
	crunch_post_end = lastanalsweep
	
	DrawText 10, 25, "Enter full path to disk folder to write crunch waves."
	SetVariable sv_crunchpath pos={10, 30}, size={250,30}, title="Save Path", value=crunchpathstring, fsize=10
	DrawText 10,80,"Baseline period"	
	SetVariable sv_BlineStart pos={10, 85}, size={120,25}, title="Start sweep", value=crunch_bline_start, fsize=10, noedit =1	
	SetVariable sv_BlineEnd pos={10, 110}, size={120,25}, title="End sweep", value=crunch_bline_end, fsize=10	
	DrawText 150,80,"Post period"	
	SetVariable sv_PostStart pos={150, 85}, size={120,25}, title="Start sweep", value=crunch_post_start, fsize=10	
	SetVariable sv_PostEnd pos={150, 110}, size={120,25}, title="End sweep", value=crunch_post_end, fsize=10	
	Button bSaveWavesForCrunch, pos = {70, 150}, size = {80, 30}, title = "Save sweeps", proc = bSaveWavesForCrunchProc
	Button bCloseSaveCrunch, pos = {170, 150}, size = {60, 30}, title = "Close", proc = bSaveWavesForCrunchProc 
	// needs "Close" button  //DFDF3
	
End

Function bSaveWavesForCrunchProc(ctrlName)
	string ctrlName
	
	// Called when user hits button to save analysis waves for crunch.
	
	Wave/T sourcewavename = sourcewavename
	Wave/T diskwavename = diskwavename
	NVAR crunch_bline_start = crunch_bline_start
	NVAR crunch_bline_end = crunch_bline_end
	NVAR crunch_post_start = crunch_post_start
	NVAR crunch_post_end = crunch_post_end
	
	if (cmpstr(ctrlName, "bSaveWavesForCrunch")==0)
		SaveAnalysisWavesForCrunch(sourcewavename, diskwavename, crunch_bline_start, crunch_bline_end, crunch_post_start, crunch_post_end)
	endif
	if (cmpstr(ctrlName, "bCloseSaveCrunch")==0)
		DoWindow/K Crunch_Save_Dialog
		DoWindow/K Crunch_Save_Table
	endif
End

Function SaveAnalysisWavesForCrunch(sourcewavename, diskwavename, first_sweep_in_anal_wave, end_bline, start_post, end_post)
	Wave/T sourcewavename			// name of existing analysis wave to split into Bline and Post portions and save to disk
	Wave/T diskwavename			// name to use when saving analysis waves to disk
	variable first_sweep_in_anal_wave	// first sweep analyzed, this is the sweepnumber corresponding to point 0 in analysis wave
	variable end_bline					// sweepnumber that is end of baseline period
	variable start_post				// sweepnumber that is start of postpairing period
	variable end_post					// sweepnumber that is end of postpairing period
	
	SVAR crunchpathstring = crunchpathstring
	
	variable num
	string savewaveblinename, savewavepostname, srcname, outstr
	
	variable numwaves = numpnts(sourcewavename)			// number of source waves to process

	num = 0				// for each wave in user list of wavenames to store
	do
	
		if (strlen(diskwavename[num])==0)
			print "Aborting crunch save because of invalid analysis name for entry ", num
			return 0
		endif
		savewaveblinename = diskwavename[num]+"Bline"
		savewavepostname = diskwavename[num] + "Post"
		srcname = sourcewavename[num]
		
		Wave sourcewave = $srcname						// get data from indicated source wave
	
		Make/O/N=(end_bline-first_sweep_in_anal_wave+1) tempbline		// note, for in vivo analysis program with n interleaved stimuli, N should = ((last-first)/n + 1)
		Make/O/N=(end_post - start_post+1) temppost					// note, for in vivo analysis program with n interleaved stimuli, N should = ((last-first)/n + 1)
	
		variable sourcept=0
		variable destpt = 0
	
		// write data into baseline wave
		do
			if (sourcewave[sourcept]>-9999)				// skip -9999 entries because in in vivo program, -9999 means inappropriate stimuli.
				tempbline[destpt] = sourcewave[sourcept]	// preserving this keeps this routine compatible with the in vivo whole cell analysis.
				destpt += 1
				sourcept += 1
			else		// entry was -9999
				sourcept += 1
			endif
		while (sourcept <= (end_bline - first_sweep_in_anal_wave))
		Reverse tempbline								// Store baseline waves in reverse order, with pt 0 being point immediately before post or pairing epoch.
	
		// write data into post wave
		sourcept = (start_post - first_sweep_in_anal_wave)
		destpt = 0
		do
			if (sourcewave[sourcept]>-9999)
				temppost[destpt] = sourcewave[sourcept]
				destpt += 1
				sourcept += 1
			else		// entry was -9999
				sourcept += 1
			endif
		while (sourcept <= (end_post - first_sweep_in_anal_wave))
	
		// copy into waves with desired disk names	
		outstr = "Duplicate/O tempbline "+savewaveblinename
		execute outstr
		outstr = "Duplicate/O temppost "+savewavepostname
		execute outstr
		
		// save baseline and post waves in disk files (these are igor binary .ibt files)
		outstr = "Save/C "+savewaveblinename+" as \""+crunchpathstring+":"+diskwavename[num]+"Bline\""			
		execute outstr
		outstr = "Save/C "+savewavepostname+" as \""+crunchpathstring+":"+diskwavename[num]+"Post\""			
		execute outstr
	
		killwaves tempbline, temppost
		killwaves $savewaveblinename
		killwaves $savewavepostname
		
		num += 1
		
	while (num < numwaves)
	
End



//-----------------------------------------------------  OLD Crunch Routines  ----------------------------------------------------------//
Function Make_Crunch_Dialog()

	NVAR crunch_type = crunch_type				// 0 = slope;  1 = netamp;  2= absamp
	NVAR crunch_no_files = crunch_no_files
	SVAR crunchfilenamestr = crunchfilenamestr
	NVAR crunch_normalize = crunch_normalize
	
	NewPanel/W=(200,125,500,295) as "Crunch Multiple Experiments"
	DoWindow/C Crunch_Dialog
		
	DrawText 90,30, "Default folder: D:\DATA\CRUNCH"
	Button bLoadCrunch pos={10,10}, size={50,25}, fsize=10, title="Load..", proc=bLoadSaveCrunchProc
	Button bSaveCrunch pos={10,40}, size={50,25}, fsize=10, title="Save..", proc=bLoadSaveCrunchProc
	Button bNewCrunch pos={70,40}, size={50,25}, fsize=10, title="New", proc=bNewCrunchProc
	Button bRunCrunch pos={150,135}, size={60,25}, fsize=10, title="Run Crunch", proc=bRunCrunchProc
	Button bCloseCrunch pos={220,135}, size={60,25}, fsize=10, title="Exit", proc=bCloseCrunchProc
	Button bAddCell pos={10,135}, size={60,25}, fsize=10, title="Add Cell", proc=bAddCellProc
	Button bCleanUpCrunch pos={80, 135}, size={60,25}, fsize=10, title="CleanUp", proc=bCleanUpCrunchProc
	
	Make_Crunch_Checkboxes()
	
	// in here count up number of cells in loaded crunch file and display prominently somewhere
	
End

Function Make_Crunch_Checkboxes()
	NVAR crunch_type = crunch_type
	NVAR crunch_normalize = crunch_normalize
	
	Checkbox slopebox, pos={50,75}, size={70,25}, title="Slope", value=(crunch_type == 0),proc=Crunchmarkchecked
	Checkbox netbox, pos={120, 75}, size={70,25}, title="Net Ampl.", value=(crunch_type == 1), proc=Crunchmarkchecked
	Checkbox absbox, pos={190,75},size={70,25},  title="Abs Ampl.", value=(crunch_type == 2), proc=Crunchmarkchecked
	Checkbox normalizebox, pos={20,105},size={150,25}, title="Normalize to Baseline", value=crunch_normalize,proc=Crunchmarkchecked
End


Function bNewCrunchProc(dummy)				// this routine sets up a new crunch
	string dummy
	
	NVAR crunch_no_files=crunch_no_files 
	Wave/T crunch_file=crunch_file
	Wave crunch_sweep0=crunch_sweep0			// sweep range start for crunch
	Wave crunch_sweep1=crunch_sweep1			// sweep range end for crunch
	Wave crunch_bline0=crunch_bline0				// sweep range start for baseline normalization
	Wave crunch_bline1=crunch_bline1				// sweep range end for baseline normalization
	Wave crunch_anal0=crunch_anal0				// sample number start for analysis window
	Wave crunch_anal1=crunch_anal1				// sample number end for analysis window
	Wave crunch_align=crunch_align				// sweep number to align sweeps between cells
	Wave crunch_binsize = crunch_binsize			// number of sweeps per crunch bin
	Wave crunch_included=crunch_included			// on-off 1-0 for including a cell in the crunch.  Not saved to disk.

	
	// Redimension all crunch variables to N=1 so user can enter first experiment.
	crunch_no_files = 1
	Redimension/N=1 crunch_file; crunch_file = ""
	Redimension/N=1 crunch_sweep0; crunch_sweep0 = 0
	Redimension/N=1 crunch_sweep1; crunch_sweep1 = 0
	Redimension/N=1 crunch_bline0; crunch_bline0 = 0
	Redimension/N=1 crunch_bline1; crunch_bline1 = 0
	Redimension/N=1 crunch_anal0; crunch_anal0 = 0
	Redimension/N=1 crunch_anal1; crunch_anal1 = 0
	Redimension/N=1 crunch_align; crunch_align = 0
	Redimension/N=1 crunch_binsize; crunch_binsize=10
	Redimension/N=1 crunch_included; crunch_included = 1
	
	// Put up a new Edit table so user can enter data
	if (WinType("Crunch_Table")==0)		// if Table does not already exist, create it
		Edit/W=(5,250, 500, 400) crunch_included, crunch_file, crunch_sweep0, crunch_sweep1, crunch_bline0, crunch_bline1, crunch_anal0, crunch_anal1, crunch_align, crunch_binsize as "Crunch Parameters"
		DoWindow/C Crunch_Table
		Execute "Arrange_Crunch_Table()"
	endif
End
	
Function bLoadSaveCrunchProc(ctrlname)			// this routine does both reading and writing of crunch files
	string ctrlname
	
	SVAR CrunchFilePath = CrunchFilePath		// from #include "CollectFileDefaults"
	SVAR CrunchFileNameStr = CrunchFileNameStr
	NVAR crunch_no_files=crunch_no_files
	
	Wave/T crunch_file=crunch_file
	Wave crunch_sweep0=crunch_sweep0			// sweep range start for crunch
	Wave crunch_sweep1=crunch_sweep1			// sweep range end for crunch
	Wave crunch_bline0=crunch_bline0				// sweep range start for baseline normalization
	Wave crunch_bline1=crunch_bline1				// sweep range end for baseline normalization
	Wave crunch_anal0=crunch_anal0				// sample number start for analysis window
	Wave crunch_anal1=crunch_anal1				// sample number end for analysis window
	Wave crunch_align=crunch_align				// sweep number to align sweeps between cells
	Wave crunch_binsize = crunch_binsize			// number of sweeps in each crunch time bin
	Wave crunch_included=crunch_included			// on-off 1-0 for including a cell in the crunch.  Not saved to disk.
	string cmdstr
	
	if (cmpstr(ctrlname, "bLoadCrunch")==0) 
		// Load in file of name CrunchFileNameStr and fill relavent variables.  Display in edit table.  Redimension waves properly (initial length 0)
		// Declare temporary input waves
		
		Make/T/N=25 inp0
		Make/N=25 inp1
		Make/N=25 inp2
		Make/N=25 inp3
		Make/N=25 inp4
		Make/N=25 inp5
		Make/N=25 inp6
		Make/N=25 inp7
		Make/N=25 inp8
		
		cmdstr = "NewPath/O/Q crunch \"" + CrunchFilePath + "\""		// Default file location specified in CollectFileDefaults.ipf
		Execute cmdstr
		Print "Preparing to load crunch file data."
		LoadWave/J/P=crunch/K=0/N=inp
		Print "Loading complete."
		
		// determine number of files
		crunch_no_files = 0;  variable end_detected = 0
		
		do
			if (cmpstr(inp0[crunch_no_files],"end")==0)
				end_detected = 1
			endif
			if (crunch_no_files > 25)
				end_detected = 1
				DoAlert 0, "There may have been a problem loading the crunch parameter file."
			endif
			crunch_no_files += 1
		while (!end_detected)
		
		crunch_no_files -= 1
		
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_file"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_sweep0"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_sweep1"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_bline0"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_bline1"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_anal0"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_anal1"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_align"
		Execute cmdstr
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_binsize"
		Execute cmdstr
		
		crunch_file = inp0;  crunch_sweep0=inp1;  crunch_sweep1=inp2; crunch_bline0=inp3; crunch_bline1=inp4
		crunch_anal0 = inp5; crunch_anal1 = inp6; crunch_align = inp7; crunch_binsize=inp8
		
		// assume everything that was saved was included.
		cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_included"
		Execute cmdstr
		crunch_included = 1	
		
		Killwaves inp0, inp1, inp2, inp3, inp4, inp5, inp6, inp7, inp8
		
		// Set up Edit Table to allow user to view what's been loaded
		if (WinType("Crunch_Table")==0)		// if Table does not already exist, create it
			Edit/W=(5,250, 500, 400) crunch_included, crunch_file, crunch_sweep0, crunch_sweep1, crunch_bline0, crunch_bline1, crunch_anal0, crunch_anal1, crunch_align, crunch_binsize as "Crunch Parameters"
			DoWindow/C Crunch_Table	
			Execute "Arrange_Crunch_Table()"		
		endif
	endif
	
	if (cmpstr(ctrlname, "bSaveCrunch")==0)
		// Save relavent variables as a file as CrunchFileNameStr
		
		cmdstr = "Make/T/N="+num2str(crunch_no_files+1)+" temp"
		Execute cmdstr
		cmdstr = "temp = crunch_file"
		Execute cmdstr
		cmdstr = "temp[crunch_no_files]=\"end\""
		Execute cmdstr
		Save/J/I/P=crunch temp, crunch_sweep0, crunch_sweep1, crunch_bline0, crunch_bline1, crunch_anal0, crunch_anal1, crunch_align, crunch_binsize as CrunchFileNameStr
		Print "Wrote crunch parameters to file", crunchfilenamestr
		
		cmdstr ="Killwaves temp"; Execute cmdstr
	endif
End

Function bAddCellProc(dummy)			// This function adds a new empty cell to a crunch list.  User fills it in on edit table.
	string dummy
	
	NVAR crunch_no_files = crunch_no_files
	string basestr, cmdstr
	
	crunch_no_files += 1
	
	basestr = "Redimension/N="+num2str(crunch_no_files)+" "
	cmdstr = basestr+"crunch_file"
	execute cmdstr
	cmdstr=basestr+"crunch_sweep0, crunch_sweep1, crunch_bline0, crunch_bline1, crunch_anal0, crunch_anal1, crunch_align, crunch_binsize, crunch_included"
	execute cmdstr
End

Function bRunCrunchProc(dummy)
	string dummy
	
	// This will actually calculate the crunch and display the results.  All crunch parameters should be in memory already.
	
	NVAR crunch_no_files=crunch_no_files
	
	Wave/T crunch_file=crunch_file
	Wave crunch_sweep0=crunch_sweep0			// sweep range start for crunch
	Wave crunch_sweep1=crunch_sweep1			// sweep range end for crunch
	Wave crunch_bline0=crunch_bline0				// sweep range start for baseline normalization
	Wave crunch_bline1=crunch_bline1				// sweep range end for baseline normalization
	Wave crunch_anal0=crunch_anal0				// sample number start for analysis window
	Wave crunch_anal1=crunch_anal1				// sample number end for analysis window
	Wave crunch_align=crunch_align				// sweep number to align sweeps between cells
	Wave crunch_binsize = crunch_binsize			// number of sweeps in each crunch time bin
	Wave crunch_included=crunch_included			// on-off 1-0 for including a cell in the crunch.  Not saved to disk.
	Wave crunch_align_offset = crunch_align_offset	// whole bin offset for aligning cells
	Wave crunch_align_firstn = crunch_align_firstn	// number of sweeps in first bin for alignment.
	Wave/D crunch_mean=crunch_mean
	Wave/D crunch_stdev=crunch_stdev
	Wave crunch_n=crunch_n
	NVAR max_crunch_bins = max_crunch_bins
	NVAR crunch_normalize = crunch_normalize
	NVAR crunch_zero_bin = crunch_zero_bin
	
	SVAR Expt = Expt							// for displaying which cell is being analyzed during crunch
	variable cell, sweep, bin, sweep_in_bin, val
	variable sumbaseline, nbaseline
	variable max_bins, bin1, b1
	string cmdstr
	Make/D/N=0 sum1, n1								// tallies for each bin within a cell
	Make/D/N=0 crunch_sum, crunch_ss					// sum & sum-squares for tallies across cells
	
	// delete any previous crunch results saved for debugging purposes
	cmdstr = "Killwaves/Z Crunchcell0, crunchn0, crunchcell1, crunchn1, crunchcell2, crunchn2, crunchcell3, crunchn3"
	execute cmdstr
	cmdstr = "Killwaves/Z Crunchcell4, crunchn4, crunchcell5, crunchn5, crunchcell6, crunchn6, crunchcell7, crunchn7"
	execute cmdstr
	cmdstr = "Killwaves/Z Crunchcell8, crunchn8, crunchcell9, crunchn9, crunchcell10, crunchn10, crunchcell11, crunchn11"
	execute cmdstr
	cmdstr = "Killwaves/Z Crunchcell12, crunchn12, crunchcell13, crunchn13, crunchcell14, crunchn14, crunchcell15, crunchn15"
	execute cmdstr	
	
	
	//  Calculate offset and firstn for each cell so that cells are aligned at appropriate sweep.
	//  The convention will be that the sweepnumber in crunch_align is the first sweep in bin crunch_zero_bin
	
	cell = 0
	variable bins_before_align, temp, max_offset=0
	cmdstr = "Redimension/N="+num2str(crunch_no_files)+" crunch_align_offset, crunch_align_firstn"
	execute cmdstr
	do
		if (crunch_binsize[cell] <= 1)
			DoAlert 0, "Improper bin size for cell "+num2str(cell)
		endif
		bins_before_align = ((crunch_align[cell]-crunch_sweep0[cell])/crunch_binsize[cell])				// this includes fractional bins.
		crunch_align_firstn[cell] = mod((crunch_align[cell]-crunch_sweep0[cell]),crunch_binsize[cell])		// remainder = sweeps in first bin
		crunch_align_offset[cell] = floor(bins_before_align) + (crunch_align_firstn[cell]!=0)					// rounded up to whole bins
		
		if (crunch_align_firstn[cell]==0)														// if no remainder, fill the first bin completely.
			crunch_align_firstn[cell] = crunch_binsize[cell]
		endif
		
		if (crunch_align_offset[cell] > max_offset)						// keep track of largest offset
			max_offset = crunch_align_offset[cell]
		endif
		cell += 1
	while (cell < crunch_no_files)
	
	 
	crunch_zero_bin = max_offset									// this will be the bin where the aligned sweeps are.
	
	 // Now loop through cells calculating within-cell averages
	 
	Crunch_sum = 0; crunch_n = 0; crunch_ss = 0
	cell =0;
	max_crunch_bins = 0
	
	do				// loop through all cells
		if (crunch_included[cell])
			
			// figure out which bin number to start with, according to crunch_align_offset of cell
			bin1 = max_offset - crunch_align_offset[cell]
			bin = bin1
			// Redimension the within-cell tally waves to the right size
			temp = ((crunch_sweep1[cell]-crunch_sweep0[cell]+1-crunch_align_firstn[cell])/crunch_binsize[cell])+1+bin1
			if (floor(temp)!=temp)
				temp = floor(temp)+1
			endif
			cmdstr = "Redimension/D/N="+num2str(temp)+" sum1, n1"
			Execute cmdstr
			sum1=0			
			n1=0
			sumbaseline=0; nbaseline=0									

			// first sweep 
			print "Starting Cell: ",crunch_file[cell] 
			Expt = crunch_file[cell]		// user display of which cell is being analyzed	
			sweep=crunch_sweep0[cell]
			if (Find_Sweep(sweep,crunch_file[cell])==0)	// load crunch_sweep0 into display_wave1	
				DoAlert 0, "Path should be specified on Control Bar.  Use no path or extension in crunch file names."
				return 0
			endif
			Read_Sweep(crunch_file[cell])								
			sum1[bin] = Calculate_Value(cell)			// calculate the appropriate value from display_wave1
			n1[bin] = 1
			sweep += 1

													// tally baseline values for later normalization
			if ((crunch_sweep0[cell] >= crunch_bline0[cell]) %& (crunch_sweep0[cell] <= crunch_bline1[cell]))
				sumbaseline += sum1[bin]
				nbaseline += 1
			endif
		
			if ((crunch_binsize[cell] == 1) %| (crunch_align_firstn[cell]==1))				// special case for 1 sweep per bin
				bin += 1
			endif
			
			// remaining sweeps
			do
				if (Find_Next_Sweep(crunch_file[cell])==0)
					return 0
				endif
				Read_Sweep(crunch_file[cell])
				val = Calculate_Value(cell)
				sum1[bin] += val
				n1[bin] += 1
													// tally baseline values for later normalization
				if ((sweep >= crunch_bline0[cell]) %& (sweep <= crunch_bline1[cell]))
					sumbaseline += val
					nbaseline += 1
				endif
			
				if (( bin == bin1) %& (n1[bin] == crunch_align_firstn[cell]) )			// if first bin, check that we're not exceeding firstn
					bin += 1
				endif
				
				if (n1[bin] == crunch_binsize[cell])				// for other bins, check that we're not exceeding binsize[cell]
					bin += 1
				endif
			
				sweep += 1
				
			while (sweep <= crunch_sweep1[cell])
			
			if (n1[bin]==0)			// if there are no sweeps in the last bin, remove that bin from crunch waves.
				bin -= 1
			endif
		
			if (bin>max_crunch_bins)					// keep track of max number of bins
				max_crunch_bins = bin
			endif
		
			// now normalize to baseline and for number of sweeps per bin
			b1 = 0
			do
				if (n1[b1]!=0)
					sum1[b1] /= n1[b1]
				endif
				b1 += 1
			while (b1 <= bin)
		
			if (crunch_normalize == 1)
				sum1 /= (sumbaseline/nbaseline)
			endif
		
			// debugging
			cmdstr = "Make/N="+num2str(bin+1)+" Crunchcell"+num2str(cell)
			execute cmdstr
			cmdstr = "Make/N="+num2str(bin+1)+ " Crunchn"+num2str(cell)
			Execute cmdstr
			cmdstr = "Crunchcell"+num2str(cell)+"= sum1"
			execute cmdstr
			cmdstr = "Crunchn"+num2str(cell)+"= n1"
			Execute cmdstr
		
			// add this single-cell result to the tally across cells. 
			cmdstr = "Redimension/D/N="+num2str(max_crunch_bins+1)+" crunch_sum, crunch_ss, sum1 "
			Execute cmdstr
			cmdstr = "Redimension/N="+num2str(max_crunch_bins+1)+" crunch_n, n1"
			Execute cmdstr
			crunch_sum += sum1
			crunch_ss += (sum1 * sum1)
			crunch_n += (n1 != 0)
		endif		// if cell was crunch_included	
		
		cell += 1
		
	while (cell < crunch_no_files)
	
	// Prepare to average across individual cells
	Duplicate/O/D crunch_sum, crunch_stdev, crunch_mean		// Make mean & stdev waves the appropriate size
	
	// calculate means etc. across cells.
	bin = 0
	do
		crunch_stdev[bin] = stdev(crunch_sum[bin], crunch_ss[bin], crunch_n[bin])
		bin += 1
	while (bin <= max_crunch_bins)
	
	crunch_mean = crunch_sum/crunch_n
	
	Killwaves sum1, n1, crunch_sum, crunch_ss
	
	// NOTE:  results are left in globals: crunch_mean, crunch_stdev[], and crunch_n[].  0->max_crunch_bins (global)
	// NOTE:  the specified alignment sweeps are the first sweeps in the bin crunch_zero_bin
	CheckDisplayed/A crunch_mean
	if (V_flag == 0)
		Display_Crunch_Results()
	endif
	
End

Function Display_Crunch_Results()
	Wave crunch_mean = crunch_mean
	Wave crunch_stdev = crunch_stdev
	Wave crunch_n = crunch_n
	NVAR max_crunch_bins = max_crunch_bins
	NVAR crunch_zero_bin = crunch_zero_bin
	String labelstr
	
	Display crunch_mean
	ModifyGraph mode=3,marker=8, rgb=(0,0,0), opaque=1, axisEnab(left)={0,0.7}, grid(left)=1
	ErrorBars crunch_mean Y,wave=(crunch_stdev,crunch_stdev)
	AppendToGraph/L=n crunch_n
	ModifyGraph grid(n)=1,axisEnab(n)={0.85,1}, freePos(n)=0, rgb=(0,0,0), mode(crunch_n)=6, grid(n)=1
	ModifyGraph manTick(n)={1,1,0,0},manMinor(n)={0,50}
	SetAxis/A/N=1 n
	Label n, "Cells"; ModifyGraph lblPos(n)=40
	Label left, "Crunch Units"; ModifyGraph lblPos(left)=40
	Label bottom, "Bins"
	
	// mark the point at crunch_zero_bin:  this is the bin containing all the aligned sweeps.
	textbox /A=MT/F=0/E "Crunch Results.  Aligned at bin: \{crunch_zero_bin}"
	
End

Function stdev(sum, ss, n1)
	variable sum, ss, n1
	
	variable num
	
	num = ss - ((sum*sum) / n1)
	if (n1>1)
		num /= (n1-1)
	endif
	if (n1==1)
		num = 0
	endif
	return sqrt(num)
end

Function Calculate_Value(cellnumber)
	variable cellnumber
	// This function returns the desired value for the sweep in display_wave1.  It returns slope, absolute amplitude,
	// or net amplitude depending on the value of the global variable crunch_type.
	
	// NOTE:  netamp is defined as absolute amplitude at specified window MINUS absolute amplitude of msec0-4 of
	// the sweep.
	
	NVAR crunch_type = crunch_type				// 0 = slope, 1 = netamp, 2 = absamp
	Wave crunch_anal0 = crunch_anal0
	Wave crunch_anal1 = crunch_anal1
	
	variable temp1
	
	if (crunch_type ==0)			// if slope analysis is desired
		Wave W_Coef = W_Coef
		Curvefit/Q line, display_wave1(crunch_anal0[cellnumber],crunch_anal1[cellnumber])
		temp1 = W_Coef[1]/1000			// convert sec to msec
	endif
	
	if ((crunch_type==1) %| (crunch_type==2))
		temp1= mean(display_wave1,crunch_anal0[cellnumber], crunch_anal1[cellnumber])
		if (crunch_type==1)
			temp1 -= mean(display_wave1, 0.000,0.004)			// DEFAULT BASELINE is 0-4 msec
		endif
	endif
	
	Return temp1
End

Function bCloseCrunchProc(dummy)
	string dummy
	string cmdstr
	
	DoWindow/K Crunch_Dialog
	DoWindow/K Crunch_Table
	
	cmdstr = "Killwaves/Z Crunchcell0, crunchn0, crunchcell1, crunchn1, crunchcell2, crunchn2, crunchcell3, crunchn3"
	execute cmdstr
	cmdstr = "Killwaves/Z Crunchcell4, crunchn4, crunchcell5, crunchn5, crunchcell6, crunchn6, crunchcell7, crunchn7"
	execute cmdstr
	cmdstr = "Killwaves/Z Crunchcell8, crunchn8, crunchcell9, crunchn9, crunchcell10, crunchn10, crunchcell11, crunchn11"
	execute cmdstr
	cmdstr = "Killwaves/Z Crunchcell12, crunchn12, crunchcell13, crunchn13, crunchcell14, crunchn14, crunchcell15, crunchn15"
	execute cmdstr	

End

Function bCleanUpCrunchProc(dummy)
	string dummy
	
	NVAR crunch_no_files = crunch_no_files
	Wave/T crunch_file=crunch_file
	Wave crunch_sweep0=crunch_sweep0			// sweep range start for crunch
	Wave crunch_sweep1=crunch_sweep1			// sweep range end for crunch
	Wave crunch_bline0=crunch_bline0				// sweep range start for baseline normalization
	Wave crunch_bline1=crunch_bline1				// sweep range end for baseline normalization
	Wave crunch_anal0=crunch_anal0				// sample number start for analysis window
	Wave crunch_anal1=crunch_anal1				// sample number end for analysis window
	Wave crunch_align=crunch_align				// sweep number to align sweeps between cells
	Wave crunch_binsize = crunch_binsize			// number of sweeps in each crunch time bin
	Wave crunch_included=crunch_included			// on-off 1-0 for including a cell in the crunch.  Not saved to disk.
	
	Variable cell = 0, i1=0
	
	Make/T/N=25 temp0
	Make/N=25 temp1, temp2, temp3, temp4, temp5, temp6, temp7, temp8
	
	do
		if (crunch_included[cell]!=0)		// if cell is currently included, add it to new cell list
			temp0[i1]=crunch_file[cell]
			temp1[i1]=crunch_sweep0[cell]
			temp2[i1]=crunch_sweep1[cell]
			temp3[i1]=crunch_bline0[cell]
			temp4[i1]=crunch_bline1[cell]
			temp5[i1]=crunch_anal0[cell]
			temp6[i1]=crunch_anal1[cell]
			temp7[i1]=crunch_align[cell]
			temp8[i1]=crunch_binsize[cell]
			i1 += 1
		endif
		cell +=1
	while (cell < crunch_no_files)
	crunch_no_files = i1
 	
 	string cmdstr="Redimension/N="+num2str(crunch_no_files)+" crunch_file, crunch_sweep0, crunch_sweep1, crunch_bline0, crunch_bline1,"
 	cmdstr += " crunch_anal0, crunch_anal1, crunch_align, crunch_binsize, crunch_included"
 	Execute cmdstr
 	crunch_file = temp0; crunch_sweep0=temp1; crunch_sweep1=temp2; crunch_bline0=temp3; crunch_bline1=temp4
 	crunch_anal0=temp5; crunch_anal1=temp6; crunch_align=temp7; crunch_binsize=temp8; crunch_included =1
 	
	Killwaves temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7, temp8
End

Function CrunchMarkChecked(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	
	// I just need to make sure that only one of the slope/netamp/absamp boxes is checked at once
	NVAR crunch_type = crunch_type
	NVAR crunch_normalize = crunch_normalize
	
	if (cmpstr(ctrlName, "slopebox")==0)		// user selects slope
		crunch_type = 0
	endif
	if (cmpstr(ctrlName, "netbox")==0)			// user selects net amplitude
		crunch_type = 1
	endif
	if (cmpstr(ctrlName, "absbox")==0)			// user selects absolute amplitude
		crunch_type = 2
	endif
	if (cmpstr(ctrlName, "normalizebox")==0)	// user checked normalize box
		crunch_normalize = (!crunch_normalize)
	endif
	
	// Redraw the checkboxes
	DoWindow/F Crunch_Dialog
	Killcontrol slopebox
	Killcontrol netbox
	Killcontrol absbox
	Killcontrol normalizebox	
	Make_Crunch_Checkboxes()
End


//------------------------------------------ Epoch Calculation Routines ------------------------------------------------------//

// These routines allow a user to specify epochs within an experiment, and then have the program
// calculate mean & S.D. values for specified analyses during those epochs.  The idea is to calculate
// baseline and post-treatment values for a slope or amplitude window, for example.  Or for an I-V curve.

// First a dialog box is set up where the user enters which analysis they want calculated, the sweep
// ranges for the epochs to use, and whether they want the results normalized to a control epoch.

Function Epoch_Calculator_Dialog()
	
	SVAR epoch_analysis_list	= epoch_analysis_list		// analysis numbers to calculate values for

	variable num = 0
	string namestr, titlestr, valstr
	variable xpos, ypos
		
	NewPanel/W=(200,125,479,380) as "Epoch Analyzer"
	DoWindow/C Epoch_Dialog
		
	Setvariable setvar_epoch_list pos = {10,10}, size = {250,30}, fsize =10, title = "Analysis Numbers", value=epoch_analysis_list, noproc
	xpos = 10
	ypos = 40
	do
		namestr = "set_epoch"+num2str(num)
		titlestr = "Epoch "+num2str(num)
		valstr = "epoch_range"+num2str(num)
		Setvariable $namestr pos = {(xpos),(ypos)}, size = {120,30}, fsize = 10, title = titlestr, value = $valstr, proc=epoch_range_proc
		num += 1
		xpos = 10 + (num>=6)*130
		ypos = 40+ (((num/6) - floor(num/6))*150)
	while (num < 12)
	
	SetDrawEnv fsize=9
	Button bUseAvgforEpoch pos = {80,190}, size={140,20}, title = "Use Average Ranges", fsize = 10, proc = bUseAvgforEpochProc
	Button bRunEpoch pos = {60,220}, size = {60,30}, fsize=10, title = "Run", proc = bRunEpochProc
	Button bCloseEpoch pos = {170, 220}, size = {60,30}, fsize = 10, title = "Exit", proc = bCloseEpochProc
End

Function Epoch_Range_Proc(ctrlName, varNum, varStr, varName)
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	// Called when user sets an Epoch Range setvariable control
		
	variable epoch
	string outstr
	Wave/T EpochRange = EpochRange
	
	ctrlName += " "		
	epoch = str2num(ctrlName[9,10])
	EpochRange[epoch] = varStr						// copy entry into EpochRange text wave
	
End

Function bUseAvgforEpochProc(dummy)
	string dummy
	
	// This procedure is called when user wants to set all epoch ranges to match sweep ranges
	//  previously entered in the average dialog box. 
	
	Wave average_exists = average_exists
	Wave/T AvgRange = AvgRange
	Wave/T EpochRange = EpochRange
	
	variable epoch_number
	string outstr
	
	epoch_number = 0
	do
		if (average_exists[epoch_number] )
			EpochRange[epoch_number] = AvgRange[epoch_number]
			outstr = "epoch_range"+num2str(epoch_number)+"=AvgRange["+num2str(epoch_number)+"]"
			execute outstr
		endif
		epoch_number += 1
	while (epoch_number < 11)				// There are currently 11 averages (0-10).	
	
End


Function bCloseEpochProc(dummy)
	string dummy
	
	DoWindow/K Epoch_Dialog
End

Function bRunEpochProc(dummy)
	string dummy
	
	Wave/T EpochRange = EpochRange
	NVAR epoch_normalize = epoch_normalize
	SVAR epoch_analysis_list = epoch_analysis_list
	SVAR Expt = Expt
	NVAR sweepnumber = sweepnumber
	Wave/T analysis_name = analysis_name
	NVAR number_of_analyses = number_of_analyses
	 
	variable epoch_number
	string cmdstr, sourcewave
	variable startswp, endswp, returnval, len, singleswp, semi, hyphen, i1, numswps
	variable analnumber, space, posn, last_epoch_flag

	 if (strlen(epoch_analysis_list)==0)
	 	DoAlert 0, "Please enter analysis numbers separated by spaces."
	 	Return 0
	 endif
	 
	 if (number_of_analyses == 0)
	 	DoAlert 0, "Please load analysis file before running Epoch Calculator."
	 	Return 0
	 endif
	 
	 // print header for output to history area
	 printf "Epoch"
	 posn = 0; last_epoch_flag = 0
	 if (strlen(epoch_analysis_list)==0)
		DoAlert 0, "Epoch analysis list was empty."
		Return 0
  	 endif
	 do
		space = strsearch(epoch_analysis_list," ",posn)
		if (space == -1)							// if not found, this was the last entry
			last_epoch_flag = 1
			space = strlen(epoch_analysis_list)
		endif
		analnumber = str2num(epoch_analysis_list[posn,space-1])
		posn = space+1
		printf "\t%s\tS.D.",analysis_name[analnumber]
		execute cmdstr
	 while (last_epoch_flag == 0)	
	 printf "\r"
	 
	 // Cycle through each Epoch.  If it has a valid range string, analyze sweeps for that epoch and calculate epoch results
	 epoch_number = 0
	 do
	 	numswps = 0
		len = strlen(EpochRange[epoch_number])
		if (len >0)			// if this epoch number is in use
			printf "#%s\t", EpochRange[epoch_number]
			posn = 0
			do	
				singleswp = 0															// for each semi-separated subrange in the string:
				semi = strsearch((EpochRange[epoch_number]),";",posn)						// find semi
				if (semi == -1)															// if no semi, treat as if semi at end of string
					semi = len
				endif
				hyphen = strsearch((EpochRange[epoch_number]),"-",posn)				// find hyphen
				if ((hyphen > 0) %& (hyphen < semi))
					startswp = str2num((EpochRange[epoch_number])[posn, hyphen-1])		// determine start & end sweeps for this subrange of range string
					endswp = str2num((EpochRange[epoch_number])[hyphen+1, semi-1])	
				else		// there was no hyphen -- user only input a single sweep number
					startswp = str2num((EpochRange[epoch_number])[posn, semi-1])
					singleswp = 1
				endif	
				if  ( (startswp < 0) %| (endswp < startswp) %| ((singleswp == 1) %& (startswp < 0)) )			// check for valid subrange.  Exit if invalid.
					DoAlert 0, "Invalid sweep range for epoch number "+num2str(epoch_number)
					Return 0
				endif	
			  	if (numswps == 0)
			  		Reset_Analyses()	
			  	endif
				Find_Sweep(startswp,Expt)				// read first sweep of the subrange
				Read_Sweep(Expt)
				sweepnumber = numswps					// Analysis master needs global sweepnumber set correctly to build analysis waves
				Analysis_Master()
				numswps += 1
				if (singleswp == 0)						// next sweeps in subrange
					i1 = startswp+1
					do
						returnval = Find_Next_Sweep(Expt)										// read subsequent sweeps in this subrange
						if (returnval > 0)
							Read_Sweep(Expt)
							sweepnumber = numswps
							Analysis_Master()
							numswps += 1
						endif
						i1 += 1
					while ( (i1 < endswp+1) %& (returnval >0) )										// end of this subrange or couldn't find sweep
				endif			// sweep range
				posn = semi + 1		
			while ((posn < len) %& (returnval > 0))											// until all subranges are done.
			
			// now that all sweeps across all subranges have been read & analyzed, calculate mean value of all analyses in epoch_analysis_list	
			posn = 0; last_epoch_flag = 0
			do
				space = strsearch(epoch_analysis_list," ",posn)
				if (space == -1)							// if not found, this was the last entry
					last_epoch_flag = 1
					space = strlen(epoch_analysis_list)
				endif
				analnumber = str2num(epoch_analysis_list[posn,space-1])
				posn = space+1
				sourcewave = "analysis"+num2str(analnumber)
				WaveStats/Q $sourcewave
				
				printf " %.4f\t %.4f\t",V_avg, V_sdev
				
			while (last_epoch_flag == 0)
			printf "\r"		
		endif		// if len > 0 so epoch number is in use
		epoch_number += 1
	while (epoch_number < 12)			// only allow epoch numbers 0-11
	printf "\r"
	
End



//------------------------------------------ Functions to Read Sweep Files --------------------------------------------------//

Function NewFileProc(ctrlName, varNum, varStr,varName)
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	NVAR fversion = fversion		// 1 = Classic;  2 = ECCLES
	NVAR disk_sweep_no = disk_sweep_no
	
	Find_Sweep(0,varStr)			// Open the first sweep.  This reads & sets fversion.
	if (fversion == 1)		// Classic file.  Requires user to remember if current or voltage recording.
		// Make the dialog box.
		NewPanel/W=(200,125,380,255) as "Recording Type"
		DoWindow/C Recording_Type_Dialog
		
		SetDrawEnv textxjust=1
		DrawText 90,25, "Please specify whether"
		SetDrawEnv textxjust=1
		DrawText 90, 40, varStr
		SetDrawEnv textxjust=1
		DrawText 90,55, "is a current or voltage recording."
		DrawTheBoxes()
	endif
	if (fversion == 2)		// ECCLES
		disk_sweep_no = 0
		GetSweep("",0,"","")			// just read the first sweep
	endif
End

Function DrawTheBoxes()
	Wave path_mode = path_mode
	
	Checkbox currentbox, pos={30,60}, size={70,25}, title="Current", value=(path_mode[0] %& 1),proc=RecTypechecked
	Checkbox voltagebox, pos={110, 60}, size={70,25}, title="Voltage", value=!(path_mode[0] %& 1), proc=RecTypechecked
	Button bOK7 pos={70, 100}, size={40,25}, fsize=10, title="OK", proc=bOKNewFileProc
End

Function RecTypeChecked(ctrlName, checked)
	string ctrlname
	variable checked
	
	// called when user selects voltage or current recording type boxes on Recording_Type_Dialog
	
	Wave path_mode = path_mode
	
	if (cmpstr(ctrlName, "currentbox")==0)		// user selects current
		path_mode[0]=1
		path_mode[1]=1
	endif
	if (cmpstr(ctrlName, "voltagebox")==0)		// user selects voltage
		path_mode[0]=0
		path_mode[1]=0
	endif

	// Redraw the checkboxes
	Killcontrol currentbox
	Killcontrol voltagebox
	Killcontrol bOK7
	DrawTheBoxes()
	
End

Function bOKNewFileProc(dummy)
	string dummy
	
	// Relabel existing analysis windows to reflect new path_mode entered by user.
	// Also relabel Stepsize setvariable control on control bar.
	
	NVAR disk_sweep_no = disk_sweep_no
	Wave path_mode = path_mode
	
	variable i1
	string cmdstr, labelstr

	DoWindow/K Recording_Type_Dialog
	
	Label_Windows(path_mode[0])				// label all windows to reflect recording mode.  Not clear if I will allow multiple paths here
	
	// Read first sweep
	disk_sweep_no = 0
	GetSweep("",0,"","")
	
End

Function Label_Windows(sweep_recording_mode)
	variable sweep_recording_mode			// 0 = OFF;  1= current clamp;  2= voltage clamp
	
	// This function redraws all window labels to reflect recording mode of the sweep (or mode entered by user)
	NVAR number_of_analyses = number_of_analyses
	Wave analysis_display = analysis_display
	Wave analysis_on = analysis_on
	Wave/T analysis_type = analysis_type
	Wave path_mode = path_mode				// This is the initial path mode that the user specifies when the file is opened.
	variable i1, commandmode
	string cmdstr, labelstr
	
	i1 = 0
	do
		if ((analysis_display[i1]>=1) %& (analysis_on[i1]==1))
			labelstr = yaxislabel(analysis_type[i1],sweep_recording_mode)					// figure out correct y axis label
			cmdstr="Label/W=analysis_window"+num2str(i1)+" left \""+labelstr+"\""
			Execute cmdstr
		endif
		i1 += 1
	while (i1 < number_of_analyses)
	
	Label/W=Sweep_window left (yaxislabel("AMPL", sweep_recording_mode))
	
	if (sweep_recording_mode == 1)
		commandmode = 2
	endif
	if (sweep_recording_mode == 2)
		commandmode = 1
	endif
	Label/W=CommandOut left (yaxislabel("AMPL", commandmode))
	
	cmdstr = "ModifyTable/W=CommandPulseTable title(command_pulse_value)=\""+yaxislabel("AMPL", commandmode)+"\""
	execute cmdstr
	
	if (sweep_recording_mode==0)
		SetVariable setvar_stepsize, win=Control_Bar, title="Step (pA)"
	else
		SetVariable setvar_stepsize, win=Control_Bar, title="Step (mV)"
	endif
		
End

Function Find_Sweep (sweep_number, filename)
	Variable sweep_number
	String filename
	
	//    This procedure will open the requested file for Reading, using the global symbolic path,
	//     and use the linked list of waveheaders to locate the waveheader corresponding to the 
	//     requested sweep number.  It will return the byte location of desired waveheader.
	//     If the desired sweep number does not exist, it will return 0.
	// 	Note:  the opened file is left open so that future Find_Next_Sweep or Read_Sweep routines don't have to re-open it.
	//	Therefore, when opening each new file, Find_Sweep must be called before any other read routine.
	
	NVAR current_wheader_ptr = current_wheader_ptr				// byte address of current waveheader (global)
	SVAR ydataname = ydataname
	SVAR xdataname = xdataname
	SVAR exptname = exptname 
	NVAR refnum=refnum
	variable magic_number
	variable wheaderptr, wheader_magicnumber
	variable sweepptr, tempptr
	variable sweep, pulse
	variable exitcode = 0
	variable garbage
	variable scale_factor
	string inputstr
	
	variable i, c
	
	xdataname=""
	ydataname=""
	exptname=""
	
	SVAR separator = separator									// global for field separator for saved strings
	NVAR classic_fheader_magicnumber = classic_fheader_magicnumber
	NVAR classic_wheader_magicnumber = classic_wheader_magicnumber
	NVAR ECCLES_fheader_magicnumber = ECCLES_fheader_magicnumber
	NVAR ECCLES_wheader_magicnumber = ECCLES_wheader_magicnumber
	SVAR extension = extension
	NVAR fversion = fversion				// 1 = classic file format;  2= ECCLES file format
	
	filename += extension
	
	if (refnum != 0)
		Close refnum			// close the previous file if one existed.
	endif
	
	// test to see if filename exists in path savepath //
	Open/Z/R/P=savepath /T="IGT-" refnum filename
	if (V_flag != 0)
		DoAlert 0, "No such filename found."
		Return 0
	endif
	Close refnum
	
	// open the file //
	Open/R /P=savepath /T="IGT-" refnum filename
	
	// Read Fileheader //
	fversion = 0
	FSetPos refnum, 0				
	FBinRead/F=2 refnum, magic_number		// For valid files, magicnumber = 1
	if (magic_number == classic_fheader_magicnumber)
		if (sweep_number == 0)
//			print "This file is a classic Igor sweep file."
		endif
		fversion = 1			// classic file format
		wheader_magicnumber = classic_wheader_magicnumber
		
	endif
	if (magic_number == ECCLES_fheader_magicnumber)
		if (sweep_number == 0)
//			print "This file is an ECCLES Igor sweep file."
		endif
		wheader_magicnumber = ECCLES_wheader_magicnumber
		fversion = 2			// ECCLES file format
	endif
	if (fversion == 0)
		DoAlert 0, "This is not a valid Igor sweep file."
		return 0
	endif
	
	FBinRead/U/F=3 refnum, wheaderptr		// byte address of first waveheader
	FBinRead/F=4 refnum, garbage				// skip:  absolute time of first sweep	
	inputstr  = "                    "					// this must be set to 20 spaces //
	FBinRead refnum, inputstr	
	i=0; c=strsearch(inputstr, separator, 0)			
	do										// ydataname = inputstr up to separator
		ydataname += inputstr[i]
		i += 1
	while (i<c)
	FBinRead refnum, inputstr	
	i=0; c=strsearch(inputstr, separator, 0)			
	do										// xdataname = inputstr up to separator
		xdataname += inputstr[i]
		i += 1
	while (i<c)
	FBinRead refnum, inputstr	
	i=0; c=strsearch(inputstr, separator, 0)			
	do										// exptname = inputstr up to separator
		exptname += inputstr[i]
		i += 1
	while (i<c)
	
	// Now follow the linked list of waveheaders to find the desired sweep. //
	do
		FSetPos refnum, wheaderptr					// Go to next waveheader
	
		FBinRead/F=2 refnum, magic_number			// check magicnumber	
		if (magic_number != wheader_magicnumber)
			DoAlert 0, "Failed to find wheader"
			return 0
		endif
		FBinRead/F=2 refnum, sweep						// read sweep
		if  (sweep == sweep_number)	
			exitcode = 1									// is this the one?
		endif
		
		if (fversion == 1)			// CLASSIC mode  -- 2 bytes for no_samples
			FBinRead/F=2 refnum, garbage					// number of pts in sweep
		endif
		if (fversion == 2)			// ECCLES mode  -- 4 bytes for no_samples.  
			FBinRead/F=4 refnum, garbage					// number of pts in sweep
		endif
		FBinRead/U/F=3 refnum, garbage					// scale factor (SKIP)
		FBinRead/F=4 refnum, garbage						// amplifier gain (SKIP)
		FBinRead/F=4 refnum, garbage						// sample rate, kHz (SKIP)
		FBinRead/F=4 refnum, garbage						// RECORDING MODE (SKIP)
		FBinRead/F=4 refnum, garbage						// dx for calculating x-axis (SKIP)
		FBinRead/F=4 refnum, garbage						// time of sweep			(SKIP)					
		if (fversion == 2)			// if ECCLES file, read the new ECCLES data fields
			pulse = 0
			do
				FBinRead/F=3 refnum, garbage				// command_pulse_flag[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_value[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_start[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_duration[pulse]		
				pulse += 1
			while (pulse < 5)
			FBinRead/F=5 refnum, garbage					// flag for DC pulse (command_pulse_flag[5])
			FBinRead/F=5 refnum, garbage					// value for DC pulse (command_pulse_value[5])
			FBinRead/F=4 refnum, garbage					// unused 
			FBinRead/F=4 refnum, garbage					// unused 
			FBinRead/F=4 refnum, garbage					// unused 
		endif		// ECCLES new fields
		FBinRead/U/F=3 refnum, garbage					// ptr to wavedata for this sweep (SKIP)
		FBinRead/U/F=3 refnum, tempptr					// ptr to next waveheader
		if (exitcode == 0)
			wheaderptr = tempptr
		endif
		FBinRead/U/F=3 refnum, garbage					// ptr to previous waveheader (SKIP)
		
		if (wheaderptr == 0)		// if no next sweep //
			inputstr = "Final sweep in file was "+num2str(sweep)
			DoAlert 0, inputstr
			return 0
		endif
		
	while (exitcode == 0) 
	
	//  Note:  leaving file open..
	current_wheader_ptr = wheaderptr						// set global current_wheader_ptr to this waveheader
	
End


Function Find_Next_Sweep(filename)
	string filename
	
	// This function starts at the current waveheader in file filename
	// and looks forward to find the next sweep.  It returns the byte
	// address of the next waveheader.
	
	// Note:  I have modified this procedure so it just reads from the open file specified by refnum.  It will not reopen or close it.
	
	NVAR refnum=refnum
	variable garbage, sweep
	variable nextwheaderptr
	string outstr
	variable magic_number
	NVAR classic_wheader_magicnumber = classic_wheader_magicnumber
	NVAR ECCLES_wheader_magicnumber = ECCLES_wheader_magicnumber
	NVAR current_wheader_ptr = current_wheader_ptr
	SVAR extension = extension
	NVAR fversion = fversion				// 1 = classic file format;  2= ECCLES file format
	variable wheader_magicnumber, pulse
	
	// File is assumed to be already open..
	
	if (fversion == 1)		// CLASSIC 
		wheader_magicnumber = classic_wheader_magicnumber
	endif
	if (fversion == 2)		// ECCLES
		wheader_magicnumber = ECCLES_wheader_magicnumber
	endif
	
	FSetPos refnum, current_wheader_ptr
	FBinRead/F=2 refnum, magic_number			// check magicnumber	
	
		if (magic_number != wheader_magicnumber)
			DoAlert 0, "Improper waveheader byte address in Find_Next_Sweep"
			return 0
		endif
		FBinRead/F=2 refnum, sweep						// read sweep (SKIP)
		if (fversion == 1)			// CLASSIC mode  -- 2 bytes for no_samples
			FBinRead/F=2 refnum, garbage					// number of pts in sweep
		endif
		if (fversion == 2)			// ECCLES mode  -- 4 bytes for no_samples.  
			FBinRead/F=4 refnum, garbage					// number of pts in sweep
		endif
		FBinRead/U/F=3 refnum, garbage					// scale factor (SKIP)
		FBinRead/F=4 refnum, garbage						// amplifier gain (SKIP)
		FBinRead/F=4 refnum, garbage						// sample rate, kHz (SKIP)
		FBinRead/F=4 refnum, garbage						// Vm (SKIP)
		FBinRead/F=4 refnum, garbage						// dx for calculating x-axis (SKIP)
		FBinRead/F=4 refnum, garbage						// time of sweep			(SKIP)	
		if (fversion == 2)		// if ECCLES file, read the new ECCLES data fields
			pulse = 0
			do
				FBinRead/F=3 refnum, garbage				// command_pulse_flag[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_value[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_start[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_duration[pulse]		
				pulse += 1
			while (pulse < 5)
			FBinRead/F=5 refnum, garbage					// flag for DC pulse (command_pulse_flag[5])
			FBinRead/F=5 refnum, garbage					// value for DC pulse (command_pulse_value[5])
			FBinRead/F=4 refnum, garbage					// unused 
			FBinRead/F=4 refnum, garbage					// unused 
			FBinRead/F=4 refnum, garbage					// unused 
		endif			// ECCLES new fields
		FBinRead/U/F=3 refnum, garbage					// ptr to wavedata for this sweep (SKIP)
		FBinRead/U/F=3 refnum, nextwheaderptr					// ptr to next waveheader
		if (nextwheaderptr == 0)
			outstr = "Sweep "+num2str(sweep)+" is the final sweep."
			DoAlert 0, outstr
			return 0
		endif
		
		current_wheader_ptr = nextwheaderptr				// update the current sweep pointer.
		Return 1
		
End
		
Function Find_Previous_Sweep (filename)
	string filename
	
	// This function starts at the current waveheader in file filename
	// and looks backwared to find the previous sweep.  It returns the byte
	// address of the previous waveheader.
	
	// As for Find_Next_Sweep, this assumes a file is already open and specified by refnum.
	
	NVAR refnum=refnum
	variable garbage, sweep
	variable prevwheaderptr
	string outstr
	variable magic_number
	NVAR classic_wheader_magicnumber = classic_wheader_magicnumber
	NVAR ECCLES_wheader_magicnumber = ECCLES_wheader_magicnumber
	NVAR current_wheader_ptr = current_wheader_ptr
	SVAR extension = extension
	NVAR fversion = fversion				// 1 = classic file format;  2= ECCLES file format

	variable wheader_magicnumber, pulse
	
	// File is assumed to be already open..
	
	if (fversion == 1)		// CLASSIC 
		wheader_magicnumber = classic_wheader_magicnumber
	endif
	if (fversion == 2)		// ECCLES
		wheader_magicnumber = ECCLES_wheader_magicnumber
	endif
	
	// Note I'm assuming the file is already open here.
	
	FSetPos refnum, current_wheader_ptr
	FBinRead/F=2 refnum, magic_number			// check magicnumber	
		if (magic_number != wheader_magicnumber)
			DoAlert 0, "Improper waveheader byte address in Find_Previous_Sweep"
			return 0
		endif
		FBinRead/F=2 refnum, sweep						// read sweep (SKIP)
		if (fversion == 1)			// CLASSIC mode  -- 2 bytes for no_samples
			FBinRead/F=2 refnum, garbage					// number of pts in sweep
		endif
		if (fversion == 2)			// ECCLES mode  -- 4 bytes for no_samples.  
			FBinRead/F=4 refnum, garbage					// number of pts in sweep
		endif
		FBinRead/U/F=3 refnum, garbage					// scale factor (SKIP)
		FBinRead/F=4 refnum, garbage						// amplifier gain (SKIP)
		FBinRead/F=4 refnum, garbage						// sample rate, kHz (SKIP)
		FBinRead/F=4 refnum, garbage						// Vm (SKIP)
		FBinRead/F=4 refnum, garbage						// dx for calculating x-axis (SKIP)
		FBinRead/F=4 refnum, garbage						// time of sweep			(SKIP)		
		if (fversion == 2)		// if ECCLES file, read the new ECCLES data fields
			pulse = 0
			do
				FBinRead/F=3 refnum, garbage				// command_pulse_flag[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_value[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_start[pulse]
				FBinRead/F=5 refnum, garbage				// command_pulse_duration[pulse]		
				pulse += 1
			while (pulse < 5)
			FBinRead/F=5 refnum, garbage					// flag for DC pulse (command_pulse_flag[5])
			FBinRead/F=5 refnum, garbage					// value for DC pulse (command_pulse_value[5])
			FBinRead/F=4 refnum, garbage					// unused 
			FBinRead/F=4 refnum, garbage					// unused 
			FBinRead/F=4 refnum, garbage					// unused 
		endif			// ECCLES new fields
			
		FBinRead/U/F=3 refnum, garbage					// ptr to wavedata for this sweep (SKIP)
		FBinRead/U/F=3 refnum, garbage					// ptr to next waveheader
		FBinRead/U/F=3 refnum, prevwheaderptr			// ptr to previous waveheader
		
		if (prevwheaderptr == 0)
			outstr = "Sweep "+num2str(sweep)+" is the first sweep."
			DoAlert 0, outstr
			return 0
		endif
		current_wheader_ptr = prevwheaderptr				// update the current sweep pointer
		
End

Function Read_Sweep(filename)
	String filename				// file to read from disk

	// This function reads the sweep, scales it, and loads it into display_wave1.  
	//     It also reads the amplifier command wave pulse descriptors and synthesizes CommandWave1
	
	// Note:  this routine assumes the file is already open and specified by the global refnum.
	
	NVAR refnum=refnum

	variable sweep, npts, Vm, dx, sweep_time, sweepptr
	string outstr
	variable magicnumber, sweep_magicnumber, wheader_magicnumber, garbage
	Wave display_wave1 = display_wave1				// referencing global wave for displaying data 
	NVAR disk_sweep_no = disk_sweep_no
	NVAR disk_sweep_time = disk_sweep_time
	NVAR no_samples = no_samples
	NVAR rate = kHz
	NVAR current_wheader_ptr = current_wheader_ptr
	SVAR extension = extension
	NVAR gZERO = gZERO
	variable scale_factor, amplifier_gain, pulse, tempno1, tempno2, tempno3, tempno4
	NVAR DCoffset = DCoffset							// to enable zero on/off in other procedures
	
	NVAR classic_wheader_magicnumber = classic_wheader_magicnumber
	NVAR classic_sweep_magicnumber = classic_sweep_magicnumber
	NVAR ECCLES_wheader_magicnumber = ECCLES_wheader_magicnumber
	NVAR ECCLES_sweep_magicnumber = ECCLES_sweep_magicnumber
	NVAR fversion = fversion				// 1 = classic file format;  2= ECCLES file format
	NVAR sweep_mode = sweep_mode
	NVAR stepsize = stepsize
	SVAR RecModeStr = RecModeStr
	
	Wave command_pulse_flag = command_pulse_flag
	Wave command_pulse_start = command_pulse_start
	Wave command_pulse_value = command_pulse_value
	Wave command_pulse_duration = command_pulse_duration
	
	NVAR temperature = temperature
	
	Make/W sw1										// local wave: 16-bit sweep for reading data from file
	
	// Note:  I'm assuming here the file is already open and specified by refnum
	
	if (fversion == 1)		// CLASSIC 
		wheader_magicnumber = classic_wheader_magicnumber
		sweep_magicnumber = classic_sweep_magicnumber
	endif
	if (fversion == 2)		// ECCLES
		wheader_magicnumber = ECCLES_wheader_magicnumber
		sweep_magicnumber = ECCLES_sweep_magicnumber
	endif


	FSetPos refnum, current_wheader_ptr				// Read the waveheader
	FBinRead/F=2 refnum, magicnumber				// check magicnumber	
		if (magicnumber != wheader_magicnumber)
			DoAlert 0, "Improper waveheader byte address in Read_Sweep"
			return 0
		endif
	FBinRead/F=2 refnum, disk_sweep_no				// sweep number
	if (fversion == 1)			// CLASSIC mode  -- 2 bytes for no_samples
		FBinRead/F=2 refnum, no_samples					// number of pts in sweep
	endif
	if (fversion == 2)			// ECCLES mode  -- 4 bytes for no_samples.  Allows long sweeps to work accurately.
		FBinRead/F=4 refnum, no_samples					// number of pts in sweep
	endif
	FBinRead/U/F=3 refnum, scale_factor				// scale factor 
	FBinRead/F=4 refnum, amplifier_gain				// amplifier gain 
	FBinRead/F=4 refnum, rate						// kHz sample rate for this sweep
	if (fversion == 1)		// Classic mode
		Sweep_mode = -1							
		FBinRead/F=4 refnum, Vm						// This is either Vm in CLASSIC file
	endif
	if (fversion == 2)		// ECCLES mode				// ....or... Sweep_Mode in ECCLES file
		Vm = 0
		FBinRead/F=4 refnum, sweep_mode			// 0 = OFF;  1 = current clamp;  2 = voltage clamp
	endif
	FBinRead/F=4 refnum, dx							// dx for calculating x-axis
	FBinRead/F=4 refnum, disk_sweep_time			// time of sweep			
	if (fversion == 2)		// if ECCLES file, read the new ECCLES data fields
		pulse = 0
		do												// for each of 5 output pulses (KJB : note the F flag is 1 larger than in version 5.3 to accomodate bigger flags):
			FBinRead/F=3 refnum, tempno1				// command_pulse_flag[pulse]
			FBinRead/F=5 refnum, tempno2				// command_pulse_value[pulse]
			FBinRead/F=5 refnum, tempno3				// command_pulse_start[pulse]
			FBinRead/F=5 refnum, tempno4				// command_pulse_duration[pulse]		
			command_pulse_flag[pulse] = tempno1
			command_pulse_value[pulse]=tempno2
			command_pulse_start[pulse]=tempno3
			command_pulse_duration[pulse]=tempno4
			pulse += 1
		while (pulse < 5)
		FBinRead/F=5 refnum, tempno1				// flag for DC pulse (command_pulse_flag[5])
		FBinRead/F=5 refnum, tempno2				// value for DC pulse (command_pulse_value[5])
		command_pulse_flag[5] = tempno1
		command_pulse_value[5] = tempno2
		
		FBinRead/F=4 refnum, temperature				// KJB --added temp output from Warner thermistor, in deg C
		FBinRead/F=4 refnum, garbage					// unused 
		FBinRead/F=4 refnum, garbage					// unused 

	endif			// ECCLES new fields
			
	FBinRead/U/F=3 refnum, sweepptr					// ptr to wavedata for this sweep
	
	// Dimension data and display waves appropriately for the data in the file //
	if (no_samples == -15036) 
		print "Sweep too long.  No_samples = -15036.  Manually changing no_samples to a 10-sec 5kHz sweep."
		no_samples = 50500
	endif
	if (no_samples < 0)
		DoAlert 0, "Incorrect no_samples.  To many samples per sweep in original data acquisition."
		Return 0
	endif
	outstr = "Redimension/N="+num2str(no_samples)+" sw1"
	execute outstr
	outstr = "Redimension/N="+num2str(no_samples)+" display_wave1"
	execute outstr
	
	FSetPos refnum, sweepptr							// read sweep data
	FBinRead/F=2 refnum, magicnumber				// magicnumber
	if (magicnumber != sweep_magicnumber)
//		DoAlert 0, "Improper sweep byte address in Read_Sweep"
//		return 0
	endif
	FBinRead/F=2 refnum, sw1								// the sweep itself (2 bytes per sample)
	
	display_wave1 = (sw1/scale_factor/amplifier_gain*1000)+Vm	// scale sw1 back to real data values
	setscale /p x, 0, 0.001/rate, "sec", display_wave1
	
	if (gZERO ==1)					// if user wants baseline zero //
		DCoffset = mean (display_wave1,0,pnt2x(display_wave1,9))
		display_wave1 -= DCoffset
	endif
	
	if (fversion == 2)
		Make_Command_Waves()				// re-synthesized CommandWaveOut from pulse values, rate, and no_samples.
		Label_Windows(sweep_mode)
		stepsize = command_pulse_value[4]	// in ECCLES, command_pulse 1 is used by default as Rs test step.
	endif
	
	// Set RecModeStr to show user what kind of sweep has just been read
	if (fversion == 2)
	variable fc1, fc2, fc3
	switch (sweep_mode)
		case 1: 
		RecModeStr="I clamp"; fc1 = 65000; fc2 = 1000; fc3 = 1000
		break
		case 2:
		RecModeStr="V clamp"; fc1 = 1000; fc2 = 65000; fc3 = 1000
		break
		case 3:
		RecModeStr="Linescan"; fc1 = 1000; fc2 = 1000; fc3 = 65000		// Not used in ECCLES but here as placeholder for TANK
		break
		default:
		DoAlert 0, "Unknown sweep_mode read in Igor sweep file."
		break					
	endswitch
	// update color of Rec Mode box
	
	TitleBox tbMode, win=Sweep_Description_Window, fcolor=(fc1,fc2,fc3)

	endif
	

	// Don't close the file--leave it open!
	killwaves sw1
	
End
	
Function GetSweep(ctrlName, varNum, varStr,varName)
	string ctrlName
	variable varNum
	string varStr
	string varName
	
	// called when user enters a number on the sweep number control.
	// this will read & display the specified sweep.
	
	bReadWaveProc("")
End

Function bReadWaveProc(dummy) : buttoncontrol
	string dummy
	
	SVAR Expt = Expt
	NVAR disk_sweep_no = disk_sweep_no
	
	Find_Sweep(disk_sweep_no, Expt)
	Read_Sweep(Expt)
	
End


Function bNextWaveProc(dummy) : buttoncontrol
	string dummy
	
	SVAR Expt = Expt
	
	Find_Next_Sweep(Expt)
	Read_Sweep(Expt)
	
End


Function bPrevWaveProc(dummy) : buttoncontrol
	string dummy

	SVAR Expt = Expt
	Find_Previous_Sweep(Expt)
	Read_Sweep(Expt)
	
End

Function SetupCursorProc()				// This procedure called from the Analysis Menu to identify single sweep nums from anal windows.
	string ctrlname
	NVAR CursorAposn = CursorAposn
	
	// if control window already exists, don't remake it
	if (WinType("Read_Sweep_Number_Panel") == 0)
		NewPanel/W=(520,140,770,257) as "Read Sweep Number"
		DoWindow/C Read_Sweep_Number_Panel
		SetDrawEnv textxjust=1
		DrawText 125,25, "Read Sweep Number from Anal. Window"

		PopupMenu bPickAnalysis, pos={2,40}, mode=1, value=WinList("Analysis*",";","WIN:1"), proc=bPickAnalysisProc, title = "Use Analysis Window"
		Button bClose_Read_Sweep_Number_Panel, pos = {160,75}, size = {50,30}, title = "Close", proc=bCloseReadSweepNoProc
		Button bReadThisSweepNo, pos = {30,75}, size = {100,30}, title = "Read Sweep No.", proc=bReadThisSweepNoProc
	endif
	
End

Function bReadThisSweepNoProc(ctrlName)
	string ctrlName
	
	NVAR disk_sweep_no = disk_sweep_no
	NVAR firstanalsweep = firstanalsweep
						
	ControlInfo bPickAnalysis
	DoWindow /F $S_value
	disk_sweep_no = pcsr(A) + firstanalsweep	
	
	bReadWaveProc("")
End

Function bCloseReadSweepNoProc(ctrlName)
	string ctrlname
	
	DoWindow/K Read_Sweep_Number_Panel
	// This will also delete the controls bUseCursor, bNoUseCursor, and bPickAnalysis.
	DeleteCursorsOnAnalWindows()
	
End


Function bPickAnalysisProc(ctrlName, popNum, popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	NVAR disk_sweep_no = disk_sweep_no
	NVAR firstanalsweep=firstanalsweep
	
	DeleteCursorsOnAnalWindows()
				
	ControlInfo/W=Read_Sweep_Number_Panel bPickAnalysis			// check which analysis window the user has selected.
	DoWindow /F $S_value
	string mytracename = TraceNameList(S_value,";",0)
	Cursor/P A, $mytracename,  disk_sweep_no - firstanalsweep		// put the cursor on at the position specified by disk_sweep_no.

	// note the cursor value is not read until user clicks the Read Sweep No. button.

End
 
 Function DeleteCursorsOnAnalWindows()			// This proc deletes any CursorA that may exist on an analysis window.
 	string window_name
 	NVAR number_of_analyses = number_of_analyses
 	
 	variable num = 0
 	
 	do
 		window_name = "Analysis_Window"+num2str(num)
 		if (WinType(window_name) == 1)			// if this graph exists, delete the cursor on it
 			DoWindow/F $window_name
 			Cursor/K A
 		endif
 		num += 1
 	while (num < number_of_analyses)
 End
 

// ------------------------------------------------------------ Printing Functions ---------------------------------------------------------------------//

Function bLayoutProc(dummy)
	string dummy
	
	Execute "Make_Layout()"
End


Window Make_Layout(): Layout
	// don't need global declarations--this is a macro.
	
	variable left1=50
	variable top1=120
	variable right1=570
	variable bottom1
	variable spacing = 1
	string cmdstr
	variable i1
	
	PauseUpdate; Silent 1		// building window...
	Layout /C=1 /W=(85.5,41,586.5,479.75)
	if (WinType("Stim_Protocol_Window") == 1)
		cmdstr="Stim_Protocol_Window("
		cmdstr += num2str(380)+","+num2str(45)+","+num2str(560)+","+num2str(225)+")/O=1/F=0"
		AppendToLayout $cmdstr
		top1 += (100+spacing)
	endif
	
	i1 = 0
	do
		if ((analysis_on[i1]==1) %& (analysis_display[i1]>=1) )
			if (( cmpstr(analysis_type[i1],"IHOLD")==0) %| (cmpstr(analysis_type[i1],"RSERIES")==0) %| (cmpstr(analysis_type[i1],"RINPUT")==0) )
				bottom1 = top1 + 60			// set appropriate graph height
			else
				bottom1 = top1 + 120			// graph height for major graphs 
			endif
			cmdstr="analysis_window"+num2str(i1)+"("
			cmdstr += num2str(left1)+","+num2str(top1)+","+num2str(right1)+","+num2str(bottom1)+")/O=1/F=0"
			AppendToLayout $cmdstr
			top1 = bottom1 + spacing
		endif
		i1 += 1
	while (i1 < number_of_analyses)
	
	// print whatever is in the sweep window
	bottom1 = top1 + 180
	right1 = left1 + 530			// make this one narrower
	cmdstr = "Sweep_window("
	cmdstr += num2str(left1)+","+num2str(top1)+","+num2str(right1)+","+num2str(bottom1)+")/O=1/F=0"
	AppendToLayout $cmdstr
	
	// Print a label
	Textbox/F=0/A=MT/E=1/X=0/Y=0 "\\Z14"+Expt
	Textbox/F=0/A=RT/E=1/X=5/Y=0 "\\Z12"+date()+"     "+time()	
	
	ModifyLayout mag=.5, units=1

EndMacro




Function CleanUp()
	variable num
	string cmdstr
	
	Close/A							// close any open files
	
	KillVariables/A/Z
	DoWindow/K Control_Bar
	DoWindow/K Sweep_Window
	DoWindow/K Step_window			// Close step window
	DoWindow/K CommandOut
	DoWindow/K CommandPulseTable
	DoWindow/K Make_Avg_Window
	DoWindow/K Sweep_Description_Window
	DoWindow/K ExportCont
	DoWindow/K Kernel_Window
	DoWindow/K Deconvolved_Signal
	DoWindow/K AllPointDistribution
	DoWindow/K mEPSCCont
	DoWindow/K EventCont

	
	// all the sweep average stuff //
	Killwaves avgstart
	Killwaves/Z avgend
	Killwaves average_exists
	Killwaves avgDCoffset
	Killwaves avgtitle
	
	num = 0
	do
		cmdstr = "KillWaves/Z Average_"+num2str(num)
		execute cmdstr
		cmdstr = "DoWindow/K analysis_window"+num2str(num)
		execute cmdstr
		cmdstr = "Killwaves/Z analysis"+num2str(num)
		execute cmdstr
		num += 1
	while (num < 30)
	
	// all the mark stuff //
	KillWaves mark_exists
	KillWaves marksweep 
	
	// new crunch stuff
	Killwaves sourcewavename,  diskwavename 
	
	// all the OLD crunch stuff //
	Killwaves crunch_file
	Killwaves crunch_sweep0
	Killwaves crunch_sweep1
	Killwaves crunch_bline0
	Killwaves crunch_bline1
	Killwaves crunch_anal0
	Killwaves crunch_anal1
	Killwaves crunch_align
	Killwaves crunch_binsize
	Killwaves crunch_included
	Killwaves crunch_mean
	Killwaves crunch_stdev
	Killwaves crunch_n
	Killwaves crunch_align_offset, crunch_align_firstn
	
	DoWindow/K Stim_Protocol_Window
	
	Killwaves AvgRange, EpochRange
	
	Killwaves analysis_name, analysis_type, analysis_path, analysis_on, analysis_display, analysis_y0, analysis_y1
	Killwaves analysis_cursor0, analysis_cursor1, path_mode
	Killwaves bline, pairing, post
	
	Killwaves command_pulse_flag, command_pulse_start, command_pulse_value, command_pulse_duration
	Killwaves CommandWaveOut
	Killwaves analmenureference
	
	Killwaves sweeptimes
	Killwaves display_wave1
	
	DoWindow/K Linescan_Controls
	DoWindow/K G_over_R
	DoWindow/K G_over_R_Avg
	DoWindow/K Align_Transients
	DoWindow/K Align_Calcium_Transients
	Killwaves/Z Thresh_Vm, Thresh_time, Peak_Vm, Peak_time, Peak_Repol, Spike_amp, Spike_width, Rise_dVdt, Fall_dVdt, stim_onset
	Killwaves/A/Z
	
End


//---------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------
//
//		Prairie Linescan Viewer, v1.2
//			imports tab delimited linescan stacks from ImageJ (1 column/image)
//			generates graphs of Green/Red fluorescence for a spine and its parent dendrite
//		
//		v1.1 now allows for calculation of baselines and sigmoid fits
//		v1.2 time locks calcium transients to a threshold value or max dV/dt in parent ephys sweep 101607
//
//		Kevin Bender, 05-2007
//
//
//---------------------------------------------------------------------------------------------------------



Function Make_Linescan_Input_Window()
	Variable/G linescan_sweep_num = 1
	Variable/G Avg_Spine_Value = 0
	Variable/G Avg_Dendrite_Value = 0

	NewPanel/W=(10, 167, 465, 340)
	DoWindow/C Linescan_Controls
	
	SetVariable line_path pos={10,25}, size={300,25}, title="Path", value=line_folder, fsize=10
	Button Calc_GoverR, pos = {10, 47}, title = "Import from ImageJ", size = {100, 25}, proc = Import_GoverRproc
	Button Display_Current_Linescan, pos = {120, 47}, title = "Display LS", size = {70,25}, proc = Display_linescan
	Button Display_Avg_Linescan, pos = {120, 77}, title = "Display Avg", size = {70,25}, proc = Display_Avg_Linescan
	Button Next_Sweep, pos = {325, 20}, title = "Next", size = {50, 25}, proc = Display_Next_Linescan
	Button Prev_Sweep, pos = {325, 50}, title = "Prev", size = {50, 25}, proc = Display_Prev_Linescan		
	Button Next_Both, pos = {395, 20}, title = "Next", size = {50, 25}, proc = Display_Next_Both
	Button Prev_Both, pos = {395, 50}, title = "Prev", size = {50, 25}, proc = Display_Prev_Both
	SetVariable linescan_sweep pos={325, 82}, title = "Linescan Swp.", size = {120,25}, limits={1,1000,1}, value = linescan_sweep_num, proc = Display_Update
	SetVariable linescan_timestamp pos={10, 82}, title = "ms/line", size = {100, 25}, value = ms_per_line
	SetVariable G_over_R_max pos= {200, 52}, title = "G/R Max", size = {110,25}, value = GR_max
	Button Normalize, pos = {194, 77}, title = "Normalize", size = {70,25}, proc = Normalize_Proc
	Drawtext 272,89, "Overlay?"
	Checkbox Overlay, pos = {285,90}, title = " ", proc = Normalize_check_proc
	Drawtext 318, 18, "Linescans"
	Drawtext 388, 18, "LS + ephys"
	Drawtext 10, 18, "Specify Path for ImageJ output files:"
	Button Avg_Spine, pos = {10, 118}, title = "S_Avg", size = {80, 20}, proc = Avg_Spine
	SetVariable Avg_Spine_Value pos={96, 120}, title = " ", size = {80, 25}, limits={-1000,1000,0}, value = Avg_Spine_Value, proc = Avg_Spine
	Button Avg_Dendrite, pos = {10, 143}, title = "D_Avg", size = {80, 20}, proc = Avg_Dendrite
	SetVariable Avg_Dendrite_Value pos={96, 145}, title = " ", size = {80, 25}, limits={-1000,1000,0}, value = Avg_Dendrite_Value, proc = Avg_Dendrite
	Button Sig_Spine, pos = {186, 118}, title = "S Peak of Exp.", size = {90, 20}, proc = Exp_Spine
	Button Sig_Dendrite, pos = {186, 143}, title = "D Peak of Exp.", size = {90, 20}, proc = Exp_Dendrite
	Button Erase_Fits, pos = {281, 118}, title = "\\JCErase\r\\JCFits", size = {40, 45}, proc = Erase_Fits
	Button Align_Transients, pos = {335, 118}, title = "\\JCAlign\r\\JCTransients", size = {58, 45}, proc = Align_Transients
	Button Threshold_line, pos = {400, 118}, title = "\\JCThresh.\r\\JCLine", size = {45, 30}, proc = Threshold_line_proc
	Button Erase_Threshold, pos = {400, 150}, title = "Erase", size = {45, 20}, proc = Erase_threshold_proc
	Drawline 7, 107, 447, 107
	Drawline 7, 109, 447, 109
	Drawline 179, 111, 179, 170
	Drawline 328, 111, 328, 170
end

Function Normalize_check_proc(ctrlName,checked) : CheckBoxControl	// outputs "Normalized_check" variable (0 or 1), to tell "Display Avg" procedure to overlay Avg_s and Avg_d linescan traces
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	Variable/G Normalized_check 	// 1 if checked, 0 if not
	
	If (checked ==1)
		Normalized_check = 1
	else
		Normalized_check = 0
	endif
end


Function Import_GoverRproc(ctrlName)		//Function to call up 4 files in defined directory, these MUST be named: sRed, sGreen, dRed, dGreen

	string ctrlName
	string Varlocate, Varlocate_1
	string line_path
	string sRed = "sRed.txt"							// Strings for linescans in Red and Green channels through spine and parent dendrite
	string sGreen = "sGreen.txt"
	string dRed = "dRed.txt"
	string dGreen = "dGreen.txt"
	string/G dList, sList								// Reference string lists for GoverR waves
	Variable i
	string tempG, tempR, tempGoverR, temp_i			// string placeholders for generating G over R waves for each sweep

	NVAR linescan_sweep_num						// Reset linescan counter to 0
	ControlInfo/W=Linescan_Controls linescan_sweep
	linescan_sweep_num = 1

	NVAR Avg_Spine_Value							// Reset averages
	NVAR Avg_Dendrite_Value
	Avg_Spine_Value = 0
	Avg_Dendrite_Value = 0
	
	// First, delete old linescan waves, as well as the G_over_R graph
	DoWindow/K G_over_R							// Deletes Graph, code doesn't care if it exists or not
	DoWindow/K G_over_R_Avg
	DeleteWaveList(WaveList("*Red*",";",""))			// Delete all red waves
	DeleteWaveList(WaveList("*Green*",";",""))			// Delete all green waves
	DeleteWaveList(WaveList("*GoverR*",";",""))			// Delete all GoverR waves
	
	ControlInfo/W=Linescan_Controls line_path			// Lookup the path from "Make_Linescan_Input_Window'"
	Varlocate = "line_folder"
	SVAR line_folder = $varlocate
	NewPath/Z/O line_path, line_folder 					// Specify said path
	if(V_flag !=0)
		DoAlert 0, "Path not found."
		Return 0
	endif

	GetFileFolderInfo/Z/Q/P=line_path sRed				// Load spine data (G and R) and compute G/R if both are found
	if (V_Flag==0)
		GetFileFolderInfo/Z/Q/P=line_path sGreen
		if (V_Flag==0)
			LoadWave/O/J/N=sRed/K=0/P=line_path/L={0,1,0,1,0} sRed
			LoadWave/O/J/N=sGreen/K=0/P=line_path/L={0,1,0,1,0} sGreen	
				For(i=0;i<(V_flag);i+=1)				// V_flag-1 because the last column imported from ImageJ is blank; edit: BLC - not true
					temp_i = num2str(i)				// Iterative strings to call the numbered waves of the linescan
					tempG = "sGreen"+temp_i
					tempR = "sRed"+temp_i
					tempGoverR = "sGoverR"+temp_i					
					make/N=(numpnts($tempG))/O tempGoverR_1		
					Wave tempG_1 = $tempG
					Wave tempR_1 = $tempR
					tempGoverR_1 = (tempG_1)/(tempR_1)
					make/N=(numpnts($tempG))/O $tempGoverR = tempGoverR_1
				endfor
		else
			DoAlert 0, "Spine Data Not Found"
		endif
	else
		DoAlert 0, "Spine Data Not Found"	
	endif

	GetFileFolderInfo/Z/Q/P=line_path dRed				// Load dendrite data (G and R) and compute G/R if both are found
	if (V_Flag==0)
		GetFileFolderInfo/Z/Q/P=line_path dGreen
		if (V_Flag==0)
			LoadWave/O/J/N=dRed/K=0/P=line_path/L={0,1,0,1,0}  dRed
			LoadWave/O/J/N=dGreen/K=0/P=line_path/L={0,1,0,1,0}  dGreen
			For(i=0;i<(V_flag);i+=1)			// V_flag-1 because the last column imported from ImageJ is blank; edit BLC - not true
				temp_i = num2str(i)			// Iterative strings to call the numbered waves of the linescan
				tempG = "dGreen"+temp_i
				tempR = "dRed"+temp_i
				tempGoverR = "dGoverR"+temp_i					
				make/N=(numpnts($tempG))/O tempGoverR_1		
				Wave tempG_1 = $tempG
				Wave tempR_1 = $tempR
				tempGoverR_1 = (tempG_1)/(tempR_1)
				make/N=(numpnts($tempG))/O $tempGoverR = tempGoverR_1
			endfor
		else
			DoAlert 0, "Parent Dendrite Data Not Found"
		endif
	else
		DoAlert 0, "Parent Dendrite Data Not Found"	
	endif
	
	//  Code to make the time scale wave, "linescan_time"
	ControlInfo/W=Linescan_Controls linescan_timestamp
	Varlocate_1 = "ms_per_line"
	SVAR ms_per_line = $varlocate_1
	string sRed0_string = wavelist("sRed0","","")		// This is a kludge to generate a string of the wavename sRed0, so I don't explicitly call that wave in the function
	Make/O/N=(numpnts($sRed0_string)) linescan_time
	linescan_time = p*(str2num(ms_per_line))*0.001  // take timescale in ms and multiply out to display seconds on graph
end

Function DeleteWaveList(list)			// Stolen directly from "Processing list of waves" section of manual
	string list
	string theWave	
	Variable index = 0
	
	do
		theWave = StringFromList(index, list)
		if (strlen(theWave) == 0)
			break
		else
			Killwaves $theWave
		endif
		index += 1
	while (1)
end

Function Display_Linescan(ctrlName)
	string ctrlName
	string sLS, dLS, dList, sList
	NVAR linescan_sweep_num
	string dGoverR0_string = wavelist("dGoverR0","","")		// This is a kludge to generate a string of the wavename sRed0, so I don't explicitly call that wave in the function

	ControlInfo/W=Linescan_Controls linescan_sweep_num			// Read current linescan sweep

	dList = (WaveList("dGoverR*",";",""))		// Create Index of all dendrite GoverR data
	sList = (WaveList("sGoverR*",";",""))		// Create Index of all spine GoverR data	
	dLS = StringFromList(linescan_sweep_num-1, dList)		//kb		offset by 1 to correspond to ImageJ
	sLS = StringFromList(linescan_sweep_num-1, sList)		//kb
	
	if (strlen(sLS) == 0)
		Print "Exceeded stack range."
		Beep
	else	
		// Generate display waves
		If (waveexists($dGoverR0_string)==1)
			Wave sLinescan_temp = $sLS
			Make/O/N=(numpnts($sLS)) sLinescan = sLinescan_temp
			Wave dLinescan_temp = $dLS
			Make/O/N=(numpnts($sLS)) dLinescan = dLinescan_temp
		Else
			Wave sLinescan_temp = $sLS
			Make/O/N=(numpnts($sLS)) sLinescan = sLinescan_temp
		Endif
	Endif
	
	DoWindow G_over_R
	if (V_flag ==0)				// If display window isn't there, generate it for the first time
		if (waveexists($dGoverR0_string)==1)					// If dendritic data exists, display both spine and dendrite
			Display/W=(8, 280, 350, 640) sLinescan vs linescan_time as "G_over_R"
			Label left "Spine G/R"
			Label bottom "time (sec)"
			AppendToGraph/L=VertCrossing dLinescan vs linescan_time
			Label VertCrossing "Dendrite G/R"
			AppendToGraph/L=ephys display_wave1
			Label ephys "mV"
			DoWindow/C G_over_R
			ModifyGraph axisEnab(left)={0.35,0.65}, axisEnab(VertCrossing)={0,0.3}, freePos(VertCrossing)={0,bottom}, rgb(sLinescan)=(0,52224,0),rgb(dLinescan)=(0,0,65280)
			ModifyGraph lblPos(left)=45,lblPos(VertCrossing)=45,lblPos(ephys)=45
			ModifyGraph axisEnab(ephys)={0.7,1},freePos(ephys)={0,bottom}
//			SetAxis left 0.01,0.4
//			SetAxis VertCrossing 0.01,0.4
//			SetAxis ephys -2,10 
		else
			Display/W=(8, 280, 350, 640) sLinescan vs linescan_time as "G_over_R"
			Label left "Spine G/R"
			Label bottom "time (sec)"
			AppendToGraph/L=ephys display_wave1
			Label ephys "mV"
			ModifyGraph lblPos(left)=45,lblPos(ephys)=45
			ModifyGraph axisEnab(ephys)={0.7,1},freePos(ephys)={0,bottom}
			DoWindow/C G_over_R
			ModifyGraph axisEnab(left)={0.35,0.65}, rgb(sLinescan)=(0,52224,0)
//			SetAxis left 0.01,0.4
//			SetAxis ephys -2,10 
		endif		
	endif
end

Function Display_Avg_Linescan(ctrlName)
	string ctrlName
	string sLS, dLS, dList, sList, Varlocate_1
	string sGoverR0_string = wavelist("sGoverR0","","")		// This is a kludge to generate a string of the wavename sRed0, so I don't explicitly call that wave in the function
	string dGoverR0_string = wavelist("dGoverR0","","")		// This is a kludge to generate a string of the wavename sRed0, so I don't explicitly call that wave in the function
	NVAR linescan_sweep_num, Normalized_check
	Variable index = 0

	dList = (WaveList("dGoverR*",";",""))		// Create Index of all dendrite GoverR data
	sList = (WaveList("sGoverR*",";",""))		// Create Index of all spine GoverR data	
	dLS = StringFromList(linescan_sweep_num-1, dList)		//KB  offset by 1 to correspond to imageJ
	sLS = StringFromList(linescan_sweep_num-1, sList)

	// Generate average waves	
	Make/O/N=(numpnts($sLS)) Avg_sLinescan = 0
	Make/O/N=(numpnts($sLS)) Avg_dLinescan = 0

	If (waveexists($dGoverR0_string)==1)
		do
			dLS = StringFromList(index, dList)
			if(strlen(dLS) == 0)
				break
			else
				Wave dLinescan_temp = $dLS
				Make/O/N=(numpnts($dLS)) dLinescan = dLinescan_temp
				Avg_dLinescan = Avg_dLinescan + dLinescan
				index +=1
			endif
		while(1)
		Avg_dLinescan = (Avg_dLinescan/index)
	Endif
	
	index = 0
	If (waveexists($sGoverR0_string)==1)
		do
			sLS = StringFromList(index, sList)
			if(strlen(sLS) == 0)
				break
			else
				Wave sLinescan_temp = $sLS
				Make/O/N=(numpnts($sLS)) sLinescan = sLinescan_temp
				Avg_sLinescan = Avg_sLinescan + sLinescan
				index +=1
			endif
		while(1)
		Avg_sLinescan = (Avg_sLinescan/index)
	Endif
	
	DoWindow G_over_R_Avg
	if (V_flag ==0)				// If display window isn't there, generate it for the first time
		if (waveexists($dGoverR0_string)==1)					// If dendritic data exists, display both spine and dendrite
			Display/W=(18, 280, 360, 640) Avg_sLinescan vs linescan_time as "G_over_R_Avg"
			Label left "Avg Spine G/R"
			Label bottom "time (sec)"
			AppendToGraph/L=VertCrossing Avg_dLinescan vs linescan_time
			Label VertCrossing "Avg Dendrite G/R"
			AppendToGraph/L=ephys Average_0
			Label ephys "mV"
			DoWindow/C G_over_R_Avg
			ModifyGraph axisEnab(left)={0.35,0.65}, axisEnab(VertCrossing)={0,0.3}, freePos(VertCrossing)={0,bottom}, rgb(Avg_sLinescan)=(0,52224,0),rgb(Avg_dLinescan)=(0,0,65280)
			ModifyGraph lblPos(left)=45,lblPos(VertCrossing)=45,lblPos(ephys)=45
			ModifyGraph axisEnab(ephys)={0.7,1},freePos(ephys)={0,bottom}
//			SetAxis left 0.01,0.4
//			SetAxis VertCrossing 0.01,0.4
//			SetAxis ephys -2,10
			ShowInfo
		else
			Display/W=(18, 280, 360, 640) Avg_sLinescan vs linescan_time as "Avg G_over_R"
			Label left "Avg Spine G/R"
			Label bottom "time (sec)"
			AppendToGraph/L=ephys Average_0
			Label ephys "mV"
			ModifyGraph lblPos(left)=45,lblPos(ephys)=45
			ModifyGraph axisEnab(ephys)={0.7,1},freePos(ephys)={0,bottom}
			DoWindow/C G_over_R_Avg
			ModifyGraph axisEnab(left)={0.35,0.65}, rgb(Avg_sLinescan)=(0,52224,0)
//			SetAxis left 0.01,0.4
//			SetAxis ephys -2,10
			ShowInfo
		endif		
	endif
	if (numpnts(Avg_sLinescan) != numpnts(linescan_time))		// If average is remade with Align_Transients, this redimensions timestamp to compensate
		ControlInfo/W=Linescan_Controls linescan_timestamp
		Varlocate_1 = "ms_per_line"
		SVAR ms_per_line = $varlocate_1		
		Redimension/N=(numpnts(Avg_sLinescan)) linescan_time
		Wave linescan_time = linescan_time
		linescan_time = p*(str2num(ms_per_line))*0.001  // take timescale in ms and multiply out to display seconds on graph
	endif
end

Function Display_Next_Linescan(ctrlName)
	string ctrlName
	NVAR linescan_sweep_num
	string sList, sLS

	linescan_sweep_num = linescan_sweep_num + 1		// Iterate forward by one
	sList = (WaveList("sGoverR*",";",""))		// Create Index of all spine GoverR data	
	sLS = StringFromList(linescan_sweep_num-1, sList)			// KB offset for imageJ
	ControlInfo/W=Linescan_Controls linescan_sweep_num			// Lookup the path from "Make_Linescan_Input_Window'"

	If (strlen(sLS) == 0)
		linescan_sweep_num = linescan_sweep_num - 1		// Revert back to usable range
		Beep
	else
		Display_Linescan(ctrlName)
	endif
end

Function Display_Prev_Linescan(ctrlName)
	string ctrlName
	NVAR linescan_sweep_num
	string sList, sLS

	linescan_sweep_num = linescan_sweep_num - 1		// Iterate back by one
	sList = (WaveList("sGoverR*",";",""))		// Create Index of all spine GoverR data	
	sLS = StringFromList(linescan_sweep_num-1, sList)				// KB offset for imageJ
	ControlInfo/W=Linescan_Controls linescan_sweep_num			// Lookup the path from "Make_Linescan_Input_Window'"
	
	If (strlen(sLS) == 0)
		linescan_sweep_num = linescan_sweep_num + 1		// Revert back to usable range
		Beep
	else
		Display_Linescan(ctrlName)
	endif
end

Function Display_update(ctrlName, varNum, varStr, varName)		// Updates G_over_R graph if a number is entered into the Sweep range
	string ctrlName
	Variable varNum
	String varStr
	String varName
	
	Display_Linescan(ctrlName)
end


//	Move back and forth with both the ephys and the linescan data. 
Function Display_Next_Both(ctrlName)
	string ctrlName
	NVAR linescan_sweep_num
	string sList, sLS
	SVAR Expt = Expt

	linescan_sweep_num = linescan_sweep_num + 1		// Iterate forward by one
	sList = (WaveList("sGoverR*",";",""))		// Create Index of all spine GoverR data	
	sLS = StringFromList(linescan_sweep_num-1, sList)			// KB offset for imageJ
	ControlInfo/W=Linescan_Controls linescan_sweep_num			// Lookup the path from "Make_Linescan_Input_Window'"

	If (strlen(sLS) == 0)
		linescan_sweep_num = linescan_sweep_num - 1		// Revert back to usable range
		Beep
	else
		Display_Linescan(ctrlName)
		Find_Next_Sweep(Expt)
		Read_Sweep(Expt)
	endif
end

Function Display_Prev_Both(ctrlName)
	string ctrlName
	NVAR linescan_sweep_num
	string sList, sLS
	SVAR Expt = Expt

	linescan_sweep_num = linescan_sweep_num - 1		// Iterate back by one
	sList = (WaveList("sGoverR*",";",""))		// Create Index of all spine GoverR data	
	sLS = StringFromList(linescan_sweep_num-1, sList)				// KB offset for imageJ
	ControlInfo/W=Linescan_Controls linescan_sweep_num			// Lookup the path from "Make_Linescan_Input_Window'"
	
	If (strlen(sLS) == 0)
		linescan_sweep_num = linescan_sweep_num + 1		// Revert back to usable range
		Beep
	else
		Display_Linescan(ctrlName)
		Find_Previous_Sweep(Expt)
		Read_Sweep(Expt)
	endif
end

// Normalize Averages to G/R Max value of dye (measured in 2-10 mM Ca buffered with HEPES to pH 7.2)

Function Normalize_Proc(ctrlName)
	string ctrlName
	string Varlocate_1
	wave Avg_sLinescan = Avg_sLinescan
	wave Avg_dLinescan = Avg_dLinescan
	string dGoverR0_string = wavelist("dGoverR0","","")		// This is a kludge to generate a string of the wavename sRed0, so I don't explicitly call that wave in the function
	NVAR normalized_check

	ControlInfo/W=Linescan_Controls G_over_R_max
	Varlocate_1 = "GR_max"
	SVAR GR_max = $varlocate_1
	
	If (waveexists($dGoverR0_string)==1)					// If dendritic data exists, display both spine and dendrite

		WaveStats/R=(xcsr(A),xcsr(B)) Avg_sLinescan
		Avg_sLinescan = Avg_sLinescan - V_avg
		Avg_sLinescan = Avg_sLinescan/(str2num(GR_max))
		Avg_sLinescan = Avg_sLinescan*100

		WaveStats/R=(xcsr(A),xcsr(B)) Avg_dLinescan
		Avg_dLinescan = Avg_dLinescan - V_avg
		Avg_dLinescan = Avg_dLinescan/(str2num(GR_max))
		Avg_dLinescan = Avg_dLinescan*100

		SetAxis/A left;DelayUpdate
		SetAxis/A VertCrossing
	else
		WaveStats/R=(xcsr(A),xcsr(B)) Avg_sLinescan
		Avg_sLinescan = Avg_sLinescan - V_avg
		Avg_sLinescan = Avg_sLinescan/(str2num(GR_max))
		Avg_sLinescan = Avg_sLinescan*100
	
		SetAxis/A left;DelayUpdate
	endif
	
	If (Normalized_check ==1)
		AppendToGraph Avg_dLinescan vs linescan_time
		ModifyGraph rgb(Avg_dLinescan#1)=(0,0,65280)
	endif
end


// Functions to get average baseline and peak amplitudes from user-defined cursor ranges.
// Will do analysis on top graph, whether it be single linescans or averages.

Function Avg_Spine(ctrlName)
	string ctrlName
	NVAR Avg_Spine_Value
	
	String waveCursorIsOn = CsrWave(A)				// Get info on what top graph is
	If (cmpstr(waveCursorIsOn, "sLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) sLinescan	
		Avg_Spine_Value = V_avg
	endif
	If (cmpstr(waveCursorIsOn, "dLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) sLinescan	
		Avg_Spine_Value = V_avg
	endif	
	If (cmpstr(waveCursorIsOn, "Avg_sLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) Avg_sLinescan	
		Avg_Spine_Value = V_avg
	endif
	If (cmpstr(waveCursorIsOn, "Avg_dLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) Avg_sLinescan	
		Avg_Spine_Value = V_avg
	endif
end

Function Avg_Dendrite(ctrlName)
	string ctrlName
	NVAR Avg_Dendrite_Value
	
	String waveCursorIsOn = CsrWave(A)				// Get info on what top graph is
	If (cmpstr(waveCursorIsOn, "sLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) dLinescan	
		Avg_Dendrite_Value = V_avg
	endif
	If (cmpstr(waveCursorIsOn, "dLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) dLinescan	
		Avg_Dendrite_Value = V_avg
	endif	
	If (cmpstr(waveCursorIsOn, "Avg_sLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) Avg_dLinescan	
		Avg_Dendrite_Value = V_avg
	endif
	If (cmpstr(waveCursorIsOn, "Avg_dLinescan")==0)		
		WaveStats/Q/R=(xcsr(A),xcsr(B)) Avg_dLinescan	
		Avg_Dendrite_Value = V_avg
	endif
end

// Functions to calculate sigmoid fits to rising slope of calcium transients.
// Again, works with the top graph.

Function Exp_Spine(ctrlName)
	string ctrlName
	NVAR Exp_Spine
	NVAR Avg_Spine_Value
	
	String waveCursorIsOn = CsrWave(A)				// Get info on what top graph is
	If (cmpstr(waveCursorIsOn, "sLinescan")==0)		
		CurveFit/Q exp_XOffset  sLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_sLinescan
		Avg_Spine_Value = V_max
	endif
	If (cmpstr(waveCursorIsOn, "dLinescan")==0)		
		CurveFit/Q exp_XOffset  sLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_sLinescan
		Avg_Spine_Value = V_max 
	endif
	If (cmpstr(waveCursorIsOn, "Avg_sLinescan")==0)		
		CurveFit/Q exp_XOffset  Avg_sLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_Avg_sLinescan
		Avg_Spine_Value = V_max 
	endif
	If (cmpstr(waveCursorIsOn, "Avg_dLinescan")==0)		
		CurveFit/Q exp_XOffset  Avg_sLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_Avg_sLinescan
		Avg_Spine_Value = V_max  
	endif

//	DoWindow Sigmoid_Coeff
//	If (V_flag == 0)
//		Edit/W=(260,250,420,365) W_coef
//		DoWindow/C Sigmoid_Coeff
//	endif
end

Function Exp_Dendrite(ctrlName)
	string ctrlName
	NVAR Exp_Dendrite
	NVAR Avg_Dendrite_Value
	
	String waveCursorIsOn = CsrWave(A)				// Get info on what top graph is
	If (cmpstr(waveCursorIsOn, "sLinescan")==0)		
		CurveFit/Q exp_XOffset  dLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_dLinescan
		Avg_Dendrite_Value = V_max 
	endif
	If (cmpstr(waveCursorIsOn, "dLinescan")==0)		
		CurveFit/Q exp_XOffset  dLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_dLinescan
		Avg_Dendrite_Value = V_max 
	endif
	If (cmpstr(waveCursorIsOn, "Avg_sLinescan")==0)		
		CurveFit/Q exp_XOffset  Avg_dLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_Avg_dLinescan
		Avg_Dendrite_Value = V_max 
	endif
	If (cmpstr(waveCursorIsOn, "Avg_dLinescan")==0)		
		CurveFit/Q exp_XOffset  Avg_dLinescan[pcsr(A),pcsr(B)] /X=linescan_time /D
		WaveStats/Q fit_Avg_dLinescan
		Avg_Dendrite_Value = V_max 
	endif

//	DoWindow Sigmoid_Coeff
//	If (V_flag == 0)
//		Edit/W=(260,250,420,365) W_coef
//		DoWindow/C Sigmoid_Coeff
//	endif
end


Function Erase_Fits(ctrlName)
	string ctrlName
	DoWindow/K Sigmoid_Coeff

	String waveCursorIsOn = CsrWave(A)				// Get info on what top graph is
	If (cmpstr(waveCursorIsOn, "sLinescan")==0)		
		RemoveFromGraph/Z fit_sLinescan, fit_dLinescan		
		KillWaves/Z fit_sLinescan, fit_dLinescan
	endif
	If (cmpstr(waveCursorIsOn, "dLinescan")==0)		
		RemoveFromGraph/Z fit_sLinescan, fit_dLinescan		
		KillWaves/Z fit_sLinescan, fit_dLinescan
	endif
	If (cmpstr(waveCursorIsOn, "Avg_sLinescan")==0)		
		RemoveFromGraph/Z fit_Avg_sLinescan, fit_Avg_dLinescan		
		KillWaves/Z fit_Avg_sLinescan, fit_Avg_dLinescan
	endif
	If (cmpstr(waveCursorIsOn, "Avg_dLinescan")==0)		
		RemoveFromGraph/Z fit_Avg_sLinescan, fit_Avg_dLinescan		
		KillWaves/Z fit_Avg_sLinescan, fit_Avg_dLinescan
	endif	
end

// Align_Transients function:	Calculates the first time the parent ephys sweep passes a user-defined Vm threshold
//							and aligns calcium transients to that time.  Useful for aligning isolated calcium-mediated
//							complex spikes riding on long depolarizations, or anything that is time-varying within a sweep.

Function Align_Transients(ctrlName)		// Control Window
	string ctrlName
	NewPanel/N=Align_Calcium_Transients/W=(490, 780, 660, 935)

	Variable/G Alignment_Check, diff_Check, threshold, Adjust_check
	threshold = -10
	SVAR Ca_Swp_Range
	SVAR LS_Swp_Range
	NVAR disk_sweep_no = disk_sweep_no

	
	Ca_Swp_Range = num2str(disk_sweep_no)+"-"+num2str(disk_sweep_no + 19)  // Set to 20 sweeps to start
	LS_Swp_Range = "1-20"
	
	SetVariable Threshold pos={5,10}, size={90,50}, limits={-100,100,0.1},title="Threshold", value = threshold
	SetVariable Swp_Rnge, pos ={5, 80}, size = {150,50}, title="ephys Swp Range", value = Ca_Swp_Range
	SetVariable LS_Swp_Rnge, pos ={5, 100}, size = {150,50}, title="LS Sweep Range ", value = LS_Swp_Range
	Checkbox Align_check, pos={5,34}, size={30,15}, title = "Look Between Cursors?", proc = Alignment_Check_Proc
	Button Run_Alignment, pos={15,123}, size={140, 25}, title = "Run Alignment", proc = Run_Alignment_Proc
	Checkbox diff, pos={118,5}, size={10, 25}, title = "\\JCMax\r\\JCdV/dt", proc = diff_Proc
	Drawtext 100, 25, "or"
	Checkbox Adjust_check, pos={5,54}, size={30,25}, title = "Adjust cursors w/each swp?", proc = Adjust_Check_Proc
end


Function Alignment_Check_Proc(ctrlName,checked) : CheckBoxControl	// outputs "alignment_check" variable (0 or 1), to tell "Run_alignment" procedure to calc between cursors or not
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	NVAR alignment_check	// 1 if checked, 0 if not
	
	If (checked ==1)
		alignment_check = 1
	else
		alignment_check = 0
	endif
end

Function diff_Proc(ctrlName,checked) : CheckBoxControl	// outputs "diff_check" variable (0 or 1), to tell "Run_alignment" procedure to calc based on threshold or max dV/dt
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	NVAR diff_check 			// 1 if checked, 0 if not

	If (checked ==1)
		diff_check = 1
	else
		diff_check = 0
	endif
end

Function Adjust_Check_Proc(ctrlName,checked) : CheckBoxControl	// outputs "adjust_check" variable (0 or 1), to tell "Run_alignment" whether cursors need to updated each sweep
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	NVAR Adjust_check	// 1 if checked, 0 if not
	
	If (checked ==1)
		Adjust_check = 1
	else
		Adjust_check = 0
	endif
end

Function Run_Alignment_Proc(ctrlName)
	string ctrlName

	SVAR Ca_Swp_Range = Ca_Swp_Range			// string description of sweep ranges for calcium averages.  Format:  X-Y
	SVAR LS_Swp_Range = LS_Swp_Range			// string of corresponding calcium transients. Format: X-Y
	NVAR threshold = threshold
	SVAR Expt = Expt
	NVAR alignment_check = alignment_check
	NVAR diff_check = diff_check
	NVAR Adjust_check = Adjust_check
	NVAR disk_sweep_no = disk_sweep_no
	Wave display_wave1 = display_wave1

	// Calculate time passing threshold for each sweep in range.	
	variable startswp, endswp, hyphen, posn, len, i1, i2, returnval, threshold_time_val, length

 	len = strlen(Ca_Swp_Range)
	posn = 0			
	hyphen = strsearch((Ca_Swp_Range),"-", posn)				// find hyphen
	startswp = str2num((Ca_Swp_Range)[posn, hyphen-1])
	endswp = str2num((Ca_Swp_Range)[hyphen+1, len])
	Make/O/N=(endswp-startswp+1) Threshold_Time				// Wave containing time display wave passes threshold, note that this indexes well to Ca Transients (i.e. value at 0 is for sLinescan0 and so on)
	Threshold_Time = 0										// Reset values
	Make/O/N=(numpnts(Threshold_Time)) Offset_Index			// Index of how many points need to be added to each wave
	Offset_Index = 0											// Reset values

	// Threshold-based run
	If (diff_check == 0)
		Find_Sweep(startswp,Expt)								// read first sweep of the subrange
		Read_Sweep(Expt)
		If (alignment_check == 1)									// If cursors are checked on, find the first iteration in display_wave1 where it passes threshold
			i2 = pcsr(A, "Sweep_window")
			do
				if (display_wave1[i2]>threshold)
					threshold_time_val = i2
					Break
				endif
				i2 += 1
			while (i2 < pcsr(B, "Sweep_window"))		
		else														// No cursors?  Runs through the entire sweep starting from the beginning.
			Wavestats/Q display_wave1
			length = v_npnts
			i2 = 0
			do
				if (display_wave1[i2]>threshold)
					threshold_time_val = i2
					Break
				endif
				i2 += 1
			while (i2 < length)	
		endif
		If (threshold_time_val == 0)								// Alert if threshold is not crossed.
			DoAlert 0, "Threshold was not crossed on sweep " + num2str(disk_sweep_no) +".  Dumb fuck."
			Abort
		endif
		Threshold_Time[0] = threshold_time_val
		i1 = startswp+1
		do
			returnval = Find_Next_Sweep(Expt)						// read subsequent sweeps and performs same calculation
			if (returnval > 0)
				Read_Sweep(Expt)			
				If (alignment_check == 1)
					If (Adjust_check == 1)
						UserCursorAdjust()
					endif
					i2 = pcsr(A, "Sweep_window")
					do
						if (display_wave1[i2]>threshold)
							threshold_time_val = i2
							Break
						else
							threshold_time_val = 0		// Reset threshold value to 0 if it can't find threshold, and alert user of issue
						endif
						i2 += 1
					while (i2 < pcsr(B, "Sweep_window"))	
				else
					Wavestats/Q display_wave1
					length = v_npnts
					i2 = 0
					do
						if (display_wave1[i2]>threshold)
							threshold_time_val = i2
							Break
						else
							threshold_time_val = 0		// Reset threshold value to 0 if it can't find threshold, and alert user of issue
						endif
						i2 += 1
					while (i2 < length)	
				endif
				If (threshold_time_val == 0)								// Alert if threshold is not crossed.
					DoAlert 0, "Threshold was not crossed on sweep " + num2str(disk_sweep_no)
					Abort
				endif
				Threshold_Time[i1-startswp] = threshold_time_val		// Indexes value.  Values are relative to digitization rate, not time.
			endif
			i1 += 1
		while ( (i1 < endswp+1) %& (returnval >0) )										// end of this subrange or couldn't find sweep
	else		// Max dV/dt-based run
		Find_Sweep(startswp,Expt)								// read first sweep of the subrange
		Read_Sweep(Expt)
		Smooth 500, display_wave1								// Smooth with a 50 msec gaussian, to isolate real max dV/dt
		Differentiate display_wave1									// Find peak
		If (alignment_check == 1)									// If cursors are checked on, find the first iteration in display_wave1 where it passes threshold
			i2 = pcsr(A, "Sweep_window")
			Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// Find max dV/dt between cursors
			do
				if (display_wave1[i2] == V_max)
					threshold_time_val = i2
					Break
				endif
				i2 += 1
			while (i2 < pcsr(B, "Sweep_window"))		
		else														// No cursors?  Runs through the entire sweep starting from the beginning.
			Wavestats/Q display_wave1
			length = v_npnts
			i2 = 0
			do
				if (display_wave1[i2] == V_max)
					threshold_time_val = i2
					Break
				endif
				i2 += 1
			while (i2 < length)	
		endif
		If (threshold_time_val == 0)								// Alert if threshold is not crossed.
			DoAlert 0, "Threshold was not crossed on sweep " + num2str(disk_sweep_no) +".  Dumb fuck."
			Abort
		endif
		Threshold_Time[0] = threshold_time_val
		i1 = startswp+1
		do
			returnval = Find_Next_Sweep(Expt)						// read subsequent sweeps and performs same calculation
			if (returnval > 0)
				Read_Sweep(Expt)
				If (alignment_check == 1)
					If (Adjust_check == 1)
						UserCursorAdjust()
					endif
					Smooth 500, display_wave1								// Smooth with a 50 msec gaussian, to isolate real max dV/dt
					Differentiate display_wave1									// Find peak	
					i2 = pcsr(A, "Sweep_window")
					Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// Find max dV/dt between cursors
					do
						if (display_wave1[i2] == V_max)
							threshold_time_val = i2
							Break
						else
							threshold_time_val = 0		// Reset threshold value to 0 if it can't find threshold, and alert user of issue
						endif
						i2 += 1
					while (i2 < pcsr(B, "Sweep_window"))	
				else
					Smooth 500, display_wave1								// Smooth with a 50 msec gaussian, to isolate real max dV/dt
					Differentiate display_wave1									// Find peak	
					Wavestats/Q display_wave1
					length = v_npnts
					i2 = 0
					do
						if (display_wave1[i2] == V_max)
							threshold_time_val = i2
							Break
						else
							threshold_time_val = 0		// Reset threshold value to 0 if it can't find threshold, and alert user of issue
						endif
						i2 += 1
					while (i2 < length)	
				endif
				If (threshold_time_val == 0)								// Alert if threshold is not crossed.
					DoAlert 0, "Threshold was not crossed on sweep " + num2str(disk_sweep_no)
					Abort
				endif
				Threshold_Time[i1-startswp] = threshold_time_val		// Indexes value.  Values are relative to digitization rate, not time.
			endif
			i1 += 1
		while ( (i1 < endswp+1) %& (returnval >0) )										// end of this subrange or couldn't find sweep	
		Read_Sweep(Expt)	// Back to un-differentiated state
	endif
	
	// Now we adjust sLinescan and dLinescans offset by threshold timing.  Note that original linescans will be overwritten (easy to recover from ImageJ source)
	
	NVAR kHz = kHz
	String Varlocate, dList, sList, dLS, sLS
	Variable i = 0
	Variable Offset
	
	ControlInfo/W=Linescan_Controls linescan_timestamp		// Recall ms_per_line value
	Varlocate = "ms_per_line"
	SVAR ms_per_line = $varlocate
	Threshold_Time = (Threshold_Time/(kHz))/((str2num(ms_per_line)))		// Convert threshold index from point in sweep to floored point in transient
	Threshold_Time = floor(Threshold_Time)								
	Wavestats/Q Threshold_Time										// Index of how many points need to be added to each wave
	Offset_Index = abs(Threshold_Time - V_max)

	dList = (WaveList("dGoverR*",";",""))		// Create Index of all dendrite GoverR data
	sList = (WaveList("sGoverR*",";",""))		// Create Index of all spine GoverR data	
	hyphen = strsearch((LS_Swp_Range),"-", posn)				// find hyphen in Linescan Sweep Range Input
	startswp = str2num((LS_Swp_Range)[posn, hyphen-1])		// find starting sweep for LS data.  note that it's offset by 1 in user domain
	
	do
		Offset = Offset_Index[i]
		dLS = StringFromList(i+startswp-1, dList)		// -1 to eliminate offset
		sLS = StringFromList(i+startswp-1, sList)	
		if (waveexists ($dLS) ==1)
			insertPoints 0, Offset, $dLS
		endif
		insertPoints 0, Offset, $sLS
		i += 1		
	while (i < numpnts(Offset_Index))
	
end

Function UserCursorAdjust()			// If user needs to adjust cursors between each sweep, this does it.  Ripped from Igor manual

	NewDataFolder/O root:tmp_PauseforCursorDF
	Variable/G root:tmp_PauseforCursorDF:canceled= 0

	NewPanel/K=2 /W=(139,300,280,400) as "Pause for Cursor"
	DoWindow/C tmp_PauseforCursor					// Set to an unlikely name
	AutoPositionWindow/E/M=1/R=Sweep_window		// Put panel near the graph


	DrawText 10,20,"Adjust the cursors and"
	DrawText 10,38,"then press Continue."
	Button button0,pos={20,48},size={92,20},title="Continue"
	Button button0,proc=UserCursorAdjust_ContButtonProc
	Button button1,pos={20,73},size={92,20}
	Button button1,proc=UserCursorAdjust_CancelBProc,title="Cancel"

	PauseForUser tmp_PauseforCursor, Sweep_window

	NVAR gCaneled= root:tmp_PauseforCursorDF:canceled
	Variable canceled= gCaneled			// Copy from global to local before global is killed
	KillDataFolder root:tmp_PauseforCursorDF

	return canceled
End

Function UserCursorAdjust_ContButtonProc(ctrlName) : ButtonControl
	String ctrlName
	DoWindow/K tmp_PauseforCursor			// Kill self
End

Function UserCursorAdjust_CancelBProc(ctrlName) : ButtonControl
	String ctrlName
	Variable/G root:tmp_PauseforCursorDF:canceled= 1
	DoWindow/K tmp_PauseforCursor			// Kill self
End

// Functions to place a line where the threshold or max dV/dt is in G_over_R_Avg graph.

Function Threshold_line_proc(ctrlName)
	String ctrlName
	String Varlocate

	ControlInfo/W=Linescan_Controls linescan_timestamp		// Recall ms_per_line value
	Varlocate = "ms_per_line"
	SVAR ms_per_line = $varlocate
	
	Wavestats/Q Threshold_Time
	Variable x_pos = (V_max)*(str2num(ms_per_line))/1000		// Position in time of line
	SetDrawLayer/W=G_over_R_Avg UserFront
	SetDrawEnv/W=G_over_R_Avg linefgc= (65280,0,0)
	SetDrawEnv/W=G_over_R_Avg xcoord= bottom,ycoord= abs
	Drawline/W=G_over_R_Avg x_pos,351,x_pos, 130.5
end

Function Erase_threshold_proc(ctrlName)
	String ctrlName
	
	SetDrawLayer/W=G_over_R_Avg/K UserFront
end

// Functions to sort Ch1 and Ch2 tif files into subfolders named Alexa and Fluo

Function FileSortWindow()

	NewPanel/W=(10, 550, 730, 610)
	DoWindow/C File_Sort_Window
	String/G folder_path
	
	SetVariable folder_path pos={10,8}, size={700,30}, title="Path", value=folder_path, fsize=10
	Button Sort_files pos = {400, 32}, title = "Sort Linescans into subfolders", size = {170, 25}, proc = FileSort
	Button Close_sort pos = {20, 32}, title = "Close", size = {50, 25}, proc = Close_FileSort

end

Function FileSort(ctrlname)
	String ctrlname
	//The aim of this procedure is to identify a windows folder and then sort files within that folder
	//into separate folders based on the presence of "Ch1" or "Ch2" in the file names
	
	Variable fileindex, Ch1check, Ch2check
	String FolderPath, Ch1FolderPath, Ch2FolderPath, CurrentFile, CurrentFilePath
	
	String FileListString, varlocate
	
	//Prompt user to select folder
	ControlInfo/W=File_Sort_Window folder_path
	Varlocate = "folder_path"
	SVAR folder_path = $varlocate
		
	GetFileFolderInfo /D/Q folder_path
	If (V_flag!=0)
		DoAlert 0, "Folder not selected.  Function canceled."
		Return -1
	Endif
	FolderPath = S_path
	
	//Make Ch1 and Ch2 folders in the selected file folder
	Ch1FolderPath = FolderPath+"Alexa"		// Name in quotes will be new folder name.
	Ch2FolderPath = FolderPath+"Fluo"
	NewPath /Q/O SelectedFolder, FolderPath
	NewPath /C/Q/O Ch1Folder, Ch1FolderPath
	NewPath /C/Q/O Ch2Folder, Ch2FolderPath
		
	//Sort files into folders
	FileListString = IndexedFile (SelectedFolder, -1, ".tif")

	fileindex=0
	Do
		CurrentFile = StringFromList(fileindex, FileListString)
		If (Strlen(CurrentFile) == 0)
			break
		Endif
		CurrentFilePath = FolderPath+CurrentFile
		Ch1Check = strsearch (CurrentFile, "Ch1_Image", 0, 2)		// String in quotes should be unique and repeatable to all Ch1 images
		Ch2Check = strsearch (CurrentFile, "Ch2_Image", 0, 2)
		Ch1Check = strsearch (CurrentFile, "Settings_Ch1", 0, 2)		// String in quotes should be unique and repeatable to all Ch1 images
		Ch2Check = strsearch (CurrentFile, "Settings_Ch2", 0, 2)
		If (Ch1Check != -1)
			MoveFile /D CurrentFilePath as Ch1FolderPath
			//print CurrentFilePath+" Ch1"
		Elseif (Ch2check != -1)
			MoveFile /D CurrentFilePath as Ch2FolderPath
			//print CurrentFilePath+" Ch2"
		Endif
	
		fileindex += 1
				
	While (1)
		
End		//end of FileSort

Function Close_FileSort(ctrlname)
	string ctrlname
	
	DoWindow/K File_Sort_Window
end


//----------------------------------------------------------------------------------------------------------------------------------------------

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Spike analysis toolbox:		Makes calculations of spike parameters.  Make sure you place your cursors around the spike!
//							It's also a good idea to sample at 50 kHz or higher... but that's up to you.
//
//			This toolbox calculates:												Corresponding wave:
//					Threshold Vm (defined as max of 3rd derivative)							Thresh_Vm
//					Threshold timing														Thresh_time
//					Peak Amp and timing													Peak_Vm; Peak_time
//					Peak Repolarization (i.e., repolarization Vmin)							Peak_Repol
//					Spike amplitude (Peak Amp - Peak Repol)								Spike_amp
//					Spike width (width @ 1/2 max, 1/2 max = Peak amp - 1/2 spike amp)		Spike_width
//					Max rising and falling dV/dt											Rise_dVdt; Fall_dVdt
//		
//							v 1.0 KJB 052408
//
//		Dan, add this to "Menu "--Analyses--"":	"Spike Analysis Toolbox", Spike_toolbox_window()
//
//			Waves to kill in "CleanUp()"
//				Killwaves/Z Thresh_Vm, Thresh_time, Peak_Vm, Peak_time, Peak_Repol, Spike_amp, Spike_width, Rise_dVdt, Fall_dVdt, stim_onset
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


Function Spike_toolbox_window()		// Control Window
	NewPanel/N=Spike_Toolbox/W=(20, 180, 190, 335)

	make/o/n=1 stim_onset = 400

	Variable/G Adjust_spike_toolbox_check
	SVAR Ca_Swp_Range
	NVAR disk_sweep_no = disk_sweep_no
	
	Ca_Swp_Range = num2str(disk_sweep_no)+"-"+num2str(disk_sweep_no + 9)  // Set to 10 sweeps to start
	
	SetVariable Stim_onset, pos ={5, 82}, size = {150,50}, title="Stimulus onset (ms)", value = stim_onset
	SetVariable Swp_Rnge, pos ={5, 62}, size = {150,50}, title="Sweep Range", value = Ca_Swp_Range
	Button Run_spike_toolbox, pos={7,123}, size={100, 25}, title = "Analyze Spikes", proc = Run_spike_toolbox
	Button Close_spike_toolbox, pos = {115,123}, size={50,25}, title = "Close", proc = Close_spike_toolbox
	Drawtext 10, 40, "Place cursors around spike"
	Drawtext 10, 55, "& specify swp range XX-YY"
	Checkbox Adjust_spike_toolbox_check, pos={5,100}, size={30,25}, title = "Adjust cursors w/each swp?", proc = Adjust_spike_toolbox_Check_Proc
	Setdrawenv fsize = 14
	Drawtext 10, 20, "Spike Analyzer"
end


Function Cursor_Check_Proc(ctrlName,checked) : CheckBoxControl	// outputs "alignment_check" variable (0 or 1), to tell "Run_alignment" procedure to calc between cursors or not
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	NVAR Cursor_check	// 1 if checked, 0 if not
	
	If (checked ==1)
		Cursor_check = 1
	else
		Cursor_check = 0
	endif
end

Function Adjust_spike_toolbox_Check_Proc(ctrlName,checked) : CheckBoxControl	// outputs "adjust_check" variable (0 or 1), to tell "Run_alignment" whether cursors need to updated each sweep
	String ctrlName
	Variable checked					// 1 if checked, 0 if not
	NVAR Adjust_spike_toolbox_check	// 1 if checked, 0 if not
	
	If (checked ==1)
		Adjust_spike_toolbox_check = 1
	else
		Adjust_spike_toolbox_check = 0
	endif
end

Function Run_spike_toolbox(ctrlName)
	string ctrlName

	SVAR Ca_Swp_Range = Ca_Swp_Range			// string description of sweep ranges for calcium averages.  Format:  X-Y
	SVAR Expt = Expt
	NVAR Adjust_spike_toolbox_check = Adjust_spike_toolbox_check
	NVAR disk_sweep_no = disk_sweep_no
	Wave display_wave1 = display_wave1
	Wave stim_onset = stim_onset
	NVAR kHz = kHz

	// Calculate time passing threshold for each sweep in range.	
	variable startswp, endswp, hyphen, posn, len, i1, i2, returnval, threshold_time_val, length, threshold_temp, half_height, Half_rise_time, Half_fall_time

 	len = strlen(Ca_Swp_Range)
	posn = 0			
	hyphen = strsearch((Ca_Swp_Range),"-", posn)				// find hyphen
	startswp = str2num((Ca_Swp_Range)[posn, hyphen-1])
	endswp = str2num((Ca_Swp_Range)[hyphen+1, len])
	Make/O/N=1 Thresh_Time				// Wave containing timing of V_thresh
	Thresh_Time = 0							// Reset values
	Make/O/N=1 Peak_Time				// Wave containing timing of Peak_time (i.e., spike timing)
	Peak_Time = 0							// Reset values



	// Run the analysis on the first sweep of the set
		Find_Sweep(startswp,Expt)								// read first sweep of the subrange
		Read_Sweep(Expt)

			i2 = pcsr(A, "Sweep_window")
			
			Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// First find peak
			Make/O/N=1 Peak_Vm = V_max
			do
				if (display_wave1[i2] == V_max)
					Peak_time = i2/kHz-stim_onset					// Time of Vmax in msec
					Wavestats/Q/R=[i2, pcsr(B, "Sweep_window")] Display_wave1	// First repolarization value
					Make/O/N=1 Peak_Repol = V_min		// Peak repol must follow peak, right?
					Break
				endif
				i2 += 1
			while (i2 < pcsr(B, "Sweep_window"))
			Make/O/N=1 Spike_amp = Peak_Vm - Peak_Repol

		// Code for spike width
			half_height = Peak_Vm - (0.5*Spike_amp)
			i2 = pcsr(A, "Sweep_window")
			do
				if (display_wave1[i2] >=half_height)
					Half_rise_time = i2/kHz					// Time of 1/2 max rise in msec
					Break
				endif
				i2 += 1
			while (i2 < pcsr(B, "Sweep_window"))
			i2 =Half_rise_time*kHz							// Now search for 1/2 fall, from 1/2 rise point
			do
				if (display_wave1[i2] <=half_height)
					Half_fall_time = i2/kHz					// Time of 1/2 fall rise in msec
					Break
				endif
				i2 += 1
			while (i2 < pcsr(B, "Sweep_window"))	
			Make/O/N=1 Spike_width = Half_fall_time - Half_rise_time
			
		
		// Code for dV/dt's	
			Differentiate display_wave1								// take first derivative, then find dV/dt max and min from this
			display_wave1 = display_wave1/1000
			Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// Find max dV/dt between cursors
			Make/O/N=1 Rise_dVdt = V_max
			Make/O/N=1 Fall_dVdt = V_min

		// Code to calculate threshold
			Differentiate display_wave1			// second derivative... on the way to spike threshold
			Differentiate display_wave1			// and one more time for fun.  Peak is spike threshold (Thresh_Vm)
			Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// Find threshold
			i2 = pcsr(A, "Sweep_window")
			do
				if (display_wave1[i2] == V_max)
					Thresh_time = i2/kHz					// Time of Threshold in msec
					Break
				endif
				i2 += 1
			while (i2 < pcsr(B, "Sweep_window"))					// Searches for the inflection between cursor A and 0.1 ms before the spike peak, to avoid spurious results around spike peak
			Read_Sweep(Expt)	// Back to un-differentiated state
			Make/O/N=1 Thresh_Vm = (Display_wave1[Thresh_time*kHz])
			Thresh_time = thresh_time - stim_onset

		// Now run analysis on all subsequent sweeps
		i1 = startswp+1
		do
			returnval = Find_Next_Sweep(Expt)						// read subsequent sweeps and performs same calculation
			if (returnval > 0)
				Read_Sweep(Expt)

					If (Adjust_spike_toolbox_check == 1)
						UserCursorAdjust_Spike_Toolbox()
					endif
					i2 = pcsr(A, "Sweep_window")
			
					Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// First find peak
					redimension/N=(numpnts(Peak_Vm)+1), Peak_Vm
					Peak_Vm[numpnts(Peak_Vm)] = V_max
					do
						if (display_wave1[i2] == V_max)
							redimension/N=(numpnts(Peak_time)+1), Peak_time
							Peak_time[numpnts(Peak_time)] = i2/kHz- stim_onset					// Time of Vmax in msec
							Wavestats/Q/R=[i2, pcsr(B, "Sweep_window")] Display_wave1	// First repolarization value
							redimension/N=(numpnts(Peak_Repol)+1), Peak_Repol
							Peak_Repol[numpnts(Peak_Repol)] = V_min					// Peak repol must follow peak, right?
							Break
						endif
						i2 += 1
					while (i2 < pcsr(B, "Sweep_window"))
					Redimension/N=(numpnts(Spike_amp)+1), Spike_amp
					Spike_amp[numpnts(Spike_amp)] = Peak_Vm[numpnts(Peak_Vm)] - Peak_repol[numpnts(Peak_Repol)]	
					
				// Code for spike width
					half_height = Peak_Vm[numpnts(Peak_Vm)] - (0.5*Spike_amp[numpnts(Spike_amp)])
					i2 = pcsr(A, "Sweep_window")
					do
						if (display_wave1[i2] >=half_height)
							Half_rise_time = i2/kHz					// Time of 1/2 max rise in msec
							Break
						endif
						i2 += 1
					while (i2 < pcsr(B, "Sweep_window"))
					i2 =Half_rise_time*kHz							// Now search for 1/2 fall, from 1/2 rise point
					do
						if (display_wave1[i2] <=half_height)
							Half_fall_time = i2/kHz					// Time of 1/2 fall rise in msec
							Break
						endif
						i2 += 1
					while (i2 < pcsr(B, "Sweep_window"))	
					Redimension/N=(numpnts(Spike_width)+1), Spike_width
					Spike_width[numpnts(Spike_width)] = Half_fall_time - Half_rise_time
			
				// Code for dV/dt's	
					Differentiate display_wave1								// take first derivative, then find dV/dt max and min from this
					display_wave1 = display_wave1/1000
					Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// Find max dV/dt between cursors
					redimension/N=(numpnts(Rise_dVdt)+1), Rise_dVdt
					Rise_dVdt[numpnts(Rise_dVdt)] = V_max			
					redimension/N=(numpnts(Fall_dVdt)+1), Fall_dVdt
					Fall_dVdt[numpnts(Fall_dVdt)] = V_min	


				// Code to calculate threshold
					Differentiate display_wave1			// second derivative... on the way to spike threshold
					Differentiate display_wave1			// and one more time for fun.  Peak is spike threshold (Thresh_Vm)
					Wavestats/Q/R=[pcsr(A, "Sweep_window"), pcsr(B, "Sweep_window")] Display_wave1	// Find threshold
					i2 = pcsr(A, "Sweep_window")
					do
						if (display_wave1[i2] == V_max)
							redimension/N=(numpnts(Thresh_time)+1), Thresh_time
							Thresh_time[numpnts(Thresh_time)] = i2/kHz			// Time of Threshold in msec
							Break
						endif
						i2 += 1
					while (i2 < pcsr(B, "Sweep_window"))		// Searches for the inflection between cursor A and 0.1 ms before the spike peak, to avoid spurious results around spike peak
					Read_Sweep(Expt)	// Back to un-differentiated state			
					redimension/N=(numpnts(Thresh_Vm)+1), Thresh_Vm
					Thresh_Vm[numpnts(Thresh_Vm)] = (Display_wave1[Thresh_time*kHz])
					Thresh_time[numpnts(Thresh_time)] = Thresh_time[numpnts(Thresh_time)]- stim_onset			
			endif
			i1 += 1
		while ( (i1 < endswp+1) %& (returnval >0) )										// end of this subrange or couldn't find sweep	
		Read_Sweep(Expt)	// Back to un-differentiated state
	DoWindow/K Spike_statistics
	edit/W=(10,280,880,480)/N=spike_statistics Thresh_Vm, Thresh_time, Peak_Vm, Peak_time, Peak_Repol, Spike_amp, Spike_width, Rise_dVdt, Fall_dVdt
end

Function UserCursorAdjust_Spike_Toolbox()			// If user needs to adjust cursors between each sweep, this does it.  Ripped from Igor manual

	NewDataFolder/O root:tmp_PauseforCursorDF
	Variable/G root:tmp_PauseforCursorDF:canceled= 0

	NewPanel/K=2 /W=(139,300,280,400) as "Pause for Cursor"
	DoWindow/C tmp_PauseforCursor					// Set to an unlikely name
	AutoPositionWindow/E/M=1/R=Sweep_window		// Put panel near the graph


	DrawText 10,20,"Adjust the cursors and"
	DrawText 10,38,"then press Continue."
	Button button0,pos={20,48},size={92,20},title="Continue"
	Button button0,proc=ContButtonProc_ST
	Button button1,pos={20,73},size={92,20}
	Button button1,proc=CancelBProc_ST,title="Cancel"

	PauseForUser tmp_PauseforCursor, Sweep_window

	NVAR gCaneled= root:tmp_PauseforCursorDF:canceled
	Variable canceled= gCaneled			// Copy from global to local before global is killed
	KillDataFolder root:tmp_PauseforCursorDF

	return canceled
End

Function ContButtonProc_ST(ctrlName) : ButtonControl
	String ctrlName
	DoWindow/K tmp_PauseforCursor			// Kill self
End

Function CancelBProc_ST(ctrlName) : ButtonControl
	String ctrlName
	Variable/G root:tmp_PauseforCursorDF:canceled= 1
	DoWindow/K tmp_PauseforCursor			// Kill self
End

Function Close_spike_toolbox(ctrlName)
	String ctrlName
	DoWindow/K Spike_Toolbox
End

//-------------------Command line entry for spike train analysis-------------------------------------------------------------
//
//			Code modified from Michael T Roberts, PhD    Emailed 020813,  mtroberts111@gmail.com
//
//			To use, enter this in the command line:	
//			SpikeTrainAnalysis (WaveIn, StartPnt, EndPnt, DetectionThreshold)
//				
//				values noted in function immediately below this bulletin.
//				Most commonly, we would enter   SpikeTrainAnalysis(display_wave1, 0.1, 0.4, -30)
//
//			Picks out Spike peak timings (in seconds relative to sweep onset), calculates ISI, instantaneous freq), threshold timing and voltage (from peak of 3rd derivative), and AHP values.
//				relevant corresponding waves are
//
//					SpikePeakLocs				(sec)
//					SpikeThresholdsLoc			(sec)
//					SpikeThresholdsAmp			(mV)
//					SpikeISIs					(sec)
//					SpikeInstFreq				(Hz)
//					SpikeAHPamps 				(mV)		note that AHP after last spike is not reported
//
//
//----------------------------------------------------------------------------------------------------------------------------------------------------


Function SpikeTrainAnalysis (WaveIn, StartPnt, EndPnt, DetectionThreshold)
	
	Wave WaveIn		//Data wave to analyze
//	Variable baseline	//Y value (in mV) of basline		//KJB took this out, it's not used in our analysis as of Feb 2013
	Variable StartPnt	//point value indicating where spike train analysis should begin
	Variable EndPnt		//point value indicating where spike train analysis should end
	Variable DetectionThreshold	//Y value that when crossed indicates start or end of action potential
	NVAR kHz = kHz			// KJB, To convert point data to actual timings	
		
	Variable Xwindow = 3*kHz			// Looks for spike threshold within 3 milliseconds of spike peak.  If your spikes are slower, you're recording at room temp and are screwing up.
	Variable ThreshMethod = 2		//threshold detection method; 1=2nd derivative, 2=3rd derivative
	

	StartPnt *= kHz*1000		// Start and end points entered in seconds, converts to data point in wave
	EndPnt *= kHz*1000
	
	//Determine start and end points of each spike based on when DetectionThreshold is crossed
	//Generate wave to hold these values
	Make /N=(0,2)/O SpikeBoundaries
	STA_DetectSpikes (WaveIn, SpikeBoundaries, StartPnt, EndPnt, DetectionThreshold)
	
	//Check to make sure that spikes were detected in WaveIn
	//If not, end function with return value of -100
	If (DimSize(SpikeBoundaries,0)==0)
		Return -100
	Endif
	
	//Determine where the peak of each action potential occurs (in points)
	Make /N=0/O SpikePeakLocs
	STA_SpikePeakDetect (WaveIn, SpikeBoundaries, SpikePeakLocs)
	
	//Determine the point and Y values for the threshold for each action potential in the train
	Make /N=0/O SpikeThresholdsLoc
	Make /N=0/O SpikeThresholdsAmp
	STA_FindSpikeThresholds (WaveIn, SpikePeakLocs, SpikeThresholdsLoc, SpikeThresholdsAmp, Xwindow,threshmethod)
	
	//Determine spike peak amp in several ways
//	Make /N=0/O SpikeAbsAmp			//holds absolute Y values for spike peaks
//	Make /N=0/O SpikeRelThreshAmp	//holds amplitude of peaks above threshold
//	Make /N=0/O SpikeRelBlineAmp	//holds amplitude of peaks above baseline
//	STA_SpikePeakData (WaveIn, SpikePeakLocs, SpikeThresholdsAmp, SpikeAbsAmp, SpikeRelThreshAmp, SpikeRelBlineAmp, baseline)
	
	//Determine inter-spike intervals
	Make /N=0/O SpikeISIs
	STA_SpikeISI (WaveIn, SpikePeakLocs, SpikeISIs)
	
	//Determine most negative value during ISI --> AHP
	Make /N=0/O SpikeAHPamps
	STA_SpikeAHP (WaveIn, SpikeBoundaries, SpikeAHPamps)
	
	//Determine FWHM of each spike in train
//	Make /N=0/O SpikeFWHMs
//	STA_SpikeFWHM_RelThresh (WaveIn, SpikePeakLocs, SpikeThresholdsAmp, SpikeFWHMs, Xwindow)
	
	//Determine the 10-90% rise time of each AP
//	Make /N=0/O SpikeRiseTimes
//	STA_Spike10to90RiseTime (WaveIn, SpikePeakLocs, SpikeRelThreshAmp, SpikeRiseTimes, Xwindow)
		
//	Edit SpikeBoundaries, SpikePeakLocs, SpikeThresholdsLoc, SpikeThresholdsAmp, SpikeAbsAmp, SpikeRelThreshAmp, SpikeRelBlineAmp
//	AppendtoTable SpikeISIs, SpikeAHPAmps, SpikeFWHMs, SpikeRiseTimes, SpikeDecayTaus

	SpikePeakLocs /= (kHz * 1000)  // KJB converts values to seconds
	SpikeThresholdsLoc /= (kHz * 1000)  // KJB converts values to seconds
	Make/O/n=(numpnts(SpikeISIs)) SpikeInstFreq = 1/SpikeISIs

	Return numpnts(SpikePeakLocs)

End		//end of SpikeAnalysis

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_DetectSpikes (WaveIn, WaveOut, StartPnt, EndPnt, Threshold)

	//Purpose:	To analyze a region of WaveIn, defined by StartPnt and EndPnt, to
	//			detect action potentials based on Threshold crossings.  Function will
	//			return data in WaveOut.
	
	Wave WaveIn		//wave to analyze
	Wave WaveOut		//2D wave with 0 pnts but two columns to hold start point and
						//end point of each detcted action potential.
	Variable StartPnt	//point value defining start of wave region to analyze
	Variable EndPnt		//point value defining end of wave region to analyze
	Variable Threshold	//Y-value, normally in mV, the crossing of which indicates
						//the start of an action potential
						
	//Find threshold crossings
	Variable APstartPnt, APendPnt
	Make /N=0/O STA_Tempwave1
	FIndLevels /B=3 /D=STA_Tempwave1 /P /Q /R=[StartPnt, EndPnt] WaveIn, Threshold

	//Format output into 2D wave with start of each spike in column 0 and end in column 1
	InsertPoints /M=0 inf, numpnts(STA_Tempwave1)/2, WaveOut
	WaveOut [][0] = round(STA_Tempwave1[2*p])
	WaveOut [][1] = round(STA_Tempwave1[2*p+1])
	KillWaves /Z STA_Tempwave1	
	
	Return 0

End		//end STA_DetectSpikes

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_SpikePeakDetect (WaveIn, SpikeBoundaries, WaveOut)

	//Purpose: To determine the point (X) values of the peaks of action potentials
	//			in WaveIn located between the start and end points defined by the
	//			2D input wave APStartEndWave.  Return these values in WaveOut.
	
	Wave WaveIn			//data wave to analyze
	Wave SpikeBoundaries	//wave holding output of STA_DetectSpikes; i.e. point values
							//defining points before and after each spike in the train
	Wave WaveOut			//wave to hold peak point values
	
	Variable i
	For (i=0; i < DimSize(SpikeBoundaries,0); i+=1)
		WaveStats /Q/R=[SpikeBoundaries[i][0],SpikeBoundaries[i][1]] WaveIn
		InsertPoints /M=0 DimSize(WaveOut,0), 1, WaveOut
		WaveOut[DimSize(WaveOut,0)-1] = x2pnt(WaveIn,V_maxloc)
	Endfor
	
	
	Return 0
	
End		//end of STA_SpikePeakDetect

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_FindSpikeThresholds (WaveIn, SpikePeakLocs, SpikeThresholdsLoc, SpikeThresholdsAmp, Xwindow, method)

	//Purpose:	To find the action potential threshold for each spike in a train.  This function
	//			currently defines threshold as the peak in the 2nd derivative of WaveIn within
	//			Xwindow ms of the spike peak
	
	
	Wave WaveIn				//data wave to analyze
	Wave SpikePeakLocs		//Holds point locations of action potential peaks.  Output of 
								//STA_SpikePeakDetect
	Wave SpikeThresholdsLoc	//output wave, holding point location of action potential thresholds
								//for each spike in train
	Wave SpikeThresholdsAmp	//output wave, holding Y values for action potential thresholds
								//for each spike in train
	Variable Xwindow			//time, usually in ms, to search for peak of derivative to the left
								//of the spike peak
	Variable method				//Switch indicating which method to use to find threshold.
								//1 indicates second derivative
								//2 indicates third derivative
	Variable i

	NVAR kHz = kHz
	
	Switch (method)

		case 1:		//second derivative	
			//Make temporary wave holding second derivative of WaveIn
			Make /N=0/O temp_d2vdtwave
			Differentiate WaveIn /D=d2vdtwave
			Differentiate d2vdtwave
			
			//Find threshold for each action potential in train
			For (i=0; i<numpnts(SpikePeakLocs); i+=1)
				InsertPoints inf, 1, SpikeThresholdsLoc, SpikeThresholdsAmp
				WaveStats /Q/R=(pnt2x(WaveIn, (SpikePeakLocs[i])-Xwindow), pnt2x(WaveIn, SpikePeakLocs[i])) d2vdtwave		
				SpikeThresholdsLoc[i] = x2pnt(WaveIn, V_maxloc)
				SpikeThresholdsAmp[i] = WaveIn[x2pnt(d2vdtwave,V_maxloc)]
			Endfor
			KillWaves /Z d2vdtwave
		
		case 2:		//third derivative
			//Make temporary wave holding third derivative of WaveIn
			Make /N=0/O temp_d3vdtwave
			Differentiate WaveIn /D=d3vdtwave
			Differentiate d3vdtwave
			Differentiate d3vdtwave
						
			//Find threshold for each action potential in train
			For (i=0; i<numpnts(SpikePeakLocs); i+=1)
				InsertPoints inf, 1, SpikeThresholdsLoc, SpikeThresholdsAmp
				WaveStats /Q/R=(pnt2x(WaveIn, (SpikePeakLocs[i])-Xwindow), pnt2x(WaveIn, SpikePeakLocs[i])) d3vdtwave	
				SpikeThresholdsLoc[i] = x2pnt(WaveIn, V_maxloc)
				SpikeThresholdsAmp[i] = WaveIn[x2pnt(d3vdtwave,V_maxloc)]
			Endfor
			KillWaves /Z d3vdtwave	

		default:		//method selection incorrect
			Return -1

	Endswitch
					
	Return 0


End		//end of STA_FindSpikeThresholds

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_SpikePeakData (WaveIn, SpikePeakLocs, SpikeThresholds, SpikeAbsAmp, SpikeRelThreshAmp, SpikeRelBlineAmp, baseline)

	//Purpose:	To determine the absolute, relative to baseline, and relative to
	//			threshold amplitudes of action potentials.  The X locations of spike
	//			peaks are defined in SpikePeakLocs.
	
	Wave WaveIn				//data wave to analyze
	Wave SpikePeakLocs		//Holds point locations of action potential peaks.  Output of 
								//STA_SpikePeakDetect
	Wave SpikeThresholds		//Holds threshold values in mV for each spike.  Output of
								//???
	Wave SpikeAbsAmp			//holds absolute Y values for spike peaks
	Wave SpikeRelThreshAmp	//holds amplitude of peaks above threshold
	Wave SpikeRelBlineAmp		//holds amplitude of peaks above baseline
	Variable baseline			//absolute value of baseline
	
	NVAR kHz = kHz
	
	Variable i
	For (i=0; i<numpnts(SpikePeakLocs); i+=1)
		InsertPoints inf, 1, SpikeAbsAmp, SpikeRelThreshAmp, SpikeRelBlineAmp
		SpikeAbsAmp[i] = WaveIn[SpikePeakLocs[i]]
		SpikeRelThreshAmp[i] = WaveIn[SpikePeakLocs[i]] - SpikeThresholds[i]
		SpikeRelBlineAmp[i] = WaveIn[SpikePeakLocs[i]] - baseline
	Endfor
	
	Return 0

End

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_SpikeISI (WaveIn, SpikePeakLocs, WaveOut)

	//Purpose:	To calculate the interspike interval (ISI) between subsequent action
	//			potentials based on the time of action potential peaks provided by
	//			the first column of SpikePeakWave.
	
	Wave WaveIn			//data wave to analyze
	Wave SpikePeakLocs	//wave holding point values for each AP peak. Output
							//of STA_SpikePeakData
	Wave WaveOut			//1D wave to hold ISI values in X units (not points).
	
	Variable i
	For (i=0; i<numpnts(SpikePeakLocs)-1; i+=1)
		InsertPoints numpnts(WaveOut), 1, WaveOut
		WaveOut[numpnts(WaveOut)-1] = pnt2x(WaveIn,SpikePeakLocs[i+1]) - pnt2x(WaveIn,SpikePeakLocs[i])
	Endfor
	
	Return 0

End		//end of STA_SpikePeakData

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_SpikeAHP (WaveIn, SpikeBoundaries, WaveOut)

	//Purpose:	To calculate the maximal extent of repolarization (AHP peak) between
	//			subsequent action potentials in a spike train.
	
	Wave WaveIn			//Data wave to analyze
	Wave SpikeBoundaries	//2D wave holding X and Y values for each AP peak. Output
							//of STA_SpikePeakData
	Wave WaveOut			//1D wave to hold AHP peak (min) values
							
	Variable i
	For (i=0; i<DimSize(SpikeBoundaries,0)-1; i+=1)
		InsertPoints numpnts(WaveOut), 1, WaveOut
		WaveStats /Q/R=[SpikeBoundaries[i][1],SpikeBoundaries[i+1][1]] WaveIn
		WaveOut[numpnts(WaveOut)-1] = V_min
	Endfor
	
	Return 0
	
End		//end of STA_SpikeAHP

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_SpikeFWHM_RelThresh (WaveIn, SpikePeakLocs, SpikeThresholdsAmp, WaveOut, Xwindow)

	//Purpose:	To calculate the full-width at half maximum of spikes in a spike train,
	//			Here, half-maximum is defined as half-way between AP threshold and
	//			and AP peak amplitude.
	
	Wave WaveIn				//data wave to analyze
	Wave SpikePeakLocs		//Wave holding point values of AP peaks
	Wave SpikeThresholdsAmp	//Wave holding absolute Y values of AP thresholds
	Wave WaveOut				//ouput wave to hold FWHM values
	Variable Xwindow			//specifies time in X units to search before and after peak for half-max

	Variable i, halfmax, X1, X2
	For (i=0; i<numpnts(SpikePeakLocs); i+=1)
		halfmax = SpikeThresholdsAmp[i] + (WaveIn[SpikePeakLocs[i]] - SpikeThresholdsAmp[i])/2
		//Backward search
		FindLevel /B=3/Q/R=[SpikePeakLocs[i], SpikePeakLocs[i]-x2pnt(WaveIn,Xwindow)] WaveIn, halfmax
		X1 = V_levelX
		//Forward search
		FindLevel/B=3/Q/R=[SpikePeakLocs[i], SpikePeakLocs[i]+x2pnt(WaveIn,Xwindow)] WaveIn, halfmax
		X2 = V_levelX
		InsertPoints inf, 1, WaveOut
		WaveOut[i] = X2-X1
	Endfor

End

//_____________________________________________________________________
//_____________________________________________________________________

Function STA_Spike10to90RiseTime (WaveIn, SpikePeakLocs, SpikeRelThreshAmp, SpikeRiseTimes, Xwindow)

	//Purpose:	To calculate the 10% to 90% rise time of action potentials in a spike train.
	//			10 to 90% range is determined from action potential threshold to peak.
	
	Wave WaveIn				//data wave to analyze
	Wave SpikePeakLocs		//point location of AP peaks
	Wave SpikeRelThreshAmp	//amplitude of spike peak above spike threshold
	Wave SpikeRiseTimes		//output wave to hold 10 to 90% rise times
	Variable Xwindow			//time window to search prior to spike peak to find 10 and 90%
								//level crossings
	
	Variable i, TenPcntLevel, NinetyPcntLevel, TenPcntX, NinetyPcntX
	For (i=0; i<numpnts(SpikePeakLocs); i+=1)
		//Find X values where spike crosses 10% and 90% levels
		TenPcntLevel = WaveIn[SpikePeakLocs[i]] - (0.9 * SpikeRelThreshAmp[i])
		NinetyPcntLevel = WaveIn[SpikePeakLocs[i]] - (0.1 * SpikeRelThreshAmp[i])
		FindLevel /B=1 /Q /R=[SpikePeakLocs[i], SpikePeakLocs[i]-x2pnt(WaveIn,Xwindow)] WaveIn, TenPcntLevel
		TenPcntX = V_LevelX
		FindLevel /B=1 /Q /R=[SpikePeakLocs[i], SpikePeakLocs[i]-x2pnt(WaveIn,Xwindow)] WaveIn, NinetyPcntLevel
		NinetyPcntX = V_LevelX
	
		//Calculate and store 10 to 90% rise time
		InsertPoints inf, 1, SpikeRiseTimes
		SpikeRiseTimes[numpnts(SpikeRiseTimes)-1] = NinetyPcntX - TenPcntX
	Endfor
	
	Return 0
	
End		//end of STA_Spike10to90RiseTime



//_____________________________________________________________________
//_____________________________________________________________________


//--------------------END OF SPIKE ANALYSIS TOOLBOX----------------------------------------------------------------------



//--------------------START EXPORT STUFF----------------------------------------------------------------------
// CREATES GUI TO EXPORT THE FOLLOWING RAW DATA INTO TEXT FILES:
// Raw sweeps (saved in matrix with columns representing sweeps)
// Commands (saved in matrix with columns representing command sweeps)
// Temperature (saved in vector with one value for each sweep)
// Sweep Timees (saved in vector with the value in seconds of the time that each sweep occurred)
// Written by JCA & KJB2 08/21/14

Function Make_Export_Window()
	SVAR Expt=Expt	
	String/G expPathRaw =  "C:Data:Export:" 	// name of path for data of interest
	String/G expPathCust = "C:Data:Default:"
	String/G custWaveName = "myWave"
	String/G custFileName = "myIgorBinaryWaveFile"
	
	//Savenames are same as raw data .ibt filename with suffix for type of data saved
	String/G sweepFile=Expt+"_rawsweeps"  
	String/G commandFile=Expt+"_commands"
	String/G tempFile=Expt+"_temperature"
	String/G timeFile=Expt+"_sweeptimes"
	
	NewPanel/W=(10, 380, 490, 550) as "Export Control Bar"
	DoWindow/C ExportCont					
	SetVariable expOutRaw pos={10,35}, size={210,25}, title="Export Path", value=expPathRaw, fsize=10 
	Drawtext 70,20, "Raw File Export"
	Checkbox SweepCheck, pos = {10,65}, title = " ", proc = sweepCheckProc
	Drawtext 25,80, "Raw Sweeps"
	Checkbox CommandCheck, pos = {10,95}, title = " ", proc = commandCheckProc  
	Drawtext 25,110, "Commands"
	Checkbox TempCheck, pos = {130,65}, title = " ", proc = tempCheckProc
	Drawtext 145,80, "Temperature"
	Checkbox TimeCheck, pos = {130,95}, title = " ", proc = timeCheckProc
	Drawtext 145,110, "Sweep Times"
	Button RunSweepExportbtn, pos = {65,122}, title = "Run Raw Export", size = {100, 40}, proc = RunSweepExportFunc 
	DrawLine 230, 3, 230, 167
	DrawLine 232, 3, 232, 167
	SetVariable expWaveCust pos={244,35}, size={228,25}, title="Which Wave?", value=custWaveName, fsize=10 
	SetVariable expOutCust pos={258,65}, size={214,25}, title="Export Path", value=expPathCust, fsize=10 
	Drawtext 302,20, "Custom Wave Export"
	SetVariable expNameCust pos={241,82}, size={204,25}, title="New File Name", value=custFileName, fsize=10 
	Drawtext 445,98, ".ibw"
	Button RunCustExportbtn, pos = {295,122}, title = "Run Custom Export", size = {100, 40}, proc = RunCustExportFunc 
	Button KillExportbtn, pos = {435,142}, title = "Close", size = {40, 20}, proc = Kill_Export_Window 

end

Function Kill_Export_Window(dummy) : buttoncontrol
	string dummy
	
	DoWindow/K ExportCont
end

//Checkbox functions
Function sweepCheckProc(ctrlName,checked) : CheckBoxControl	// outputs "checked" variable (0 or 1)
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	Variable/G doSweeps 	// 1 if checked, 0 if not	
	If (checked ==1)
		doSweeps = 1
	else
		doSweeps = 0
	endif
end

Function commandCheckProc(ctrlName,checked) : CheckBoxControl	// outputs "checked" variable (0 or 1)
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	Variable/G doCommands 	// 1 if checked, 0 if not
	If (checked ==1)
		doCommands = 1
	else
		doCommands = 0
	endif
end

Function tempCheckProc(ctrlName,checked) : CheckBoxControl	// outputs "checked" variable (0 or 1)
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	Variable/G doTemp 	// 1 if checked, 0 if not
	If (checked ==1)
		doTemp = 1
	else
		doTemp = 0
	endif
end

Function timeCheckProc(ctrlName,checked) : CheckBoxControl	// outputs "checked" variable (0 or 1)
	String ctrlName
	Variable checked			// 1 if checked, 0 if not
	Variable/G doTime 	// 1 if checked, 0 if not
	If (checked ==1)
		doTime = 1
	else
		doTime = 0
	endif
end

Function RunCustExportFunc(dummy) : buttoncontrol
	string dummy
	String/G expPathCust = expPathCust
	String/G custWaveName = custWaveName
	String/G custFileName = custFileName
	String/G suffix = ".ibw"
	string cmdstr
	
	print ""
	print "-----Export Start-----"
	
	cmdstr = "Save "+custWaveName+" as "+"expPathCust+custFileName+suffix"
	
	print "\tSaving "+custWaveName+" as "+expPathCust+custFileName+suffix
	
	execute cmdstr
	
	print "-----Export Complete-----"
	print ""
	DoAlert 0, "Export Complete!"

end

//Sweep export function
Function RunSweepExportFunc(dummy) : buttoncontrol
	string dummy
	SVAR Expt=Expt
	String/G expPathRaw = expPathRaw
	Variable/G currSweep=0					//functions as counter
	String/G sweepFile=Expt+"_rawsweeps"
	String/G commandFile=Expt+"_commands"
	String/G tempFile=Expt+"_temperature"
	String/G timeFile=Expt+"_sweeptimes"
	Wave display_wave1 = display_wave1   			//raw sweep data
	Wave CommandWaveOut= CommandWaveOut	//raw command data
	Variable/G doSweeps							//checkbox 1=true
	Variable/G doCommands						//checkbox 1=true
	Variable/G doTemp							//checkbox 1=true
	Variable/G doTime							//checkbox 1=true
	Variable/G disk_sweep_time = disk_sweep_time
	Variable/G temperature = temperature
	String/G AllKJBWaves
	String/G AllKJBComm
	Make/N=0 timeWave			//creates wave to append sweep times through while loop below
	Make/N=0 tempWave			//creates wave to append sweep times through while loop below
	
	SVAR Expt = Expt
	NVAR disk_sweep_no = disk_sweep_no
	
	print ""
	print "-----Export Start-----"
	print "\tExperiment File Name : "+Expt+"..."
	
	disk_sweep_no = currSweep			//starts from beginning.... change if desired
	
	print "\tScanning Sweeps..."
	print "\t\tStart = "+num2str(disk_sweep_no)
	
	//COMPILE THE DATA
	do
		disk_sweep_no = currSweep
		Find_Sweep(disk_sweep_no, Expt)
		Read_Sweep(Expt)
		
		if(doSweeps==1)
			string sweepName="skjb"+num2str(currSweep)
			duplicate/O display_wave1 $sweepName
		endif
		
		if(doCommands ==1)
			string CmdName="ckjb"+num2str(currSweep)
			duplicate/O CommandWaveOut $cmdName
		endif
		
		if(doTime == 1)
			insertpoints numpnts(timeWave)+1, 1, timeWave
			timeWave[numpnts(timeWave)] = disk_sweep_time
		endif
		
		if(doTemp == 1)
			insertpoints numpnts(tempWave)+1, 1, tempWave
			tempWave[numpnts(tempWave)] = temperature
		endif	
			
		currSweep+=1
		
	while (Find_Next_Sweep(Expt) != 0)
	
	print "\t\tStop = "+num2str(disk_sweep_no)
	print "\tScan Complete"
	
	//SAVE IT ALL
	if(doSweeps==1)
		print "\tSaving Sweeps..."
		AllKJBWaves = WaveList("skjb*", ";", "")
		Concatenate AllKJBWaves, RawDataWave
		Save RawDataWave as expPathRaw+sweepFile+".ibw"
	endif
	
	if(doCommands==1)
		print "\tSaving Commands..."
		AllKJBComm = WaveList("ckjb*", ";", "")
		Concatenate AllKJBComm, CommWave
		Save CommWave as expPathRaw+commandFile+".ibw"
	endif

	if(doTime==1)
		print "\tSaving Sweep Times..."
		Save timeWave as expPathRaw+timeFile+".ibw" 
	endif
	
	if(doTemp==1) 
		print "\tSaving Temperature..."
		Save tempWave as expPathRaw+tempFile+".ibw"  
	endif
	
	KillWaves RawDataWave,CommWave,timeWave,tempWave
	KillStrings AllKJBWaves, AllKJBComm
	
	print "-----Export Complete-----"
	print ""
	DoAlert 0, "Export for file:    "+Expt+"\nin directory:       "+expPathRaw+"\n\n\tComplete!"
		
end



//--------------------END EXPORT STUFF----------------------------------------------------------------------

//--------------------(DE)CONVOLUTION THROUGH FFT-------------------------------------------------


// - Ken Burke, June/July 2015
// 	--- Code adapted/expanded from Pernia-Andrade et al., 2012 (Biophysical Journal, PI = Peter Jonas)
//
// These functions use deconvolution via division in frequency domain for spontaneous event 
// detection (e.g. miniature EPSC's). Deconvolution improves signal-to-noise and temporal precision 
// of detection of these events significantly over amplitude/first derivative measurements and template-matching algorithms.
//
// Main free parameters (in approximate order of importance) are:
//
//			a) event template function to be used for deconv. kernel 
//					-- (suggested sum of exponentials for EPSCs, or average of several hand-picked events)
//			b) signal-to-noise detection threshold for deconvolved trace,
//					-- This parameter affects the tradeoff between false positives and false negatives, 
//					   critical for mini frequency/amplitude analysis
//			c) low-pass filter for deconvolved trace 
//					-- Relatively unnecessary to adjust, as long as it's strong enough attenuation
//


//				***GUI THINGS***

Function Start_Event_Detection()
	Make_Event_Selection_Window()
	Make_mEPSC_Analysis_Window()
End

// *******EVENT DETECTION WINDOW GUI

Function Make_mEPSC_Analysis_Window()
	SVAR Expt=Expt
	SVAR ydataname = ydataname
	NVAR gRadioVal = gRadioVal
	NVAR mRadioVal = mRadioVal
	
	DoWindow/K mEPSCCont
	NewPanel/W=(1030,170,1430,575) as "mEPSC Analysis Window"
	DoWindow/C mEPSCCont					
	Button PrevWaveMbtn pos={10,10}, size={80,25}, title="Prev Sweep", proc = bMiniPrevWaveProc
	Button NextWaveMbtn pos={110,10}, size={80,25}, title="Next Sweep", proc = bMiniNextWaveProc	
	Button RunAllMinibtn pos={10,46}, size={80,20}, title="Run All", proc = bRunMiniProc
	Button RemoveSubplotbtn pos={95,46}, size={110,20}, title="Remove Subplot", proc = bRemoveSubplotProc

	CheckBox FxnKernelbx pos={225,23}, size={50,20}, title="Use Alpha Function Kernel", value = gRadioVal==1, mode=1, proc = bWhichKernelProc
	CheckBox EmpKernelbx pos={225,46}, size={50,20}, title="Use Empirical Kernel", value= gRadioVal==2, mode=1, proc = bWhichKernelProc

	DrawLine 199, 69, 199, 390
	DrawLine 201, 69, 201, 390
	
	DrawLine 5, 72, 395, 72
	DrawLine 5, 70, 395, 70
	
	SetDrawEnv fsize = 12, fstyle = 2
	Drawtext 5,95, "Event Kernel (Alpha)"
	SetVariable Kern_Amp, size = {130, 20}, pos = {35, 103}, value = Kernel_Amp, proc = bMakeEKerProc, Title = "Event Amplitude"
	SetVariable Kern_TauF, size = {130, 20}, pos = {35, 123}, value = tau_one, proc = bMakeEKerProc, Title = "           Rise Tau"
	SetVariable Kern_TauS, size = {130, 20}, pos = {35, 143}, value = tau_two, proc = bMakeEKerProc, Title = "        Decay Tau"
	Drawtext 170,117, "pA"
	Drawtext 170,138, "ms"
	Drawtext 170,159, "ms"
	
	SetDrawEnv fsize = 12, fstyle = 2
	Drawtext 205,95, "Event Kernel (Empirical)"
	SetDrawEnv fsize = 10, fstyle = 2
	Drawtext 205,105, "**uses checked events"
	Button MakeEmpKerBtn, pos={344,82}, size={45,20}, title="Make", proc = bMakeEmpKerProc
	SetVariable empKerDur, size = {95, 20}, pos = {260, 115}, value = empKerDur, Title = "Duration "
	SetVariable empKerSmoothing, size = {95, 20}, pos = {260, 135}, value = empKerSmooth, Title = "Smoothing "
	SetDrawEnv fsize = 12
	Drawtext 367,130, "ms"
	SetDrawEnv fsize = 12
	Drawtext 361,150, "samp"
	
	DrawLine 5, 168, 395, 168
	DrawLine 5, 170, 395, 170

	SetDrawEnv fsize = 12, fstyle = 2
	Drawtext 5,192, "Deconvolution"
	Button RunDeconvbtn pos={148,175}, size={40,20}, title="Go", proc = bDECProc
	SetVariable Deconv_target_wn, size = {165, 20}, pos = {25, 200}, value = Deconv_Target_Wavename, Title = "Input Wavename"
	SetVariable Deconv_output_wn, size = {165, 20}, pos = {25, 220}, value = Deconv_Output_Wavename, Title = "Output Wavename"   
	DrawLine 5, 244, 395, 244
	DrawLine 5, 246, 395, 246
	
	CheckBox EventMarkersbx pos={210,185}, size={50,20}, title="Event Markers", value = 1, variable = events_on, proc = bEventPeakMarkersProc, mode=0
	CheckBox PeakMarkersbx pos={210,208}, size={50,20}, title="Peak Markers", value= 0, variable = peaks_on, proc = bEventPeakMarkersProc, mode=0	
	CheckBox findMinbx pos={303,185}, size={50,20}, title="Find Minimum", value = mRadioVal==1, mode=1, proc = bMaxOrMinProc
	CheckBox findMaxbx pos={303,208}, size={50,20}, title="Find Maximum", value= mRadioVal==2, mode=1, proc = bMaxOrMinProc
	CheckBox blineSubbx pos={240,226}, size={50,20}, title="Trendline Correction", value= 0, variable = blineSubOn, proc = bBlineSubProc, mode=0	

	SetDrawEnv fsize = 12, fstyle = 2
	Drawtext 5,268, "Detect Events"
	Button RunDetEvbtn pos={158,251}, size={30,20}, title="Go", proc = bDetEvProc
	Button KillMarkersbtn pos={85,251}, size={69,20}, title="Kill Marks", proc = bKillMarksProc
	SetVariable Event_Maximum, size = {137, 20}, pos = {25, 276}, value = Event_Max, Title = "Max, Num. Events "
	SetVariable Event_thresh, size = {137, 20}, pos = {25, 296}, value = Event_Threshold, Title = " Detection Thresh.  "   
	SetVariable Event_spacing, size = {152, 20}, pos = {10, 316}, value = minimum_time_spacing, Title = " Min. Inter-Event Interval"   
	SetVariable Peak_Smoothing, size = {137, 20}, pos = {25, 336}, value = peak_smoothing, Title = " Smoothing Width    "   
	SetVariable Hard_Minimum_Amplitude, size = {137, 20}, pos = {25, 356}, value = hard_min_amp, Title = " Hard Minimum Amp"   
	Drawtext 170,290, "#"
	Drawtext 170,311, "S.D."
	Drawtext 170,332, "ms"
	Drawtext 166,353, "samp"
	Drawtext 166,374, "| pA |"
	SetDrawEnv fsize = 9, fstyle = 2
	Drawtext 206, 372, "<< WARNING, hard minimum overrides manual"
	SetDrawEnv fsize = 9, fstyle = 2
	Drawtext 206, 382, "selections in Event Selection Window"
	
	
	SetDrawEnv fsize = 12, fstyle = 2
	Drawtext 205,268, "Search Range In Sweep"
	SetVariable Detection_Start, size = {125, 20}, pos = {240, 276}, value = detection_start, Title = "Detection Start ", proc = bChangeDetectTime
	SetVariable Detection_End, size = {125, 20}, pos = {240, 296}, value = detection_end, Title = "Detection End ", proc = bChangeDetectTime
	SetDrawEnv fsize = 10
	Drawtext 370,293, "sec"
	SetDrawEnv fsize = 10
	Drawtext 370,313, "sec"

	DrawLine 5, 385, 395, 385
	DrawLine 5, 383, 395, 383
	
	Make_EPSC_Kernel()
	
end

Function bMiniPrevWaveProc(ctrlName)
	string ctrlName
	
	SVAR Expt = Expt
	Find_Previous_Sweep(Expt)
	Read_Sweep(Expt)
	
	bRemoveSubplotProc(ctrlName)
	bRunMiniProc(ctrlName)

end

Function bMiniNextWaveProc(ctrlName)
	string ctrlName
	
	SVAR Expt = Expt
	Find_Next_Sweep(Expt)
	Read_Sweep(Expt)
	
	bRemoveSubplotProc(ctrlName)
	bRunMiniProc(ctrlName)

end

Function bRunMiniProc(ctrlName)
	string ctrlName
	String/G Deconv_Target_Wavename = Deconv_Target_Wavename
	String/G Deconv_Output_Wavename = Deconv_Output_Wavename
	String Output_Wavename = "s_"+Deconv_Output_Wavename			// s_ prefix so you can find subplot waves with WaveList
	NVAR disk_sweep_no = disk_sweep_no
	NVAR blineSubOn = blineSubOn
	
	print "---------------------------Sweep "+num2str(disk_sweep_no)+"---------------------------"
	strswitch(ctrlName)
		case "PrevWaveMbtn":
			break
		case "NextWaveMbtn":
			break
		case "RunAllMinibtn":
			break
		default:
			Make_EPSC_Kernel()
			break
	endswitch
	
	FFT_Deconv($Deconv_Target_Wavename, EPSC_kernel, Output_Wavename)
	
	if (blineSubOn == 1)
		duplicate/O $Output_Wavename outputwave_subbed
		Wave W_coef = W_coef
		CurveFit/Q/NTHR=0/TBOX=0 line  outputwave_subbed /D
		outputwave_subbed -= W_coef[0] + W_coef[1]*x
		duplicate/O outputwave_subbed $Output_Wavename
		killwaves outputwave_subbed
	endif
	
	Detect_Peaks($Output_Wavename)
	print "---------------------------------------------------------------------"
	print "\n"

end

Function bRemoveSubplotProc(ctrlName)
	string ctrlName
	
	Variable killMarks = Remove_Subplot("Sweep_window", "all_waves")
	
	if (killMarks==1)
		bKillMarksProc(ctrlName)
	endif
	
end

Function bKillMarksProc(ctrlName)
	string ctrlName
	
	RemoveFromGraph/W=Sweep_window marker_placeholder
end

Function bDECProc(ctrlName)
	string ctrlName
	String/G Deconv_Target_Wavename = Deconv_Target_Wavename
	String/G Deconv_Output_Wavename = Deconv_Output_wavename
	String Output_Wavename = "s_"+Deconv_Output_Wavename			// s_ prefix so you can find subplot waves with WaveList
	
	FFT_Deconv($Deconv_Target_Wavename, EPSC_kernel, Output_Wavename)
	
end

Function bDetEvProc(ctrlName)
	string ctrlName
	String/G Deconv_Output_Wavename = Deconv_Output_wavename
	String Output_Wavename = "s_"+Deconv_Output_Wavename			// s_ prefix so you can find subplot waves with WaveList
	
	Detect_Peaks($Output_Wavename)
	
end

Function bEventPeakMarkersProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked		// 1 if selected, 0 if not
	
	Display_Event_Detections()
	
end

Function bBlineSubProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR blineSubOn = blineSubOn
	
	if (checked==0)
		CheckBox blineSubbx, value=0, win=mEPSCCont
	else
		CheckBox blineSubbx, value=1, win=mEPSCCont
	endif
	
	printf num2str(blineSubOn)
		
end

Function bWhichKernelProc(name,value)
	String name
	Variable value
	
	NVAR gRadioVal= gRadioVal
	
	strswitch (name)
		case "FxnKernelbx":
			gRadioVal= 1
			break
		case "EmpKernelbx":
			gRadioVal = 2
			break
	endswitch
	
	CheckBox FxnKernelbx,value= gRadioVal==1, win=mEPSCCont
	CheckBox EmpKernelbx,value= gRadioVal==2, win=mEPSCCont
	
	Make_EPSC_Kernel()
	
End

Function bMakeEmpKerProc(ctrlName)
	string ctrlName
	
	NVAR gRadioVal = gRadioVal
	
	gRadioVal = 2
	
	CheckBox FxnKernelbx,value= gRadioVal==1, win=mEPSCCont
	CheckBox EmpKernelbx,value= gRadioVal==2, win=mEPSCCont
	
	Make_EPSC_Kernel()
end	


Function bMaxOrMinProc(name,value)
	String name
	Variable value
	
	NVAR mRadioVal= mRadioVal
	NVAR Kernel_Amp = Kernel_Amp
	
	strswitch (name)
		case "findMinbx":
			mRadioVal= 1
			Kernel_Amp = abs(Kernel_Amp)*-1			// sets kernel to be negative
			break
		case "findMaxbx":
			mRadioVal= 2
			Kernel_Amp = abs(Kernel_Amp)			// sets kernel to be positive
			break
	endswitch
	
	CheckBox findMinbx,value= mRadioVal==1, win=mEPSCCont
	CheckBox findMaxbx,value= mRadioVal==2, win=mEPSCCont
	
	Make_EPSC_Kernel()
	
End

Function bChangeDetectTime (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	
	bRunMiniProc(ctrlName)
	
End



Function Subplot(window_name, subplot_trace, focus_trace,range_min, range_max,axis_label)
	//assumes they have the same x_range
	
	string window_name		//name of target window
	wave subplot_trace		//trace to be added
	wave focus_trace			//trace on sweep_window already to focus axes on
	variable range_min
	variable range_max
	string axis_label
	
	AppendToGraph/W=$window_name/L=subplot subplot_trace
	ModifyGraph/W=$window_name axisEnab(subplot)={0,0.48}
	ModifyGraph/W=$window_name axisEnab(left)={0.52,1}	
	Wavestats/Q focus_trace
	SetAxis/W=$window_name left (V_min-5), (V_max+5)
	SetAxis/W=$window_name subplot range_min,range_max
	Label/W=$window_name subplot axis_label
	ModifyGraph/W=$window_name lblPos(subplot)=40
	ModifyGraph/W=$window_name freePos(subplot)=0
end

Function Remove_Subplot(window_name, subplot_trace)
	//removes subplots created above
	
	string window_name
	string subplot_trace
	
	if (~cmpstr(subplot_trace,"all_waves"))				//keyword to kill all waves
		String subplot_list = WaveList("s_*", ";", "WIN:"+window_name)
		
		if (cmpstr(subplot_list,"")==0)			//if there's nothing with that prefix, then nothing to remove
			return 0
		endif
		
		String theWave
		Variable i=0
		do								// Remove all waves found in wavelist
			theWave = StringFromList(i, subplot_list)
			if (strlen(theWave) == 0)
				break // Ran out of waves
			endif
			RemoveFromGraph/W=$window_name $theWave
			i += 1
		while (1) // Loop until break above
	else
		RemoveFromGraph/W=$window_name $subplot_trace
	endif
	
	ModifyGraph/W=$window_name axisEnab(left)={0,1}
end

// ********* EVENT SELECTION GUI


Function Make_Event_Selection_Window()

	Wave peakPositionsX = peakPositionsX
	Wave peakPositionsY = peakPositionsY
	
	Make/O/B/N=(numpnts(text_PPX),2) sel_events = 0
	sel_events[][0] += 2^4+2^5 // turn on bit 4 and 5 to have checkboxes

	DoWindow/K EventCont
	newpanel/w=(480,780,830,990) as "Event Selection Window"
	DoWindow/C EventCont
	
	SetDrawEnv fsize = 12, fstyle = 2
	Drawtext 25,18, "List of Detected Events"
//	SetDimLabel 1, , Time_Sec, text_PPX
	ListBox Event_List win=EventCont, pos={10,22}, size={165,175}, mode=4, listWave=text_events, selWave = sel_events, proc = bEvent_Listbox_Proc
	SetDrawEnv fsize = 10, fstyle = 2
	Drawtext 18,210, "time (sec)        amp (pA)"

	Button CalculateAmpsbtn pos={190,7}, size={140,20}, title="Save Amps and IEIs", proc = bCalcAmpsProc
	SetVariable Bline_Range, size = {115, 20}, pos = {192, 35}, value = bline_range, Title = "Baseline Range "
	SetVariable Peak_Range, size = {115, 20}, pos = {192, 55}, value = peak_range, Title = "Peak Range "
	SetVariable Peak_Offset, size = {115, 20}, pos = {192, 75}, value = peak_offset, Title = "Peak Offset "
	SetDrawEnv fsize = 12
	Drawtext 315,50, "ms"
	SetDrawEnv fsize = 12
	Drawtext 315,70, "ms"
	SetDrawEnv fsize = 12
	Drawtext 315,90, "ms"
	DrawLine 185, 100, 342, 100
	DrawLine 185, 102, 342, 102
	
	
	Button ConcatenateAmpbtn pos={180,118}, size={160,20}, title="Concat. Summary Waves", proc = bConcatenateAllProc
	Button PlotEventsbtn pos={180,148}, size={160,20}, title="Plot Events & Average", proc = bStoreEventTemplatesProc
	Button ClearAmpIEIWavesbtn pos={180,178}, size={160,20}, title="Reset Summary Waves", proc = bClearAmpIEIProc

end

Function bEvent_Listbox_Proc(LB_Struct) : ListboxControl
	STRUCT WMListboxAction &LB_Struct
	
	if (LB_Struct.eventCode == 2)
		Display_Event_Detections()
	endif
	
end

Function bConcatenateAllProc(ctrlName)

	string ctrlName
	
	bConcatAmpsProc("")
	bConcatIEIProc("")
	bConcatTimesProc("")

end

Function bConcatAmpsProc(ctrlName)

	string ctrlName
	String AllAmpsList
	
	AllAmpsList = WaveList("s*_amps", ";", "")
	
	Variable numList = ItemsInList(AllAmpsList)
	
	if(numList == 0)
		printf "\r No waves with amplitudes found. Quitting.\r"
		return 0
	endif
	
	Concatenate/O AllAmpsList, allAmplitudes
	printf("\rAll Amplitudes:\r\r")
	print allAmplitudes
	printf("\rWavestats on All Amplitudes\r\r")
	wavestats allAmplitudes
	
End

Function bConcatIEIProc(ctrlName)

	string ctrlName
	String AllEventIntervalList
	
	AllEventIntervalList = WaveList("s*_iei", ";", "")
	
	Variable numList = ItemsInList(AllEventIntervalList)
	
	if(numList == 0)
		printf "\r No waves with IEI found. Quitting.\r"
		return 0
	endif
	
	Concatenate/O AllEventIntervalList, allEventInts
	printf("\rAll Event Intervals:\r\r")
	print allEventInts
	printf("\rWavestats on All Event Intervals\r\r")
	wavestats allEventInts
	
End

Function bConcatTimesProc(ctrlName)

	string ctrlName
	String AllTimesList
	
	AllTimesList = WaveList("s*_times", ";", "")
	
	Variable numList = ItemsInList(AllTimesList)
	
	if(numList == 0)
		printf "\r No waves with Times found. Quitting.\r"
		return 0
	endif
	
	Concatenate/O AllTimesList, allEventTimes
	printf("\rAll Event Times:\r\r")
	print allEventTimes
	printf("\rWavestats on All Event Times\r\r")
	wavestats allEventTimes
	
End

Function bClearAmpIEIProc(ctrlName)

	string ctrlName
	string allAmpsList
	String AllEventIntervalList
	String AllTimesList
	
	AllEventIntervalList = WaveList("s*_iei", ";", "")
	AllAmpsList = WaveList("s*_amps", ";", "")
	AllTimesList = WaveList("s*_times", ";", "")

	printf "\r: killing amp, timing, and iei waves (s*_amps, s*_times and s*_iei)\r"
 	Variable numList = ItemsInList(AllEventIntervalList)
 	Variable index
 	
 	if (numList != 0)
 		for (index=0;index<numList;index+=1)
 			KillWaves/Z $(StringFromList(index, AllEventIntervalList))
 		endfor
 	endif
 	
 	numList = ItemsInList(AllAmpsList)
 	
 	if (numList != 0)
 		for (index=0;index<numList;index+=1)
 			KillWaves/Z $(StringFromList(index, AllAmpsList))
 		endfor
 	endif
 	
  	numList = ItemsInList(AllTimesList)
 	
 	if (numList != 0)
 		for (index=0;index<numList;index+=1)
 			KillWaves/Z $(StringFromList(index, AllTimesList))
 		endfor
 	endif

 	KillWaves/Z allEventInts, allAmplitudes, allTimes, setOfEvents; AbortOnRTE
 	
end

Function bMakeEKerProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	
	Make_EPSC_Kernel()
end

//				***END GUI THINGS***

//				***MINI ANALYSIS FUNCS***



Function Make_EPSC_Kernel()

	NVAR gRadioVal = gRadioVal
	
	switch (gRadioVal)
		case 1:
			bFxnKernelProc("")
			break
		case 2:
			bEmpiricalKernelProc("")
			break
	endswitch
	
end

Function bFxnKernelProc(ctrlName)

	string ctrlName	
	Variable/G tau_one = tau_one				// in ms
	Variable/G tau_two = tau_two
	Variable/G Kernel_Amp = Kernel_Amp		// in pA
	
	Variable/G kHz = kHz
	
	DoWindow/K Kernel_Window
	KillWaves/Z EPSC_Kernel, time_index 		// cleanup
	
	Variable tau_fast = tau_one*kHz
	Variable tau_slow =tau_two*kHz 			//scale to sampling frequency
	
	Variable kernel_window = 4*tau_slow
	Variable amp_prime = (tau_slow/tau_fast)^(tau_fast/(tau_fast-tau_slow))		// normalization factor
	
	make/O/N=(kernel_window) time_index=p
	SetScale/P x, 0, 1/(kHz), time_index			// normalize to units of ms
	make/O/N=(kernel_window) EPSC_kernel = (Kernel_Amp/amp_prime)*(-exp(-time_index/(tau_fast))+exp(-time_index/(tau_slow))		// sum of exponentials
	SetScale/P x, 0, 1/(kHz), EPSC_kernel		//normalize to units of s
	
	display/W=(0,125,345,285)/N=Kernel_Window EPSC_Kernel
	textbox/W=Kernel_Window/A=MT/X=-3/F=0/E "EPSC Kernel / Rise = "+num2str(tau_fast/kHz)+" ms / Decay = "+num2str(tau_slow/kHz)+" ms"		
	Label left "pA"
	Label bottom "ms"
	
end

Function bEmpiricalKernelProc(ctrlName)			//makes an kernel with detected events (rather than "idealized" kernel)
	string ctrlName
	wave sel_events = sel_events
	wave display_wave1 = display_wave1
	wave peakPositionsX = peakPositionsX
	NVAR kHz = kHz
	NVAR empKerDur = empKerDur
	NVAR empKerSmooth = empKerSmooth
	
	
	// normalize all events, average them, and fit a sum of exponentials with 3 parameters
	// or, perhaps just average and smooth?
	
	Make/O/N=(empKerDur*kHz) empiricalKernel

	variable i = 0		//iterator
	variable n = 0		//num counted events

	do
		if ((sel_events[i] & 2^4) != 0)			// if checked in manual selection window
			Make/O/N=(empKerDur*kHz) singleEvent = display_wave1[p+peakPositionsX(i)*kHz*1e3]
			empiricalKernel += singleEvent
			n += 1
		endif
		i +=1
	while (i < numpnts(peakPositionsX))
	
	if (n != 0)
		empiricalKernel /= n
		Smooth/B=(empKerSmooth) 4, empiricalKernel
		Variable baseSub = empiricalKernel[0]
		empiricalKernel -= baseSub
	else
		printf " : no checked events, empirical kernel not created. quitting."
		return 0
	endif
	
	SetScale/P x, 0, 1/(kHz), empiricalKernel			// normalize to units of ms
	
	duplicate/O empiricalKernel, EPSC_Kernel
	
	DoWindow/K Kernel_Window
	KillWaves/Z empiricalKernel, time_index
	
	display/W=(0,125,345,285)/N=Kernel_Window EPSC_Kernel
	textbox/W=Kernel_Window/A=MT/X=-3/F=0/E "Empirical Kernel"		
	Label left "pA"
	Label bottom "ms"
	
end



Function FFT_Deconv(OutputSignal, Kernel, DestName)

	//assumes no x-scaling on outputsignal or kernel (i.e. x-scaling is 0 to numpnts(wave)-1)
	// WARNING!!! SCALING OVERESTIMATES THE VARIANCE OF DECONVOLVED INPUT SIGNAL
	//		For better estimate fit the all-point histogram to a gaussian and take the SD (see "detect_peaks()")
	
	
	Wave OutputSignal
	Wave Kernel
	String DestName	
	NVAR kHz = kHz
	Variable Fs = kHz*1e3
	String/G Deconv_Output_Wavename = Deconv_Output_wavename
	String Output_Wavename = "s_"+Deconv_Output_Wavename				// s_ prefix so you can find subplot waves with WaveList

	if (exists("Saved_Deconv_Wavename")==2)								// if we've already got a wavename saved, remove it from the subplot
		String/G Saved_Deconv_Wavename = Saved_Deconv_Wavename	
		Remove_subplot("Sweep_window",Saved_Deconv_Wavename)
	elseif (exists("Saved_Deconv_Wavename")==0)
		String/G Saved_Deconv_Wavename = ""								// otherwise if it doesn't exist, put in placeholder and do nothing
	endif
	
	Saved_Deconv_Wavename = Output_Wavename							// reset the stored value
	
	Variable Lx = numpnts(OutputSignal) - numpnts(Kernel) + 1				// anticipated length of input ("DestName") in number of points

	SetScale x, 0, (NumPnts(OutputSignal)-1)/Fs, OutputSignal				// must scale signals for appropriate frequency decomposition

	FFT/OUT=1/DEST=Output_FFT OutputSignal							// move input and kernel to frequency domain
	FFT/OUT=1/PAD={NumPnts(OutputSignal)}/DEST=Kernel_FFT Kernel 		// pad the kernel so they're of equal lengths

	Make/N=(numpnts(Output_FFT))/D/C DeconvFFT							// Length of FFTs above^^ = NumPnts(OutputSignal)/2 +1, must be same here
	DeconvFFT=Output_FFT/Kernel_FFT

	IFFT/DEST=Deconv_raw DeconvFFT

	FilterFIR/LO={0.012, 0.013, 101} Deconv_raw								// uninterpretable without low-pass filter
	WaveStats/Q Deconv_raw
	Make/O/N=(numpnts(Deconv_raw)) $DestName = (Deconv_raw-V_avg)/V_sdev	// normalize to units of standard deviation (NOT ACCURATE)
	SetScale x, 0, (NumPnts(Deconv_raw)-1)/Fs, $DestName
	
	KillWaves Deconv_raw, DeconvFFT, Output_FFT, Kernel_FFT							// cleanup
	Subplot("Sweep_window",$DestName,OutputSignal,-1,7,"Event Amp (arb. units)")		// display on subplot of sweep window
	ModifyGraph/W=Sweep_window rgb($DestName) = (0,9472,39168)
	
end

Function FFT_Conv(InputSignal, Kernel, Fs, DestName)

	//assumes no x-scaling on inputsignal or kernel (i.e. x-scaling is 0 to numpnts(wave)-1)

	Wave InputSignal
	Wave Kernel
	Variable Fs
	String DestName

	Variable Lx = numpnts(InputSignal) + numpnts(Kernel) - 1				// anticipated length of output in number of points

	SetScale x, 0, (NumPnts(InputSignal)-1)/Fs, InputSignal				// must scale signals for appropriate frequency decomposition
	SetScale x, 0, (NumPnts(Kernel)-1)/Fs, Kernel

	FFT/OUT=1/DEST=Input_FFT InputSignal							// move input and kernel to frequency domain
	FFT/OUT=1/PAD={NumPnts(InputSignal)}/DEST=Kernel_FFT Kernel	// pad the kernel so they're of equal lengths

	Make/N=(numpnts(Input_FFT))/D/C ConvFFT							// Length of FFTs above^^ = NumPnts(InputSignal)/2 +1, must be same here
	ConvFFT=Input_FFT*Kernel_FFT									// Convolution is multiplication in the frequency domain

	IFFT/DEST=$DestName ConvFFT									// Inverse FFT and scale back to real time 
	SetScale x, 0, (Lx-1)/Fs, $DestName
	
	KillWaves ConvFFT, Input_FFT, Kernel_FFT							// cleanup and display
	display $DestName
	
end


Function Detect_Peaks(trace)

	wave trace									// trace data 
	Variable/G Event_Max = Event_Max			// cap on number of peaks
	Variable/G Event_Threshold = Event_Threshold	// threshold in units of S.D. from mean of gaussian fit to all-point histogram of data
	Variable min_spacing							// minimum time between detected events in ms
	
	Wave W_coef = W_coef
	Variable peaksFound=0
	NVAR kHz = kHz
	NVAR detection_start = detection_start	
	NVAR detection_end = detection_end
	NVAR peak_smoothing = peak_smoothing
	Variable/G minimum_time_spacing = minimum_time_spacing
	Variable startP=detection_start*kHz*1e3				//startP is sliding range that help to find maxima one-by-one
	Variable endP= detection_end*kHz*1e3 - 1					//endP is end of region for detection

	
	String graphname = "AllPointDistribution"

	DoWindow/K $graphname											//cleanup
	Killwaves/Z y_placeholder, fit_trace_histogram, trace_histogram, threshold_height, adjusted_thresh_wave, peakPositionsX, peakPositionsY
	
	// First, find the standard deviation of the noise in your trace 
	Make/N=1 trace_histogram
	histogram/B={-10,0.1,270} trace, trace_histogram			// all-point hist, binned from -10 to 16.9 in 0.1 bins (more not needed, as this is just for the gauss fit)
	
		
	// Then fix the offset to zero, set a couple other parameter guesses, fit the data to a gaussian and adjust
	K0 = 0
	K1 = 5000 
	K2 = -0.1
	K3 = 1
	
	CurveFit/Q/G/H="1000" gauss trace_histogram /D				// fit wave is fit_trace_histogram
	
	Variable noise_sd = abs(W_coef[3])							// W_coeff is wave of parameters for fit, 3 is SD (2 is mean)
	Variable noise_mean = W_coef[2]
	Variable adjusted_threshold = noise_mean + noise_sd*Event_Threshold	// convert thresh from SD units to arbitrary input units
	
	print "\n"
	print "\t-Mean of All-Point Histogram Gaussian Fit = "+num2str(noise_mean)
	print "\t-Standard Deviation of All-Point Histogram Gaussian Fit = "+num2str(noise_sd)
	print "\t\t---Adj. Thresh. (Arb. Units) = "+num2str(adjusted_threshold)
	print "\tPLOTTING ALL-POINT DISTRIBUTION...."
	
	display/W=(0,312,345,552)/N=$graphname trace_histogram
	ModifyGraph/W=$graphname rgb(trace_histogram)=(0,9472,39168)
	AppendToGraph/W=$graphname/C=(52224,0,0) fit_trace_histogram
	
	// NOW, go through and find all of the peaks that pass your threshold
	Make/O/N=(Event_Max) peakPositionsX= NaN, peakPositionsY= NaN    	// empty vectors to store data
	
	do
	    FindPeak/B=(peak_smoothing)/I/M=(adjusted_threshold)/P/Q/R=[startP, endP] trace		// find a peak in given range
	    
	    // FindPeak outputs are V_Flag, V_PeakLoc, V_LeadingEdgeLoc,
	    // V_TrailingEdgeLoc, V_PeakVal, and V_PeakWidth. 
	    
	    if( V_Flag != 0 )			// if you didn't find another peak
	        break
	    elseif( numtype(V_TrailingEdgeLoc) == 2 )			// if the max is at the end (trailingEdge is NaN)
	        break
	    endif
	    
	    peakPositionsX[peaksFound]=pnt2x(trace,V_PeakLoc)					// fill in time for this peak
	    peakPositionsY[peaksFound]=V_PeakVal								// fill in value for the peak
	    peaksFound += 1													// counter
	    
	    startP= V_TrailingEdgeLoc+minimum_time_spacing*kHz				// move start time for range of next peak 
	    																	// detection to after current peak
	while ( peaksFound < Event_Max )					//caps out max number of peaks
	
      Extract/O peakPositionsX, peakPositionsX, (numtype(peakPositionsX) != 2)			//kill all the NaNs
      Extract/O peakPositionsY, peakPositionsY, (numtype(peakPositionsY) != 2)

	print "\t-Peaks Detected = "+num2str(peaksFound)

	Make/N=(numpnts(trace_histogram)) y_placeholder=200							
	AppendToGraph/W=$graphname/C=(0,0,0) y_placeholder vs peakPositionsY			// to plot points of detected single events
	ModifyGraph/W=$graphname mode(y_placeholder)=3,marker(y_placeholder)=10
	
	// plot threshold line on histogram
	Make/N=1 threshold_height = 6000			
	Make/N=1 adjusted_thresh_wave = adjusted_threshold
	AppendToGraph/W=$graphname threshold_height vs adjusted_thresh_wave
	ModifyGraph/W=$graphname mode(threshold_height)=1, rgb(threshold_height)=(0,39168,19712)
	SetAxis/W=$graphname left 0, 210
	SetAxis/W=$graphname bottom -2,10
	textbox/W=$graphname/A=MT/X=1/F=0/E "Detected Peaks, Thresh. = "+num2str(Event_Threshold)+" S.D."
	Label left "Num. Points"
	Label bottom "Amplitude (Arbitrary Units)"
	
	
	//plot threshold onto deconvolved subplot, and range over which we're detecting peaks
	if (~cmpstr(Wavelist("s_thresh*",":","WIN:Sweep_window"), "s_threshold*"))
		RemoveFromGraph/W=Sweep_window s_threshold					// s_ prefix so you can find subplot waves with WaveList
	endif
	Make/O/N=(numpnts(trace)) s_threshold=adjusted_threshold
	Make/O/N=2 rangeThresh = {detection_start,detection_end}
	AppendToGraph/W=Sweep_window/L=subplot s_threshold vs rangeThresh
	ModifyGraph/W=Sweep_window rgb(s_threshold)=(0,39168,19712)
			
	if (peaksFound == Event_Max)
		doAlert 0, "Maximum number of events reached!\nYou may have missed events! Raise cap!"
	endif
	
	Make/O/T/n=(numpnts(peakPositionsX)) text_PPX = num2str(peakPositionsX)
	Make/O/T/n=(numpnts(peakPositionsY)) text_PPY = num2str(peakPositionsY)
	Concatenate/O {text_PPX,text_PPY}, text_events	

	Make_Event_Selection_Window()
	bCalcAmpsProc("")
	Display_Event_Detections()

end

Function Display_Event_Detections()
	NVAR events_on = events_on			// 1 if displaying event markers, 0 if not
	NVAR peaks_on = peaks_on			// 1 if displaying peak markers, 0 if not
	Wave peakPositionsX = peakPositionsX
	Wave display_wave1 = display_wave1
	Wave disp_index = disp_index
	Wave sel_events = sel_events
	wave peak_locs
	NVAR mRadioVal = mRadioVal			// = 1 if searching for minimum, 2 if max
	NVAR disk_sweep_no = disk_sweep_no
	
	
	string name_of_wave = "s"+num2str(disk_sweep_no)+"_amps"
	Wave current_sweep_amps = $name_of_wave
	
	if (~cmpstr(Wavelist("marker_*",":","WIN:Sweep_window"), "marker_placeholder*"))
		RemoveFromGraph/W=Sweep_window marker_placeholder
	endif
	if (~cmpstr(Wavelist("amp_*",":","WIN:Sweep_window"), "amp_placeholder*"))
		RemoveFromGraph/W=Sweep_window amp_placeholder
	endif
	
	Make/O/N=(numpnts(peakPositionsX)) marker_placeholder=0
	Make/O/N=(numpnts(current_sweep_amps)) amp_placeholder=0

	variable i = 0
	variable n = 0
	do
		if ((sel_events[i] & 2^4) != 0)			// if checked in manual selection window
			marker_placeholder[i] = display_wave1(peakPositionsX[i])-21
		else									// if unchecked
			marker_placeholder[i] = 10000		// off the screen
		endif
		
		i +=1
	while (i < numpnts(peakPositionsX))
	
	i=0
	do
		amp_placeholder[i] = display_wave1(peak_locs[i])-2
		i+=1
	while (i<numpnts(current_sweep_amps))
	
	if(events_on == 1)
	AppendToGraph/W=Sweep_window/C=(0,0,0) marker_placeholder vs peakPositionsX
	ModifyGraph/W=Sweep_window mode(marker_placeholder)=3, marker(marker_placeholder)=17
	endif
	
	if(peaks_on == 1)
		if (mRadioVal == 2)		//searching for maximum
			amp_placeholder += 5
		endif
	AppendToGraph/W=Sweep_window/C=(100,100,0) amp_placeholder vs peak_locs
	ModifyGraph/W=Sweep_window mode(amp_placeholder)=3, mrkThick(amp_placeholder)=2,rgb(amp_placeholder)=(0,52224,0), marker(amp_placeholder)=10
	endif
	
end

Function bCalcAmpsProc(ctrlName)			// calculates amplitudes of selected events in pA
	
	string ctrlName
	wave sel_events = sel_events
	wave display_wave1 = display_wave1
	wave peakPositionsX = peakPositionsX
	wave/T text_events = text_events
	wave text_PPX = text_PPX
	wave text_PPY = text_PPY
	NVAR kHz = kHz
	NVAR disk_sweep_no = disk_sweep_no
	variable peak_smoothing = peak_smoothing
	wave EPSC_Kernel = EPSC_Kernel
	wave display_wave1 = display_wave1
	NVAR hard_min_amp = hard_min_amp
	NVAR peak_range = peak_range			// range over which to average peak, in ms
	NVAR peak_offset = peak_offset			// amount by which to offset suspected peak location, in ms
	NVAR bline_range = bline_range			// range over which to average bline, in ms
	NVAR mRadioVal = mRadioVal			// 1 if searching for a minimum, 2 if maximum
	
	Concatenate/O/T {text_PPX,text_PPY}, text_events	
	
	print "----------------------------------------------"
	print "Calculating Selected Amplitudes for Sweep "+num2str(disk_sweep_no)+"...."
	print "\n"
	
	string name_of_amps = "s"+num2str(disk_sweep_no)+"_amps"
	string name_of_iei = "s"+num2str(disk_sweep_no)+"_iei"
	string name_of_times = "s"+num2str(disk_sweep_no)+"_times"
	
	Make/O/N=0 temp_amps
	Make/O/N=0 temp_ieis
	Make/O/N=0 temp_times
	Make/O/N=0 peak_locs
	variable baseline = 0			
	variable peak = 0
	variable event_amp = 0
	variable peak_location = 0

	variable i=0
	
	// FIND Kernel Extremum (so you know what range to look for peak)
	switch (mRadioVal)
		case 1:	//find min
			FindPeak/B=(peak_smoothing)/I/N/Q/P EPSC_Kernel	
			break
		case 2:	//find max
			FindPeak/B=(peak_smoothing)/I/Q/P EPSC_Kernel
			break
	endswitch
	
	variable kernel_peak = V_PeakLoc
	
	// now get peaks
	variable suspected_peak_loc = 0
	
	do
		if ((sel_events[i] & 2^4) != 0)		// if checked in manual selection window
	
			wavestats/Q/R=[peakPositionsX[i]*kHz*1e3-bline_range*kHz,peakPositionsX[i]*kHz*1e3] display_wave1
			baseline = V_avg			//determine baseline and peak for event amp
			
			suspected_peak_loc = (peakPositionsX[i]+peak_offset/1e3)*kHz*1e3+kernel_peak		// in samples
			
			wavestats/Q/R=[suspected_peak_loc-peak_range*kHz,suspected_peak_loc+peak_range*kHz] display_wave1
			
			switch (mRadioVal)
				case 1:	//find min
					peak_location = V_minloc
					wavestats/Q/R=[V_minloc*kHz*1e3-peak_range*kHz/2,V_minloc*kHz*1e3+peak_range*kHz/2] display_wave1
					break
				case 2:	//find max
					peak_location = V_maxloc
					wavestats/Q/R=[V_maxloc*kHz*1e3-peak_range*kHz/2,V_maxloc*kHz*1e3+peak_range*kHz/2] display_wave1
					break
			endswitch

			
			peak = V_avg
			
			event_amp = peak-baseline
			
			switch (mRadioVal)
				case 1:	//find min
					if (event_amp > abs(hard_min_amp)*-1)	// if it's smaller than the minimum amplitude, or positive, uncheck
						sel_events[i] = sel_events[i] %^ 2^4
					else		// if it's big enough, record it
						insertpoints numpnts(temp_amps), 1, temp_amps
						temp_amps[numpnts(temp_amps)-1] = event_amp
						insertpoints numpnts(peak_locs), 1, peak_locs
						peak_locs[numpnts(peak_locs)-1] = peak_location
					endif
					break
				case 2:	//find max
					if (event_amp < abs(hard_min_amp))	// if it's smaller than the minimum amplitude, or negative, uncheck
						sel_events[i] = sel_events[i] %^ 2^4
					else		// if it's big enough, record it
						insertpoints numpnts(temp_amps), 1, temp_amps
						temp_amps[numpnts(temp_amps)-1] = event_amp
						insertpoints numpnts(peak_locs), 1, peak_locs
						peak_locs[numpnts(peak_locs)-1] = peak_location
					endif
					break
			endswitch
							
			text_events[i][1] = num2str(event_amp)		// record in list anyways, since it'll just be unchecked
		
		endif
		
		i+=1
	while (i < numpnts(peakPositionsX))

		
	if (numpnts(temp_amps)==0)
		killwaves/z temp_amps, $name_of_amps
		print "No events found or stored"
	else
		duplicate/O temp_amps, $name_of_amps
	
		print "--"+num2str(numpnts($name_of_amps))+" amplitudes saved into "+name_of_amps
		wavestats/z/q $name_of_amps
		print "     Mean = "+num2str(V_avg)+"    Std. Dev. = "+num2str(V_sdev)
		print "\n"
	endif
	
	i=0
	variable n=0			//counter		
	variable iei = 0
	variable prev_time = 0
	
	do
		if ((sel_events[i] & 2^4) != 0)								// if checked in manual selection window
			
			if (n != 0)
				iei = peakPositionsX[i]-prev_time
				insertpoints numpnts(temp_ieis), 1, temp_ieis
				temp_ieis[numpnts(temp_ieis)-1] = iei
			endif
			n+=1
			prev_time = peakPositionsX[i]							// save as reference for next number
			
			insertpoints numpnts(temp_times), 1, temp_times		// append time to wave
			temp_times[numpnts(temp_times)-1] = peakPositionsX[i]
		endif
		
		i+=1
	while (i < numpnts(peakPositionsX))
	
	if (numpnts(temp_ieis)==0)
		killwaves/z temp_ieis, $name_of_times
		print "No IEIs found or stored"
	else
		duplicate/O temp_ieis, $name_of_iei
		print "--"+num2str(numpnts($name_of_iei))+" intervals saved into "+name_of_iei
		wavestats/z/q $name_of_iei
		print "     Mean = "+num2str(V_avg)+"    Std. Dev. = "+num2str(V_sdev)
		print "----------------------------------------------"
		print "\n"	
	endif
	
	if (numpnts(temp_times)==0)
		killwaves/z temp_times, $name_of_times
	else
		duplicate/O temp_times, $name_of_times
	endif
	
		
	KillWaves temp_amps, temp_ieis, temp_times

end

Function bStoreEventTemplatesProc(ctrlName)
	string ctrlName

	wave sel_events = sel_events
	wave display_wave1 = display_wave1
	wave peakPositionsX = peakPositionsX
	NVAR kHz = kHz
	NVAR empKerDur = empKerDur
	NVAR disk_sweep_no = disk_sweep_no
	SVAR Expt = Expt
		
	Make/O/N=(empKerDur*kHz,1) setOfEvents=0		//multidimensional wave that will be appended with new waves

	//first find all sweeps that have been saved so far
	String AllTimesList = WaveList("s*_times", ";", "")
	Variable numList = ItemsInList(AllTimesList)
	Variable thisSweepNum
	
	//then iterate through each sweep, navigating to that sweep, and summing up all inputs
	
	variable i = 0		//sweep iterator
	variable n = 0		//number of events in this sweep
	variable j = 0		//number of events in ALL SWEEPS

	for (i=0;i<numList;i+=1)	
		
		string currentSweepTimesList = stringfromlist(i,AllTimesList)		//pick first wave in list of event times
		sscanf currentSweepTimesList, "s%f_times", thisSweepNum		//parse sweep number	
		
		//go to the sweep
		disk_sweep_no = thisSweepNum
		Find_Sweep(disk_sweep_no, Expt)
		Read_Sweep(Expt)

		duplicate/O $currentSweepTimesList tempSweepTimesList
				
		for(n=0;n<numpnts($currentSweepTimesList);n+=1)
			if(j>0)
				InsertPoints/M=1 DimSize(setOfEvents,1), 1, setOfEvents		//add another column
			endif
			variable eventLoc = tempSweepTimesList(n)
			Make/O/N=(empKerDur*kHz) singleEvent = display_wave1[p+eventLoc*kHz*1e3]		//grab the data
			variable baseSub = singleEvent[0]
			singleEvent -= baseSub						//baseline subtraction
			setOfEvents[][j] = singleEvent[p]		//insert single event into the column
			j+=1
		endfor
		
		killwaves tempSweepTimesList
	endfor
	
	
	SetScale/P x, 0, 1/(kHz), setOfEvents			// normalize to units of ms
	
	Variable numRows = DimSize(setOfEvents,0)
	Variable numCols = DimSize(setOfEvents,1)		//also known as j

	Make/O/N=0 meanTrace						//make mean trace
	
	variable kk
	for (kk=0;kk<numRows;kk+=1)
	
		duplicate/O/R=[kk][] setOfEvents tempWave
		Redimension/N=(numCols,0) tempWave
		Variable rowMean = mean(tempWave)
		meanTrace[kk] = rowMean
		InsertPoints numpnts(meanTrace), 1, meanTrace
		
	endfor
		
	SetScale/P x, 0, 1/(kHz), meanTrace

	String graphname = "Average_Trace"
	
	DoWindow/K $graphname											//cleanup
	String AllEventsList
	AllEventsList = WaveList("event_*", ";", "")

	printf "\r: killing event waves (event_*)\r"
 	numList = ItemsInList(AllEventsList)
 	Variable index
 	
 	if (numList != 0)
 		for (index=0;index<numList;index+=1)
 			KillWaves/Z $(StringFromList(index, AllEventsList))
 		endfor
 	endif
 	
	variable k												//plot it
	
	for (k=0; k<numCols; k+=1)
		string tempwavename = "event_"+num2str(k)
		duplicate/O/R=[][k] setOfEvents $tempwavename
		Redimension/N=(numRows,0) $tempwavename
		if (k==0)
			display/W=(0,212,645,752)/N=$graphname $tempwavename
		else
			AppendToGraph/W=$graphname $tempwavename
		endif
		ModifyGraph/W=$graphname rgb($tempwavename)=(52224,32224,32224), lsize($tempwavename)=0.5
	endfor

	AppendToGraph/W=$graphname meanTrace
	ModifyGraph/W=$graphname rgb(meanTrace)=(0,0,0), lsize(meanTrace)=2
	
	textbox/W=$graphname/A=MT/X=-3/F=0/E "Events, Mean and "+num2str(j)+" Singles"		
	Label left "pA"
	Label bottom "ms"
	
	Make/O/N=2 baseline = {0,0}
	Make/O/N=2 baselineX = {0,25}
	
	AppendToGraph baseline vs baselineX
	ModifyGraph lstyle(baseline)=7,rgb(baseline)=(0,0,0)

	
end

//--------------------END DECONVOLUTION STUFF----------------------------------------------------------------------


//--------------------START INCLUSION CRITERIA FUNCS----------------------------------------------------------------------

// Ken Burke, October 2015
// Used for determination of whether cells pass/fail certain inclusion criteria
// Originally developed for experiments in D1r modulation of Glutamate EPSCs

Function Baseline_Regression(drug_sweep, range)

	Variable drug_sweep	//sweep where drug hit the bath
	Variable range		//number of sweeps before drug application you want to go back
	Wave analysis2 = analysis2
	Wave W_StatsLinearRegression
	
	duplicate/o/r=((drug_sweep-range),drug_sweep) analysis2, lin_test
	StatsLinearRegression/T=1 lin_test
	
	if (W_StatsLinearRegression[9] > W_StatsLinearRegression[10])		// if the F statistic is above the critical F value
		print "\tThe baseline regression is significant"
		print "\t\t-- F = "+num2str(W_StatsLinearRegression[9])+"\n\t\t-- Fc = "+num2str(W_StatsLinearRegression[10])
		Variable slope = (W_StatsLinearRegression[2]*4)/mean(lin_test)
		if (slope < -0.03)			// if the slope is stronger than a 3% decrease per minute
			print "\tand the slope is stronger than 3% decrease / minute.... FAILURE"
			print "\t\t-- Slope = "+num2str(round(slope*10000)/100)
		else
			print "\tHowever, the slope of "+num2str(round(slope*10000)/100)+"% / minute does not indicate strong enough rundown....\nACCEPT"
		endif
	else
		print "\tThe baseline regression is not significant"
		print "\t\t-- F = "+num2str(W_StatsLinearRegression[9])+"\n\t\t-- Fc = "+num2str(W_StatsLinearRegression[10])
		print "ACCEPT"
	endif
	
end

Function FindPeakParams(sweep,start,stop)

	wave sweep
	variable start // timing of start of range, in ms
	variable stop // timing of stop
	NVAR kHz = kHz
	
	duplicate/O sweep, smoothed_sweep
	
	Smooth/B=10 4, smoothed_sweep

	variable V_minloc
	Wavestats/q/r=(start/1e3,stop/1e3) smoothed_sweep
	Print "--peak location at "+num2str(V_minloc*1e3)+" ms, "+num2str(V_min)+" pA"
	
	// the following assumes you've already zero'd to baseline
	
	variable peak_90 = sweep(V_minloc)*0.9
	variable peak_10 = sweep(V_minloc)*0.1
	
	duplicate/O/R=(0.1,0.12) sweep, sweep_chunk
	interpolate2/n=(numpnts(sweep_chunk)*1e4) sweep_chunk
	FindValue/S=0.101/V=(peak_10)/T=1e-3 $(NameOfWave(sweep_chunk)+"_CS")
	variable ten = V_Value/(1e4*kHz) + 100
	FindValue/S=0.101/V=(peak_90)/T=1e-3 $(NameOfWave(sweep_chunk)+"_CS")
	variable ninety = V_Value/(1e4*kHz) + 100
	print "\t10% reached at "+num2str(ten)
	print "\t90% reached at "+num2str(ninety)
	print "--Rise Time = "+num2str((ninety-ten)*1e3)+" us"
	KillWaves $(NameOfWave(sweep_chunk)+"_CS")
	

end

Function RInput_Change(pre_average, post_average)

	wave pre_average	//sweep
	wave post_average 
	Variable V_avg = V_avg
	
	wavestats/q/r=(0.52,0.549) average_0 
	Variable baseline_ihold = V_avg
	
	wavestats/q/r=(0.64,0.669) average_0 
	Variable baseline_step = V_avg
	
	Variable baseline_rin = (-5/(baseline_step-baseline_ihold))*1e3
	
	print "-- Baseline Rinput = "+num2str(baseline_rin)+" Mohm"
	
	wavestats/q/r=(0.52,0.549) average_1
	Variable post_ihold = V_avg
	
	wavestats/q/r=(0.64,0.669) average_1 
	Variable post_step = V_avg
	
	Variable post_rin = (-5/(post_step-post_ihold))*1e3
	
	print "-- Post Rinput = "+num2str(post_rin)+" Mohm"
	
	print "\t\tPercent change = "+num2str(100*((post_rin / baseline_rin)-1))+"%"
	
end

Function Ihold_Change(drug_sweep, post_sweep, range)

	variable drug_sweep	//sweep
	variable post_sweep
	variable range 
	Variable V_avg = V_avg
	
	wavestats/q/r=((drug_sweep-range),drug_sweep) analysis7
	Variable baseline_ihold = V_avg
	
	wavestats/q/r=(post_sweep,(post_sweep+range)) analysis7 
	Variable post_ihold = V_avg
	
	print "-- Baseline Ihold = "+num2str(baseline_ihold)+" pA"
	print "-- Post Ihold = "+num2str(post_ihold)+" pA"
	
end

Function Amplitude_Change(drug_sweep, post_sweep, range)

	variable drug_sweep	//sweep
	variable post_sweep
	variable range 
	Variable V_avg = V_avg
	
	wavestats/q/r=((drug_sweep-range),drug_sweep) analysis2
	Variable baseline_Amp1 = V_avg
	
	wavestats/q/r=(post_sweep,(post_sweep+range)) analysis2 
	Variable post_Amp1 = V_avg
	
	print "-- Baseline Amp1 = "+num2str(baseline_Amp1)+" pA"
	print "-- Post Amp1 = "+num2str(post_Amp1)+" pA"
	
	wavestats/q/r=((drug_sweep-range),drug_sweep) analysis5
	Variable baseline_Amp2 = V_avg
	
	wavestats/q/r=(post_sweep,(post_sweep+range)) analysis5 
	Variable post_Amp2 = V_avg
	
	print "-- Baseline Amp2 = "+num2str(baseline_Amp2)+" pA"
	print "-- Post Amp2 = "+num2str(post_Amp2)+" pA"
	
end

Function CV_Change(drug_sweep, post_sweep, range, pre_noise_variance,post_noise_variance,sequential,point)
	// set cursors to range in which you expect to find the peak
	// MUST BE BASELINE SUBTRACTED!! (only finds value for amplitude, not the difference between amplitude and baseline!)
	// IF SEQUENTIAL = 1, use "sequential variance" estimate, starting with 5 sweeps before post_sweep onwards

	variable drug_sweep	//sweep
	variable post_sweep
	variable range
	variable pre_noise_variance 
	variable post_noise_variance
	variable sequential	 		// toggle.... if 1, estimate variance on sweep-by-sweep basis to correct for changing baseline. If 0, just use normal variance
	variable point					// toggle, if 1 use value at xcsr(A) rather than minimum between cursors
	Variable V_avg = V_avg
	NVAR disk_sweep_no = disk_sweep_no
	wave display_wave1

	Make/O/N=(range+1) pre_amps
	Make/O/N=(range+1) post_amps
	
	variable i=0
	disk_sweep_no = (drug_sweep-range)
	bReadWaveProc("")
	do
		if (point == 1)
			pre_amps[i] = display_wave1(xcsr(A))
		else
			FindPeak/Q/B=25/N/R=(xcsr(A),xcsr(B)) display_wave1		
			pre_amps[i] = V_PeakVal
		endif
		
		bNextWaveProc("")
		i+=1
	while (i<(range+1))
	
	wavestats/q pre_amps
	
	Variable running_sum_sq_base = 0
	Variable base_CV_sq = 0
	if (sequential==0)
		base_CV_sq = (V_sdev^2-pre_noise_variance)/V_avg^2

	elseif (sequential == 1)
		i=1
		do
			running_sum_sq_base += (pre_amps[i+1]-pre_amps[i])^2
			i += 1
		while (i < range)
		Variable seq_base_variance = running_sum_sq_base / (2*(range-1))
		base_CV_sq = (seq_base_variance-pre_noise_variance)/V_avg^2
	endif
	
	print "-- Baseline CV^2 = "+num2str(base_CV_sq)

	i=0
	disk_sweep_no = (post_sweep)
	bReadWaveProc("")
	do
		if (point == 1)
			post_amps[i] = display_wave1(xcsr(A))
		else
			FindPeak/Q/B=25/N/R=(xcsr(A),xcsr(B)) display_wave1		
			post_amps[i] = V_PeakVal
		endif
		bNextWaveProc("")
		i+=1
	while (i<(range+1))


	wavestats/q post_amps
	Variable running_sum_sq_post = 0
	Variable post_CV_sq = 0
	if (sequential==0)
		post_CV_sq = (V_sdev^2-post_noise_variance)/V_avg^2

	elseif (sequential == 1)
		i=1
		do
			running_sum_sq_post += (post_amps[i+1]-post_amps[i])^2
			i += 1
		while (i < range)
		Variable seq_post_variance = running_sum_sq_post / (2*(range-1))
		post_CV_sq = (seq_post_variance-post_noise_variance)/V_avg^2
	endif
	
	print "-- Post CV^2 = "+num2str(post_CV_sq)

end

Function Noise_Variance(wave1,wave2,wave3)
	//pick three waves in one condition, set cursors and go
	Variable wave1
	variable wave2
	variable wave3
	
	NVAR disk_sweep_no = disk_sweep_no
	
	variable noise_variance = 0
	
	disk_sweep_no = wave1
	bReadWaveProc("")
	wavestats/q/r=(xcsr(A),xcsr(B)) display_wave1
	noise_variance += (V_sdev^2)
	disk_sweep_no = wave2
	bReadWaveProc("")
	wavestats/q/r=(xcsr(A),xcsr(B)) display_wave1
	noise_variance += (V_sdev^2)
	disk_sweep_no = wave3
	bReadWaveProc("")
	wavestats/q/r=(xcsr(A),xcsr(B)) display_wave1
	noise_variance += (V_sdev^2)
	
	noise_variance /=3
	print "Average Noise Variance = "+num2str(noise_variance)
	
end

Function Run_Inclusion_Test(drug_sweep, post_sweep, regress_range, average_range)

// MUST SET CURSORS AROUND EXPECTED PEAK LOC
// Must Zero Averages/DisplayWave first

	variable drug_sweep
	variable post_sweep
	variable regress_range // normally 40
	variable average_range // normally 10
	
	print "\n"
	print "\nBaseline Regression"
	Baseline_Regression(drug_sweep, regress_range)
	print "\n"
	print "\nPeak Parameters, Baseline"
	FindPeakParams(Average_0,xcsr(A)*1e3, xcsr(B)*1e3)
	print "\n"
	print "\n\nPeak Parameters, Post"
	FindPeakParams(Average_1,xcsr(A)*1e3, xcsr(B)*1e3)
	print "\n"
	print "\n\nResistance Change"
	RInput_Change(Average_0, Average_1)
	print "\n"
	print "\n\nHolding Current Change"
	Ihold_Change(drug_sweep, post_sweep, average_range)
	print "\n"
	print "\n\nEPSC Change"
	Amplitude_Change(drug_sweep, post_sweep, average_range)
	print "\n"

end

//-------------END INCLUSION CRITERIA FUNCS--------------

//-------------EXTRA STUFF--------------

Function low_cal(range_wave, intervals)

// ASSUMPTIONS: range_wave puts the "high_cal" ranges first, then "low_cal", and in the same order (e.g. 20h,10h,40h,80h,20l,10l,40l,80l)

	Wave/T range_wave
	Wave intervals	// = wave of inter-stim-intervals, in ms, half length as "range_wave" (e.g. {50,100,25,12.5} )



	Select_Avg_Proc()
	
	Variable i=0
	do
		string namestr="Avg"+num2str(i)
		Avg_Checked(namestr,1)
		
		namestr="Range"+num2str(i)
		string nameval = "RangeStr"+num2str(i)
		string valstr = range_wave[i]
		variable valnum = 5
		SetRange(namestr, valnum, valstr, nameval)
		
		String/G $nameval = range_wave[i]
		
		i += 1
	while(i < numpnts(range_wave))
	
	bMake_Average_Proc("bAvgOK")
	
	bZEROProc("bZERO")
	
	i=0
	variable j=0
	variable toggle = 0
	
	Make/N=3/O colorwave={0,0,0}		//black
	
	do
		string sweepstr = "Average_"+num2str(j)
		if(j<(numpnts(range_wave)/2))
			colorwave={0,0,0}
		elseif(j>(numpnts(range_wave)/2))
			colorwave={32768,32768,32768}
		else
			colorwave={44584,44584,44584}
		endif
		
		if(i>0)
			colorwave[i-1]=65280		//rgb
		endif
		
		ModifyGraph/W=Sweep_window rgb($sweepstr)=(colorwave[0],colorwave[1],colorwave[2])
		
		if (i==((numpnts(range_wave)/2)-1))
			i=-1
			colorwave={19584,19584,19584}
		endif
		
		i+=1
		j+=1

	while( j < numpnts(range_wave))
	
	SetAxis/W=Sweep_window bottom, 0.08, 0.25
	SetAxis/W=Sweep_window left, -150, 50
	
	i=0

	Make/O/N=(numpnts(range_wave)/2) ppr_sens_wave
	Make/O/N=(numpnts(range_wave)/2) high_ppr_wave
	Make/O/N=(numpnts(range_wave)/2) low_ppr_wave
	execute "variable temp_scale_factor = 0"
	string cmdstr
	do
		string basestr = "Average_"+num2str(i)
		string poststr = "Average_"+num2str(i+numpnts(range_wave)/2)	
		variable start_peak_range = 0.1025
		variable end_peak_range = 0.107
		
		//scale the first peaks to be the same (for a given frequency)
		FindPeak/N/B=(5)/I/P/Q/R=(start_peak_range,end_peak_range) $basestr
		variable first_amp = V_PeakVal
		cmdstr = "temp_scale_factor = "+num2str(V_PeakVal)+"/"+poststr+"[round("+num2str(V_PeakLoc)+")]"
		execute cmdstr
		cmdstr = poststr+" *= temp_scale_factor"
		execute cmdstr
		
		//find the ratio of the "low cal" peak to the "high cal" peak (%change)
		FindPeak/N/B=(5)/I/P/Q/R=((start_peak_range+intervals[i]*1e-3),(end_peak_range+intervals[i]*1e-3)) $basestr
		variable high_ppr = (V_PeakVal/first_amp)
		FindPeak/N/B=(5)/I/P/Q/R=((start_peak_range+intervals[i]*1e-3),(end_peak_range+intervals[i]*1e-3)) $poststr
		variable low_ppr = (V_PeakVal/first_amp)
		variable ppr_sens = (low_ppr/high_ppr)
		print ""
		print num2str(1/intervals[i]*1e3)+"Hz : High PPR = "+num2str(high_ppr)+", Low PPR = "+num2str(low_ppr)+"       => PPR sensitivity = "+num2str(ppr_sens)
		
		high_ppr_wave[i] = high_ppr
		low_ppr_wave[i] = low_ppr
		ppr_sens_wave[i] = ppr_sens
		
		i += 1
	while( i < (numpnts(range_wave)/2))
	execute "KillVariables temp_scale_factor"

	
end

function GO(numreps,int)
	variable numreps, int
	NVAR disk_sweep_no = disk_sweep_no
	wave display_wave1 = display_wave1
	
	duplicate/O display_wave1 meanTrace
	
	variable start = disk_sweep_no
	
	variable i
	
	for(i=1;i<numreps;i+=1)
		disk_sweep_no = start + i*int
		bReadWaveProc("")
		meanTrace += display_wave1
	endfor
	
	meanTrace /= i
	display meanTrace
	
end


//--------------------END Ken's Favorite Functions----------------------------------------------------------------------
