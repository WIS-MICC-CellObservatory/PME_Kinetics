#@ String(choices=("Segment", "Update"), style="list") runMode
#@ String(choices=("singleFile", "wholeFolder", "AllSubFolders"), style="list") processMode
#@ String (label="File Extension",value=".nd2", persist=true, description="eg .nd2 .tif, .h5") fileExtension
#@ Boolean(label="Check For Existing Ilastik Output File?",value=true, persist=true, description="Use previous Ilastik results if exist") checkForExistingIlastikOutputFile
#@ File(label="Ilastik Location", persist=true, description="point to the exe location of the Ilastik software executable eg C:/Program Files/ilastik-1.3.3post3/ilastik.exe") IlastikLocation
#@ Integer(label="Max memory for Ilastik (MB)", min=0, max=256000, value=150000, persist=true, description="set to about 70-80% of available RAM") IlastikMaxMemoryMB
#@ File(label="Ilastik Embryo Classifier", persist=true, description="point to the ilp file of Ilastik AutoContext classifier, eg  = E:/Data/Lab/AutoContext_ForEmbryo.ilp , embryo is class 2") IlastikAutoContextClassifier
#@ Integer(label="Num of pixels to erode from detected Embryo", min=0, max=20, value=3, persist=true) erodeEmbryoPixels
#@ Boolean(label="Apply backround subtraction before segmentation?",value=true, persist=true, description="Apply Rolling Ball Background subtraction?") applyRollingBallBGS
#@ Integer(label="Rolling Ball Sigma", min=0, max=100, value=25, persist=true) rollingBallSigma
#@ Integer(label="Minimum Paternal Mitochondria Intensity To Measure", min=0, max=20000, value=2000, persist=true) MinIntensityToMeasure


/*
 * QuantifyPaternalMitochondriaInEmbryo2D.ijm
 * 
 * Segment Embryo from brightfield images using Ilastik autocontext workflow, and quantify paternal mitochondria intensity within each embryo from flourescent channel 
 * 
 * Workflow
 * ========
 * - Read image, 
 * - Segment Embryo: 
 * 		Run Ilastik Autocontext pixel classifier - it is assumed that the embryo class is 2 and the background is YY 
 * 		Process labels: 
 * 			erode labels by  erodeEmbryoPixels (defualt 3)  to avoid artifacts on the edges of the embryo 
 * 			remove segments smaller than  MinSizePixels (default 5000) 
 * 		Add the embryos regions to the Rois Manager
 * 	- Quantify flourescent signal: 
 * 		- optionally (default, depends on applyRollingBallBGS) apply Rolling ball background subtraction with sigma = rollingBallSigma
 * 		- segment Mito-positive regions by applying fixed threshold (MinIntensityToMeasure) to the florescent signal - optionally afterbackground subtraction
 * 		- for each embryo quantify total/mean signal in whole embryo / Mito-Positive region / Mito negative region, calculate MeanMitoPositive-MeanMitoNegative 
 *  - Save results 
 * 		- Create Quality control images
 * 		- save Rois - to enable manual correction of embryo regions with Update mode
 * 		- save results in a table with one line for each embryo in each image
 * 
 *  You can use previous ilastik clasification by checking "CheckForExistingIlastikOutputFile". 
 *  This is useful if you want to try different macro parameters without running ilastik again (as it takes most of the runtime)
 *  
 *  If the embryo segmentation is not good enouh for some of the embryos, 
 *  you can use manually correct the embryo segmentation (see below) and and run the macro in update mode. 
 *  This will use the manually corrected segmentation if this is available and the original automatic segmentation for all other embryos
 * 
 * Usage
 * =====
 * 
 * 	1. Run in Segment Mode
 * 		- Set runMode to be Segment 
 * 		- Set processMode to singleFile or wholeFolder or AllSubfolders
 * 		- select Iastik location and Ilastik classifier
 * 		- set parameters - see description above
 * 	
 * 	3. Manual correction
 * 		- Careful inspection of results:  
 * 		- ... correct embryos Rois if needed ... 
 * 		- Save as FN_RoiSet_Manual.zip
 * 		- Set runMode to be Update 
 * 		- Set processMode to singleFile or wholeFolder
 * 		
 * - NOTE: It is very important to inspect All quality control images to verify that segmentation is correct 
 * 
 * Output
 * ======
 * For each input image FN, the following output files are saved in ResultsSubFolder under the input folder
 * - FN_Ch1Overlay.tif 	- the original brightfield channel with overlay of the segmented Embryos in magenta (EmbryoColor)
 * - FN_Ch2_AboveTh.tif - the flourescnce channel after background subtraction and where all pixels below MinIntensityToMeasureare set to 0  
 * - FN_Ch2Overlay.tif 	- the original flourescnce channel with overlay of the segmented Embryos in magenta (EmbryoColor), and PME signal above threshold in yellow (IntensityColor)  
 * - FN_DetailedResults.xls - the detailed measurements with one line for each embros in the image  
 * - FN_EmbryosRoiSet.zip   - the embryo segments used for measurements - this file can be used for manually update 
 * - FN__Segmentation Stage 2.h5  - the Crystal Domain segments used for measurements
 * 
 *  Overlay colors can be controled by EmbryoColor and IntensityColor
 * 
 * AllDetailedResults_test.xls - Table with one line for each embryo in each image file  
 * QuantifyPaternalMitochondriaInEmbryo2DParameters.txt - Parameters used during the latest run
 * 
 * Dependencies
 * ============
 * Fiji with ImageJ version > 1.53e (Check Help=>About ImageJ, and if needed use Help=>Update ImageJ...
 * This macro requires the following Update sites to be activate through Help=>Update=>Manage Update site
 * - Ilastik Fiji Plugin (add "Ilastik" to your selected Fiji Update Sites)
 * 
 * Please cite Fiji (https://imagej.net/Citing) and Ilastik (https://www.ilastik.org/about.html) 
 * 
 * By Ofra Golani, MICC Cell Observatory, Weizmann Institute of Science, June 2022
 * 
 */


