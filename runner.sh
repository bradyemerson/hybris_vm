#!/bin/bash
VERSION=1
TEMP_DIR="/tmp"
INSTALLER_DIR=~/app/installer
HYBRIS_DIR=~/app/hybris

function show_menu(){
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"` #Blue
    NUMBER=`echo "\033[33m"` #yellow
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[33m"`
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER} 1)${MENU} Start hybris server"
    echo -e "${MENU}**${NUMBER} 2)${MENU} Stop hybris server"
    echo -e "${MENU}**${NUMBER} 3)${MENU} List Configuration Recipes"
    echo -e "${MENU}**${NUMBER} 4)${MENU} Change Configuration Recipe"
    echo -e "${MENU}**${NUMBER} 5)${MENU} Initialize hybris"
    echo -e "${MENU}**${NUMBER} 6)${MENU} Rebuild hybris"
    echo -e "${MENU}**${NUMBER} 7)${MENU} Tail console log"
    echo -e "${MENU}**${NUMBER} 8)${MENU} Self update this program"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Please enter a menu option and enter or ${RED_TEXT}enter to exit. ${NORMAL}"
    read opt
}

function option_picked() {
    COLOR='\033[01;31m' # bold red
    RESET='\033[00;00m' # normal white
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${COLOR}${MESSAGE}${RESET}"
}

function pause(){
   read -p "$*"
}

clear
show_menu
while [ opt != '' ]
    do
    if [[ $opt = "" ]]; then 
            exit;
    else
        case $opt in
        1) clear;
		cd ${HYBRIS_DIR}/bin/platform;
		./hybrisserver.sh start;
		if [ $? -eq 0 ]; then
		    option_picked "hybris has started, but it may take a couple more minutes before you can access it in the web browser."
		fi
	        show_menu;
        ;;

        2) clear;
		cd ${HYBRIS_DIR}/bin/platform;
		./hybrisserver.sh stop;
	        show_menu;
            ;;

        3) clear;
		option_picked "Loading recipies...";
		${INSTALLER_DIR}/install.sh -l > ${TEMP_DIR}/recipies.out
		zenity --width=800 --height=600 --title "Available Recipies" --text-info --filename="${TEMP_DIR}/recipies.out" 2> /dev/null
		rm ${TEMP_DIR}/recipies.out
		clear;
		show_menu;
            ;;

        4) clear;
		option_picked "Enter the new recepie name: ";
		read recipie;
		${INSTALLER_DIR}/install.sh -r ${recipie} setup
		show_menu;
  	;;

	5) clear;
		cd ${HYBRIS_DIR}/bin/platform;
		. ./setantenv.sh
		ant initialize;
		option_picked "Initialization complete. You should see a success or error message above. Press enter to continue."
		pause;
		clear;
		show_menu;
	;;

	6) clear;
		cd ${HYBRIS_DIR}/bin/platform;
		. ./setantenv.sh
		ant clean all;
		option_picked "Build complete. You should see a success or error message above. Press enter to continue."
		pause;
		clear;
		show_menu;
	;;

	7) clear;
		cd ${HYBRIS_DIR}/log/tomcat;
		file=`ls -t console* | head -n1`
		lxterminal --geometry=120x35 -e "tail --lines=200 -f ${file}"
		show_menu;
	;;

	8) clear;
		#TODO
		show_menu;
	;;

	x)exit;
	;;

	\n)exit;
	;;

	*)clear;
        option_picked "Pick an option from the menu";
        show_menu;
	;;
esac
fi
done