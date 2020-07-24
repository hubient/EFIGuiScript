#!/bin/ksh
#  Name: chooseEFIBoot.sh
#  Date: 22.7.2020
VERSION="0.2"
#  Description:
#   Script for easy chnage the next boot in EFI 
#   And or lets you set the standad boot
#
#  Depenecies:
#   ksh         must be installed in /bin/ksh (I use actual version ((AT&T Research) 93u+ 2012-08-01)
#   zenity      must be installed for to use the gui it needs also to be in the path it is running with version 3.32.0
#   efibootmgr  must be installed i use the version 14 
#
#   configuration to set:
#   /etc/sudoers must contain and entry:<user> ALL = (root) NOPASSWD:/usr/sbin/efibootmgr
#               Where <user> is your login userid  
#######################################################################################

# Setup for the windows sizes
WIDTH="600"
HEIGHT="500"

CHANGED="false"

PRG="$0"
PRG=${PRG#*/}
PRG=${PRG%.sh}

IFS=" 
"
DEBUG="echo debug "
DEBUG=""

sbootList="FALSE empty"
nbootList="FALSE empty"

EFI="sudo /usr/sbin/efibootmgr"

KDE_REBOOT="qdbus org.kde.ksmserver /KSMServer org.kde.KSMServerInterface.logout 1 1 1"
GNOME_REBOOT=""
REBOOT=""

case "$XDG_CURRENT_DESKTOP" in
    KDE) REBOOT=${KDE_REBOOT};;
    GNOME) RBOOT=${GNOME_REBOOT};;
esac
        

typeset -a filter
export filter

function usage {
	cat <<EOF
Syntax: $0 [--filter|-f <entry filter>]...  [--help|-h] 

	--filter 	only display patterin the enties filter (can be used mutliple times)
	--kde-boot  calls
	--help		this output

Version : ${VERSION}
	
EOF
} ### end usage

while [[ -n $1 ]]
do
	case "$1" in
		--filter|-f)
			filter[${#filter[*]}]="$2"
			shift
			;;
		--help|-h)
			usage
			exit 1
			;;
        --kde-boot)
            REBOOT=${KDE_REBOOT}
            ;;
        --gnome-boot)
            REBOOT=${GNOME_REBOOT}
            ;;
		*)
			echo "Unknow argument $1"
			usage
			exit 1
			;;
	esac
	shift
done

if [[ ${#filter[*]} == 0 ]]
then
	filter[0]="allenries"
fi

printf "filter %s\n" ${filter[*]}


function readEfiIn {
    sbootList=""
    nbootList=""
	$EFI | while read boot string
	do
		# echo $boot / $string / $findBoot
		if [[ $boot == "BootCurrent:" ]]
		then
			CurrentBoot=$string
		fi
		if [[ $boot == "BootNext:" ]]
		then
			NextBoot=$string
		fi
		if [[ $boot == "BootOrder:" ]]
		then
			BootOrder=$string
			StandardBoot=${string%%,*}
		fi

		if [[ $boot =~ Boot[0-9][0-9][0-9][0-9]* ]]
		then
			nr=${boot##Boot}
			nr=${nr%\*}
			SBOOT="FALSE"
			NBOOT="FALSE"
			if [[ $boot == "Boot${StandardBoot}*" ]]
			then
				SBOOT="TRUE"
				SBOOT_STRING="$string"
			fi
			if [[ $boot == "Boot${NextBoot:=${StandadBoot}}*" ]]
			then
				NBOOT="TRUE"
				NBOOT_STRING="$string"
			fi

			fiFound=false
			echo filter=${filter[*]}
			for actfilter in ${filter[*]}
			do
				if [[ $fiFound == "false" ]]
				then
					if [[ "$nr $string" == *"${actfilter}"* ]] || [[ "$actfilter" == "allenries" ]]
					then
						fiFound=true
						export sbootList="$sbootList $SBOOT \"$nr $string\""
						export nbootList="$nbootList $NBOOT \"$nr $string\""
					fi
				fi
			done
		fi
	done
} ## end readEfiIn

readEfiIn


LANG=C
set -x      
# NBOOT_STRING=$(echo ${NBOOT_STRING} | sed 's/\s/\\ /g')
NBOOT_STRING="\"${NBOOT_STRING:=""}\""
SBOOT_STRING="\"${SBOOT_STRING:=""}\""

choosed=$(eval zenity --width=${WIDTH} --height=${HEIGHT} --list --radiolist \
      --title '${PRG}\ ${VERSION}\ /\ next\ boot' \
      --text "Select\ next\ boot\ enrty:\ actual\ \(${NextBoot:=none}${NextBoot:+\ }${NBOOT_STRING}\)" \
      --column 'Select\ next\ boot:' \
      --column 'Boot\ partition' \
      ${nbootList} )
      

set +x
if [[ -n $choosed ]]
then
	echo $choosed
	choosedNum=${choosed%% *}
	choosedText=${choosed#* }

	$DEBUG $EFI --bootnext $choosedNum
	CHANGED="true"
else
	echo "Skip nextboot"
fi
set -x
choosed=$(eval zenity --width=${WIDTH} --height=${HEIGHT} --list --radiolist \
      --title '${PRG}\ ${VERSION}\ /\ standad\ boot' \
      --text "Standard=${StandardBoot}${StandardBoot:+\ }${SBOOT_STRING}" \
      --column 'standard\ boot' \
      --column 'Boot-Partition' \
      ${sbootList} )
set +x

echo $choosed
if [[ -n $choosed ]]
then
	choosedNum=${choosed%% *}
	choosedText=${choosed#* }

	NBOOT="TRUE"
	echo "We boot standard with $choosed"
	newBootOrder="$choosedNum"
	IFS=","
	for boot in $BootOrder
	do
		IFS=" 
"
		if [[ $boot != $choosedNum ]]
		then
			echo $boot
			newBootOrder="${newBootOrder},$boot"
		fi	
	done
	echo "New BootOrder = $newBootOrder"
	echo "old BootOrder = $BootOrder"
	$DEBUG $EFI --bootorder $newBootOrder
	CHANGED="true"
else
	echo "Skip new bootorder"
fi

if [[ ${CHANGED} == "true" ]]
then
    $REBOOT
fi
