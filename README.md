
## NAME: cutbasin 

## PURPOSE
    Given a set of hydrologic unit codes, of any hierarchy level, cut those units from a list of input files.

## ASSUMPTIONS
  current directory is writeable
  The size & extent of the HUC and value files match

## INPUT/STARTING STATE
  1. list of codes to extract. Format indicates hierarchy level. <br/>
     Hydrologic Unit Code hierarchy <br/>
      - aa : drainage region (21 in western region) 
      - aabb: subregion (222 in western region) 
      - aabbcc: hydrologic accounting unit (352 in western region)
      - aabbccdd: watershed 
  2. huc is the tiff file of HUC values
  3. list of files from which to cut out data
  4. Mask keyword, default=no  (zero out data outside basin boundary, but within extent)

    The size & extent of the HUC and value files must match!
    
## OUTPUT/ENDING STATE
  1. Subdirectory is created locally to house all output.  
  2. Data from each input file is extracted into a new file according to the HUC 
    values selected.

## USAGE (sample)
  sample codes:
    13060001 (bottom of CO), 10190001 (middle of CO) 17100101 (WA) 10190006 big thompson, 10190007 North Fork Poudre

   * spawn, 'ls /data/ceres5/snowt/akashi_work/temp*/*.tif' ,tempfiles
   * spawn, 'ls /data/ceres5/snowt/akashi_work/ska*/*.tif' ,snowfiles
   * xfiles = [snowfiles,tempfiles]
   * cutbasin ,'10190006','HUCwest_clip.tif',xfiles, /mask

## NOTES
 add:  
  - include option to spit out file or stack bands  
  - flush out error handling  

## HISTORY:
	written 12/2009, C Ownby, CSU
