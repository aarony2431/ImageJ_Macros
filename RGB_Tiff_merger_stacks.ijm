inputDir = getDir("Choose input directory");
outputDir = getDir("Choose output directory");

function getChannelNumberFromColor(color_abbreviation) {
	if (color_abbreviation == "R") {
		return 1;
	} else if (color_abbreviation == "G") {
		return 2;
	} else if (color_abbreviation == "B") {
		return 3;
	} else if (color_abbreviation == "Y") {
		return 4;
	} else {
		return -1;
	}
}

files = getFileList(inputDir);
for (i = 0; i < files.length; i++) {
	file = inputDir + files[i];
	open(file);
	order = "RGB";
	options = "";
	for (j = 0; j < order.length; j++) {
		color = fromCharCode(charCodeAt(order, j));
		channel = getChannelNumberFromColor(color);
		options = options + "c" + channel + "=" + File.getNameWithoutExtension(file) + "-000" + (j+1) + " ";
	}

	run("Stack to Images");
	run("Merge Channels...", options);
	saveAs("Tiff", outputDir + File.getNameWithoutExtension(file) + "_merged.tif");
	run("Close All");
}