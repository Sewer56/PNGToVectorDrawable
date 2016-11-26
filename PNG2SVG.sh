#!/bin/sh

## This script has unused/toggleable functionality, look out for comments

## DEPS:
## IMAGEMAGICK
## AUTOTRACE
## POTRACE
## TPUT

#### CONFIGURATION ####

## SCRIPT DIRECTORY
WORKING_DIRECTORY="${0%/*}"

## READ? (Batch or user confirm) 1/0
# This gives you an option to remove/edit unwanted traces manually before putting separate colours together.
READSTATUS=0

## CONVERT SVG TO VECTOR DRAWABLE? Y/N
CONVERTSVG=N

## Conversion Method
# Manual: User manually splits image components as separate vectors.
# Autotrace: Use autotrace with script builtin color handling/substitution.
# AutotraceAlternate: Use autotrace with autotrace's own color handling/substitution (no transparency support)
# Potrace: Use Potrace as the sketcher utility.
ConversionMethod=Autotrace

# Note: Alpha/Transparency support for Autotrace
# Note: Colour support for Potrace is available

# Use Potrace for complex sketches, Autotrace for simple sketches.

## I/O
INPUT="$1"

## Autotrace Settings

## AutotraceAlternate Specific Settings
BackgroundColour=ffffff
Centerline= ## "-centerline" for 'centerlining', else leave empty
NumberOfColours=0 ## 0 = Any number
CornerAlwaysDegreeThreshold=60 ## If angle @ pixel is < than this, then it's a corner. Default: 60.
CornerSurround=4 ## #Pixels <> side of pixels to consider if corner Default: 4
AutoTraceDespeckle=0 ## Default=none
AutoTraceDespeckleTightness=2.0 ## Default=2.0

## ColoursSampleIntensity (1-32) - Setting too high can cause bloated vector drawables or even broken traces.
## This is the bit depth at which colours are sampled for in Autotrace.
ColoursSampleIntensity=8

## Potrace Settings
CornerThresholdParameter=1 ## "Alphamax" ## -a
DESPECKLELEVEL=0  ## "Turdsize" ## -t
QuantizationLevel=2.0 ## Quant level in 1/pixels ## -u
CurveOptimizationTolerance=0.2 ## -O
BlackCutoff=0.9 ## Black/White cutoff in input file

#USE FOR DEBUGGING
#___________
## DEBUG AYY LMAO ##
#ObtainColoursOpaque "$1"
#echo "Alpha: ""${FullColours[@]}"
#echo "Opaque: ""${Colours[@]}"
#read;
#HexToRGB "${FullColours[1]}"
#sleep 9999s
#___________

#### END ####

## Clear
clear

## For When input is a directory
Images=()

## Shell In-Replacement Colours For Text - Sewer Palette
ColourReset=`tput sgr0`
ColourReset2=`tput sgr0` ##Used if one wants to later change UI colours by a simple regex replace
ColourStandout=`tput smso`
ColourNameText=`tput setaf 3`
ColourLabel=`tput setaf 3`
ColourTrack=`tput setaf 6`
ColourTrack2=`tput setaf 5`
ColourItem=`tput setaf 2`
ColourBold=`tput bold`
ColourWarning=`tput setaf 15`
ColourInfo=`tput setaf 10`
ColourInfoSub=`tput setaf 10`

