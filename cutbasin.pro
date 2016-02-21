; per IDL convention, the main method is the same name as the file and 
; starts on line 209

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;+
; NAME: cutbasin_make_extraction_subdir
;
; PURPOSE:
;    Create subdirectory to house all extracted data files  
;    name as <code-list>_extraction[_mask]
;
; INPUT/STARTING STATE: 
;    list of HUCs and optional mask flag
;  
; OUTPUT/ENDING STATE: 
;    Subdirectory created in current location
;    Execution halts here if permission is insufficient
;
; HISTORY:
;	written 12/2009, C Ownby, CSU
;-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
function cutbasin_make_extraction_subdir ,codelist ,mask

  extract_dir = ""
  for i=0 , n_elements(codelist)-1 do begin
    extract_dir = extract_dir + string(codelist[i]) + "_"
  endfor

  if (keyword_set(mask)) then begin
    extract_dir = extract_dir + "extraction_mask"
  endif else begin
    extract_dir = extract_dir + "extraction"
  endelse

  ;strip whitespace from filename string
  extract_dir = strc(extract_dir)
  
  FILE_MKDIR, extract_dir
  print, "Adding output to subdiretory ",extract_dir
  return ,extract_dir
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;+
; NAME: cutbasin_save_extraction
;
; PURPOSE:
;    Save an extracted image image in the extraction subdirectory
;
; INPUT/STARTING STATE
;    1) filename of new file
;    2) image to save
;    3) extraction info structure
;    4) subdirectory name    
;
; HISTORY:
;	written 12/2009, C Ownby, CSU
;-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro cutbasin_save_extraction ,filename ,image ,bounds ,xdir 

    pushd ,xdir
    write_tiff ,filename ,image ,GEOTIFF=bounds.gtag ,/LONG
    popd 
    
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;+
; NAME: cutbasin_set_info
;
; PURPOSE:
;    Define & return a structure of extraction information
;
; HISTORY:
;	written 12/2009, C Ownby, CSU
;-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
function cutbasin_set_info ,xmin,xmax ,ymin,ymax ,geotag ,mask

  ;this is the return structure
  extractionInfo = {$
    xmin : xmin $
    ,xmax : xmax $
    ,ymin : ymin $
    ,ymax : ymax $
    ,gtag : geotag $
    ,mask : mask[xmin:xmax,ymin:ymax] $
    }
    
  ;construct the geotiff tag to reflect the extraction extent
  extractionInfo.gtag.MODELTIEPOINTTAG[3] $
    = geotag.MODELTIEPOINTTAG[3]+(xmin * geotag.MODELPIXELSCALETAG[0])
  extractionInfo.gtag.MODELTIEPOINTTAG[4] $
    = geotag.MODELTIEPOINTTAG[4]-(ymin * geotag.MODELPIXELSCALETAG[1])
    
  return , extractionInfo
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;+
; NAME: cutbasin_extract
;
; PURPOSE:
;    Given input hydrologic unit codes, create a tif containing all HUCs 
;    and a mask (1=input HUC, 0=other)   
;
; INPUT/STARTING STATE
;    1) list of HUCs
;    2) array of all HUC values
;    3) Original HUC file geotiff tag
;
; OUTPUT/ENDING STATE
;    Returns a structure of extraction/clip info with extent, mask, geotiff tag'
;    Returns failure (0) upon error: insufficent parameters or no codes are found
;
; HISTORY:
;	written 12/2009, C Ownby, CSU
;-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
function cutbasin_extract ,codelist ,HUCimage ,geotag

  ;TODO - check parameters
  if (n_params() lt 3) then begin
    print ,"insufficent parameters in cutbasin_extract"
	help ,/struct ,codelist ,HUCimage ,geotag
    return ,0
  endif
  
  ;create & initialize mask
  mask = HUCimage * 0 
  
  ;for each HU code,
  ;  determine scale by number of digits (region, subreg, accounting, HUC)
  ;  add up extents
  ;  create & save mask, if requested
  ;  save clipped HUC
  
  for i=0L ,n_elements(codelist)-1 do begin
  
    ;number of code[i] digits indicates what part of HUC hierarchy to extract
    codetype = fix(alog10( codelist[i] )/alog10(10)) + 1
    
    case (codetype) of
      ;    8: ;this isn't working, so just repeat code for 7 & 8
      7: begin
        print ,"...extracting basin ", codelist[i]
        w = where(HUCimage eq codelist[i], count)
      end
      8: begin
        print ,"...extracting basin ", codelist[i]
        w = where(HUCimage eq codelist[i], count)
      ;test out appending codes here
      end
      6: begin
        print ,"...extracting accounting region", codelist[i]
        w = where( ((HUCimage - (HUCimage mod 100)) /100) eq codelist[i], count)
      end
      4: begin
        print ,"...extracting sub-region", codelist[i]
        w = where( ((HUCimage - (HUCimage mod 10000)) /10000) eq codelist[i], count)
      end
      2: begin
        print ,"...extracting region", codelist[i]
        ;( "VALUE" - mod ( "VALUE" , 1000000) ) / 1000000
        ;(10190001 - (10190001 mod 1000000)) / 1000000
        w = where( ((HUCimage - (HUCimage mod 1000000)) /1000000) eq codelist[i], count)
      end
      
      else: begin
        print ,"WARNING!  Code length must be in [2,4,6,7,8]. No match for: ",codelist[i],", length of ",codetype
        print ,"Nothing extracted"
        count = 0
      end
    endcase
    
    ;ccumulate indexes extracted.  First interation initializes tags
    if (0 lt count) then begin  ;ensure something was found
      if (keyword_set(tags)) then begin
        tags = [w,tags]
      endif else begin 
        tags = w
      endelse
    endif
    
  endfor

   if (0 lt n_elements(tags)) then begin
    ;convert 1Dim indexes to 2D
    wheretomulti_smart ,size(HUCimage),tags,x,y
 
    ;define & set mask
    mask = HUCimage * 0
    mask[tags] = 1

    ;store extraction info
    exInfo = cutbasin_set_info(min(x),max(x),min(y),max(y),geotag,mask)

    return ,exInfo
    
  endif else begin
    print, "WARNING! Found no HUCs in image"
    return, 0
  endelse
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;+
; NAME: cutbasin 
;
; PURPOSE
;    Given a set of hydrologic unit codes, of any hierarchy level, cut those
;    units from a list of input files.
;
; ASSUMPTIONS
;  current directory is writeable
;  The size & extent of the HUC and value files match
;
; INPUT/STARTING STATE
;   1) list of codes to extract. Format indicates hierarchy level.
;     Hydrologic Unit Code hierarchy
;      aa : drainage region (21 in western region)
;      aabb: subregion (222 in western region)
;      aabbcc: hydrologic accounting unit (352 in western region)
;      aabbccdd: watershed 
;   2) huc is the tiff file of HUC values
;   3) list of files from which to cut out data
;   4) Mask keyword, default=no  (zero out data outside basin boundary, but within extent)
;
;    The size & extent of the HUC and value files must match!
;    
; OUTPUT/ENDING STATE
;    1) Subdirectory is created locally to house all output.  
;    2) Data from each input file is extracted into a new file according to the HUC 
;    values selected.
;
; USAGE (sample)
;  sample codes: 
;    13060001 (bottom of CO), 10190001 (middle of CO) 17100101 (WA)
;    10190006 big thompson, 10190007 North Fork Poudre
;
;   spawn, 'ls /data/ceres5/snowt/akashi_work/temp*/*.tif' ,tempfiles
;   spawn, 'ls /data/ceres5/snowt/akashi_work/ska*/*.tif' ,snowfiles
;   xfiles = [snowfiles,tempfiles]
;   cutbasin ,'10190006','HUCwest_clip.tif',xfiles, /mask
;
; NOTES
; add:
;  include option to spit out file or stack bands
; flush out error handling
;
; HISTORY:
;	written 12/2009, C Ownby, CSU
;-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro cutbasin ,codelist, hucfile, filelist, mask=mask

  if (n_params() lt 3) then begin
    print , "usage: cutbasin ,codelist, hucfile, filelist, [/mask]"
    return
  endif
  if not keyword_set(mask) then mask = 0 ;false
 
  seconds = systime(1,/seconds) ;recording time to execute
 
  
  ;create subdirectory for extracted files, & save name for later use
  xdir = cutbasin_make_extraction_subdir(codelist,mask)
 
  ;get the geotif image of hydrologic unit codes
  ;enhancement: check that is really a geotiff
  huc = read_tiff(hucfile, geotiff = geotag)
  
  ;get bounds from HUC file matching code(s)
  exInfo = cutbasin_extract (codelist ,huc ,geotag)
  if not keyword_set(exInfo) then begin
    print ,"Extraction failed.  Stopping"
	help ,codelist ,huc ,geotag ,exInfo
	;IDL is interactive, so here you can examine the code state to see what went awry
    stop  
  endif
  
  ;extract region of interest from HUC file
  extractImage = huc[exInfo.xmin:exInfo.xmax,exInfo.ymin:exInfo.ymax]  
  if keyword_set(mask) then begin
    extractImage = extractImage * exInfo.mask
    cutbasin_save_extraction ,"mask.tif" ,exInfo.mask ,exInfo ,xdir
  endif
  cutbasin_save_extraction ,"huc.tif" ,extractImage ,exInfo ,xdir

  ;traverse input list:
  ;  pull bounds area from each modis file
  ;  mask or not, save to subdir
  for i = 0L, n_elements(filelist)-1 do begin
  
    ;print, "DEBUG ","extracting from ",filelist[i]
    t = read_tiff(filelist[i])
    extractImage = t[exInfo.xmin:exInfo.xmax,exInfo.ymin:exInfo.ymax]
    if keyword_set(mask) then extractImage = extractImage * exInfo.mask
    
    ;construct filename & strip whitespace
    xfile = "xhuc_" + file_basename(filelist[i])
    xfile = strc(xfile)
    cutbasin_save_extraction ,xfile ,extractImage ,exInfo ,xdir

  endfor

  print, systime(1,/seconds) - seconds, format='("... took ",i5," seconds")'

end ;cutbasin

