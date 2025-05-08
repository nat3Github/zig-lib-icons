#!/bin/bash


# Note: you must cd into icons and then run ./sh/run.sh

# decls:
path_src="src"
path_tvgt="src/tvgt"
path_tvg="src/tvg"
path_svg="src/svg"

feather="feather"
herooutline="heroicons/outline"
herosolid="heroicons/solid"
lucide="lucide"
  
arr=("$feather" "$herosolid" "$herooutline" "$lucide")

#programs:
CONVERTER_PATH="/Users/nat3/programming/zig/lib/tvg-sdk2/src/tools/svg2tvgt/bin/Debug/net8.0/svg2tvgt"
TVGTEXT="/Users/nat3/programming/zig/lib/tvg-sdk2/zig-out/bin/tvg-text"

svg2tvgt__() {
    # wrapper for svg2tvg tool from https://github.com/TinyVG/sdk
    $CONVERTER_PATH $1
}

tvgt2tvg__() {
    # wrapper for tvgt conversion tool from https://github.com/TinyVG/sdk
    $TVGTEXT -I tvgt $1 -O tvg
}


setup() {
  mkdir -p $path_tvg/"$1"
  mkdir -p $path_tvgt/"$1"
}



svg_conv() {
# Loop through all SVG files in the current directory
var_dir=$1
for file in "$path_svg"/"$var_dir"/*.svg; do
  # Check if the file exists (in case no SVG files match)
  if [[ -f "$file" ]]; then
    svg2tvgt__ "$(realpath "$file")"
  fi
done

#copy them to tvgt
find "$path_svg"/"$var_dir"/*.tvgt -exec mv {} $path_tvgt/"$var_dir"/ \; 

for file in "$path_tvgt"/"$var_dir"/*.tvgt; do
  if [[ -f "$file" ]]; then
    var_p="$(realpath "$file")"
    tvgt2tvg__ $var_p
  fi
done

#copy them to tvg
find "$path_tvgt"/"$var_dir"/*.tvg -exec mv {} $path_tvg/"$var_dir"/ \; 
}


srcgen_svg(){
var_dir=$1
zig_file1="$var_dir".zig
zig_file2="${zig_file1//\//-}"
mkdir "$path_src"/embed-svg
zig_file="$path_src"/embed-svg/"$zig_file2"
# str_no_slash="${zig_file//\//}" 
rm "$zig_file"
touch "$zig_file"
for file in "$path_svg"/"$var_dir"/*.svg; do
  if [[ -f "$file" ]]; then
   withoutsfx=$(basename "$file")
   withoutsfx="${withoutsfx%.*}"
   zig_str=$(zig_decl_svg "$var_dir" "$withoutsfx")
   #  echo "$zig_str"
   echo "$zig_str" >> "$zig_file" 
  fi
done
}

srcgen_tvg(){
var_dir=$1
zig_file1="$var_dir".zig
zig_file2="${zig_file1//\//-}"
mkdir "$path_src"/embed-tvg
zig_file="$path_src"/embed-tvg/"$zig_file2"
# str_no_slash="${zig_file//\//}" 
rm "$zig_file"
touch "$zig_file"
for file in "$path_tvg"/"$var_dir"/*.tvg; do
  if [[ -f "$file" ]]; then
   withoutsfx=$(basename "$file")
   withoutsfx="${withoutsfx%.*}"
   zig_str=$(zig_decl_tvg "$var_dir" "$withoutsfx")
   #  echo "$zig_str"
   echo "$zig_str" >> "$zig_file" 
  fi
done
}

zig_decl_tvg () {
  folder=$1
  name=$2
  embedf="@embedFile(\"../tvg/$folder/$name.tvg\");"
  pubconst="pub const @\"$name\" = "
  echo "$pubconst""$embedf"
}
zig_decl_svg () {
  folder=$1
  name=$2
  embedf="@embedFile(\"../svg/$folder/$name.svg\");"
  pubconst="pub const @\"$name\" = "
  echo "$pubconst""$embedf"
}



run() {
  for k in "${arr[@]}"; do
  setup "$k"
  svg_conv "$k"
done
only_src_gen
}

only_src_gen() {
  for k in "${arr[@]}"; do
  srcgen_tvg "$k"
  srcgen_svg "$k"
  echo "$k"
done
}

# echo $(zig_decl "feather" "myicon");
# only_src_gen
run


