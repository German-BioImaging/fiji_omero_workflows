// @String(label="Username") USERNAME
// @String(label="Password", style='password', persist=false) PASSWORD
// @String(label="Host", value='omero-host-address') HOST
// @Integer(label="Port", value=4064) PORT
// @Integer(label="Group ID", value=0) GROUP
// @Integer(label="Dataset ID", value=0) dataset_id
// @String(label="ROI prefix", value='batch_mask') ROI_prefix

/*
 * Macro developed by Michael Gerlach (michael.gerlach2@tu-dresden.de) for 
 * Anett Jannasch adapted to work with OMERO by Tom Boissonet and Michele Bortolomeazzi.
 * This macro processes all images in a given dataset and measures cell numbers
 * in each ROI matching a given prefix. Images with no matching ROIs are skipped.
 * The resulting ROIs are saved back to OMERO, togheter with tables reporting the number of cells.
 * The macro is applied to all images in the dataset.
 * Only ROIs matching the prefix are used. Images with no matching ROIs are skipped
 * Requires: 
 * - OMERO_macro-extensions (https://github.com/GReD-Clermont/omero_macro-extensions)
 * - ColorDeconvolution 2 (https://blog.bham.ac.uk/intellimic/g-landini-software/colour-deconvolution-2/)
 * Correctly adjust White Balance before use!
 */


// Cleanup before the start
print("\\Clear");
run("Clear Results");
close("*");
setOption("BlackBackground", true);
setBatchMode(true); // Set to false for better debugging
run("OMERO Extensions");

// Summary table to attach to the dataset
dataset_table_name = "CellCountSummary_" + dataset_id

//Connect to OMERO and switch to the correct group
connected = Ext.connectToOMERO(HOST, PORT, USERNAME, PASSWORD);
if (GROUP > 0) {
    Ext.switchGroup(GROUP);
}

// Get the images in the dataset
if(connected == "true") {
    images = Ext.list("images", "dataset", dataset_id);
    image_ids = split(images, ",");
}

// Process the images
for(i=0; i<image_ids.length; i++) {
	image_id = image_ids[i];
	processImage(image_id);
}

// Save cell count table to the dataset
Ext.saveTable(dataset_table_name, "Dataset", dataset_id);

//Close everything and disconnect
close("*");
Ext.disconnect();

//Definition of functions below
function makeROItable(image_id){
	// Gets the ROIs from OMERO and filter them by the prefix
	// The filtered ROIs are then copied to a new table.
	
	// Get the ROIs
	ij_id = Ext.getROIs(image_id);
	roiManager("list");
	Table.create("Filtered_ROIs");
	omero_roi_number = roiManager("count");
	if (omero_roi_number > 0) {
		// Process the ROIs
		for(i=0; i<omero_roi_number; i++){
			name = getResultString("Name", i, "Overlay Elements of tmp_load");
			if (startsWith(name, ROI_prefix)){
				x = getResult("X", i, "Overlay Elements of tmp_load");
				w = getResult("Width", i, "Overlay Elements of tmp_load");
				y = getResult("Y", i, "Overlay Elements of tmp_load");
				h = getResult("Height", i, "Overlay Elements of tmp_load");
				c = getResult("C", i, "Overlay Elements of tmp_load");
				z = getResult("Z", i, "Overlay Elements of tmp_load");
				t = getResult("T", i, "Overlay Elements of tmp_load");
				selectWindow("Filtered_ROIs");
				n = Table.size;
				Table.set("Name", n, name);
				Table.set("X", n, x);
				Table.set("Width", n, w);
				Table.set("Y", n, y);
				Table.set("Height", n, h);
				Table.set("C", n, c);
				Table.set("Z", n, z);
				Table.set("T", n, t);
			}
		}
		Table.update;
	}
}