// ============ Parameters =======================================
var macroVersion = "v2";

var MinSizePixels = 5000;
var EmbryoColor = "magenta";
var LineWidth = 2;
var IntensityColor = "yellow";

var IlastikAutoContextExtention = "_Segmentation Stage 2.h5";

var EmbryosRoisSuffix = "_EmbryosRoiSet"; 

var ResultsSubFolder = "Results";
var cleanupFlag = 1; 
var debugFlag = 0; 

// Global Parameters
var SummaryTable = "SummaryResults.xls";
var AllDetailedTable = "DeatiledResults.xls";
var SuffixStr = "";
var SegTypeStr = "";
var TimeString;
var saveIlastikOutputFileFlag = 1;
var SaveColorCodeImages = 0;
var generateSummaryLines = 1;

// ================= Main Code - Don't Change below this line ====================================

Initialization();

// Choose image file or folder
if (matches(processMode, "singleFile")) {
	file_name=File.openDialog("Please select an image file to analyze");
	directory = File.getParent(file_name);
	}
else if (matches(processMode, "wholeFolder")) {
	directory = getDirectory("Please select a folder of images to analyze"); }

else if (matches(processMode, "AllSubFolders")) {
	parentDirectory = getDirectory("Please select a Parent Folder of subfolders to analyze"); }


// Analysis 
if (matches(processMode, "wholeFolder") || matches(processMode, "singleFile")) {
	resFolder = directory + File.separator + ResultsSubFolder + File.separator; 
	File.makeDirectory(resFolder);
	print("inDir=",directory," outDir=",resFolder);
	SavePrms(resFolder);
	
	if (matches(processMode, "singleFile")) {
		ProcessFile(directory, resFolder, file_name); }
	else if (matches(processMode, "wholeFolder")) {
		ProcessFiles(directory, resFolder); }
}