IdentifyInput () {
  if [[ -d ${INPUT} ]]; then
    ## Populate Images Array with Images
    Images=()
    OLDIFS=$IFS; IFS=$'\n'; for ConvertImage in $(find ${INPUT} -name '*.png'); do Images+=("$ConvertImage"); done; IFS=$OLDIFS

    for Image in "${Images[@]}"; do ConvertToSVG "$Image"; done

    ## Wait for all the BG Tasks to complete
    wait

    echo "DONE"
    exit

  #################################################################################################################
  elif [[ ! ${INPUT##*.} == png ]]; then
    echo "Invalid File Path/Directory! Supported formats are .png"
    exit

  elif [[ -f ${INPUT} ]]; then
    ## Input is a file
    ConvertToSVG "$INPUT"
    exit
  else
    echo "User's input file/directory is not valid"
    exit
  fi
}

ConvertToSVG(){
  ## S1 is the input
  ## S2 output
  OUTPUT="${1%.*}"

  ## Trim the last extension & Directory of the file name
  TrimDirectory="${1%.*}"
  FileExtensionTrim="${TrimDirectory#*.}"
  DotNinePatchCheck="${FileExtensionTrim:0:1}"

  ## Shave edges if .9 patch
  if [[ "${DotNinePatchCheck}" = "9" ]]; then
    convert "$1" -quality 100 -shave 1x1 "$1"
  fi

  ## If manual all is done here
  if [[ "$ConversionMethod" = "Manual" ]]; then TraceColoursManual "$1"; fi

  if [[ ! "$ConversionMethod" = "Manual" ]]; then ObtainColours "$1"; fi
  if [[ ! "$ConversionMethod" = "Manual" ]]; then AlphaOffColours "$1"; fi

  ## For Each Colour Strip Colours
  if [[ ! "$ConversionMethod" = "Manual" ]] && [[ ! "$ConversionMethod" = "AutotraceAlternate" ]]; then StripColours "$1"; fi

  ## For Each Colour Trace And Merge Colour
  if [[ ! "$ConversionMethod" = "Manual" ]]; then TraceColours "$1"; fi

  RemoveLeftovers "$1"

  if [[ $CONVERTSVG = "Y" ]]; then
    ConvertSVG2Vector "${1%%.*}.svg" &> /dev/null
    ## Remove old svg
    rm "${1%%.*}"*".svg" &> /dev/null
  fi
}

RemoveLeftovers(){
  if [[ "$ConversionMethod" = "Autotrace" ]] || [[ "$ConversionMethod" = "Potrace" ]]; then
    ## Change Directory to File Location
    cd "${1%/*}"
    mv "$1.0.svg" "${1%%.*}.svg"

    ## Remove all leftovers
    rm "${1%.*}"*".png" &> /dev/null
    rm "${1%%.*}"*".pnm" &> /dev/null
    rm "${1%%.*}"*.*".svg" &> /dev/null
  fi
  if [[ "$ConversionMethod" = "Manual" ]]; then
    ## Change Directory to File Location
    cd "${1%/*}"
    mv "$1.0.svg" "${1%%.*}.svg"

    ## Remove all leftovers
    rm "${1%.*}"*".png" &> /dev/null
    rm "$1."* &> /dev/null
    rm "${1%%.*}"*".pnm" &> /dev/null
    rm "${1%%.*}"*.*".svg" &> /dev/null
  fi
  if [[ "$ConversionMethod" = "AutotraceAlternate" ]]; then
    ## Change Directory to File Location
    cd "${1%/*}"
    rm "$1"
    rm "$1.pnm"
    mv "$1.svg" "${1%%.*}.svg"
  fi
}

ConvertSVG2Vector() {
  mono "$WORKING_DIRECTORY/SVG2VD/svg2vd.exe" -i "$1"
}

AlphaOffColours(){
  convert "$1" -alpha off "$1"
}

StripColours() {
  for (( i = 0; i < ${#Colours[@]}; i++ )); do
    convert "$1" -fuzz 0.1% -fill "white" +opaque "${Colours[i]}" -fill "black" -opaque "${Colours[i]}" "$1.$i.pnm"
  done
}

TraceColours() {
  for (( i = 0; i < ${#FullColours[@]}; i++ )); do

    ## Potrace method
    if [[ "$ConversionMethod" = "Potrace" ]]; then potrace -C "${Colours[i]}" -t $DESPECKLELEVEL -a $CornerThresholdParameter -u $QuantizationLevel -k $BlackCutoff -s -o "$1.$i.svg" "$1.$i.pnm"; fi

    ## Autotrace
    if [[ "$ConversionMethod" = "Autotrace" ]]; then autotrace -output-file "$1.$i.svg" -output-format svg --background-color $BackgroundColour --color-count $NumberOfColours $Centerline --corner-always-threshold $CornerAlwaysDegreeThreshold -corner-surround $CornerSurround -despeckle-level $AutoTraceDespeckle -despeckle-tightness $AutoTraceDespeckleTightness "$1.$i.pnm"; fi
  done

  ## AutotraceAlternate method
  if [[ "$ConversionMethod" = "AutotraceAlternate" ]]; then convert "$1" "$1.pnm"; autotrace -output-file "$1.svg" -output-format svg --background-color ${UnusedColour:1} --color-count $NumberOfColours $Centerline --corner-always-threshold $CornerAlwaysDegreeThreshold -corner-surround $CornerSurround -despeckle-level $AutoTraceDespeckle -despeckle-tightness $AutoTraceDespeckleTightness "$1.pnm"; fi

  if [[ "$ConversionMethod" = "Autotrace" ]]; then SVGTraceAppendColour "$1"; fi

  if [[ $READSTATUS -eq 1 ]]; then echo "${ColourInfo}Processing File: ${1##*/} | ${ColourReset}Remove/edit unwanted traces & press enter, don't remove (.0) trace"; read; fi;
  if [[ "$ConversionMethod" = "Autotrace" ]]; then MergeColoursAutoTrace "$1" &> /dev/null; fi
  if [[ "$ConversionMethod" = "Potrace" ]]; then MergeColours "$1" &> /dev/null; fi
}

TraceColoursManual(){
  ImageTrigger=False
  Segments=0 ## Initial segment
  declare -a FileArray
  echo "${ColourInfo}Processing File: ${1##*/}"
  echo "Please split the file into separate colours in files manually, each segment should only have 1 colour${ColourReset}"
  echo ""
  read -p "Choose Sketching Method For Image (Autotrace/Potrace): " SketchMethod
  while [ $ImageTrigger = "False" ]
  do
    echo "__________________"
    echo "${ColourInfo}Segment/Colour: $Segments${ColourReset}"
    echo "__________________"
    echo ""
    echo "${ColourInfo}Expected Path:${ColourReset} ${1}.$Segments"
    read -p "File (full path): " SplitFile; ObtainColoursManual "$SplitFile"; FileArray=("${FileArray[@]}" "$SplitFile.svg")
    echo "Colour Predictions:${ColourInfo}${FullColours[@]}${ColourReset}"
    if [[ "$SketchMethod" = "Autotrace" ]]; then read -p "Colour (#RRGGBBAA): " FileColour; else read -p "Colour (#RRGGBB): " FileColour; fi
    SketchManual "$SplitFile" "$FileColour" "$SketchMethod"
    read -p "Done? (True/False): " ImageTrigger
    Segments=$(($Segments + 1))
  done

  ## Combine segments
  if [[ "$SketchMethod" = "Autotrace" ]]; then MergeColoursAutoTraceManual &> /dev/null; fi
  if [[ "$SketchMethod" = "Potrace" ]]; then MergeColoursManual &> /dev/null; fi
}

MergeColoursManual(){
  for (( i = 1; i < ${#FileArray[@]}; i++ )); do
    ItemToMerge=`cat "${FileArray[i]}" | awk '/<g/,/<\/g>/'`
    Pattern='</svg>'
    Insertion="${ItemToMerge}
${Pattern}"
    FileData=`cat "${FileArray[0]}"`
    echo "${FileData//$Pattern/$Insertion}" > "${FileArray[0]}"
  done
}

MergeColoursAutoTraceManual(){
  for (( i = 1; i < ${#FileArray[@]}; i++ )); do
    ItemToMerge=`cat "${FileArray[i]}" | awk '/<path style/,/\/>/'`
    Pattern='</svg>'
    Insertion="${ItemToMerge}
${Pattern}"
    FileData=`cat "${FileArray[0]}"`
    #echo $FileData
    echo "${FileData//$Pattern/$Insertion}" > "${FileArray[0]}"
  done
}

SketchManual(){
  ## $1 = File
  ## $2 = Colour
  ## $3 = Method

  convert "$1" "$1.pnm";
  ## Potrace/Autotrace Sketch
  if [[ "$3" = "Potrace" ]]; then potrace -C "${2}" -t $DESPECKLELEVEL -a $CornerThresholdParameter -u $QuantizationLevel -k $BlackCutoff -s -o "$1.svg" "$1.pnm"; rm "$1.pnm"; fi
  if [[ "$3" = "Autotrace" ]]; then autotrace -output-file "$1.svg" -output-format svg --background-color $BackgroundColour --color-count $NumberOfColours $Centerline --corner-always-threshold $CornerAlwaysDegreeThreshold -corner-surround $CornerSurround -despeckle-level $AutoTraceDespeckle -despeckle-tightness $AutoTraceDespeckleTightness "$1.pnm"; rm "$1.pnm"; fi

  if [[ "$3" = "Autotrace" ]]; then SVGTraceAppendColourManual "$1.svg" "$2"; fi
}

SVGTraceAppendColourManual() {
  ## $1 = File
  ## $2 = Colour
  HexToRGB "${2}"
  FileData=`cat "$1"`
  ColoursLowercase0="${FullColours[0]}"
  ColoursLowercase="${ColoursLowercase0,,}"
  echo "${FileData//"fill:${ColoursLowercase:0:-2};"/"fill:${RGBA};"}" > "$1"
}

MergeColours(){
  for (( i = 1; i < ${#Colours[@]}; i++ )); do
    ItemToMerge=`cat "$1.$i.svg" | awk '/<g/,/<\/g>/'`
    Pattern='</svg>'
Insertion="${ItemToMerge}
${Pattern}"
    FileData=`cat "$1.0.svg"`
    #echo $FileData
    echo "${FileData//$Pattern/$Insertion}" > "$1.0.svg"

    ## FUCK SED
    #sed -i -r "s|$Pattern|$Insertion|g" "$1.0.svg"
    ## FUCK AWK
    #ItemToWrite=`awk -v var="$ItemToMerge" '/<\/g>/{print;print var;next}1' "$1.0.svg"`
  done
}

SVGTraceAppendColour() {
  for (( i = 0; i < ${#FullColours[@]}; i++ )); do
    HexToRGB "${FullColours[i]}" &> /dev/null
    FileData=`cat "$1.$i.svg"`
    echo "${FileData//"fill:#000000"/"fill:${RGBA}"}" > "$1.$i.svg"
  done
}

MergeColoursAutoTrace(){
  for (( i = 1; i < ${#FullColours[@]}; i++ )); do
    ItemToMerge=`cat "$1.$i.svg" | awk '/<path style/,/\/>/'`
    Pattern='</svg>'
Insertion="${ItemToMerge}
${Pattern}"
    FileData=`cat "$1.0.svg"`
    #echo $FileData
    echo "${FileData//$Pattern/$Insertion}" > "$1.0.svg"
  done
}

ObtainColours(){
  ## Get Colours from Image
  Colours=()
  FullColours=()

  OLDIFS=$IFS; IFS=$'\n';
  FullColours=(`convert "$1" -define histogram:unique-colors=true -format %c -depth ${ColoursSampleIntensity} histogram:info:-`)
  IFS=$OLDIFS

  for ((x=0; x<${#FullColours[@]}; x++))
  do
    ## Just strip the hex colour only
    OriginalColour=${FullColours[x]}
    Expansion1=${OriginalColour##*#}
    Expansion2=${Expansion1% *}
    FullColours[x]="#$Expansion2"
  done

  ## Remove Duplicates
  FullColours=( $(echo "${FullColours[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ') )

  for ((x=0; x<${#FullColours[@]}; x++)); do Colours[x]=`echo ${FullColours[x]} | cut -c1-7`; done

  if [[ "$ConversionMethod" = "AutotraceAlternate" ]]; then GetRandomUnusedColour; fi
}

ObtainColoursManual(){
  ## Get Colours from Image
  FullColours=()

  OLDIFS=$IFS; IFS=$'\n'; FullColours=(`convert "$1" -define histogram:unique-colors=true -format %c -depth ${ColoursSampleIntensity} histogram:info:-`);IFS=$OLDIFS

  for ((x=0; x<${#FullColours[@]}; x++))
  do
    ## Just strip the hex colour only
    OriginalColour=${FullColours[x]}
    Expansion1=${OriginalColour##*#}
    Expansion2=${Expansion1% *}
    FullColours[x]="#$Expansion2"
  done

  ## Remove Duplicates
  FullColours=( $(echo "${FullColours[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ') )
}

HexToRGB(){
 # Import: Hex2RGB.sh
 HexInput=`echo $1 | tr '[:lower:]' '[:upper:]'` ## LOS UPPERCASOS AYY LMAO
 a=`echo $HexInput | cut -c2-3`
 b=`echo $HexInput | cut -c4-5`
 c=`echo $HexInput | cut -c6-7`
 d=`echo $HexInput | cut -c8-9`

 r=`echo "ibase=16; $a" | bc`
 g=`echo "ibase=16; $b" | bc`
 b=`echo "ibase=16; $c" | bc`
 a=`echo "ibase=16; $d" | bc`

 Alpha100=`echo "scale=2;${a}/255" | bc`

 ## Add leading zero
 if (( $(echo "$Alpha100 < 1.00" | bc -l) )); then Alpha100="0""$Alpha100"; fi

 if [[ $Alpha100 = "" ]]; then RGBA="rgba($r, $g, $b, 1)"
 else RGBA="rgba($r, $g, $b, $Alpha100)"; fi
}

GetRandomUnusedColour() {
  UnusedColour=False
  while [ $UnusedColour == "False" ]
  do

    ## Get Random Colour
    RandomColour=`tr -c -d 0-9 < /dev/urandom | head -c 6`

    for ((x=0; x<${#Colours[@]}; x++)); do
      if [ "#${RandomColour}" != "${Colours[x]}" ]; then
        UnusedColour="#$RandomColour"
      fi
    done

  done
}

EchoMessage() {
  echo "${ColourInfo}PROCESSING"
  echo "----------${ColourReset}"

  if [[ $ConversionMethod == "Manual" ]]; then
    echo ""
    echo "${ColourInfo}You have chosen the 'Manual', the most accurate method. With the manual method you will be expected to split the files into individual parts, padded. In these parts please keep the colours of the parts intact and apply a colour overlay so only one colour exists in the image (or recommended, make the individual parts fully opaque and specify the colour of the part in #HEXA/#RRGGBBAA), please do NOT TRIM any of the parts.

    Make the background white, leave no semitransparent pixels, to do this you may need to disable Antialiasing in your image editor${ColourReset}"
    echo ""
    echo "${ColourInfo}Autotrace has transparency support, Potrace has not.${ColourReset}"
    echo ""
    echo "Example: 1: test.png.0"
    echo "Example: 2: #00B4E7"
    echo "Example: 3: Autotrace"
    echo ""
  fi
}

## Unused

EchoMessage
IdentifyInput
