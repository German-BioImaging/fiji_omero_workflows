// @String(label="Username") USERNAME
// @String(label="Password", style='password', persist=false) PASSWORD
// @String(label="Host", value='omero-host-address') HOST
// @Integer(label="Port", value=4064) PORT
// @Integer(label="Dataset ID", value=0) dataset_id

// Activate the plugin
run("OMERO Extensions");

// Speed up by hiding the images
//setBatchMode("hide")

//Connect to OMERO
connected = Ext.connectToOMERO(HOST, PORT, USERNAME, PASSWORD);

// Set up a table for the results
table_name = "Summary_from_Fiji";

// Get the images in the dataset
omero_images = Ext.list("images", "dataset", dataset_id);
omero_image_ids = split(omero_images, ",");

// Process the images
for(i=0; i<omero_image_ids.length; i++) {
	
	// Get the omero id and name of the image
	omero_image_id = omero_image_ids[i];
	image_name = Ext.getName("image", omero_image_id);
	
	// Open the image from OMERO and select it
	ij_id = Ext.getImage(omero_image_id);
  	ij_id = parseInt(ij_id);
  	selectImage(ij_id);
	
	// Process the image and prepare the result table
	AnalyzeImage(omero_image_id, table_name, image_name);
	
	// Clean up before starting with the next image
	roiManager("reset");
	selectImage(ij_id);
	close();
}

// Save cell count table to the dataset
Ext.saveTable(table_name, "Dataset", dataset_id);
	

//Close everything and disconnect
close("*");
Ext.disconnect();



function AnalyzeImage(image_id, table_name, image_name) {
	
		// Measure Area and Mean intensity
		getStatistics(area, mean);
		
		// Smooth and segment the image
        run("Smooth");
        setAutoThreshold("Default dark no-reset");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		run("Watershed");
        run("Analyze Particles...", "size=100-Infinity pixel exclude add");
        
        // Save the ROIs back to OMERO
        // Avoid it if you have > 500-1000 ROIs
        Ext.saveROIs(image_id, "");
        
        // Count the ROIs
        nROIs = roiManager("count");
  
  		// Prepare the table in FiJi
  		// The FiJi table is reset for each image
  		// The results are kept in the table that will be uploaded to OMERO
		Table.create(table_name);
		Table.set("ImageName", 0, image_name);
		Table.set("TotalArea", 0, area);
		Table.set("MeanIntensity", 0, mean);
		Table.set("CellCount", 0, nROIs);
		Ext.addToTable(table_name, table_name, image_id);
		
		// Save the result to a table for the image
		Ext.addToTable("cell_count", table_name, image_id);
		Ext.saveTable(table_name, "Image", image_id);
}