else if (matches(processMode, "AllSubFolders")) {
	list = getFileList(parentDirectory);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(parentDirectory + list[i])) {
			subFolderName = list[i];
			subFolderName = substring(subFolderName, 0,lengthOf(subFolderName)-1);

			directory = parentDirectory + subFolderName + File.separator;
			resFolder = directory + ResultsSubFolder + File.separator; 
			File.makeDirectory(resFolder);
			print("inDir=",directory," outDir=",resFolder);
			SavePrms(resFolder);
			CloseTable(AllDetailedTable);
			ProcessFiles(directory, resFolder);
			print("Processing ",subFolderName, " Done");
		}
	}
}

if (cleanupFlag==true) 
{
	CloseTable(SummaryTable);	
	CloseTable(AllDetailedTable);	
}
setBatchMode(false);
print("=================== Done ! ===================");

// ================= Helper Functions ====================================

//===============================================================================================================
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(directory, resFolder) 
{
	dir1=substring(directory, 0,lengthOf(directory)-1);
	idx=lastIndexOf(dir1,File.separator);
	subdir=substring(dir1, idx+1,lengthOf(dir1));

	// Get the files in the folder 
	fileListArray = getFileList(directory);
	
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], fileExtension) ) {
			file_name = directory+File.separator+fileListArray[fileIndex];
			//open(file_name);	
			//print("\nProcessing:",fileListArray[fileIndex]);
			showProgress(fileIndex/lengthOf(fileListArray));
			ProcessFile(directory, resFolder, file_name);
		} // end of if 
	} // end of for loop

	if (isOpen(AllDetailedTable))
	{
		if (generateSummaryLines)
			GenerateSummaryLines(AllDetailedTable);
		selectWindow(AllDetailedTable);
		AllDetailedTable1 = replace(AllDetailedTable, ".xls", "");
		print("AllDetailedTable=",AllDetailedTable,"AllDetailedTable1=",AllDetailedTable1,"subdir=",subdir);
		saveAs("Results", resFolder+AllDetailedTable1+"_"+subdir+".xls");
		run("Close");  // To close non-image window
	}
	
	// Cleanup
	if (cleanupFlag==true) 
	{
		CloseTable(AllDetailedTable);	
	}
} // end of ProcessFiles


