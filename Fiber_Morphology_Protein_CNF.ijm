//colocalization of nuclei and other stain
//colocalization of fiber and other stain
function ArtefactDetection(FiberImageName, isCropped, percentFiberLimit, ROISectionFile) {
	print("\t\tChecking for artefacts...");
	selectWindow(FiberImageName);
	run("Duplicate...", "title=[Fiber Temp]");
	selectWindow("Fiber Temp");
	getStatistics(area, mean, min, max, std, histogram);
	minArea = 0.05*area;
	run("Enhance Contrast", "saturated=0.60 normalize equalize");
	if (isCropped)
		setAutoThreshold("Li dark");
	else
		setAutoThreshold("Otsu dark");
	run("Convert to Mask");
	run("Fill Holes");
	run("Analyze Particles...", "size=minArea-Infinity add display clear");
	
	totalArea = 0;
	if (nResults > 0) {
		//Merge all ROIs and use the sum as the total muscle
		multiselect = Array.getSequence(roiManager("count"));
		roiManager("select", multiselect);
		roiManager("Combine");
		roiManager("add");
		roiManager("deselect");
		for (i = 0; i < multiselect.length; i++) {
			totalArea = totalArea + getResult("Area", i);
			roiManager("Select", 0);
			roiManager("Delete");
		}
		roiManager("Set Color", "red");
		roiManager("Set Line Width", 0);
		run("Clear Results");
		
		//Fiber Quality Check
		print("\t\tChecking fiber quality...");
		selectWindow(FiberImageName);
		run("Duplicate...", "title=[Fiber Quality Check]");
		selectWindow("Fiber Quality Check");
		run("Enhance Contrast...", "saturated=10 normalize equalize");
		run("Gaussian Blur...", "sigma=2");
		run("Enhance Contrast...", "saturated=1 normalize");
		run("Subtract Background...", "rolling=20");
		if (!isCropped) {
			run("Gaussian Blur...", "sigma=10");
			run("Subtract Background...", "rolling=50");
		}
		getStatistics(area, mean, min, max, std, histogram);
		thresholdFiber = mean + std / 3.0;
		if (isCropped) { thresholdFiber = mean; }
		run("Find Maxima...", "noise=thresholdFiber output=[Segmented Particles] light");
			
		selectWindow("Fiber Quality Check Segmented");
		run("Invert");
		run("Options...", "iterations=2 count=1 black do=Dilate");
		run("Options...", "iterations=3 count=1 black do=Close");
		run("Invert");
		
		roiManager("select", 0);
		run("Analyze Particles...", "size=0-infinity circularity=0.45-1.00 display add");
		totalFiberArea = 0;
		numFibers = roiManager("count") - 1;
		for (i = 0; i < numFibers; i++) {
			totalFiberArea = totalFiberArea + getResult("Area", i);
			roiManager("Select", 1);
			roiManager("Delete");
		}
		
		selectWindow("Results");
		run("Close");
		selectWindow("Fiber Quality Check Segmented");
		close();
		selectWindow("Fiber Quality Check");
		close();
		
		output = newArray(0, totalArea);
		if (100 * totalFiberArea / totalArea < percentFiberLimit) {
			output[0] = 1;
		}
		
		roiManager("save", ROISectionFile);
		roiManager("reset");
		roiManager("deselect");
	}
	
	selectWindow("Fiber Temp");
	saveAs("tiff", dirProcessed + ImageName + "_artefact_detection");
	close();
	
	return output;
}

var fiber_bin_class_separator = 250;
var fiber_bin_class_min_area = 250;
var fiber_bin_class_max_area = 7000;
var num_fiber_bins = Math.max(1, Math.floor((fiber_bin_class_max_area - fiber_bin_class_min_area) / fiber_bin_class_separator) + 2);
//Returns a whole number between 0 and num_fiber_bins representing which bin the fiber area resides in
function getAreaClass(area) {
	calc_area = Math.max(fiber_bin_class_min_area, area);
	bin = Math.floor(calc_area / fiber_bin_class_separator);
	bin = Math.min(bin, num_fiber_bins - 1);
	return bin;
}

