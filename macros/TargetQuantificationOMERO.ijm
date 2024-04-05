// @String(label="Username") USERNAME
// @String(label="Password", style='password', persist=false) PASSWORD
// @String(label="Host", value='omero-host-address') HOST
// @Integer(label="Port", value=4064) PORT
// @Integer(label="Group ID", value=0) GROUP
// @Integer(label="Dataset ID", value=0) dataset_id
// @String(label="Target Molecule (collagen or elastin)", value='collagen') target
// @String(label="ROI prefix", value='batch_mask') ROI_prefix
// @Boolean(label="Save overlay", value=false) save_overlay

/*
 * Macro developed by Michael Gerlach (michael.gerlach2@tu-dresden.de) for 
 * Anett Jannasch adapted to work with OMERO by Tom Boissonet and Michele Bortolomeazzi.
 * This macro processes all images in a given dataset and measures the areas
 * positive for collagen or elastin (see code for color deconvolution and thresholding parameters). 
 * Images with no matching ROIs are skipped. The measured areas are saved as tables in OMERO.
 * The macro is applied to all images in the dataset.
 * Only ROIs matching the prefix are used. Images with no matching ROIs are skipped
 * Requires: 
 * - OMERO_macro-extensions (https://github.com/GReD-Clermont/omero_macro-extensions)
 * - ColorDeconvolution 2 (https://blog.bham.ac.uk/intellimic/g-landini-software/colour-deconvolution-2/)
 * - StarDist and CSBDDeep plugins
 * Correctly adjust White Balance before use!
 */


// Cleanup before the start
print("\\Clear");
run("Clear Results");
close("*");
setOption("BlackBackground", true);
setBatchMode(false); // Set to false for better debugging
run("OMERO Extensions");

// Check Target molecule
if (target != "elastin" && target != "collagen" ){
	exit("target can be only 'elastin' or 'collagen'!")
}

// Summary table to attach to the dataset
dataset_table_name = target + "_Summary_" + dataset_id;

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
total_roi_number = 0; // Used to keep a count for the result table
for(i=0; i<image_ids.length; i++) {
	image_id = image_ids[i];
	total_roi_number = processImage(image_id, total_roi_number);
}

// Updates and saves the summary table for the dataset
Ext.saveTable(dataset_table_name, "Dataset", dataset_id);


//Close everything and disconnect
close("*");
Ext.disconnect();


//Definition of functions below

