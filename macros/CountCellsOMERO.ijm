// @String(label="Username") USERNAME
// @String(label="Password", style='password', persist=false) PASSWORD
// @String(label="Host", value='omero-host-address') HOST
// @Integer(label="Port", value=4064) PORT
// @Integer(label="Group ID", value=0) GROUP
// @Boolean(label="Process By Tag", value=false) process_by_tag
// @String(label="Tag Name", value="to_process") tag_to_use
// @Integer(label="Dataset ID", value=0) dataset_id
// @String(label="ROI prefix", value='batch_mask') ROI_prefix
// @Boolean(label="Save overlay", value=false) save_overlay
// @String(label="Stardist Model", value= 'Versatile (fluorescent nuclei)') modelChoice
// @String(label="Stardist Normalize Input (true/false)", value= 'true') normalizeInput
// @String(label="Stardist percentileBottom", value= '25') percentileBottom
// @String(label="Stardist percentileTop", value= '100') percentileTop
// @String(label="Stardist probThresh Input", value= '0.4') probThresh
// @String(label="Stardist nmsThresh", value= '0.4') nmsThresh

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
setBatchMode(false); // Set to false for better debugging
run("OMERO Extensions");

// Get a timestamp
timestamp = MakeTimestamp();

//Connect to OMERO and switch to the correct group
connected = Ext.connectToOMERO(HOST, PORT, USERNAME, PASSWORD);
if (GROUP > 0) {
    Ext.switchGroup(GROUP);
}

// Select datasets to be processed
datasets_to_process = newArray();
if(process_by_tag) { // Select by tag
    datasets = Ext.list("datasets");
	datasetIds = split(datasets,",");
	for (d = 0; d < datasetIds.length; d++){
		tags = Ext.list("tags", "dataset", datasetIds[d]);
		tagIds = split(tags,",");
		for (t = 0; t < tagIds.length; t++)
		{
			tagName = Ext.getName("tag", tagIds[t]);
			if (tagName == tag_to_use)
			{
				datasets_to_process = Array.concat(datasets_to_process, datasetIds[d]);
				break
			}
		}
	}
} else { // Process the single dataset provided as an argument
	datasets_to_process = Array.concat(datasets_to_process, dataset_id);
}


// Process the datasets
for (d=0; d<datasets_to_process.length; d++){

	// dataset id and table name
	dataset_id = datasets_to_process[d];
	dataset_table_name = "CellCountSummary_" + dataset_id + "_" + timestamp;
	Table.create(dataset_table_name);
	
	// Get the images in the dataset
	images = Ext.list("images", "dataset", dataset_id);
	image_ids = split(images, ",");
	
	// Process the images
	for(n=0; n<image_ids.length; n++) {
		image_id = image_ids[n];
		processImage(image_id);
	}
	
	// Save cell count table to the dataset
	Ext.saveTable(dataset_table_name, "Dataset", dataset_id);
	
	// Attach Stardist parameters as file
	AttachParamsFile(timestamp, dataset_id);
}

//Close everything and disconnect
close("*");
Ext.disconnect();
print("DONE!");

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
	filtered_roi_length = Table.size;
	if (filtered_roi_length > 0) {
		// Process the ROIs
		for(i=0; i<filtered_roi_length; i++){

			// Get the boundaries of the ROI
			print("image_id");
			print(image_id);
			print("i");
			print(i);
			print("filtered_roi_length");
			print(filtered_roi_length);
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
			analyzeImage(title, x1, y1, image_id, i);
		}
		// Save cell count table to the image and update the summary table for the dataset
		Ext.addToTable("CellCount_" + image_id, "Filtered_ROIs", image_id);
		Ext.addToTable(dataset_table_name, "Filtered_ROIs", image_id);
		Ext.saveTable("CellCount_" + image_id, "image", image_id);
	}
	Table.reset("Filtered_ROIs"); // Cleanup
}	

