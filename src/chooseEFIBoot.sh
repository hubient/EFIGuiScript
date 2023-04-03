#!/bin/bash
#  Name: chooseEFIBoot.sh
#  Date: 22.7.2020
VERSION="0.4"
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
#	27.7.2020   VESION=0.4 Add natianlisation plus de and de_CH as languages for the gui
#######################################################################################

######################################################################################
# start default nationalsation.
# set variable for natianalization where TR is used in the line.
# So simple add a G_TITLE__<language>
# <language> needs to be a LANG version supported but . and - replaced by _
# valid will be de_CH_UTF_8 or de_CH_UTF or de_CH or simple de
# but not de_CH.UTF-8 which will be the LANG setting.
#####################################################################################
G_TITLE__de="Nächter and Standard boot"
G_COL1_TITLE__de="Nächster boot"
G_COL2_TITLE__de="Normler boot"
G_COL3_TITLE__de="Boot Nummer"
G_COL4_TITLE__de="Name"
G_TITLE__de_CH="nöchter and standard boot"
G_COL1_TITLE__de_CH="nöchste Boot"
G_COL2_TITLE__de_CH="normle Boot"
G_COL3_TITLE__de_CH="Bootnummere"
G_COL4_TITLE__de_CH="Name"
######################################################################################
# start default nationalsation.
#####################################################################################
LANG=${LANG:=en_US.UTF-8}

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

# translate a text for multilingual setting
function TR {
	IFS=""
	KEY="$1"
	DEFAULT="$2"
	LANGTOUSE="${3}"
	LANGTOUSE="${LANGTOUSE:=${LANG}}"
	LANGTOUSE=${LANGTOUSE/./_}
	LANGTOUSE=${LANGTOUSE/-/_}
	LANGKEY="${KEY}${LANGTOUSE:+__}${LANGTOUSE}"
	VALUE=${!LANGKEY}
	if [ ! -z ${VALUE} ]
	then
		echo ${VALUE}
	else
		if [[ $LANGKEY == *__* ]]
		then
			LANGTOUSE_B=${LANGTOUSE}
			LANGTOUSE=${LANGTOUSE%_*}
			if [ ${LANGTOUSE_B} != ${LANGTOUSE} ] 
			then
				TR "$KEY" "$DEFAULT" "$LANGTOUSE"
			else
				echo ${DEFAULT}
			fi
		else
			echo ${DEFAULT}
		fi
	fi
} # end TR


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
                    if [[ "$nr $string" == *"${actfilter}"* ]] || [[ "$actfilter" == "allentries" ]]
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
	filter[0]="allentries"
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
yad --title "$(TR G_TITLE 'Next and Standard boot')"  \
    --width=${WIDTH} --height=${HEIGHT} \
    --on-top --center \
    --window-icon="${PRGPATH}/chooseEFIBoot.png" \
    --list  \
    --columns=4 \
    --column="$(TR G_COL1_TITLE 'Next boot')":RD \
    --column="$(TR G_COL2_TITLE 'Default boot')":RD \
    --column="$(TR G_COL3_TITLE 'Boot Num')" \
    --column="$(TR G_COL4_TITLE 'Name')" \
    --print-all | 
readAndSet "${StandardBoot}" "${NextBoot}" "${BootOrder}"

# we get a reurncode of 10 if we did change somthing
if [ ${?} = "10" ]
then
     $REBOOT
else 
    echo "Not changed"
fi
