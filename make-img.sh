#!/bin/bash
if [[ "$USER" != "root" ]]; then
	echo "Usage: script shall be run as root"
elif [ -z "$1" ]; then
	echo "Usage: ./$0 /dev/sdX"
else
	dd if=$1 of=mon.img status=progress
	losetup --find --partscan --show mon.img > maloop
	sudo fdisk -l $(cat maloop) | tail -n1 | awk '{print $1}' > maloop_part
	sed 's/\//\\\//g' maloop > maloop_esc
	MALOOP=$(cat maloop_esc)
	sed "s/`echo $MALOOP`//g" maloop_part > my_last_partition_num
	sed 's/[0-9].*//g' my_last_partition_num > mychar
	sed "s/$(cat mychar)//g" my_last_partition_num > mynum 
 	bash chroot-to-pi.sh $(cat maloop)$(cat mychar)
	e2fsck -f $(cat maloop_part)
	resize2fs -M $(cat maloop_part)
	fdisk -l $(cat maloop) | awk  'END {print $3}' > end_sector
	fdisk -l $(cat maloop) > test
        cut -d"=" -f1  test | sed -n '2p' | awk '{print $6}' > my_bs
        #gparted mon.img
        dumpe2fs -h $(cat maloop_part) | grep "Block count:" | cut -d":" -f2 | sed 's/ //g' > block_count
        dumpe2fs -h $(cat maloop_part) | grep "Block size:" | cut -d":" -f2 | sed 's/ //g' > block_size
	parted --script $(cat maloop) unit s print | sed -n "`echo $(cat mynum) + 7 | bc`"p | cut -d"$(cat mynum)" -f2 | sed 's/ //g' | cut -d"s" -f1 > start_sector
 	START_SECTOR=$(cat start_sector)
        BLOCK_SIZE=$(cat block_size)
        BLOCK_COUNT=$(cat block_count)
        echo $BLOCK_COUNT*$BLOCK_SIZE  | bc > mybytes
        MYBYTES=$(cat mybytes)
        SECTOR_SIZE=$(cat my_bs)
        echo $MYBYTES/$SECTOR_SIZE | bc> sectors
        SECTORS=$(cat sectors)
        echo $SECTORS + $START_SECTOR + 1 | bc > end_sector
        END_SECTOR=$(cat end_sector)
        sudo parted $(cat maloop) unit s resizepart $(cat mynum) $END_SECTOR
        sfdisk -d mon.img > partitions.txt
        sudo truncate --size=$[($(cat end_sector) + 33 + 1)*$(cat my_bs)] 'mon.img'
        sed -i -e "s/last-lba: [0-9].*/last-lba:`echo $END_SECTOR`/g" partitions.txt
        sfdisk mon.img < partitions.txt

fi
xz -zkv --best mon.img
