setOption("ExpandableArrays", true);

inputDir = getDir("Choose input directory");
outputDir = getDir("Choose output directory");

list = getFileList(inputDir);
results_header = "Image Name\tDot Maxima";
results = [""];

for(i = 0; i < list.length, i++) {
	run("Bio-Formats Importer", "open=list[i] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	name = File.getName(list[i]);
	run("Find Maxima...", "prominence=0 output=Count");
	count = getResult("Count");
	results[i] = name + "\t" + count;
	close("*");
	
}

close("Results");

labels = split(results_header, "\t");
for (i = 0; i < list.length; i++) {
	items = split(results[i], "\t");
	for(j = 0; j < labels.length; j++) {
		setResult(labels[j], i, items[j]);
	}
}
updateResults();
selectWindow("Results");
saveAs("Text", outputDir + "DotCounts.txt");
