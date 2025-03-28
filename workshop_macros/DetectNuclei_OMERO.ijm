// @String(label="Username") USERNAME
// @String(label="Password", style='password', persist=false) PASSWORD
// @String(label="Host", value='omero-host-address') HOST
// @Integer(label="Port", value=4064) PORT
// @Integer(label="Image ID", value=0) omero_image_id

// Activate the plugin
run("OMERO Extensions");

//Connect to OMERO
connected = Ext.connectToOMERO(HOST, PORT, USERNAME, PASSWORD);

// Set up a table for the results
table_name = "Summary_from_Fiji";

// Open the image from OMERO and select it
image_name = Ext.getName("image", omero_image_id);
ij_id = Ext.getImage(omero_image_id);
ij_id = parseInt(ij_id);
selectImage(ij_id);

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
Ext.saveROIs(omero_image_id, "");
// Count the ROIs
nROIs = roiManager("count");
// Prepare the table
Table.create(table_name);
Table.set("ImageName", 0, image_name);
Table.set("TotalArea", 0, area);
Table.set("MeanIntensity", 0, mean);
Table.set("CellCount", 0, nROIs);
Ext.addToTable(table_name, table_name, omero_image_id);
Ext.saveTable(table_name, "Image", omero_image_id);

// Clean up, close everything and disconnect
roiManager("reset");
close("*");
Ext.disconnect();