function makeROItable(image_id){
	// Gets the ROIs from OMERO and filter them by the prefix
	// The filtered ROIs are then copied to a new table.
	
	// Get the ROIs from OMERO
	ij_id = Ext.getROIs(image_id);
	roiManager("list");
	Table.create("Filtered_ROIs");
	omero_roi_number = roiManager("count");
	if (omero_roi_number > 0) {
		// Filters the ROIs
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

function processImage(image_id, total_roi_number) {
	// Loads part of an image from OMERO (full resolution)
	// An ROI is used to select the Area to load (bounding box for polygons)
	// Then the image is analyzed and the tables are updated and uploaded to OMERO
	// total_roi_number keeps track of the processed rois

	//Need an image in Fiji to load ROIs
	newImage("tmp_load", "8-bit color-mode", 1, 1, 1, 1, 1);
	
	makeROItable(image_id);
	selectWindow("Filtered_ROIs");
	filtered_roi_length = Table.size;
	if (filtered_roi_length > 0) {
		// Process the ROIs
		for(i=0; i<filtered_roi_length; i++){

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
			
			total_roi_number = analyzeImage(title, x1, y1, image_id, total_roi_number, i);
			selectWindow("Filtered_ROIs"); // For the next loop
		}
		// Save the result table to the image and update the dataset table
		Ext.addToTable(target +"_" + image_id, "Filtered_ROIs", image_id);
		Ext.saveTable(target + "_" + image_id, "image", image_id);
		Ext.addToTable(dataset_table_name, "Filtered_ROIs", image_id);
		Table.reset("Overlay Elements of tmp_load"); // Cleanup (maybe unnecessary)
	}
	Table.reset("Filtered_ROIs"); // Cleanup
	return total_roi_number;
}	

//Definition of functions below

function analyzeImage(title, x1, y1, image_id, total_roi_number, roi_image_number) {
	// The area of the ROI is measured and everyting outside is blacked out
	// Then it performs color deconvolution, thresholds the image,
	// and measures the total area and the % of positive area
	// The ROI upload is commented out,
	// because it can result in a lot of complex ROIs that can slow down OMERO.web
	// The measurements are saved in a table.
	
	// Color deconvolution
	selectWindow(title);
	run("RGB Color");
	rename(title);
	if (target == "elastin"){
		//Color Deconvolution 2 - EvG
		run("Colour Deconvolution2", "vectors=[User values] [r1]=0.4652 [g1]=0.5254 [b1]=0.7124 [r2]=0.5717 [g2]=0.6310 [b2]=0.5244 [r3]=0.4696 [g3]=0.7077 [b3]=0.5278 output=32bit_Absorbance simulated cross hide");
		selected_colour = "-(Colour_2)A";
	}
	if (target == "collagen"){
		//Color Deconvolution 2 - PSR
		run("Colour Deconvolution2", "vectors=[User values] [r1]=0.539 [g1]=0.613 [b1]=0.5898 [r2]=0.44 [g2]=0.614 [b2]=0.653 [r3]=0.245 [g3]=0.829 [b3]=0.5026 output=32bit_Absorbance simulated cross hide");
		selected_colour = "-(Colour_3)A";
	}
	selectWindow(title + selected_colour);
	close("\\Others");
	run("8-bit");
	close(title + "-(Colour_1)A");
	print("\\Clear");
	
	// Blackout everything outside the ROI and measure the total area and the ROI area
	getStatistics(area);
    ij_id = Ext.getROIs(image_id);
	roiManager("list");
    roi_name = Table.getString("Name", roi_image_number, "Filtered_ROIs");
    RoiManager.selectByName(roi_name);
    getStatistics(roi_area);
	run("Clear Outside");
	getSelectionCoordinates(outer_xpoints, outer_ypoints); // Used to draw the ROI if required
	
	// Cleanup ROI
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	
	//Thresholding Channels and get ROI
	selectWindow(title + selected_colour);
	if (target == "collagen") {
		setThreshold(29, 255);
	}
	if (target == "elastin"){
		setThreshold(53, 255);
	}
	setOption("BlackBackground", true);
	run("Convert to Mask");
	
	
	// Measure Positive Areas
	selectWindow(title + selected_colour);
	run("Create Selection");
	getStatistics(positive_area);
	percent_area = positive_area / roi_area * 100;
	
	// Add Area and Fractional Area to the table for the image
	image_name = Ext.getName("image", image_id);
	setResult("Image", roi_image_number, image_id, "Filtered_ROIs");
	setResult("ImageName", roi_image_number, image_name, "Filtered_ROIs");
	setResult("Total_area_um2", roi_image_number, area, "Filtered_ROIs");
	setResult("Total_ROI_area_um2", roi_image_number, roi_area, "Filtered_ROIs");
	setResult("Total_Positive_area_um2", roi_image_number, positive_area, "Filtered_ROIs");
	setResult("Fractional_area_percent", roi_image_number, percent_area, "Filtered_ROIs");
	
	// MANY COMPLEX ROIs SLOW DOWN OMERO WEB TOO MUCH!
	// Make ROI from mask and add it to ROI Manager
	//run ("Create Selection");              
	//roiManager("Add");
	//roiManager("Combine")
	// Shift ROIs to their original position in the image  for verification purposes
	//for (o=0; o<roiManager("count"); ++o) {
	//	roiManager("Select", o);
	//	run("Translate... ", "x=" + x1 + " y=" + y1 + " z=0 c=0 t=0");
	//	roiManager("update");
	//}
	// Save ROIs back to OMERO
	//nROIs = Ext.saveROIs(image_id, "");
	
	// Save Overlay
	if(save_overlay)
	{
		
		run ("Create Selection");   // Make ROI from mask and add it to ROI Manager           
		roiManager("Add");
		roiManager("Combine"); 
		makeSelection("Polygon", outer_xpoints, outer_ypoints);
		setColor(42); // Set all inner pixel to an arbitrary value
		fill();
		setForegroundColor(100, 100, 100); // Set border pixels to a different value
		run("Draw", "slice");
		setForegroundColor(255, 255, 255); // Set drawing color to white
		roiManager("Draw");
		newImageId = Ext.importImage(dataset_id);
	}
	
	
	//Cleanup
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	close("*");
	
	// Update to cumulative ROI count
	total_roi_number +=1 ;
	//roi_number_array =  newArray(total_roi_number, roi_image_number);
	return total_roi_number;
}




