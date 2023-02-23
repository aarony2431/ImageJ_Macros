// Macro for RNAscope analysis of IF images
// Created by Aaron Yu
// July 12, 2022
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
function identifyMuscleSection(openImageName, isCropped, originalImageName, override) {
//	selectWindow(openImageName);
//	run("Duplicate...", "title=[Fiber Temp]");
//	selectWindow("Fiber Temp");
//	getStatistics(area, mean, min, max, std, histogram);
//	minArea = 0.05 * area;
//	
//	run("Enhance Contrast", "saturated=0.60 normalize equalize");
//	if (isCropped)
//		setAutoThreshold("Li dark");
//	else
//		setAutoThreshold("Otsu dark");
//	run("Convert to Mask");
//	run("Fill Holes");
//	run("Analyze Particles...", "size=minArea-Infinity add display clear");

	selectWindow(openImageName);
	run("Duplicate...", "title=[Fiber Identification]");
	selectWindow("Fiber Identification");
	if (!override) {
		getStatistics(area, mean, min, max, std, histogram);
		minArea = 0.05 * area;
		run("Enhance Contrast...", "saturated=10 normalize equalize");
		run("Gaussian Blur...", "sigma=2");
		run("Enhance Contrast...", "saturated=1 normalize");
		run("Subtract Background...", "rolling=20");
		if (!isCropped) {
			run("Gaussian Blur...", "sigma=10");
			run("Subtract Background...", "rolling=50");
		}
		getStatistics(area, mean, min, max, std, histogram);
		if (!isCropped) {
			ThresholdF = mean + std / 3.0;
		}
		else {
			ThresholdF = mean;
		}
		run("Find Maxima...", "noise=ThresholdF output=[Segmented Particles] light");
	} else {
		getStatistics(area, mean, min, max, std, histogram);
		run("Find Maxima...", "noise=mean output=[Segmented Particles] light");
	}
	
	selectWindow("Fiber Identification Segmented");
	run("Invert");
	run("Options...", "iterations=2 count=1 black do=Dilate");
	run("Options...", "iterations=3 count=1 black do=Close");
	run("Fill Holes");
//	run("Analyze Particles...", "size=minArea-Infinity add display clear");
	run("Analyze Particles...", "size=0-Infinity add display clear");
	
	multiselect = Array.getSequence(roiManager("count"));
	roiManager("select", multiselect);
	roiManager("Combine");
	roiManager("add");
	roiManager("deselect");
	for (i = 0; i < multiselect.length; i++) {
		roiManager("Select", 0);
		roiManager("Delete");
	}
	
	ROIfilename = ROIDir + originalImageName + "_whole_muscle_ROI.zip";
	roiManager("save", ROIfilename);
	roiManager("reset");
	roiManager("deselect");
	
	selectWindow("Fiber Identification Segmented");
	saveAs("tiff", processedDir + originalImageName + "_fiber_identification");
	close();
	selectWindow("Fiber Identification");
	close();
	
	return ROIfilename;
}

function getDotThreshold(ctrlImage) {
	selectWindow(ctrlImage);
	run("Duplicate...", "title=[Dot Temp]");
	selectWindow("Dot Temp");
	setAutoThreshold("Otsu dark");
	getThreshold(lower, upper);
	close();
	run("Clear Results");
	setResult("Ctrl Filename", 0, ctrlImage);
	setResult("Lower Threshold", 0, lower);
	setResult("Upper Threshold", 0, upper);
	updateResults();
	selectWindow("Results");
	saveAs("Text", outputDir + "CtrlImageThresholds.txt");
	run("Clear Results");
	return newArray(lower, upper);
}