function FiberDetection(FiberImageName, isCropped, ROISectionFile, ROIFiberFile, ROICentroFiberFile, ROIPeriFile) {
	print("\t\tIdentifying fibers...");
	selectWindow(FiberImageName);
	run("Duplicate...", "title=[Fiber Temp]");
	selectWindow("Fiber Temp");
	run("Enhance Contrast...", "saturated=10 normalize equalize");
	run("Gaussian Blur...", "sigma=2");
	run("Enhance Contrast...", "saturated=1 normalize");
	run("Subtract Background...", "rolling=20");
	if (!isCropped) {
	run("Gaussian Blur...", "sigma=10");
		run("Subtract Background...", "rolling=50");
	}
	getStatistics(area, mean, min, max, std, histogram);
	thresholdFiber = mean + std / 3.0;
	if (isCropped) { thresholdFiber = mean; }
	run("Find Maxima...", "noise=thresholdFiber output=[Segmented Particles] light");
		
	selectWindow("Fiber Temp Segmented");
	run("Invert");
	run("Options...", "iterations=2 count=1 black do=Dilate");
	run("Options...", "iterations=3 count=1 black do=Close");
	run("Invert");
	
	roiManager("open", ROISectionFile);
	roiManager("Select", 0);
	run("Analyze Particles...", "size=0-infinity circularity=0.00-1.00 display add");
	selectWindow("Results");
	
	//Getting fiber statistics to eliminate outliers
	print("\t\tElimintaing fiber outliers...");
	meanArea = 0;
	variance = 0;
	numFibers = roiManager("count") - 1;
	for (i = 0; i < numFibers; i++) {
		meanArea = meanArea + getResult("Area", i);
	}
	meanArea = meanArea / numFibers;
	for (i = 0; i < numFibers; i++) {
		variance = variance + Math.sqr(getResult("Area", i) - meanArea);
		roiManager("select", 1);
		roiManager("delete");
	}
	selectWindow("Results");
	run("Close");
	
	variance = variance / numFibers;
	stddev = Math.sqrt(variance);
	
	minArea = 150; //min area set to 150 um2
	maxArea = meanArea + 4.0 * stddev;
	if (isCropped) {
		maxArea = meanArea + 3.0 * stddev;
	}
	
	//Get fibers after eliminating outliers
	print("\t\tRe-identifying fibers...");
	selectWindow("Fiber Temp Segmented");
	roiManager("Select", 0);
	run("Analyze Particles...", "size=minArea-maxArea circularity=0.45-1.00 display add");
	roiManager("Select", 0);
	roiManager("delete");
	totalFiberArea = 0;
	totalFiberFeret = 0;
	numFibers = nResults;
	for (i = 0; i < numFibers; i++) {
		area = getResult("Area", i);
		feret = getResult("Feret", i);
		areaClass = getAreaClass(area);
		
		Fibers_area[i] = area;
		Fibers_areaClass[areaClass] = Fibers_areaClass[areaClass] + 1;
		Fibers_feret[i] = feret;
		Fibers_minFeret[i] = getResult("MinFeret", i);
		
		totalFiberArea = totalFiberArea + area;
		totalFiberFeret = totalFiberFeret + feret;
	}
	roiManager("Show All without labels");
	roiManager("Set Color", "green");
	roiManager("Set Line Width", 0);
	roiManager("save", ROIFiberFile);
	
	selectWindow("Results");
	run("Close");
	selectWindow("Fiber Temp Segmented");
	
	//Get ROIs for centralnucleation and perinuclei analyses
	if (numFibers > 0) {
		selectWindow("ROI Manager");
		//For centralnucleation
		print("\t\tConstructing centronuclei ROIs...");
		for (i = 0; i < numFibers; i++) {
			roiManager("select", 0);
		    //1/5 of Feret Diameter Length
		    feretDiameterChange = Fibers_minFeret[i] / 5;
		    run("Enlarge...", "enlarge=-" + feretDiameterChange);
		    roiManager("Add");
		    
		    //remove initial ROI
		    roiManager("Select", 0);
			roiManager("Delete");
		}
		roiManager("Set Color", "blue");
		roiManager("Set Line Width", 0);
		roiManager("Save", ROICentroFiberFile);
		
		//For perinuclei
		print("\t\tConstructing perinuclei ROIs...");
		roiManager("Open", ROIFiberFile);
		for (i = 0 ; i < numFibers; i++) {
			multiselect = newArray(numFibers, 0);
			roiManager("Select", multiselect);
			roiManager("XOR");
			roiManager("Add");
			
			//remove separated ROIs
			roiManager("Select", multiselect);
			roiManager("Delete");
		}
		roiManager("Set Color", "#ffc800");
		roiManager("Set Line Width", 0);
		roiManager("Save", ROIPeriFile);
		roiManager("reset");
	}
	selectWindow("Fiber Temp Segmented");
	saveAs("tiff", dirProcessed + ImageName + "_fiber_segmentation");
	run("Close");
	selectWindow("Fiber Temp");
	run("Close");
	
	output = newArray(numFibers, totalFiberArea, totalFiberFeret);
	return output;
}

