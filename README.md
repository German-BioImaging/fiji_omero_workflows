# Examples of worklfows combining Fiji and OMERO

## Environment Setup
All macros require the following FiJi plugins:
- OMERO_macro-extensions (https://github.com/GReD-Clermont/omero_macro-extensions)

The specific requirements for each macro are listed in the corresponding sections.

## Workflows

### CountCellsOMERO.ijm
The macro is at:
https://github.com/German-BioImaging/fiji_omero_workflows/blob/main/macros/CountCellsOMERO.ijm

This macro processes all images in a given dataset and measures cell numbers in each ROI matching a given prefix.
Images with no matching ROIs are skipped.
The resulting ROIs are saved back to OMERO, togheter with tables reporting the number of cells.

#### Additional requirements
-  ColorDeconvolution2 (https://blog.bham.ac.uk/intellimic/g-landini-software/colour-deconvolution-2/)
-  StarDist and CSBDDeep plugins

#### Input
From a dialog window after starting the macro:
- `Username` = OMERO username.
- `Password` = OMERO password.
- `Host` = Address of the OMERO server.
- `Port` = Port of the OMERO server (default = `4064`).
- `Group` = ID of the group the dataset belongs to (default = `0`, keeps the user's default group).
- `Dataset ID` = OMERO id of the dataset to process (can be looked up from OMERO.web).
- `ROI prefix` = Prefix of the ROI names to analyze, only matching ROIs are processed.
- `StarDist Model` = Name of the StarDist model to use (default = `'Versatile (fluorescent nuclei)')`).
- `StarDist Normalize Input (true/false)" =  StarDist normalizeInput parameter (default = `'true'`)
- `StarDist percentileBottom` =  StarDist percentileBottom parameter (default = `25`)
- `StarDist percentileTop` =  StarDist percentileTop parameter (default = `100`)
- `StarDist probThresh` =  probThresh StarDist parameter (default = `0.4`)
- `StarDist nmsThresh` =  nmsThresh StarDist parameter (default = `0.4`)

#### Output
The following tables are saved to OMERO:
- Attached to each image: `DATE_TIME_CellCount_IMAGEid`
- Attached to the dataset: `DATE_TIME_CellCountSummary_DATASETid`
  
The tables contain the following columns:
+ `Image` = OMERO image id.
+ `Name` = Name of the ROI.
+ `X` = X location of the top-left corner of the ROI.
+ `Width` = Width of the ROI.
+ `Y` = Y location of the top-left corner of the ROI.
+ `Height` = Height of the ROI.
+ `C` = c slice.
+ `Z` = z slice.
+ `T` = t slice.
+ `Label` = OMERO image id.
+ `ImageName` = Image name.
+ `Total_area_um2` = Total Area of the bounding box of the ROI (µm^2 if the pixel unit is µm).
+ `Total_ROI_area_um2` = Total Area of the ROI (µm^2 if the pixel unit is µm).
+ `CellCount` = Number of segmented cells.
  
Additionally, ROIs for all segmented cells are added to each image.

#### Attribution
The macro was developed by Michael Gerlach for 
Anett Jannasch and later adapted to work with OMERO by Tom Boissonet and Michele Bortolomeazzi.

The context this macro was originally applied in, togheter with its original version can be found at:
https://doi.org/10.1063/5.0182672

### TargetQuantificationOMERO.ijm
The macro is at:
https://github.com/German-BioImaging/fiji_omero_workflows/blob/main/macros/TargetQuantificationOMERO.ijm

This macro processes all images in a given dataset and measures the area positive for collagen or elastin
(see code for color deconvolution and thresholding parameters). Images with no matching ROIs are skipped.
The measured areas are saved as tables in OMERO.

#### Additional equirements
-  ColorDeconvolution 2 (https://blog.bham.ac.uk/intellimic/g-landini-software/colour-deconvolution-2/)

#### Input
From a dialog window after starting the macro:
- `Username` = OMERO username.
- `Password` = OMERO password.
- `Host` = Address of the OMERO server.
- `Port` = Port of the OMERO server (default = `4064`).
- `Group` = ID of the group the dataset belongs to (default = `0`, keeps the user's default group).
- `Dataset ID` = OMERO id of the dataset to process (can be looked up from OMERO.web).
- `Target Molecule (collagen or elastin)` =  Target molecule (default = `'collagen'`).
- `ROI prefix` = Prefix of the ROI names to analyze, only matching ROIs are processed.

#### Output
The following tables are saved to OMERO (the same unit as the pixel size is used):
- Attached to each image: `DATE_TIME_TARGET_IMAGEid`
- Attached to the dataset: `DATE_TIME_TARGET_Summary_DATASETid`
  
The tables contain the following columns:
+ `Image` = OMERO image id.
+ `Name` = Name of the ROI.
+ `X` = X location of the top-left corner of the ROI.
+ `Width` = Width of the ROI.
+ `Y` = Y location of the top-left corner of the ROI.
+ `Height` = Height of the ROI.
+ `C` = c slice.
+ `Z` = z slice.
+ `T` = t slice.
+ `Label` = OMERO image id.
+ `ImageName` = Image name.
+ `Total_area_um2` = Total Area of the bounding box of the ROI (µm^2 if the pixel unit is µm).
+ `Total_ROI_area_um2` = Total Area of the ROI (µm^2 if the pixel unit is µm).
+ `Total_Positive_area_um2` = Total area covered by the target moleclue in the ROI (µm^2 if the pixel unit is µm). 
+ `Fractional_area_percent` = Fractional (target moleule positive area / ROI area) area as a percentage.
  
#### Attribution
The macro was developed by Michael Gerlach  for 
Anett Jannasch and later adapted to work with OMERO by Tom Boissonet and Michele Bortolomeazzi.

The context this macro was originally applied in, togheter with its original version can be found at:
https://doi.org/10.1063/5.0182672
