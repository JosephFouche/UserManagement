#!/bin/bash

# --- Global Configuration ---
# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo " Error: This script must be run as root (or with sudo)." >&2
    exit 1
fi

# Define the departments to process
DEPARTMENTS=("Engineering" "Sales" "IS")

# --- Function to Process Each Department ---
process_department() {
    local DEPT_NAME="$1"
    # Usernames are based on department and role (e.g., eng_admin, eng_user1)
    local ADMIN_USER="${DEPT_NAME:0:3}_admin"
    local USER1="${DEPT_NAME:0:3}_user1"
    local USER2="${DEPT_NAME:0:3}_user2"
    
    # Names are converted to lowercase for standard Linux user/group names
    local GROUP_NAME=$(echo "$DEPT_NAME" | tr '[:upper:]' '[:lower:]')
    local DEPT_DIR="/$DEPT_NAME"
    local CONF_FILE="$DEPT_DIR/confidential_document.txt"

    echo "--- Setting up $DEPT_NAME Department ---"

    # 1. Create Directory
    if mkdir -p "$DEPT_DIR"; then
        echo " Directory '$DEPT_DIR' created."
    else
        echo " Failed to create directory '$DEPT_DIR'." >&2
        return 1
    fi

    # 2. Create Group
    if getent group "$GROUP_NAME" > /dev/null; then
        echo " Group '$GROUP_NAME' already exists. Skipping creation."
    elif groupadd "$GROUP_NAME"; then
        echo " Group '$GROUP_NAME' created."
    else
        echo "Failed to create group '$GROUP_NAME'." >&2
        return 1
    fi

    # 3. Create Users (Admin and 2 Normal Users)
    echo "Creating users: $ADMIN_USER, $USER1, $USER2"
    for user in "$ADMIN_USER" "$USER1" "$USER2"; do
        # -m: Create home directory
        # -s /bin/bash: Set Bash shell
        # -g "$GROUP_NAME": Set department group as PRIMARY group
        if id "$user" &> /dev/null; then
            echo " User '$user' already exists. Skipping creation."
        elif useradd -m -s /bin/bash -g "$GROUP_NAME" "$user"; then
            echo "  -> User '$user' created with primary group '$GROUP_NAME'."
            # NOTE: For security, a separate process/script should handle initial password setting.
            # We set a placeholder password for functionality, but you should prompt interactively.
            echo "$user:TempPass123!" | chpasswd
        else
            echo " Failed to create user '$user'." >&2
        fi
    done

    # 4. Set Directory Ownership
    # Owner: Department Administrator (e.g., eng_admin)
    # Group: Department Group (e.g., engineering)
    if chown "$ADMIN_USER":"$GROUP_NAME" "$DEPT_DIR"; then
        echo " Ownership for '$DEPT_DIR' set to $ADMIN_USER:$GROUP_NAME."
    else
        echo " Failed to set ownership for '$DEPT_DIR'." >&2
    fi

    # 5. Set Directory Permissions (The most critical step)
    # Permissions required:
    # a. Owner (Admin) has full access (rwx).
    # b. Group (Normal Users) has full access (rwx).
    # c. Others have NO access (---).
    # d. Sticky Bit (t) is set to restrict file deletion to the file owner.

    # Permissions: 1770
    # 1: Sticky Bit (Ensures only file owner can delete files within the dir)
    # 7: Owner (Admin) = rwx (Full control)
    # 7: Group (Normal Users) = rwx (Full control)
    # 0: Others = --- (No access)
    
    local DIR_PERMS="1770"
    if chmod "$DIR_PERMS" "$DEPT_DIR"; then
        echo " Directory permissions set to $DIR_PERMS (u=rwx,g=rwx,o=---) with **Sticky Bit**."
        echo "   (This ensures department-only access and file deletion security.)"
    else
        echo " Failed to set permissions for '$DEPT_DIR'." >&2
    fi
    
    # 6. Create and Configure Confidential Document
    
    # Create the file with content
    echo "This file contains confidential information for the $DEPT_NAME department." > "$CONF_FILE"
    echo "Confidential document created at '$CONF_FILE'."

    # Set ownership on the file (same as directory)
    if chown "$ADMIN_USER":"$GROUP_NAME" "$CONF_FILE"; then
        echo " Ownership for '$CONF_FILE' set to $ADMIN_USER:$GROUP_NAME."
    fi

    # Set file permissions:
    # a. Owner (Admin) can read/write (rw-).
    # b. Group (Normal Users) can only read (r--).
    # c. Others have NO access (---).
    
    local FILE_PERMS="640" # rw- for owner (6), r-- for group (4), --- for others (0)
    if chmod "$FILE_PERMS" "$CONF_FILE"; then
        echo " File permissions set to $FILE_PERMS."
        echo "   (Admin can modify, department users can read, others have no access.)"
    else
        echo " Failed to set permissions for '$CONF_FILE'." >&2
    fi

    echo "--- $DEPT_NAME Setup Complete ---"
    echo ""
}

# --- Main Script Execution ---
echo "Starting Linux Department Setup..."
for dept in "${DEPARTMENTS[@]}"; do
    process_department "$dept"
done

echo " All department setups are complete."