//===============================================================================================================
// Run analysis of single file
function ProcessFile(directory, resFolder, file_name) 
{

	// ===== Open File ========================
	print(file_name);
	if ( endsWith(file_name, "h5") )
		run("Import HDF5", "select=["+file_name+"] datasetname=[/data: (1, 1, 1024, 1024, 1) uint8] axisorder=tzyxc");
	else if (endsWith(file_name, "nd2") )
		run("Bio-Formats Importer", "open=["+file_name+"] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT use_virtual_stack");
	else
		open(file_name);

	directory = File.directory;
	origName = getTitle();
	Im = getImageID();
	origNameNoExt = File.getNameWithoutExtension(file_name);

	run("Duplicate...", "title=Ch1 duplicate channels=1");

	IlastikAutoContextOutFile = origNameNoExt+IlastikAutoContextExtention;
	if (matches(runMode,"Segment")) 
	{

		getVoxelSize(pixelWidth, pixelHeight, pixelDepth, pixelUnit);
	
		found = 0;
		if (checkForExistingIlastikOutputFile)
		{
			if (File.exists(resFolder+IlastikAutoContextOutFile) && File.exists(resFolder+IlastikAutoContextOutFile))
			{
				print("Reading existing Ilastik AutoContext output ...");
				run("Import HDF5", "select=["+resFolder+IlastikAutoContextOutFile+"] datasetname=/data axisorder=tzyxc");
				rename(IlastikAutoContextOutFile);
				found = 1;
			}
		}
		if (found == 0)
		{
			// Segmentation is based on Ilastik AutoContext Pixel Classifier
			print("Running Ilastik AutoContext classifier...");
			run("Run Autocontext Prediction", "projectfilename=["+IlastikAutoContextClassifier+"] inputimage=Ch1 autocontextpredictiontype=Segmentation");
			rename(IlastikAutoContextOutFile);
			
			if (saveIlastikOutputFileFlag)
			{
				selectWindow(IlastikAutoContextOutFile);
				print("Saving Ilastik autocontext classifier output...");
				run("Export HDF5", "select=["+resFolder+IlastikAutoContextOutFile+"] exportpath=["+resFolder+IlastikAutoContextOutFile+"] datasetname=data compressionlevel=0 input=["+IlastikAutoContextOutFile+"]");	
				rename(IlastikAutoContextOutFile);
			}
		}

		selectWindow(IlastikAutoContextOutFile);
		setVoxelSize(pixelWidth, pixelHeight, pixelDepth, pixelUnit);
		run("glasbey on dark");

		run("Duplicate...", "title=IlastikSeg");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		
		if (erodeEmbryoPixels > 0)
		{
			run("Gray Morphology", "radius="+erodeEmbryoPixels+" type=circle operator=erode");	
		}

		run("Analyze Particles...", "size="+MinSizePixels+"-Infinity exclude include add");
		roiManager("Set Color", EmbryoColor);
		roiManager("Set Line Width", LineWidth);
		roiManager("Associate", "false");

	} else if (matches(runMode,"Update")) {
		GetEmbryosFromRoiFile(directory, resFolder, origName, origNameNoExt);
	}

	nEmbryo = roiManager("count");
	aSegMode =  newArray(nEmbryo);
	aFileName = newArray(nEmbryo);
	aEmbryoName = newArray(nEmbryo);
	aTotalEmbryoArea = newArray(nEmbryo);
	aTotInt = newArray(nEmbryo);
	aMeanInt = newArray(nEmbryo);
	aMeanIntAboveTh = newArray(nEmbryo);
	aTotIntAboveTh = newArray(nEmbryo);
	aFracAreaIntAboveTh = newArray(nEmbryo);

	aAreaInMito = newArray(nEmbryo);
	aTotIntInMito = newArray(nEmbryo);
	aMeanIntInMito = newArray(nEmbryo);

	aAreaInNonMito = newArray(nEmbryo);
	aTotIntInNonMito = newArray(nEmbryo);
	aMeanIntInNonMito = newArray(nEmbryo);

	aMeanIntInMitoMinusNonMito = newArray(nEmbryo);

	// Collect Results for each embryo
	if ( matches(runMode,"Segment") || matches(runMode,"Update") ) 
	{
		run("Set Measurements...", "area mean integrated area_fraction redirect=None decimal=3");	
		Table.reset("Results");
		selectWindow(origName);
		
		// Measure Total Intensity inside the Embryo
		run("Duplicate...", "title=Ch2 duplicate channels=2");
		roiManager("Measure");
		
		// Measure Intensity above Fixed Threshold inside the embryo
		selectWindow("Ch2");
		roiManager("Show None");
		run("Select None");
		run("Duplicate...", "title=Ch2_AboveThMask");

		if (applyRollingBallBGS)
		{
			run("Subtract Background...", "rolling="+rollingBallSigma);
		}

		selectWindow("Ch2_AboveThMask");
		setThreshold(MinIntensityToMeasure, 65535, "raw");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		roiManager("Measure"); // measure Area Fraction
		run("Select None");
		
		run("Duplicate...", "title=Ch2_AboveThMask1");
		run("Divide...", "value=255");
		imageCalculator("Multiply create", "Ch2","Ch2_AboveThMask1");
		selectWindow("Result of Ch2");
		rename("Ch2_AboveTh");
		roiManager("Show All");
		roiManager("Measure"); // measure area & total intensity above threshold for each embryo

		// Collect results for each embryo 
		for (n = 0; n < nEmbryo; n++) 
		{
			aFileName[n] = origNameNoExt;
			aTotalEmbryoArea[n] = getResult("Area", n);
			if (matches(runMode,"Segment"))
				aSegMode[n] = "Auto";
			if (matches(runMode,"Update"))
				aSegMode[n] = SegTypeStr;
			aTotInt[n] = getResult("RawIntDen", n);
			aMeanInt[n] = getResult("Mean", n);
			aFracAreaIntAboveTh[n] = getResult("%Area", nEmbryo + n);
			aTotIntAboveTh[n] = getResult("RawIntDen", nEmbryo*2 + n);
			aMeanIntAboveTh[n] = getResult("Mean", nEmbryo*2 + n);
			roiManager("select", n);
			aEmbryoName[n] = "Embryo_"+d2s(n+1,0);
			roiManager("rename", aEmbryoName[n]);
			
			// Measure intensity in Mito/non-Mito regions for each embryo
			selectWindow("Ch2_AboveThMask");
			run("Duplicate...", "title=Ch2_AboveThMask_tmp");
			roiManager("Select", n);
			setBackgroundColor(0, 0, 0);
			run("Clear Outside");
			run("Create Selection");
			selectWindow("Ch2");
			run("Restore Selection");
			run("Measure");
			run("Select None");
			selectWindow("Ch2_AboveThMask_tmp");
			run("Select None");
			roiManager("Select", n);
			run("Invert");
			run("Create Selection");
			selectWindow("Ch2");
			run("Restore Selection");
			run("Measure");

			aAreaInMito[n] = getResult("Area", nEmbryo*3 + n*2);
			aTotIntInMito[n] = getResult("RawIntDen", nEmbryo*3 + n*2);
			aMeanIntInMito[n] = getResult("Mean", nEmbryo*3 + n*2);

			aAreaInNonMito[n] = getResult("Area", nEmbryo*3 + n*2 + 1);
			aTotIntInNonMito[n] = getResult("RawIntDen", nEmbryo*3 + n*2 + 1);
			aMeanIntInNonMito[n] = getResult("Mean", nEmbryo*3 + n*2 + 1);												
			
			aMeanIntInMitoMinusNonMito[n] = aMeanIntInMito[n] - aMeanIntInNonMito[n];
			
			selectWindow("Ch2_AboveThMask_tmp");
			close();
			selectWindow("Ch2");
			run("Select None");
		}
		roiManager("deselect");
		Array.show("DetailedResults", aFileName, aSegMode, aEmbryoName, aTotalEmbryoArea, aTotInt, aMeanInt, aFracAreaIntAboveTh, aTotIntAboveTh, aMeanIntAboveTh, aAreaInMito, aTotIntInMito, aMeanIntInMito, aAreaInNonMito, aTotIntInNonMito, aMeanIntInNonMito, aMeanIntInMitoMinusNonMito);

		// create QA images
		SaveOverlayImage("Ch2", "Ch2_AboveThMask", IntensityColor, origNameNoExt, "_Ch2Overlay"+SuffixStr+".tif", resFolder, 0);
		SaveOverlayImage("Ch1", "", IntensityColor, origNameNoExt, "_Ch1Overlay"+SuffixStr+".tif", resFolder, 1);
		
		// save ch2_AboveTh
		selectWindow("Ch2_AboveTh");
		saveAs("Tiff", resFolder+origNameNoExt+"_"+"Ch2_AboveTh.tif");	
		
		//print(origName, nEmbryo, nElongated, percentElongated, meanArea, meanAR, meanCirc, meanRound);
		if (matches(runMode,"Segment")) 
		{
			SaveEmbryosRois(resFolder+origNameNoExt+EmbryosRoisSuffix);
		}
		
		// =========== Add lines for each embryo to All Detailed Table =============
		AppendTables(AllDetailedTable,"DetailedResults");
		run("Clear Results");
			
		selectWindow("DetailedResults");
		saveAs("Results", resFolder+origNameNoExt+"_DetailedResults.xls");		
		CloseTable(origNameNoExt+"_DetailedResults.xls");
		
	}

	if (debugFlag) waitForUser;
	if(cleanupFlag) Cleanup();

	setBatchMode(false);
} // end of ProcessFile