function analyzeImage(title, x1, y1, image_id, roi_image_number) {
	// The area of the ROI is measured and everyting outside is blacked out
	// Then it performs colour deconvolution and cell segmantation with Stardist
	// cells touching the border of the ROI are deleted
	// Optionally an overlay is drawn and saved to OMERO.
	// The resulting ROIs are uploaded to OMERO and their number saved in a table
	// x1, y1 are the coordinates of the top-left corner of the ROI, used to
	// shift the ROIs to the original position in the original image
	
	//Color Deconvolution 2 - Preset H&E 2
	selectWindow(title);
	run("RGB Color");
	rename(title);
	run("Colour Deconvolution2", "vectors=[H&E 2] output=32bit_Absorbance simulated cross hide");
	//print("\\Clear");
	selectWindow(title + "-(Colour_1)A");
	close("\\Others");
	run("8-bit");
	
	// Blackout everything outside the ROI and measure the total area and the ROI area
	getStatistics(area);
    ij_id = Ext.getROIs(image_id);
	roiManager("list");
    roi_name = Table.getString("Name", roi_image_number, "Filtered_ROIs");
    RoiManager.selectByName(roi_name);
    getStatistics(roi_area);
	run("Clear Outside");
	
	// Used to create the polygon selection to filter ROIs with points outside it
	getSelectionCoordinates(outer_xpoints, outer_ypoints);

	
	// Applying StarDist to the presegmented images and count
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	
	SDcommand = "command=[de.csbdresden.stardist.StarDist2D], args=['input':'" + title + "-(Colour_1)A',";
	SDcommand += " 'modelChoice':'" + modelChoice + "', 'normalizeInput':'" + normalizeInput + "',";
	SDcommand += " 'percentileBottom':'" + percentileBottom + "', 'percentileTop':'" + percentileTop + "',";
	SDcommand += " 'probThresh':'" + probThresh + "', 'nmsThresh':'" + nmsThresh + "', 'outputType':'ROI Manager',";
	SDcommand += " 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false',";
	SDcommand += " 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]";
	print(SDcommand);
	run("Command From Macro", SDcommand);
	
	
	// Removes cells intersecting the ROI borders (at pixel resolution)
	makeSelection("Polygon", outer_xpoints, outer_ypoints);
	setColor(42); // Set all inner pixel to an arbitrary value
	fill();
	setForegroundColor(100, 100, 100); // Set border pixels to a different value
	run("Draw", "slice");
	to_be_deleted = newArray();
	for (r=0; r<roiManager("count"); r++) {
		roiManager("Select", r);
		Roi.getContainedPoints(xpoints, ypoints);
		for(n=0; n < xpoints.length; n++)
		{	// if at least one pixel doesn't have the inner value, delete the roi
			if (getPixel(xpoints[n], ypoints[n]) != 42){
				to_be_deleted = Array.concat(to_be_deleted, r);
				break;
			}
		}	
	}
	if (to_be_deleted.length > 0){
		roiManager("Select", to_be_deleted);
		roiManager("Delete");
	}
	
	// Save Overlay
	if(save_overlay)
	{
		setForegroundColor(255, 255, 255); // Set drawing color to white
		roiManager("Draw");
		newImageId = Ext.importImage(dataset_id);
	}
	
	//Shift ROIs to their original position in the image
	// Rename ROIs as "current ROI name  - timestamp"
	for (o=0; o<roiManager("count"); ++o) {
		roiManager("Select", o);
		run("Translate... ", "x="+x1+" y="+y1);
		roiManager("update");
		roiManager("rename", "Cell-" + roi_name + "-" + timestamp);
		roiManager("update");
	}
	
	image_name = Ext.getName("image", image_id);
	// Add cell count, ROI area, and total bounding box area to the table for the image
	nROIs = Ext.saveROIs(image_id);
	count = roiManager("count");
	setResult("Image", roi_image_number, image_id, "Filtered_ROIs");
	setResult("ImageName", roi_image_number, image_name, "Filtered_ROIs");
	setResult("Total_area_um2", roi_image_number, area, "Filtered_ROIs");
	setResult("Total_ROI_area_um2", roi_image_number, roi_area, "Filtered_ROIs");
	setResult("CellCount", roi_image_number, count, "Filtered_ROIs");
	
	// Cleanup
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	close("*");
}

function MakeTimestamp(){
	// Returns a timestamp in the form:
	// year-month-day-hour.minute.second.millisecond
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    TimeString = toString(year) + "-" + toString(month) + "-" + toString(dayOfMonth) + "-";
    TimeString += toString(hour) + "." + toString(minute) + "." + toString(second) + ".";
	TimeString += toString(msec);
	return TimeString;
}

function AttachParamsFile(timestamp, dataset_id) {
	// Makes a txt file in the temp folder
	// Adds the parameters used by stardist (1 per row tab separated)
	// Attaches the file to the dataset
	// Deletes the file
	
	txt_file_path = getDir("temp") + timestamp + "-CountCellsOMERO.txt";
	txt_file = File.open(txt_file_path);
	
	print(txt_file, "modelChoice" + "\t" + modelChoice);
	print(txt_file, "normalizeInput" + "\t" + normalizeInput);
	print(txt_file, "percentileBottom" + "\t" + percentileBottom);
	print(txt_file, "percentileTop" + "\t" + percentileTop);
	print(txt_file, "probThresh" + "\t" + probThresh);
	print(txt_file, "nmsThresh" + "\t" + nmsThresh);
	
	File.close(txt_file);
	file_id = Ext.addFile("Dataset", dataset_id, txt_file_path);
	deleted = File.delete(txt_file);
}
