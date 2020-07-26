#!/bin/bash
#  Name: chooseEFIBoot.sh
#  Date: 22.7.2020
VERSION="0.3"
#  Description:
#   Script for easy change the next boot in EFI 
#   and or lets you set the standad boot
#
#  Depenecies:
#   bash        must be installed in /bin/bash 
#   yad         must be installed for to use the gui it needs also to be in the path it is running with version 0.36.2 (GTK+ 3.24.21)
#   efibootmgr  must be installed i use the version 14 
#
#   configuration to set:
#   /etc/sudoers must contain and entry:<user> ALL = (root) NOPASSWD:/usr/sbin/efibootmgr
#               Where <user> is your login userid  
#
#   changed:
#       26.7.2020   VERSION=0.3 Remove zenity for gui and use now yad instead
#                   No more ksh required normal bash works now
#######################################################################################


# setup variables for global usage
# Setup for the windows sizes
WIDTH="800"
HEIGHT="500"

PRG="$0"
PRG=${PRG#*/}
PRG=${PRG%.sh}
PRGPATH="${0%/*}"
PRGPATH=${PRGPATH:="./"}

EFI="sudo /usr/sbin/efibootmgr"

IFS=" 
"
DEBUG="echo debug "
DEBUG=""


KDE_REBOOT="qdbus org.kde.ksmserver /KSMServer org.kde.KSMServerInterface.logout 1 1 1"
GNOME_REBOOT=""
REBOOT=""

case "$XDG_CURRENT_DESKTOP" in
    KDE) REBOOT=${KDE_REBOOT};;
    GNOME) RBOOT=${GNOME_REBOOT};;
esac


typeset -a filter
export filter

# ****************************************************************************************
# Start with functions
# ****************************************************************************************



function usage {
	cat <<EOF
Syntax: $0 [--filter|-f <entry filter>]...  [--help|-h] 

	--filter 	only display patterin the enties filter (can be used mutliple times)
	--kde-boot  calls
	--help		this output

Version : ${VERSION}
	
EOF
} ### end usage


function getEFIvalue {
    typeset key="$1"
    echo "$EFI_CACHE" | while read boot string
    do
        if [[ $boot == $key ]]
        then
            echo $string
            return 0
        fi
    done
    return 1
} ## end getEFIvalue


function calcBootOrder {
    newBootFirst="$1"
    BootOrder="$2"
    newBootOrder="$newBootFirst"    
    IFS=","
	for boot in $BootOrder
	do	
		IFS=" 
"
		if [[ $boot != $newBootFirst ]]
		then			
			newBootOrder="${newBootOrder},$boot"
		fi	
	done
        IFS=" 
"
	echo "${newBootOrder}"
} ## end calcBootOrder
    

# Gives return level 0 when no change has done 
# if change is done we return 10
function readAndSet {
    StandardBoot="$1"
    NextBoot="$2"
    BootOrder="$3"
    CHANGED=FALSE
    OIFS=${IFS}
    export IFS="|
"    
    while read NB SB NR TEXT rest
    do        
        # echo $NB $SB $NR $TEXT
        if [ "${NB}" = "TRUE" ]
        then
            if [ "${NR}" != "${NextBoot}" ]
            then
                echo "Next boot = $NR ${NextBoot} / $TEXT"
                (IFS=" "
                $DEBUG $EFI --bootnext $NR 1>&2
                )
                CHANGED="TRUE"
            fi                    
        fi
        if [ "${SB}" = "TRUE" ]
        then
            if [ "${NR}" != "${StandardBoot}" ]
            then
                echo "Default boot = ($NR) / $TEXT"
                echo "Boot order = ${BootOrder}"
                newBootOrder=$(calcBootOrder $NR "$BootOrder")
                echo "New Boot order = ${newBootOrder}"
                ( IFS=" "
                $DEBUG $EFI --bootorder $newBootOrder 1>&2
                )
                CHANGED="TRUE"
            fi
        fi
    done
    IFS=$OIFS
    [ ${CHANGED} == "TRUE" ] && return 10 || return 0
} # end readAndSet


function prepateEFIList {
    StandardBoot="$1"
    NextBoot="$2"    
    echo "$EFI_CACHE" | while read boot string    
    do
		if [[ $boot =~ Boot[0-9][0-9][0-9][0-9]* ]]
		then
            nr=${boot##Boot}
			nr=${nr%\*}
			SBOOT="FALSE"
			NBOOT="FALSE"
			if [[ $boot == "Boot${NextBoot}*" ]]
			then
				NBOOT="TRUE"
			fi
			if [[ $boot == "Boot${StandardBoot}*" ]]
			then
				SBOOT="TRUE"
			fi
			fiFound=false
			for actfilter in ${filter[*]}
			do 
                if [[ $fiFound == "false" ]]
                then
                    if [[ "$nr $string" == *"${actfilter}"* ]] || [[ "$actfilter" == "allenries" ]]
                    then
                        fiFound=true
                        echo $NBOOT
                        echo $SBOOT
                        echo $nr
                        echo $string
                    fi
                fi
            done
		fi
    done
} # end function


# Main Start getting values


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

printf "filter =  %s\n" ${filter[*]}


# cache the EFI Output
export EFI_CACHE="$(${EFI})"

CurrentBoot=$(getEFIvalue "BootCurrent:")
NextBoot=$(getEFIvalue "BootNext:")
BootOrder=$(getEFIvalue "BootOrder:")
StandardBoot=${BootOrder%%,*}

# pipe all commands together
prepateEFIList "${StandardBoot}" "${NextBoot}"  | 
yad --title "Next and Standard boot"  \
    --width=${WIDTH} --height=${HEIGHT} \
    --on-top --center \
    --window-icon="${PRGPATH}/EFIGuiScript.png" \
    --list  \
    --columns=4 \
    --column="Next boot":RD \
    --column="Default boot":RD \
    --column="Boot Num" \
    --column="Name" \
    --print-all | 
readAndSet "${StandardBoot}" "${NextBoot}" "${BootOrder}"

# we get a reurncode of 10 if we did change somthing
if [ ${?} = "10" ]
then
     $REBOOT
else 
    echo "Not changed"
fi