// need to figure out the optimal parameters for analyze particles
function identifyDots(openImageName, isCropped, originalImageName, wholeMuscleROI, lowerThreshold, upperThreshold) {
	selectWindow(openImageName);
	run("Duplicate...", "title=[Dot Temp]");
	selectWindow("Dot Temp");
	setThreshold(lowerThreshold, upperThreshold);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Watershed");
	saveAs("tiff", processedDir + originalImageName + "_dotsThreshold");
	
	roiManager("open", wholeMuscleROI);
	roiManager("select", 0);
	
	minArea = 0.25 * dpm; // approximate diameter of 0.6 um
	maxArea = 20.0 * dpm; // approximate diameter of 5 um
	run("Analyze Particles...", "size=minArea-maxArea circularity=0-1.00 display add");
	
	if (roiManager("count") > 1) {
		roiManager("select", 0);
		roiManager("delete");
	
		ROIfilename = ROIDir + originalImageName + "_dots_ROI.zip";
		roiManager("save", ROIfilename);
		roiManager("reset");
		roiManager("deselect");
		
		return ROIfilename;
	} else {
		return "";
	}
}

function getDotStatistics(dotsImageName, wholeMuscleROI, dotsROI, originalImageName) {
	selectWindow(dotsImageName);
	saveAs("tiff", processedDir + originalImageName + "_dots");
	run("Clear Results");
	roiManager("open", wholeMuscleROI);
	roiManager("select", 0);
	roiManager("measure");
	sectionArea = getResult("Area", 0);
	roiManager("reset");
	
	run("Clear Results");
	if (dotsROI == "") {
		dotArea = 0;
		dots_in_section = 0;
		dots_area_ratio = 0;
	} else {
		roiManager("open", dotsROI);
		dotArea = 0;
		dots_in_section = roiManager("count");
		for (i = 0; i < dots_in_section; i++) {
			roiManager("select", i);
			roiManager("measure");
			dotArea = dotArea + getResult("Area", i);
		}
		dots_area_ratio = dotArea / sectionArea;
	}
	
	selectWindow("Results");
	run("Close");
	roiManager("reset");
	roiManager("deselect");
	
	return newArray(sectionArea, dots_in_section, dots_area_ratio);
}