function processImage(image_id) { 
	// Loads part of an image from OMERO (full resolution)
	// An ROI is used to select the Area to load
	// Then the image is analyzed and the tables are updated and uploaded to OMERO
	
	//Need an image in Fiji to load ROIs
	newImage("tmp_load", "8-bit color-mode", 1, 1, 1, 1, 1);
	
	makeROItable(image_id);
	selectWindow("Filtered_ROIs");
	if (Table.size > 0) {
		// Process the ROIs
		for(i=0; i<Table.size; i++){

			// Get the boundaries of the ROI
			name = getResultString("Name", i, "Filtered_ROIs");
			x1 = getResult("X", i, "Filtered_ROIs");
			x2 = getResult("Width", i, "Filtered_ROIs") + x1 - 1;
			y1 = getResult("Y", i, "Filtered_ROIs");
			y2 = getResult("Height", i, "Filtered_ROIs") + y1 - 1;
			bounds = String.format("x:%.0f:%.0f y:%.0f:%.0f", x1,x2,y1,y2);
			
			c = getResult("C", i, "Filtered_ROIs");
			z = getResult("Z", i, "Filtered_ROIs");
			t = getResult("T", i, "Filtered_ROIs");
			if(c>0) bounds = bounds + " c:"+(c-1);
			if(z>0) bounds = bounds + " z:"+(z-1);
			if(t>0) bounds = bounds + " t:"+(t-1);
			print(bounds);
			
			// Get the image in the ROI
			Ext.getImage(image_id, bounds);
			rename(getTitle() + "["+name+"]");
			title = getTitle();
			
			// Process the image
			analyzeImage(title, x1, y1, image_id);
		}
		// Save cell count table to the image and update the summary table for the dataset
		Ext.addToTable("CellCount_" + image_id, "Filtered_ROIs", image_id);
		Ext.addToTable(dataset_table_name, "Filtered_ROIs", image_id);
		Ext.saveTable("CellCount_" + image_id, "image", image_id);
		Table.reset("Overlay Elements of tmp_load"); // Cleanup (maybe unnecessary)
	}
	Table.reset("Filtered_ROIs"); // Cleanup
}	

//Definition of functions below

function analyzeImage(title, x1, y1, image_id) {
	// Performs colour deconvolution and cell segmantation with Stardist
	// The resulting ROIs are uploaded to OMERO and their number saved in a table
	// x1, y1 are the coordinates of the top-left corner of the ROI, used to
	// shift the ROIs to the original position in the original image
	
	//Color Deconvolution 2 - Preset H&E 2
	selectWindow(title);
	run("RGB Color");
	rename(title);
	run("Colour Deconvolution2", "vectors=[H&E 2] output=32bit_Absorbance simulated cross hide");
	print("\\Clear");
	selectWindow(title + "-(Colour_1)A");
	run("8-bit");
	close(title + "-(Colour_2)A");
	close(title + "-(Colour_3)A");
	
	// Applying StarDist to the presegmented images and count
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	
	SDcommand = "command=[de.csbdresden.stardist.StarDist2D], args=['input':'" + title + "-(Colour_1)A',";
	SDcommand += " 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':";
	SDcommand += " '25.0', 'percentileTop':'100.0', 'probThresh':'0.4', 'nmsThresh':'0.4', 'outputType':'ROI Manager',";
	SDcommand += " 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false',";
	SDcommand += " 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]";
	run("Command From Macro", SDcommand);
	
	//Shift ROIs to their original position in the image
	for (o=0; o<roiManager("count"); ++o) {
		roiManager("Select", o);
		run("Translate... ", "x="+x1+" y="+y1);
		roiManager("update");
	}
	
	image_name = Ext.getName("image", image_id);
	// Add cell count to the table for the image
	nROIs = Ext.saveROIs(image_id, "");
	count = roiManager("count");
	setResult("Image", i, image_id, "Filtered_ROIs");
	setResult("ImageName", i, image_name, "Filtered_ROIs");
	setResult("CellCount", i, count, "Filtered_ROIs");
	
	// Cleanup
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	close("*");
}
