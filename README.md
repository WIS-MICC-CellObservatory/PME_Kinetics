# Evaluating paternal mitochondrial elimination kinetics in Drosophila embryos


## Overview

Measure paternal mitochondria (PM) fluorescence intensity in early Drosophila embryos, following 3 hours after egg laying. 
Two channel 2D images were acquired for each embryo: A bright field (BF) channel and a fluorescent channel of the 
(MTS)tdTomato (red-PM). Embryos that failed to complete cellularization were omitted from the analysis. 
Each image includes one or two embryos.


This macro was used in:  <br/> <br/>

<p align="center"> <strong> Egg MVBs elicit an LC3-associated phagocytosis-like pathway to degrade paternal mitochondria after fertilization </strong><br/> <br/> </p>
	
<p align="center"> <strong>Sharon Ben-Hur, Shoshana Sernik, Sara Afar, Alina Kolpakova, Yoav Politi, Liron Gal, Anat Florentin, Ofra Golani, Ehud Sivan, Nili Dezorella, David Morgenstern, Shmuel Pietrokovski, Eyal Schejter, Keren Yacobi-Sharon, Eli Arama </strong><br/> <br/>
	</p>

<p align="center">
![PME Kinetics](PNG/https://github.com/WIS-MICC-CellObservatory/PME_Kinetics/blob/master/PNG/PME-Kinetics.png)
</p>

Software package: Fiji (ImageJ)
Workflow language: ImageJ macro
     
## Workflow

Go over the folder of embryo images, for each file
- Segment Embryo from brightfield channel using Ilastik autocontext workflow
	 + Run Ilastik Autocontext pixel classifier - it is assumed that the embryo class is 2 and the background is 1
 	 + erode labels by  erodeEmbryoPixels (defualt 3)  to avoid artifacts on the edges of the embryo 
	 + remove segments smaller than  MinSizePixels (default 5000) 
 	 + Add the embryos regions to the Rois Manager

- Quantify flourescent signal
	 + optionally (default, depends on applyRollingBallBGS) apply Rolling ball background subtraction with sigma = rollingBallSigma
	 + segment Mito-positive regions by applying fixed threshold (MinIntensityToMeasure) to the florescent signal
	 + for each embryo quantify total/mean signal in whole embryo / Mito-Positive region / Mito negative region, calculate MeanMitoPositive-MeanMitoNegative
	 
- Save results 
	 + Create Quality control images
	 + save Rois - to enable manual correction of embryo regions with Update mode
	 + save results in a table with one line for each embryo in each image


You can use previous ilastik clasification by checking "CheckForExistingIlastikOutputFile". 
This is useful if you want to try different macro parameters without running ilastik again (as it takes most of the runtime)
  
If the embryo segmentation is not good enouh for some of the embryos, 
you can use manually correct the embryo segmentation (see below) and and run the macro in *update* mode. 
This will use the manually corrected segmentation if this is available and the original automatic segmentation for all other embryos

## Output

- Save results:
 	+ Detailed results tables (for cells and for edges) + overlay for each image
	+ Summary table with one line for each embryo in each image, and average values 
- Save the active macro parameters in a text file in the Results folder

For each input image FN, the following output files are saved in ResultsSubFolder under the input folder
- FN_Ch1Overlay.tif 	- the original brightfield channel with overlay of the segmented Embryos in magenta (EmbryoColor)
- FN_Ch2_AboveTh.tif - the flourescnce channel after background subtraction and where all pixels below MinIntensityToMeasureare set to 0  
- FN_Ch2Overlay.tif 	- the original flourescnce channel with overlay of the segmented Embryos in magenta (EmbryoColor), and PME signal above threshold in yellow (IntensityColor)  
- FN_DetailedResults.xls - the detailed measurements with one line for each embros in the image  
- FN_EmbryosRoiSet.zip   - the embryo segments used for measurements - this file can be used for manually update 
- FN__Segmentation Stage 2.h5  - the Crystal Domain segments used for measurements

Overlay colors can be controled by EmbryoColor and IntensityColor

AllDetailedResults_test.xls - Table with one line for each embryo in each image file - for each image folder
QuantifyPaternalMitochondriaInEmbryo2DParameters.txt - Parameters used during the latest run

## Installation and Dependencies

 1. Install Fiji:  https://imagej.net/software/fiji/
    We used the Windows-64 version, but it should work withe other Fiji versions
     
 2. Install Fiji Ilastik plugin: 

 To install it, open Fiji and within Fiji :
 - Help=>Update
 - Click “Manage Update sites”
 - Check “ilastik”
 - Click “Close”
 - Click “Apply changes”

## Usage Instructions

<p align="center">
<img src="https://github.com/WIS-MICC-CellObservatory/PME_Kinetics/blob/master/PNG/GUI.png" width="500" title="GUI">
</p>

- Set *runMode* to be *Segment* 
  
- There are two modes of operation controlled by *processMode* parameter:
  + *singleFile*    - prompt the user to select a single TJ file to process.
  + *wholeFolder*   - prompt the user to select a folder of images, and process all images
  + *AllSubfolders* - prompt the user to select a folder with subfoldrs of images, and process all images
  
- select Iastik location and Ilastik classifier
- set parameters - see description above
- click *OK*
- use the quality-control files to careful inspect of results of all files, especially pay attention to PME signal segmentation and embryo segmentation. 
- Manually correct embryos Rois if needed (see below) and Save the corrected Rois into FN_RoiSet_Manual.zip
- if any manual correction was done, run the macro again, set *runMode* to be *Update* , 
  This will use the manually corrected segmentation if this is available and the original automatic segmentation for all other embryos
  and will recalculate PME signal using the given segmentation
 
##  Manual Correction
The above automatic process segment correctly most of the embryos. 
Further manual correction is supported by switching from *Segment* Mode to *Update* Mode.   

### To start manual correction: 
- Open the original image (FN)
- make sure there is no RoiManager open
- drag-and-drop the "FN_EmbryosRoiSet.zip" into Fiji main window 
- in RoiManager: make sure that "Show All" is selected. Ususaly it is more conveinient to unselect Labels 
  
### Select A ROI
- You can select a ROI from the ROIManager or with long click inside a embryo to select its outer ROI (with the Hand-Tool selected in Fiji main window), 
  this will highlight the (outer) ROI in the RoiManager, the matching inner Roi is just above it
   
### Delete falsely detected objects
- select a ROI
- click "Delete" to delete a ROI. 
  
### Fix segmentation error 
- select a ROI
- you can update it eg by using the brush tool (deselecting Show All may be more convnient) 
- Hold the *Shift* key down and it will be added to the existing selection. Hold down the *Alt* key and it will be subracted from the existing selection
- click "Update"
  
- otherwise you can delete the ROI (see above) and draw another one instead (see below)
  
### Add non-detected embryo
- You can draw a ROI using one of the drawing tools 
- an alternative can be using the Wand tool , you'll need to set the Wand tool tolerance first by double clicking on the wand tool icon. 
  see also: https://imagej.nih.gov/ij/docs/tools.html
- click 't' from the keyboard or "Add" from RoiManger to add it to the RoiManager 
  
### Save ROIs
When done with all corrections make sure to 
- from the RoiManager, click "Deselect" 
- from the RoiManager, click "More" and then "Save" , save the updated file into a file named as the original Roi file with suffix "_Manual":  
  "FN_EmbryosRoiSet_Manual.zip", using correct file name is crucial

## Sample data
Sample files are provided for testing the macro, togetehr with the related Results files (within Results subfolder of each sample data folder) and the ilastik classifier used for the analysis (AutoContext_ForEmbryo4.zip  unzip the file and use AutoContext_ForEmbryo4.ilp).
 