function ProcessNucleiImage(NucleiImageName) {
	selectWindow(NucleiImageName);
	run("Duplicate...", "title=[Nuclei Temp]");
	run("Enhance Contrast...", "saturated=0.1 normalize");
	run("Subtract Background...", "rolling=50");
	setAutoThreshold("Otsu dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Options...", "iterations=1 count=2 black do=Erode");
	run("Watershed");
	run("Ultimate Points");
	setThreshold(1, 255);
	run("Convert to Mask");
	run("Options...", "iterations=2 count=1 black do=Dilate");
	run("Make Binary");
	saveAs("tiff", dirProcessed + ImageName + "_DAPI_nuclei");
	
	return getTitle();
}

function CountNuclei(NucleiImageName, FILE_ROICentroFiber, FILE_ROIPeri) {
	//Central nuclei
	print("\t\tCounting central nuclei...");
	roiManager("Open", FILE_ROICentroFiber);
	CNF1 = 0;
	CNF1_area = 0;
	CNF2 = 0;
	CNF2_area = 0;
	CNF3 = 0;
	CNF3_area = 0;
	roiManager("Show None");
	for (i = 0; i < roiManager("count"); i++) {
		selectWindow(NucleiImageName);
	    roiManager("select", i);
	    run("Clear Results");
	    roiManager("measure");
	    area = getResult("Area", 0);
	    run("Clear Results");
	    run("Analyze Particles...", "size=1-100 pixel circularity=0.45-1.00 display clear");
	    
	    Nuclei_central[i] = nResults;
     	if (Nuclei_central[i] == 1) {
    		CNF1++;
    		CNF1_area = CNF1_area + area;
    	} else if (Nuclei_central[i] == 2) {
    		CNF2++;
    		CNF2_area = CNF2_area + area;
    	} else if (Nuclei_central[i] >= 3) {
    		CNF3++;
    		CNF3_area = CNF3_area + area;
    	}
	}
	roiManager("reset");
	
	//Peri nuclei
	print("\t\tCounting perinuclei...");
	roiManager("Open", FILE_ROIPeri);
	roiManager("Show None");
	for (i = 0; i < roiManager("count"); i++) {
		selectWindow(NucleiImageName);
	    roiManager("select", i);
	    run("Analyze Particles...", "size=1-100 pixel circularity=0.45-1.00 display clear");
	    
	    Nuclei_peri[i] = nResults;
	}
	roiManager("reset");
	
	output = newArray(CNF1, CNF1_area, CNF2, CNF2_area, CNF3, CNF3_area);
	return output;
}

function MeasureOtherStain(OtherStainImageName, FILE_ROIFiber) {
	print("\t\tMeasuring other stain...");
	selectWindow(OtherStainImageName);
	roiManager("Open", FILE_ROIFiber);
	run("Clear Results");
	OtherStain_meanSum = 0;
	for (i = 0; i < roiManager("count"); i++) {
		roiManager("select", i);
		roiManager("measure");
		OtherStain_fibers[i] = getResult("Mean", i);
		OtherStain_meanSum = OtherStain_meanSum + OtherStain_fibers[i];
	}
	roiManager("deselect");
	roiManager("reset");
	
	getStatistics(area, mean, min, max, std, histogram);
	output = newArray(1.0 * mean / area, OtherStain_meanSum);
	return output;
}