//===============================================================================================================
// append the content of additonalTable to bigTable
// if bigTable does not exist - create it 
// if additonalTable is empty or dont exist - do nothing
function AppendTables(bigTable, additonalTable)
{

	// if additonalTable is empty or don't exist - do nothing
	if (!isOpen(additonalTable)) return;
	selectWindow(additonalTable);
	nAdditionalRows = Table.size;
	if (nAdditionalRows == 0) return;
	Headings = Table.headings;
	headingArr = split(Headings);

	if (!isOpen(bigTable))
	{
		Table.create(bigTable);
	}
	selectWindow(bigTable);
	nRows = Table.size;

	// loop over columns of additional Table and add them to bigTable
	for (i = 0; i < headingArr.length; i++)
	{
		selectWindow(additonalTable);
		ColName = headingArr[i];
		valArr = Table.getColumn(ColName);
		if (valArr.length == 0) continue;
		
		selectWindow(bigTable);
		for (j = 0; j < nAdditionalRows; j++)
		{
			//print(i, ColName, j, valArr[j]);
			Table.set(ColName, nRows+j, valArr[j]); 
		}
	}

	selectWindow(bigTable);
	Table.showRowNumbers(true);
	Table.update;
	
} // end of AppendTables


//===============================================================================================================
function GenerateSummaryLines(tableName)
{
	if (isOpen(tableName))
	{
		//Table.rename(tableName, "Results");
		selectWindow(tableName);
		nRows = Table.size;
		Headings = Table.headings;
		headingArr = split(Headings);

		selectWindow(tableName);
		Table.set("Label", nRows, "MeanValues"); 
		Table.set("Label", nRows+1, "StdValues"); 
		Table.set("Label", nRows+2, "MinValues"); 
		Table.set("Label", nRows+3, "MaxValues"); 
		for (i = 0; i < headingArr.length; i++)
		{
			ColName = headingArr[i];
			if (matches(ColName, "Label")) continue;

			valArr = Table.getColumn(ColName);
			valArr = Array.trim(valArr, nRows);
			Array.getStatistics(valArr, minVal, maxVal, meanVal, stdVal);
			if (!isNaN(meanVal))
			{
				Table.set(ColName, nRows,   meanVal); 
				Table.set(ColName, nRows+1, stdVal); 
				Table.set(ColName, nRows+2, minVal); 
				Table.set(ColName, nRows+3, maxVal); 
			}
		}
		Table.update;
	}
} // end of GenerateSummaryLines




