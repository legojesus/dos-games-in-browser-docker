#!/usr/bin/env bash

# Apply registry settings
# wine regedit /home/heroes/bin/homm3.reg 2>/dev/null

cd "/home/heroes/.wine/drive_c/Program Files (x86)/3DO/Heroes III Demo/"

# Force software rendering for better VNC compatibility
export LIBGL_ALWAYS_SOFTWARE=1
export WINE_D3D_CONFIG="renderer=gdi"

# Run game in a virtual desktop for better VNC compatibility
while :
do
	wine explorer /desktop=Game,1024x768 'Heroes3 HD.exe'
	sleep 2
done