function MeasureOtherStainMembrane(OtherStainImageName, FILE_ROIMembraneStain) {
	print("\t\tMeasuring other stain on membrane...");
	selectWindow(OtherStainImageName);
	roiManager("Open", FILE_ROIFiber);
	run("Clear Results");
	numFibers = roiManager("count");
	meanSum = 0;
	for (i = 0; i < numFibers; i++) {
		shrink_feret_adjustment = Fibers_minFeret[i] / 12;
		enlarge_feret_adjustment = Fibers_minFeret[i] / 8;
		//Inner ROI
		roiManager("select", 0);
		run("Enlarge...", "enlarge=-" + shrink_feret_adjustment);
		roiManager("Add");
		//Outer ROI
		roiManager("select", 0);
		run("Enlarge...", "enlarge=" + enlarge_feret_adjustment);
		roiManager("Add");
		//Combine Inner and Outer ROI
		multiselect = newArray(numFibers, numFibers + 1);
		roiManager("Select", multiselect);
		roiManager("XOR");
		roiManager("Add");
		//Remove separate Inner and Outer ROIs
		multiselect = newArray(numFibers, numFibers + 1);
		roiManager("Select", multiselect);
		roiManager("delete");
		//Measure the combined Inner and Outer ROI
		roiManager("select", numFibers);
		roiManager("measure");
		OtherStain_membrane[i] = getResult("Mean", i);
		meanSum = meanSum + OtherStain_membrane[i];
		//Remove base ROI
		roiManager("select", 0);
		roiManager("delete");
	}
	roiManager("Set Color", "#d8d7bf");
	roiManager("Set Line Width", 0);
	roiManager("Save", FILE_ROIMembraneStain);
	roiManager("reset");
	
	return meanSum;
}

