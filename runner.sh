#!/bin/bash
VERSION=1.0.4
TEMP_DIR="/tmp"
SOURCE_DIR=~/source
APP_DIR=~/app
INSTALLER_DIR=${APP_DIR}/installer
HYBRIS_DIR=${APP_DIR}/hybris
LAST_CHECK_FILE=~/.runner.update.check
RECIPE_FILE=~/.runner.recipe

# Check for Updates if more than 7 days
if [ ! -f ${LAST_CHECK_FILE} ]; then
	check_for_updates;
else
	old_timestamp=`cat ${LAST_CHECK_FILE} `;
	new_timestamp=$(date +%s)
	if [ $((${new_timestamp} - ${old_timestamp} > 604800)) ]; then
		check_for_updates;
	fi
fi

# Load current storefront recipe
current_recipe=Unknown
if [ -f ${RECIPE_FILE} ]; then
	current_recipe=`cat ${RECIPE_FILE}`
fi

function show_menu(){
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"` #Blue
    NUMBER=`echo "\033[33m"` #yellow
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[33m"`
    echo -e "${MENU}************************************************${NORMAL}"
	echo -e "${MENU}** Current Storefront Recipe: ${current_recipe}"
	echo -e "${MENU}************************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER} 1)${MENU} Start hybris server"
    echo -e "${MENU}**${NUMBER} 2)${MENU} Stop hybris server"
    echo -e "${MENU}**${NUMBER} 3)${MENU} Change Storefront Recipe (reload from zip)"
    echo -e ""
	echo -e "*********** Spartacus Storefront ****************"
	echo -e "${MENU}**${NUMBER} 4)${MENU} Start Spartacus (requires internet connection)"
	echo -e "${MENU}**${NUMBER} 5)${MENU} Stop Spartacus"
	echo -e ""
    echo -e "*********** Less Common Options ****************"
    echo -e "${MENU}**${NUMBER} 6)${MENU} Initialize hybris"
    echo -e "${MENU}**${NUMBER} 7)${MENU} Rebuild hybris (ant clean all)"
    echo -e "${MENU}**${NUMBER} 8)${MENU} Tail console log"
	echo -e "${MENU}**${NUMBER} 9)${MENU} Reinstall Spartacus (latest dev version)"
    echo -e "${MENU}**${NUMBER} 10)${MENU} Self update this program"
    echo -e "${MENU}************************************************${NORMAL}"
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
}

function init_hybris_with_warning() {
	error_message "Warning: Initialize will delete all your current data. Are you sure you want to continue? (y/n)"
	read option;
	if [[ $option = 'y' ]]; then
		init_hybris;
	fi
}

function check_for_updates() {
	wget -O /tmp/runner.sh -q --timeout=5 --tries=1 --no-check-certificate https://raw.githubusercontent.com/bradyemerson/hybris_vm/master/runner.sh
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
		if [ -e "${SOURCE_DIR}/hybrislicence.jar" ] ; then
			cp ${SOURCE_DIR}/hybrislicence.jar ${HYBRIS_DIR}/config/licence;
		fi
		if [ $? -eq 0 ]; then
			echo $recipe > ${RECIPE_FILE}
			current_recipe=$recipe
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

function load_spartacus() {
	if [ -d "${APP_DIR}/spartacus" ] ; then
		echo "Clearing previous Spartacus installation."
		rm -rf ${APP_DIR}/spartacus;
	fi
	git -c http.sslVerify=false clone https://github.com/SAP/cloud-commerce-spartacus-storefront.git ${APP_DIR}/spartacus;
	if [ $? -eq 0 ]; then
		init_spartacus;
	else
		error_message "Unable to download Spartacus. Are you connected to the internet?"
		pause;
	fi
}

function init_spartacus() {
	cd ${APP_DIR}/spartacus;
	yarn;
	if [ $? -eq 0 ]; then
		echo "Spartacus successful installed."
	else
		error_message "Could not install Spartacus dependencies. See error message above. Do you want to try again? (Y/n)"
		read option;
		if [[ $option = 'y' || $option = 'Y' || $option = '' ]]; then
			init_spartacus;
		fi
	fi
}

function start_spartacus() {
	pid=`pgrep "ng serve"`
	if [ $pid > 0 ] ; then
		echo "Looks like Spartacus is already running. Try accessing at http://localhost:4200/."
		echo "Press enter to continue."
		pause;
		return;
	fi
	if [ ! -d "${APP_DIR}/spartacus" ] ; then
		load_spartacus;
	fi
	cd ${APP_DIR}/spartacus;
	yarn run start &> /dev/null &
	if [ $? -eq 0 ]; then
		echo "Spartacus server is starting -- please wait approximently 90 seconds."
		echo "Checking if Spartacus is available..."
		sleep 90s
		wget_output=$(wget --spider --no-check-certificate http://localhost:4200/  2>&1)
		wget_exit_code=$?
		echo
		if [ $wget_exit_code -ne 0 ]; then
			error_message "The server has not responded. There may have been an issue during startup.";
			pause;
		else
			echo "Spartacus is ready! You can access it in the web browser at http://localhost:4200/. Press enter to continue."
			pause;
		fi
	else
		error_message "Could not start Spartacus server. See error message above."
		pause;
	fi
}

function stop_spartacus() {
	pid=`pgrep "ng serve"`
	if [ $pid > 0 ] ; then
		kill $pid;
		echo "Spartacus server stopped. Press enter to continue."
		pause;
	else
		echo "It doesn't look like the Spartacus server is running."
		echo "Press enter to continue."
		pause;
	fi
}

clear
echo "************************************************"
echo "***            Version: ${VERSION}                ***"
echo "************************************************"
echo

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
			wget_output=$(wget --spider --tries 4 --no-check-certificate https://localhost:9002/  2>&1)
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
		if [ -e "${SOURCE_DIR}/hybris.tar.lzma" ] ; then
			error_message "Warning: This will clear and rebuild hybris from zip. Are you sure you want to continue? (y/n)"
			read option;
			if [[ $option = 'y' ]]; then
				echo "Clearing previous installation"
				rm -rf ${APP_DIR}/hybris ${APP_DIR}/installer;
				cd ${APP_DIR};
				echo "Starting unzip";
				tar --lzma -xvf ${SOURCE_DIR}/hybris.tar.lzma 1>/dev/null
				if [ -e "${SOURCE_DIR}/custom.properties" ] ; then
					cp ${SOURCE_DIR}/custom.properties ${INSTALLER_DIR}/customconfig;
				fi
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
	
	4) clear;
		start_spartacus;
		clear;
		show_menu;
	;;
	
	5) clear;
		stop_spartacus;
		clear;
		show_menu;
	;;

	6) clear;
		init_hybris_with_warning;
		clear;
		show_menu;
	;;

	7) clear;
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

	8) clear;
		cd ${HYBRIS_DIR}/log/tomcat;
		file=`ls -t console* | head -n1`
		qterminal -e "tail --lines=200 -f ${file}"
		show_menu;
	;;
	
	9) clear;
		load_spartacus;
		clear;
		show_menu;
	;;

	10) clear;
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