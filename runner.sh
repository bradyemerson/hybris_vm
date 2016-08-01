#!/bin/bash
VERSION=0.0.6
TEMP_DIR="/tmp"
SOURCE_DIR=~/source
APP_DIR=~/app
INSTALLER_DIR=${APP_DIR}/installer
HYBRIS_DIR=${APP_DIR}/hybris
LAST_CHECK_FILE=~/.runner.update.check

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
    echo -e "${MENU}**${NUMBER} 3)${MENU} Change Configuration Recipe (load alternative store fronts)"
    echo -e "${MENU}**${NUMBER} 4)${MENU} Initialize hybris"
    echo -e "${MENU}**${NUMBER} 5)${MENU} Rebuild hybris (ant clean all)"
	echo -e "${MENU}**${NUMBER} 6)${MENU} Replace hybris from zip (reset hybris)"
    echo -e "${MENU}**${NUMBER} 7)${MENU} Tail console log"
    echo -e "${MENU}**${NUMBER} 8)${MENU} Self update this program"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Please enter a menu option and enter or ${RED_TEXT}enter to exit. ${NORMAL}"
    read opt
}

function error_message() {
    COLOR='\033[01;31m' # bold red
    RESET='\033[00;00m' # normal white
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${COLOR}${MESSAGE}${RESET}"
}

function pause(){
   read -p "$*"
}

function init_hybris() {
	error_message "Warning: Initialize will delete all your current data. Are you sure you want to continue? (y/n)"
	read option;
	if [[ $option = 'y' ]]; then
		cd ${HYBRIS_DIR}/bin/platform;
		. ./setantenv.sh
		ant initialize;
		if [ $? -eq 0 ]; then
			echo "Initialization successful. Press enter to continue."
			pause;
		else
			error_message "Initialization failed. Check the error messages above. Press enter to continue."
			pause;
		fi
	fi
}

function check_for_updates() {
	wget -O /tmp/runner.sh -q https://raw.githubusercontent.com/bradyemerson/hybris_vm/master/runner.sh
	if [ $? -eq 0 ]; then
		old_version=`grep -P '^VERSION=([\d\.]+)$' ~/runner.sh | grep -oP '([\d\.]+)$'`
		new_version=`grep -P '^VERSION=([\d\.]+)$' /tmp/runner.sh | grep -oP '([\d\.]+)$'`
		if [ $old_version != $new_version ]; then
			echo "Updating to new version: ${new_version}";
			rm ~/runner.sh;
			cp /tmp/runner.sh ~/runner.sh;
			chmod 775 ~/runner.sh;
			echo "New version applied. Please restart to complete upgrade. Press enter to exit.";
			pause;
			exit;
		elif [ $1 ]; then
			echo "You already have the latest version";
		fi
		rm /tmp/runner.sh;
		echo $(date +%s) > ${LAST_CHECK_FILE}
	else
		error_message "Error downloading latest version. Please check internet connection and try again later."
	fi
}

function change_recipe() {
	clear;
	echo "Available recipes:";
	for dir in `ls -D ${INSTALLER_DIR}/recipes`; do
		echo "$dir "
	done
	echo
	echo "Enter 'info' to see description of recipes. Enter the name of new recipe name or leave blank to cancel: ";
	read recipe;
	if [[ $recipe = 'info' ]]; then
		echo "Loading recipes...";
		${INSTALLER_DIR}/install.sh -l > ${TEMP_DIR}/recipes.out
		zenity --width=800 --height=600 --title "Available Recipes" --text-info --filename="${TEMP_DIR}/recipes.out" 2> /dev/null
		rm ${TEMP_DIR}/recipes.out
		change_recipe;
	elif [[ $recipe != "" ]]; then 
		${INSTALLER_DIR}/install.sh -r ${recipe} setup
		if [ $? -eq 0 ]; then
			cp ${SOURCE_DIR}/hybrislicence.jar ${HYBRIS_DIR}/config/licence;
			echo
			echo -e "Change recipe to ${recipe} was successful. Do you want to initialize to load new sample data? (y/n)";
			read choice;
			if [[ $choice = "y" ]]; then
				init_hybris;
			fi
		else
			echo
			error_message "Build failed. Check the error messages above. Press enter to continue."
			pause;
		fi
	fi
	clear;
}

# Check for Updates if more than 7 days
if [ ! -f ${LAST_CHECK_FILE} ]; then
	# no last check
	check_for_updates;
else
	old_timestamp=`cat ${LAST_CHECK_FILE} `;
	new_timestamp=$(date +%s)
	if [ $((${new_timestamp} - ${old_timestamp} > 604800)) ]; then
		check_for_updates;
	fi
fi

clear
echo "*********************************************"
echo "***          Version: ${VERSION}"
echo "*********************************************"

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
			echo
		    echo "hybris server has started, but it will take a couple more minutes before you can access it in the web browser."
			echo "Checking if hybris is available..."
			wget_output=$(wget --spider --tries 3 --no-check-certificate https://localhost:9002/  2>&1)
			wget_exit_code=$?
			echo
			
			if [ $wget_exit_code -ne 0 ]; then
				error_message "The server has not responded. There may have been an issue during startup. Use option 7 to check the logs.";
				pause;
			else
				echo "hybris is ready! Press enter to continue."
				pause
			fi
		else
			error_message "Could not start hybris server. Is it already running?"
			pause;
		fi
		clear
		show_menu
    ;;

    2) clear;
		cd ${HYBRIS_DIR}/bin/platform;
		./hybrisserver.sh stop;
		echo "Press enter to continue"
		pause;
		clear;
	    show_menu;
    ;;

    3) clear;
		change_recipe;
		show_menu;
     ;;

    4) clear;
		init_hybris;
		clear;
		show_menu;
  	;;

	5) clear;
		cd ${HYBRIS_DIR}/bin/platform;
		. ./setantenv.sh
		ant clean all;
		if [ $? -eq 0 ]; then
			echo "Build successful. Press enter to continue."
			pause;
		else
			error_message "Build failed. Check the error messages above. Press enter to continue."
			pause;
		fi
		clear;
		show_menu;
	;;

	6) clear;
		if [ -e "${SOURCE_DIR}/hybris.tar.lzma" ] ; then
			error_message "Warning: This will clear and rebuild hybris from zip. Are you sure you want to continue? (y/n)"
			read option;
			if [[ $option = 'y' ]]; then
				echo "Clearing previous instillation"
				rm -rf ${APP_DIR}/*;
				cd ${APP_DIR};
				echo "Starting unzip";
				tar --lzma -xvf ${SOURCE_DIR}/hybris.tar.lzma 1>/dev/null
				echo "Unzip Complete. Check above for error messages. Press enter to continue."
				pause;
				change_recipe;
			fi
		else
			error_message "Operation Unavailable. Please upgrade to latest VM."
			pause;
		fi
		
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
		echo "Checking for latest version"
		check_for_updates true;
		show_menu;
	;;

	x)exit;
	;;

	\n)exit;
	;;

	*)clear;
        echo "Pick an option from the menu";
        show_menu;
	;;
esac
fi
done