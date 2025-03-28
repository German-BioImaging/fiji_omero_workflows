// Set up a table for the results
table_name = "Summary_from_Fiji";

// Measure Area and Mean intensity
getStatistics(area, mean);
// Smooth and segment the image
run("Smooth");
setAutoThreshold("Default dark no-reset");
setOption("BlackBackground", true);
run("Convert to Mask");
run("Watershed");
run("Analyze Particles...", "size=100-Infinity pixel exclude add");

// Count the ROIs
nROIs = roiManager("count");
// Prepare the table
Table.create(table_name);
Table.set("TotalArea", 0, area);
Table.set("MeanIntensity", 0, mean);
Table.set("CellCount", 0, nROIs);

// Clean up, close everything
//roiManager("reset");
//close("*");