function cartography_CNF(FiberImageName, includeLegend, ROIFiberFile) {
	selectWindow(FiberImageName);
	run("Duplicate...", "title=Cartography");
	selectWindow("Cartography");
	run("Enhance Contrast...", "saturated=0.3");
	run("RGB Color");
	roiManager("Open", ROIFiberFile);
	roiManager("deselect");
	
	for (i = 0 ; i < roiManager("count"); i++) {
		roiManager("select", i);
		if (Nuclei_central[i] == 1) {
			setForegroundColor(255, 255, 0);
		}
		if (Nuclei_central[i] == 2) {
			setForegroundColor(255, 128, 0);
		}
		if (Nuclei_central[i] > 2) {
			setForegroundColor(255, 0, 0);
		}
		if (Nuclei_central[i] == 0) {
			setForegroundColor(255, 255, 255);
		}
		roiManager("Fill");
	}
	if (includeLegend) {
		roiManager("reset");
		selectWindow("Cartography");
		getDimensions(width, height, channels, slices, frames);
		
		BottomY = height - 100;
		BottomYMidle = height - 25;
		
		makeRectangle(0, BottomY, 100, 100);
		roiManager("Add");
		roiManager("select", 0);
		setForegroundColor(255, 255, 255);
		roiManager("Fill");
	  	setColor("black");
		setFont("Sanserif", 50);
		drawString("0", 50, BottomYMidle);
	  
		makeRectangle(100, BottomY, 100, 100);
		roiManager("Add");
		roiManager("select", 1);
		setForegroundColor(255, 255, 0);
		roiManager("Fill");
		setColor("black");
		setFont("Sanserif", 50);
		drawString("1", 125, BottomYMidle);
		
		makeRectangle(200, BottomY, 100, 100);
		roiManager("Add");
		roiManager("select", 2);
		setForegroundColor(255, 128, 0);
		roiManager("Fill");
		setColor("black");
		setFont("Sanserif", 50);
		drawString("2", 225, BottomYMidle);
	
	
		makeRectangle(300, BottomY, 100, 100);
		roiManager("Add");
		roiManager("select", 3);
		setForegroundColor(255, 0, 0);
		roiManager("Fill");
		setColor("black");
		setFont("Sanserif", 50);
		drawString("3+", 325, BottomYMidle);
	}
	
	saveAs("Jpeg", dirCartography + ImageName + "_cartography_CNF.jpg");
	close();
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

/////////////////////////////////////////// Main Program ///////////////////////////////////////////

setOption("ExpandableArrays", true);
run("Close All");
run("ROI Manager...");
roiManager("reset");

////////////////////// Dialog 1 //////////////////////
Dialog.create("MUSCLEJ + Cellular Stain Detection");

Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Data Acquisition\n=============");

items = newArray("Entire","Cropped");
Dialog.addRadioButtonGroup("Full Muscle Section?", items, 1, 2, "Cropped");

items = newArray("RGB TIFF","Stacked TIFF by channel");
Dialog.addRadioButtonGroup("Data Format", items, 1, 2, "Stacked TIFF by channel");

Dialog.addCheckbox("Check this if the number of pixels per micron is known", false);

Dialog.setInsets(0, 0, 0);
Dialog.addMessage(" \nData Analysis\n=============");

Dialog.addSlider("Artefact Detection (%area min)", 10, 100, 10);

Dialog.setInsets(0, 0, 0);
Dialog.addMessage(" \nData Cartography\n==============");

cartography_items = newArray("None", "Centro Nuclei Classes");
Dialog.addChoice("Cartography Choice:", cartography_items,"Centro Nuclei Classes");

items = newArray("Yes","No");
Dialog.addChoice("Legend", items,"No");

Dialog.show();

isCropped = (Dialog.getRadioButton() == "Cropped");
isRGBTIFF = (Dialog.getRadioButton() == "RGB TIFF");
ScaleIsKnown = Dialog.getCheckbox();
ArtefactDetectionLimit = Dialog.getNumber();
CartographyType = Dialog.getChoice();
includeLegend = (Dialog.getChoice() == "Yes");


////////////////////// Dialog 2 //////////////////////
Dialog.create("Image Information");

Dots_per_micron_10X = 1.5383975603;
Dots_per_micron = 1;
if (!ScaleIsKnown) {
	items = newArray("10", "20", "40");
	Dialog.addChoice("Magnification (X)", items, "20");
} else {
	Dialog.addNumber("Pixels per micron (um)", Dots_per_micron_10X);
}

ChannelNuclei = 0;
ChannelFiber = 0;
ChannelOtherStain = 0;
if (isRGBTIFF) {
	items = newArray("", "Red", "Green", "Blue");
	Dialog.addChoice("REQUIRED: Nuclear Channel", items, "Blue");
	Dialog.addChoice("REQUIRED: Fiber Channel", items, "Green");
	Dialog.addChoice("OPTIONAL: Other Stain Channel", items, "Red");
} else {
	Dialog.addMessage("\nProvide the order of the channels (usually TIFFs are stacked as RGB):\n");
	Dialog.addNumber("REQUIRED: Nuclear Channel", 3, 0, 1, "1 index");
	Dialog.addNumber("REQUIRED: Fiber Channel", 2, 0, 1, "1 index");
	Dialog.addNumber("OPTIONAL: Other Stain Channel", 1, 0, 1, "1 index");
}

Dialog.show();

if (!ScaleIsKnown) {
	MagnificationScale = parseInt(Dialog.getChoice());
	Dots_per_micron = Dots_per_micron_10X * MagnificationScale / 10;
} else {
	Dots_per_micron = Dialog.getNumber();
}

if (isRGBTIFF) {
	ChannelNuclei = getChannelNumberFromColor(Dialog.getChoice());
	ChannelFiber = getChannelNumberFromColor(Dialog.getChoice());
	ChannelOtherStain = getChannelNumberFromColor(Dialog.getChoice());
} else {
	ChannelNuclei = Dialog.getNumber();
	ChannelFiber = Dialog.getNumber();
	ChannelOtherStain = Dialog.getNumber();
}

inputDirDialog = "Select folder containing stacked TIFF images...";
if (isRGBTIFF) { inputDirDialog = "Select folder containing RGB TIFF images..."; }
outputDirDialog = "Select output folder for stacked TIFF images...";
if (isRGBTIFF) { inputDirDialog = "Select output folder for RGB TIFF images..."; }

inputDir = getDir(inputDirDialog);
outputDir = getDir(outputDirDialog);

dirArtefact = outputDir + "Artefacts" + File.separator;
dirROI = outputDir + "ROI" + File.separator;
dirCartography = outputDir + "Cartography" + File.separator;
dirResults = outputDir + "Results_by_image" + File.separator;
dirProcessed = outputDir + "Processed_images" + File.separator;

if (!File.exists(dirArtefact)) { File.makeDirectory(dirArtefact); }
if (!File.exists(dirROI)) { File.makeDirectory(dirROI); }
if (!File.exists(dirCartography)) { File.makeDirectory(dirCartography); }
if (!File.exists(dirResults)) { File.makeDirectory(dirResults); }
if (!File.exists(dirProcessed)) { File.makeDirectory(dirProcessed); }

FILE_globalResults = outputDir + "GlobalResults.txt";
ResultsTable = newArray("", "");
ResultsCurrentLine = 1;
for (i = 0; i < num_fiber_bins; i++) {
	if (i == 0){
		ResultsTable[0] = ResultsTable[0] + "\t<" + fiber_bin_class_min_area + "µm2";
	} else if (i == num_fiber_bins - 1) {
		ResultsTable[0] = ResultsTable[0] + "\t>" + fiber_bin_class_max_area + "µm2";
	} else {
		low = Math.round(fiber_bin_class_min_area + (i - 1) * fiber_bin_class_separator);
		high = Math.round(fiber_bin_class_min_area + i * fiber_bin_class_separator);
		ResultsTable[0] = ResultsTable[0] + "\t" + low + "-" + high + "µm2";
	}
}
ResultsTable[0] = "Filename\tNum Segmented Fiber\tFiber Area Mean\tFiber Feret Mean" + ResultsTable[0] + 
					"\tNum CNF\tCNF Area Mean\t1CN\t1CN Area Mean\t2CN\t2CN Area Mean\t3+CN\t3+CN Area Mean\t%CNF";

run("Set Measurements...", "area mean centroid feret's redirect=None decimal=3");

start_time = getTime();

doOtherStain = (ChannelOtherStain >= 0);
if (doOtherStain) {
	ResultsTable[0] = ResultsTable[0] + "\tEntire Area Intensity Mean\tFiber Average Intensity Mean\tFiber Membrane Avg. Intentisy Mean";
}

//define global variables
var Fibers_area = newArray(2);
var Fibers_areaClass = newArray(num_fiber_bins);
var Fibers_feret = newArray(2);
var Fibers_minFeret = newArray(2);
var Nuclei_central = newArray(2);
var Nuclei_peri = newArray(2);
var OtherStain_fibers = newArray(2);
var OtherStain_membrane = newArray(2);
var ImageName = "";

fileList = getFileList(inputDir);
for (fileNumber = 0; fileNumber < fileList.length; fileNumber++) {
	tic = getTime();
	run("Clear Results");
	fileNameFull = fileList[fileNumber];
	if (endsWith(fileNameFull, ".tif")) {
		print("File in process: " + fileNameFull);
		ImageName = File.getNameWithoutExtension(fileNameFull);
		currentFile = inputDir + fileNameFull;
		run("Bio-Formats Importer", "open=currentFile autoscale color_mode=Default split_channels view=Hyperstack stack_order=XYCZT series_1");
		run("Set Scale...", "distance=Dots_per_micron known=1 unit=um");
		NucleiImage = "";
		FiberImage = "";
		OtherStainImage = "";
		if (isRGBTIFF) {
			CurrentWindows=getTitle();
			Title = split(CurrentWindows,"=");
			NucleiImage = Title[0] + "=" + ChannelNuclei;
			FiberImage = Title[0] + "=" + ChannelFiber;
			OtherStainImage = Title[0] + "=" + ChannelOtherStain;
		} else {
			run("Stack to Images");
			add_on = "-000";
			NucleiImage = ImageName + add_on + ChannelNuclei;
			FiberImage = ImageName + add_on + ChannelFiber;
			OtherStainImage = ImageName + add_on + ChannelOtherStain;
		}
		//Save files
		FILE_ROISection = dirROI + ImageName + "_SectionROI.zip";
		FILE_ROIFiber = dirROI + ImageName + "_FiberROI.zip";
		FILE_ROICentroFiber = dirROI + ImageName + "_CentralFiber.zip";
		FILE_ROIPeri = dirROI + ImageName + "_PeriFiber.zip";
		FILE_ROIMembraneStain = dirROI + ImageName + "_FiberMembrane.zip";
		FILE_resultsByFile = dirResults + ImageName + "_ResultsByFile.txt";
		//Artefact detection
		artefacts_output = ArtefactDetection(FiberImage, isCropped, ArtefactDetectionLimit, FILE_ROISection);
		isSignificantArtefacts = (artefacts_output[0] == 1);
		SectionTotalArea = artefacts_output[1];
		if (!isSignificantArtefacts) {
			//Fiber detection to get ROIs
			Fibers_area = newArray(2);
			Fibers_areaClass = newArray(num_fiber_bins);
			Fibers_feret = newArray(2);
			Fibers_minFeret = newArray(2);
			FiberDetection_output = FiberDetection(FiberImage, isCropped, FILE_ROISection, FILE_ROIFiber, 
													FILE_ROICentroFiber, FILE_ROIPeri);
			Fibers_number = FiberDetection_output[0];
			FiberTotalArea = FiberDetection_output[1];
			Fibers_totalFeret = FiberDetection_output[2];
			
			//Central and peri nuclei detection
			Nuclei_central = newArray(2);
			Nuclei_peri = newArray(2);
			NucleiImage_Processed = ProcessNucleiImage(NucleiImage);
			CNF_counts = CountNuclei(NucleiImage_Processed, FILE_ROICentroFiber, FILE_ROIPeri);
			CNF1_number = CNF_counts[0];
			CNF1_totalArea = CNF_counts[1];
			CNF2_number = CNF_counts[2];
			CNF2_totalArea = CNF_counts[3];
			CNF3_number = CNF_counts[4];
			CNF3_totalArea = CNF_counts[5];
			
			//Other stain detection
			OtherStain_fibers = newArray(2);
			OtherStain_membrane = newArray(2);
			OtherStain_average = 0;
			OtherStain_meanSumTotal = 0;
			OtherStain_membrane_meanSumTotal = 0;
			if (doOtherStain) {
				MeasureOtherStain_output = MeasureOtherStain(OtherStainImage, FILE_ROIFiber);
				OtherStain_average = MeasureOtherStain_output[0];
				OtherStain_meanSumTotal = MeasureOtherStain_output[1];
				OtherStain_membrane_meanSumTotal = MeasureOtherStainMembrane(OtherStainImage, FILE_ROIMembraneStain);
			}
			
			//other stain colocalization with nuclei
			//other stain colocalization with fiber
			
			//Cartography
			if (CartographyType == cartography_items[1]) { //CNF cartography
				cartography_CNF(FiberImage, includeLegend, FILE_ROIFiber);
			}
			
			//Results for file
			print("Saving results...");
			run("Clear Results");
			file_tableOutput = "";
			for (i = 0; i < Fibers_number; i++) {
				setResult("Area", i, Fibers_area[i]);
				setResult("Max Feret", i, Fibers_feret[i]);
				setResult("Min Feret", i, Fibers_minFeret[i]);
				setResult("CentroNuclei", i, Nuclei_central[i]);
				setResult("PeriNuclei", i, Nuclei_peri[i]);
				if (doOtherStain) {
					setResult("Mean Other Stain Intensity", i, OtherStain_fibers[i]);
					setResult("Mean Other Stain Membrane Intensity", i, OtherStain_membrane[i]);
				}
			}
			updateResults();
			selectWindow("Results");
			saveAs("Text", FILE_resultsByFile);
			run("Clear Results");
			
			//Add to global results
			bins_output = "";
			for (i = 0; i < num_fiber_bins; i++) {
				bins_output = bins_output + "\t" + Fibers_areaClass[i];
			}
			ResultsTable[ResultsCurrentLine] = fileNameFull + "\t" + Fibers_number + "\t" + (FiberTotalArea / Fibers_number) + 
												"\t" + (Fibers_totalFeret / Fibers_number) + bins_output + 
												"\t" + (CNF1_number + CNF2_number + CNF3_number) + "\t" + 
												((CNF1_totalArea + CNF2_totalArea + CNF3_totalArea) / (CNF1_number + CNF2_number + CNF3_number)) + 
												"\t" + CNF1_number + "\t" + (CNF1_totalArea / CNF1_number) + 
												"\t" + CNF2_number + "\t" + (CNF2_totalArea / CNF2_number) + 
												"\t" + CNF3_number + "\t" + (CNF3_totalArea / CNF3_number) + 
												"\t" + (100 * (CNF1_number + CNF2_number + CNF3_number) / Fibers_number);
			if (doOtherStain) {
				ResultsTable[ResultsCurrentLine] = ResultsTable[ResultsCurrentLine] + 
													"\t" + OtherStain_average + 
													"\t" + (OtherStain_meanSumTotal / OtherStain_fibers.length) + 
													"\t" + (OtherStain_membrane_meanSumTotal / OtherStain_membrane.length);
			}
		}
		
		//Save global results just in case
		run("Clear Results");
		labels = split(ResultsTable[0], "\t");
		for (i = 1; i < ResultsTable.length; i++) {
			items = split(ResultsTable[i], "\t");
			for (j = 0; j < items.length; j++) {
				setResult(labels[j], i - 1, items[j]);
			}
		}
		updateResults();
		selectWindow("Results");
		saveAs("Text", FILE_globalResults);
		ResultsCurrentLine++;
		
		run("Close All");
		toc = getTime();
		print("\tFile process time (s): " + (toc - tic)/1000);
	}
}

end_time = getTime();
run("Close All");
close("ROI Manager");
print("Total time elapsed (s): " + (toc - tic)/1000);