//===============================================================================================================
// used in Update mode
function GetEmbryosFromRoiFile(directory, resFolder, origName, origNameNoExt)
{
	baseRoiName = resFolder+origNameNoExt+EmbryosRoisSuffix;
	manualROIFound = OpenExistingROIFile(baseRoiName);
	if (manualROIFound) 
	{
		SuffixStr = "_Manual";
		SegTypeStr = "Manual";
	}
	else 
	{	
		SuffixStr = "";
		SegTypeStr = "Auto";
	}
	print(origName, SuffixStr, SegTypeStr);
}

		
//===============================================================================================================
function SaveEmbryosRois(FullRoiNameNoExt)
{
	nRois = roiManager("count");
	if (nRois > 1)
		//roiManager("Save", resFolder+origNameNoExt+CellRoisSuffix+".zip");
		roiManager("Save", FullRoiNameNoExt+".zip");
	if (nRois == 1)
		//roiManager("Save", resFolder+origNameNoExt+CellRoisSuffix+".roi");
		roiManager("Save", FullRoiNameNoExt+".roi");
}


//===============================================================================================================
function Initialization()
{
	requires("1.53i");
	run("Check Required Update Sites");

	setBatchMode(false);
	run("Close All");
	print("\\Clear");
	run("Options...", "iterations=1 count=1 black");
	roiManager("Reset");

	// Name Settings, Set output Suffixes based on SegMode
	if (matches(runMode, "Segment")) 
	{
		SummaryTable = "SummaryResults.xls";
		AllDetailedTable = "AllDetailedResults.xls";
	} else  // (SegMode=="Update") 
	{
		SummaryTable = "SummaryResults_Manual.xls";
		AllDetailedTable = "AllDetailedResults_Manual.xls";
	}	
	CloseTable("Results");
	CloseTable("DetailedResults");
	CloseTable(SummaryTable);
	CloseTable(AllDetailedTable);

	run("Collect Garbage");

	run("Configure ilastik executable location", "executablefile=["+IlastikLocation+"] numthreads=-1 maxrammb="+IlastikMaxMemoryMB);

	print("Initialization Done");
}



//===============================================================================================================
function Cleanup()
{
	run("Select None");
	run("Close All");
	run("Clear Results");
	roiManager("reset");
	run("Collect Garbage");

	CloseTable("DetailedResults");
}