colors = newArray("", "Red", "Green", "Blue", "Gray");
function getChannelNumberFromColor(colorString) {
	if (colorString == colors[1]) {
		return 0;
	} else if (colorString == colors[2]) {
		return 1;
	} else if (colorString == colors[3]) {
		return 2;
	} else if (colorString == colors[4]) {
		return 3;
	} else {
		return -1;
	}
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				/////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

run("Close All");
run("ROI Manager...");
roiManager("reset");
setOption("ExpandableArrays", true);

// Create Dialog UI
Dialog.create("RNAscope Analysis - Avidity");
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("       Image Information\n       ==============================\n");

Dots_per_micron_10X = 1.5383975603;
Dialog.addChoice("Image Magnification", newArray("10", "20", "40"), "20");

Dialog.addChoice("Full Muscle Section?", newArray("Entire", "Cropped"), "Entire");

Dialog.addCheckbox("Override image preprocessing and just threshold?", false);

items = newArray("RGB TIFF","Stacked TIFF by channel");
Dialog.addRadioButtonGroup("Data Format", items, 1, 2, "RGB TIFF");

Dialog.show();

// Get Dialog values
Dots_per_micron_10X = 1.5383975603;
dpm = Dots_per_micron_10X * parseInt(Dialog.getChoice()) / 10;

isCropped = (Dialog.getChoice() == "Cropped");
imageprocessingoverride = Dialog.getCheckbox();
isRGBTIFF = (Dialog.getRadioButton() == "RGB TIFF");

//Second Dialog for image channels
Dialog.create("Channel Information");
if (isRGBTIFF) {
	Dialog.addChoice("Fiber Channel Color", colors, colors[2]);
	Dialog.addChoice("RNAscope Dot Channel Color", colors, colors[1]);
} else {
	Dialog.addMessage("\nProvide the order of the channels (usually TIFFs are stacked as RGB):\n");
	Dialog.addNumber("Fiber Channel", 2, 0, 1, "1 index");
	Dialog.addNumber("RNAscope Dot Channel", 1, 0, 1, "1 index");
}
Dialog.show();

dotChannel = 0;
fiberChannel = 0;
if (isRGBTIFF) {
	fiberChannel = getChannelNumberFromColor(Dialog.getChoice());
	dotChannel = getChannelNumberFromColor(Dialog.getChoice());
} else {
	fiberChannel = Dialog.getNumber();
	dotChannel = Dialog.getNumber();
}

// Select input files dialog
inputDirDialog = "Select folder with RNAscope stacked TIFF images...";
if (isRGBTIFF) { inputDirDialog = "Select folder with RNAscope RGB TIFF images..."; }
inputDir = getDir(inputDirDialog);
inputFiles = getFileList(inputDir);

// Select control image for dot thresholding
ctrlImage = File.openDialog("Choose control image for dot thresholding...");

// Select output directory dialog
outputDir = getDir("Select Folder to Save Results...");
processedDir = outputDir + "ProcessedImages" + File.separator;
if (!File.exists(processedDir)) { File.makeDirectory(processedDir); }
ROIDir = outputDir + "ROIs" + File.separator;
if (!File.exists(ROIDir)) { File.makeDirectory(ROIDir); }

// Image Processing
startTime = getTime();
// Get control thresholds
run("Bio-Formats Importer", "open=ctrlImage autoscale color_mode=Default split_channels view=Hyperstack stack_order=XYCZT");
run("Set Scale...", "distance="+dpm+" known=1 unit=um global");
dotTitle = "";
imageName = File.getNameWithoutExtension(ctrlImage);
if (isRGBTIFF) {
	CurrentWindows=getTitle();
	Title = split(CurrentWindows,"=");
	dotTitle = Title[0] + "=" + dotChannel;
} else {
	run("Stack to Images");
	add_on = "-000";
	dotTitle = imageName + add_on + dotChannel;
}
thresholds = getDotThreshold(dotTitle);
run("Close All");
// Process files
outputTable = newArray(1);
outputTableLabels = newArray("Filename", "Section Area (um^2)", "Num Dots", "Dots per um^2", "Dot Area Fraction");
currentLine = 0;
for (filenumber = 0; filenumber < inputFiles.length; filenumber++) {
	tic = getTime();
	filename = inputFiles[filenumber];
	file = inputDir + filename;
	if (endsWith(filename, ".tif")) {
		print("Processing: " + filename);
		imageName = File.getNameWithoutExtension(file);
		run("Bio-Formats Importer", "open=file autoscale color_mode=Default split_channels view=Hyperstack stack_order=XYCZT");
		run("Set Scale...", "distance="+dpm+" known=1 unit=um global");
		fiberTitle = "";
		dotTitle = "";
		if (isRGBTIFF) {
			CurrentWindows=getTitle();
			Title = split(CurrentWindows,"=");
			dotTitle = Title[0] + "=" + dotChannel;
			fiberTitle = Title[0] + "=" + fiberChannel;
		} else {
			run("Stack to Images");
			add_on = "-000";
			dotTitle = imageName + add_on + dotChannel;
			fiberTitle = imageName + add_on + fiberChannel;
		}
		
		wholeMuscleROI = identifyMuscleSection(fiberTitle, isCropped, imageName, imageprocessingoverride);
		dotsROI = identifyDots(dotTitle, isCropped, imageName, wholeMuscleROI, thresholds[0], thresholds[1]);
		
		dotStats = getDotStatistics(dotTitle, wholeMuscleROI, dotsROI, imageName);
		sectionArea = dotStats[0];
		dots_in_section = dotStats[1];
		dots_per_um2 = 1.0 * dots_in_section / sectionArea;
		dots_area_ratio = dotStats[2];
		
		outputTable[currentLine] = filename + "\t" + sectionArea + "\t" + dots_in_section + "\t" + dots_per_um2 + "\t" + dots_area_ratio;
		
		run("Close All");
		currentLine++;
	}
	toc = getTime();
	print("Time Elapsed (s): " + (toc - tic) / 1000);
}

run("Clear Results");
for (i = 0; i < outputTable.length; i++) {
	values = split(outputTable[i], "\t");
	for (j = 0; j < values.length; j++) {
		setResult(outputTableLabels[j], i, values[j]);
	}
}
updateResults();
selectWindow("Results");
saveAs("Text", outputDir + "GlobalResults.txt");
toc = getTime();
run("Close All");
close("ROI Manager");
print("Done! Total Time Elapsed (s): " + ((toc - startTime) / 1000));