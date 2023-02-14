directory = "C:/Users/ayu/OneDrive - Avidity Biosciences/Documents/Data/ImageJ/644 IF REVEAL Analysis/Tiff-converted images/";
folders = getFileList(directory);
outputDir = "C:/Users/ayu/OneDrive - Avidity Biosciences/Documents/Data/ImageJ/644 IF REVEAL Analysis/Pseudo-colored images/";


for (i = 0; i < folders.length; i++) {
	workingDir = directory + folders[i];
	if (File.isDirectory(workingDir)) {
		files = getFileList(workingDir);
		file_base = "";
		search = "_DAPI";
		for (j = 0; j < files.length; j++) {
			index = indexOf(files[j], search);
			if (index > -1) {
				file_base = File.getName(workingDir + files[j]);
				file_base = substring(file_base, 0, index);
				break;
			}
		}
		DAPI = file_base + "_DAPI_Extended.tif";
		Laminin = file_base + "_TRITC_Extended.tif";
		Dystrophin = file_base + "_Cy5_Extended.tif";

//		open(workingDir + DAPI);
//		open(workingDir + Laminin);
//		open(workingDir + Dystrophin);

		file1 = workingDir + DAPI;
		file2 = workingDir + Laminin;
		file3 = workingDir + Dystrophin;

		run("Bio-Formats Importer", "open=file1 autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");
		rename(DAPI);
		run("Bio-Formats Importer", "open=file2 autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");
		rename(Laminin);
		run("Bio-Formats Importer", "open=file3 autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");
		rename(Dystrophin);
		
		run("Merge Channels...", "c1=[" + Dystrophin + "] c2=[" + Laminin + "] c3=[" + DAPI + "]");

		title = file_base + "_merged.tif";
		saveAs("Tiff", outputDir + title);
		run("Close All");
	}
}

