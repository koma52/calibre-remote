#!/bin/bash

# Declaring the folder and database paths
LOCAL_CALIBRE_DB="<path to the locally stored metadata.db>"
REMOTE_CALIBRE_DB="<path to the remotely stored metadata.db>"
REMOTE_CALIBRE_LIBRARY="<path to the remote library root folder>"

# Declaring Calibre-Web db reconnect URL (leave it to "NaN" if not used)
CALIBRE_WEB_URL="NaN"

# The function that will handle starting Calibre and copying the metadata.db after Calibre exits
start_calibre() {
    echo "Starting up Calibre..."
    
    # Calling Calibre with the set remote library
    calibre --with-library $CALIBRE_LIBRARY_DIRECTORY
    
    echo "Calibre exited!"
    
    # Checking if the user edited anything
    if ! cmp $LOCAL_CALIBRE_DB $REMOTE_CALIBRE_DB >/dev/null 2>&1; then
        # If the user edited anything copying the new metadata.db to the server automatically
        echo "Local database edited. Copying it to remote database..."
        cp -f $LOCAL_CALIBRE_DB $REMOTE_CALIBRE_DB
        echo "Copied!"
        if [[ $CALIBRE_WEB_URL = "NaN" ]]; then
            echo "Calibre-Web URL not defined. Proceeding without reconnecting Calibre-Web to database."
        else
            curl $CALIBRE_WEB_URL
            echo "Calibre-Web reconnected to database."
        fi
        read -n 1 -s -r -p "Press any key to exit..."
        exit
    else
        # If nothing was edited prompt the user if they want to copy metadata.db or not
        echo "You did not edit the the database, so it is not necessarry to overwrite remote db. Do you want to? (y/n)"
        read ANSWER
        if [[ $ANSWER = "y" ]]; then
            cp -f $LOCAL_CALIBRE_DB $REMOTE_CALIBRE_DB
            echo "Copied!"
            if [[ $CALIBRE_WEB_URL = "NaN" ]]; then
                echo "Calibre-Web URL not defined. Proceeding without reconnecting Calibre-Web to database."
            else
                curl $CALIBRE_WEB_URL
                echo "Calibre-Web reconnected to database."
            fi
            read -n 1 -s -r -p "Press any key to exit..."
            exit
            
        else
            echo "Database won't be copied!"
            read -n 1 -s -r -p "Press any key to exit..."
            exit
        fi
    fi
}

# Checking if the remote library is mounted
if [ -d $REMOTE_CALIBRE_LIBRARY ]; then
    CALIBRE_LIBRARY_DIRECTORY=$REMOTE_CALIBRE_LIBRARY
    echo "Remote library found: $CALIBRE_LIBRARY_DIRECTORY"
    
    # Checking if metadata.db is present on the local storage
    if [ -f $LOCAL_CALIBRE_DB ]; then
        
        # If local metadata.db exists check if the remote metadata.db was edited on the server
        if ! cmp $LOCAL_CALIBRE_DB $REMOTE_CALIBRE_DB >/dev/null 2>&1; then
            # If it was edited, prompting the user if they want to copy the remote one to the local storage
            echo "Remote and local databases are different. Do you want to overwrite local db? (y/n): "
            read ANSWER
            if [[ $ANSWER = "y" ]]; then
                cp -f $REMOTE_CALIBRE_DB $LOCAL_CALIBRE_DB
            else
                echo "Cannot start Calibre without an up-to-date database!"
                read -n 1 -s -r -p "Press any key to exit..."
                exit 1
            fi
        fi
        
        # Setting up the env variable for Calibre
        export CALIBRE_OVERRIDE_DATABASE_PATH=$LOCAL_CALIBRE_DB
        echo "Metadata db found: $CALIBRE_OVERRIDE_DATABASE_PATH"
        
        # Start Calibre with the correct remote Library path and local metadata.db path
        start_calibre
        
    else
        # If local metadata.db doesn't exists copy it from the server
        echo "Metadata db not found, trying to copy it from remote server..."
        if [ -f $REMOTE_CALIBRE_DB ]; then
            cp $REMOTE_CALIBRE_DB $LOCAL_CALIBRE_DB
            echo "Database copied succesfully\!"
            export CALIBRE_OVERRIDE_DATABASE_PATH=$LOCAL_CALIBRE_DB
            echo "Metadata db now exists: $CALIBRE_OVERRIDE_DATABASE_PATH"
            
            # Start Calibre with the correct remote Library path and local metadata.db path
            start_calibre
            
        else
            # If the remote metadata.db cannot be found exit the program
            echo "Cannot find database on remote server!"
            read -n 1 -s -r -p "Press any key to exit..."
            exit 1
        fi
    fi
    
else
    # If the remote library cannot be found exit the program
    echo "Remote library not found!"
    read -n 1 -s -r -p "Press any key to exit..."
    echo "Exiting..."
    exit 1
fi
