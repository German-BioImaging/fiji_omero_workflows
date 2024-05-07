/*
 * -----------------------------------------------------------------------------
 *  Copyright (C) 2018 University of Dundee. All rights reserved.
 *
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * ------------------------------------------------------------------------------
 */

/*
 * This Groovy script downloads a file and opens it in ImageJ using Bio-Formats
 * importer.
 * Use this script in the Scripting Dialog of Fiji (File > New > Script).
 * Select Groovy as language in the Scripting Dialog.
 * Error handling is omitted to ease the reading of the script but this
 * should be added if used in production to make sure the services are closed
 * Information can be found at
 * https://docs.openmicroscopy.org/latest/omero5/developers/Java.html
 */
#@ String(label="Username") USERNAME
#@ String(label="Password", style='password') PASSWORD
#@ String(label="Host", value='workshop.openmicroscopy.org') HOST
#@ Integer(label="Port", value=4064) PORT
#@ Integer(label="Image ID", value=2331) image_id
#@ Integer(label="Series", value=0) series

import java.nio.file.Files

// OMERO Dependencies
import omero.gateway.Gateway
import omero.gateway.LoginCredentials
import omero.gateway.SecurityContext
import omero.gateway.facility.TransferFacility
import omero.log.SimpleLogger

import ij.IJ
import ij.WindowManager

import loci.formats.ImageReader
import loci.formats.MetadataTools


def connect_to_omero() {
    credentials = new LoginCredentials()
    credentials.getServer().setHostname(HOST)
    credentials.getServer().setPort(PORT)
    credentials.getUser().setUsername(USERNAME.trim())
    credentials.getUser().setPassword(PASSWORD.trim())
    simpleLogger = new SimpleLogger()
    gateway = new Gateway(simpleLogger)
    gateway.connect(credentials)
    return gateway
}

def download_image(gateway, image_id, path) {
    transfer = gateway.getFacility(TransferFacility)
    user = gateway.getLoggedInUser()
    ctx = new SecurityContext(user.getGroupId())
    return transfer.downloadImage(ctx, path, new Long(image_id))
} 

// Connect to OMERO
gateway = connect_to_omero()
println("Connected")

// Download the image. This could be composed of several files
tmp_dir = Files.createTempDirectory("OMERO_download")
files = download_image(gateway, image_id, tmp_dir.toString())
println("Downloaded")

files.each() { f ->

	reader = new ImageReader()
	omeMeta = MetadataTools.createOMEXMLMetadata()
	reader.setMetadataStore(omeMeta)
	reader.setId(f.getAbsolutePath())
	reader.close()	
	
	if (series > 1){
		orig_X = omeMeta.getPixelsSizeX(0).value
		orig_Y = omeMeta.getPixelsSizeY(0).value
    	orig_W = omeMeta.getPixelsPhysicalSizeX(0).value
		orig_H = omeMeta.getPixelsPhysicalSizeY(0).value
		new_X = omeMeta.getPixelsSizeX(series - 1).value // 0 based in the metadata and 1 based in the reader!
		new_Y = omeMeta.getPixelsSizeY(series - 1).value
		new_W = orig_W * orig_X /new_X
		new_H = orig_H * orig_Y /new_Y
		new_pixel_size = (new_W + new_H) / 2 // We assume that the pixel width and height should be the same
		println("Series 0: " + orig_X +  " X " + orig_Y + " Pixel size: " + orig_W + " X " + orig_H)
		println("Series " + series + ": " + new_X +  " X " + new_Y + " Pixel size: " + new_pixel_size + " X " + new_pixel_size)
	}

    options = "open=" + f.getAbsolutePath()
    options +=  " windowless=true"
    options +=  " stackFormat=Hyperstack stackOrder=XYCZT"
    options +=  " groupFiles=false swapDimensions=false openAllSeries=false concatenate=false stitchTiles=false"
    options +=  " colorMode=Default autoscale=true"
    options +=  " virtual=false specifyRanges=false crop=false"
    options +=  " splitWindows=false splitFocalPlanes=false splitTimepoints=false"
    if (series > 1){
    	options +=  " series_" + series
    }
    options +=	" showMetadata=false showOMEXML=false showROIs=false roiMode=[ROI manager]"
    IJ.run("Bio-Formats Importer", options)
}
println("Opened")

if (series > 1){
	img = WindowManager.getCurrentImage() // We should switch to using the image name
	IJ.run(img, "Properties...", "pixel_width=" + new_pixel_size + " pixel_height=" + new_pixel_size); 
	println("Pixel Size Corrected")
}

//Delete file in directory then delete it
dir = new File(tmp_dir.toString())
entries = dir.listFiles()
for (i =0; i < entries.length; i++) {
    entries[i].delete()
}
dir.delete()
gateway.disconnect()

println("Done")