//===============================================================================================================
function CloseTable(TableName)
{
	if (isOpen(TableName))
	{
		selectWindow(TableName);
		run("Close");
	}
}

//===============================================================================================================
//function SaveOverlayImage(imageName, MaskImage, MaskColor, baseSaveName, Suffix, resDir)
function SaveOverlayImage(imageID, MaskImage, MaskColor, baseSaveName, Suffix, resDir, showLabels)
{
	// Overlay Cells
	selectImage(imageID);
	roiManager("Deselect");
	if (showLabels) 
		roiManager("Show All with labels");
	else 
		roiManager("Show All without labels");

	// Optionally Overlay Mask Area
	run("Flatten");
	im = getImageID();
	if (lengthOf(MaskImage) > 0)
	{
		selectImage(MaskImage);
		run("Create Selection");
		selectImage(im);
		run("Restore Selection");
		run("Properties... ", "  stroke="+MaskColor);
		run("Properties... ", "  width="+LineWidth);
		run("Flatten");
	}
	saveAs("Tiff", resDir+baseSaveName+Suffix);
}


//===============================================================================================================
// Open File_Manual.zip ROI file  if it exist, otherwise open  File.zip
// returns 1 if Manual file exist , otherwise returns 0
function OpenExistingROIFile(baseRoiName)
{
	roiManager("Reset");
	manaulROI = baseRoiName+"_Manual.zip";
	manaulROI1 = baseRoiName+"_Manual.roi";
	origROI = baseRoiName+".zip";
	origROI1 = baseRoiName+".roi";
	
	if (File.exists(manaulROI))
	{
		print("opening:",manaulROI);
		roiManager("Open", manaulROI);
		manualROIFound = 1;
	} else if (File.exists(manaulROI1))
	{
		print("opening:",manaulROI1);
		roiManager("Open", manaulROI1);
		manualROIFound = 1;
	} else // Manual file not found, open original ROI file 
	{
		if (File.exists(origROI))
		{
			print("opening:",origROI);
			roiManager("Open", origROI);
			manualROIFound = 0;
		} else if (File.exists(origROI1))
		{
			print("opening:",origROI1);
			roiManager("Open", origROI1);
			manualROIFound = 0;
		} else {
			print(origROI," Not found");
			exit("You need to Run the macro in *Segment* mode before running again in *Update* mode");
		}
	}
	return manualROIFound;
}


//===============================================================================================================
function SavePrms(resFolder)
{
	// print parameters to Prm file for documentation
	PrmFile = resFolder+"QuantifyPaternalMitochondriaInEmbryo2DParameters.txt";
	File.saveString("macroVersion="+macroVersion, PrmFile);
	File.append("", PrmFile); 
	setTimeString();
	File.append("RunTime="+TimeString, PrmFile)
	File.append("runMode="+runMode, PrmFile); 
	File.append("processMode="+processMode, PrmFile); 
	File.append("fileExtension="+fileExtension, PrmFile); 
	File.append("MinIntensityToMeasure="+MinIntensityToMeasure, PrmFile); 
	File.append("EmbryoColor="+EmbryoColor, PrmFile); 
	File.append("LineWidth="+LineWidth, PrmFile); 
	File.append("IlastikLocation="+IlastikLocation, PrmFile); 
	File.append("IlastikMaxMemoryMB="+IlastikMaxMemoryMB, PrmFile); 
	File.append("IlastikAutoContextClassifier="+IlastikAutoContextClassifier, PrmFile); 
	File.append("IlastikAutoContextExtention="+IlastikAutoContextExtention, PrmFile); 
	File.append("EmbryosRoisSuffix="+EmbryosRoisSuffix, PrmFile); 
	File.append("erodeEmbryoPixels="+erodeEmbryoPixels, PrmFile); 
	File.append("applyRollingBallBGS="+applyRollingBallBGS, PrmFile); 
	File.append("rollingBallSigma="+rollingBallSigma, PrmFile); 
}


//===============================================================================================================
function setTimeString()
{
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString ="Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+", Time: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
}


