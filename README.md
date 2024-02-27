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

#### Attribution
The macro was developed by Michael Gerlach for 
Anett Jannasch and later adapted to work with OMERO by Tom Boissonet and Michele Bortolomeazzi.

The context this macro was originally applied it, togheter with its original version can be found at:
https://doi.org/10.1063/5.0182672

### TargetQuantificationOMERO.ijm
The macro is at:
https://github.com/German-BioImaging/fiji_omero_workflows/blob/main/macros/TargetQuantificationOMERO.ijm

This macro processes all images in a given dataset and measures the area positive for collagen or elastin
(see code for color deconvolution and thresholding parameters). Images with no matching ROIs are skipped.
The measured areas are saved as tables in OMERO.

#### Additional equirements
-  ColorDeconvolution 2 (https://blog.bham.ac.uk/intellimic/g-landini-software/colour-deconvolution-2/)
  
#### Attribution
The macro was developed by Michael Gerlach  for 
Anett Jannasch and later adapted to work with OMERO by Tom Boissonet and Michele Bortolomeazzi.

The context this macro was originally applied it, togheter with its original version can be found at:
https://doi.org/10.1063/5.0182672
