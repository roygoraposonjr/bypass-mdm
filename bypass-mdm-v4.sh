#!/bin/bash

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Error handling function
error_exit() {
	echo -e "${RED}ERROR: $1${NC}" >&2
	exit 1
}

# Warning function
warn() {
	echo -e "${YEL}WARNING: $1${NC}"
}

# Success function
success() {
	echo -e "${GRN}✓ $1${NC}"
}

# Info function
info() {
	echo -e "${BLU}ℹ $1${NC}"
}

# Validation function for username
validate_username() {
	local username="$1"

	if [ -z "$username" ]; then
		echo "Username cannot be empty"
		return 1
	fi

	if [ ${#username} -gt 31 ]; then
		echo "Username too long (max 31 characters)"
		return 1
	fi

	if ! [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
		echo "Username can only contain letters, numbers, underscore, and hyphen"
		return 1
	fi

	if ! [[ "$username" =~ ^[a-zA-Z_] ]]; then
		echo "Username must start with a letter or underscore"
		return 1
	fi

	return 0
}

# Validation function for password
validate_password() {
	local password="$1"

	if [ -z "$password" ]; then
		echo "Password cannot be empty"
		return 1
	fi

	if [ ${#password} -lt 4 ]; then
		echo "Password too short (minimum 4 characters recommended)"
		return 1
	fi

	return 0
}

# Check if user already exists
check_user_exists() {
	local dscl_path="$1"
	local username="$2"

	if dscl -f "$dscl_path" localhost -read "/Local/Default/Users/$username" 2>/dev/null; then
		return 0 # User exists
	else
		return 1 # User doesn't exist
	fi
}

# Find available UID
find_available_uid() {
	local dscl_path="$1"
	local uid=501

	while [ $uid -lt 600 ]; do
		if ! dscl -f "$dscl_path" localhost -search /Local/Default/Users UniqueID $uid 2>/dev/null | grep -q "UniqueID"; then
			echo $uid
			return 0
		fi
		uid=$((uid + 1))
	done

	echo "501" # Default fallback
	return 1
}

# ─────────────────────────────────────────────────────────────
# detect_all_installations()
#
# Uses `diskutil apfs list` to enumerate every APFS container
# and pair System volumes with their Data volumes by role.
# Falls back to /Volumes/ name-scanning for non-APFS setups.
# Prints one record per installation to stdout:
#
#   SYSTEM_VOL_NAME|DATA_VOL_NAME|DISK_ID
#
# DISK_ID is the diskutil identifier of the *data* volume.
# ─────────────────────────────────────────────────────────────
detect_all_installations() {
	local -a found=()

	info "Scanning APFS containers for macOS installations..." >&2

	# ── Parse every APFS container with diskutil apfs list ───────────
	# This reliably finds volumes by role regardless of their display name.
	local current_sys_disk="" current_sys_name=""
	local current_data_disk="" current_data_name=""

	# We process the output line by line, tracking System+Data pairs
	# within the same APFS container.
	while IFS= read -r line; do
		# Detect a new APFS Container boundary – flush any pending pair
		if [[ "$line" =~ "APFS Container" ]]; then
			# Flush previous container's pair if complete
			if [ -n "$current_sys_name" ] && [ -n "$current_data_name" ]; then
				# Ensure data volume is mounted
				if [ ! -d "/Volumes/$current_data_name" ]; then
					info "  Mounting data volume '$current_data_name' ($current_data_disk)..." >&2
					diskutil mount "$current_data_disk" >/dev/null 2>&1
				fi
				# Verify dslocal exists after mount
				if [ -d "/Volumes/$current_data_name/private/var/db/dslocal/nodes/Default" ]; then
					local disk_id
					disk_id=$(diskutil info "$current_data_disk" 2>/dev/null \
						| awk '/Device Identifier/ { print $NF }')
					[ -z "$disk_id" ] && disk_id="$current_data_disk"
					found+=("${current_sys_name}|${current_data_name}|${disk_id}")
					info "  Found: system='$current_sys_name'  data='$current_data_name'  disk='$disk_id'" >&2
				fi
			fi
			current_sys_disk=""; current_sys_name=""
			current_data_disk=""; current_data_name=""
			continue
		fi

		# Match: "  Volume disk3s2 Macintosh HD (No specific role)"
		# or     "  Volume disk3s2 Macintosh HD (Role: System)"
		local vol_disk vol_name vol_role
		if [[ "$line" =~ ^[[:space:]]+Volume[[:space:]]+(disk[0-9]+s[0-9]+)[[:space:]]+(.+)[[:space:]]+\((.*)\) ]]; then
			vol_disk="${BASH_REMATCH[1]}"
			vol_name="${BASH_REMATCH[2]// /}"
			# Re-extract the name properly (everything between disk id and the final parens)
			vol_name=$(echo "$line" | sed 's/.*Volume[[:space:]]\+disk[0-9]*s[0-9]*[[:space:]]\+//; s/[[:space:]]\+([^)]*)[[:space:]]*$//')
			vol_role="${BASH_REMATCH[3]}"

			if [[ "$vol_role" =~ System ]] || [[ "$vol_role" =~ "No specific role" ]]; then
				# Confirm it's a system volume by checking for /System on mount
				if [ -d "/Volumes/$vol_name/System" ]; then
					current_sys_disk="$vol_disk"
					current_sys_name="$vol_name"
				fi
			elif [[ "$vol_role" =~ Data ]]; then
				current_data_disk="$vol_disk"
				current_data_name="$vol_name"
			fi
		fi
	done < <(diskutil apfs list 2>/dev/null)

	# Flush the last container's pair
	if [ -n "$current_sys_name" ] && [ -n "$current_data_name" ]; then
		if [ ! -d "/Volumes/$current_data_name" ]; then
			info "  Mounting data volume '$current_data_name' ($current_data_disk)..." >&2
			diskutil mount "$current_data_disk" >/dev/null 2>&1
		fi
		if [ -d "/Volumes/$current_data_name/private/var/db/dslocal/nodes/Default" ]; then
			local disk_id
			disk_id=$(diskutil info "$current_data_disk" 2>/dev/null \
				| awk '/Device Identifier/ { print $NF }')
			[ -z "$disk_id" ] && disk_id="$current_data_disk"
			found+=("${current_sys_name}|${current_data_name}|${disk_id}")
			info "  Found: system='$current_sys_name'  data='$current_data_name'  disk='$disk_id'" >&2
		fi
	fi

	# ── Fallback: /Volumes/ name-based scan if APFS detection found nothing ──
	if [ ${#found[@]} -eq 0 ]; then
		info "  APFS scan found nothing, falling back to /Volumes/ scan..." >&2
		for vol_path in /Volumes/*/; do
			[ -d "$vol_path" ] || continue
			local vol_name
			vol_name=$(basename "$vol_path")
			[[ "$vol_name" =~ ^\. ]]       && continue
			[[ "$vol_name" =~ Recovery ]]  && continue
			[[ "$vol_name" =~ ^VM$ ]]      && continue
			[[ "$vol_name" =~ ^Preboot$ ]] && continue
			[ -d "$vol_path/System" ] || continue

			local data_vol="" candidate
			for candidate in \
				"/Volumes/${vol_name} - Data" \
				"/Volumes/${vol_name} Data" \
				"/Volumes/${vol_name}Data" \
				"/Volumes/Data"; do
				[ -d "$candidate" ] || continue
				if [ -d "$candidate/private/var/db/dslocal/nodes/Default" ]; then
					data_vol=$(basename "$candidate")
					break
				fi
			done
			[ -z "$data_vol" ] && continue

			local disk_id
			disk_id=$(diskutil info "/Volumes/$data_vol" 2>/dev/null \
				| awk '/Device Identifier/ { print $NF }')
			[ -z "$disk_id" ] && disk_id="unknown"
			found+=("${vol_name}|${data_vol}|${disk_id}")
			info "  Found: system='$vol_name'  data='$data_vol'  disk='$disk_id'" >&2
		done
	fi

	if [ ${#found[@]} -eq 0 ]; then
		# Signal failure via sentinel (error_exit would only kill the subshell)
		echo -e "${RED}ERROR: No macOS installation found.${NC}" >&2
		echo -e "${RED}Make sure you are in Recovery mode with volumes mounted.${NC}" >&2
		echo "__NO_INSTALL__"
		return 1
	fi

	printf '%s\n' "${found[@]}"
}

# ─────────────────────────────────────────────────────────────
# select_installation()
#
# Accepts an array of "sys|data|disk" records.
# Single installation  → auto-select (no prompt).
# Multiple installations → numbered menu so the user picks one.
# Sets globals: system_volume  data_volume
# ─────────────────────────────────────────────────────────────
select_installation() {
	local installs=("$@")
	local count=${#installs[@]}

	if [ "$count" -eq 1 ]; then
		IFS='|' read -r system_volume data_volume disk_id <<< "${installs[0]}"
		info "Single installation detected – auto-selected." >&2
		return
	fi

	echo "" >&2
	echo -e "${YEL}╔══════════════════════════════════════════════════════╗${NC}" >&2
	echo -e "${YEL}║  Multiple macOS installations detected               ║${NC}" >&2
	echo -e "${YEL}║  Please choose the one you want to bypass MDM on:    ║${NC}" >&2
	echo -e "${YEL}╚══════════════════════════════════════════════════════╝${NC}" >&2
	echo "" >&2

	local i=1
	for entry in "${installs[@]}"; do
		IFS='|' read -r sv dv di <<< "$entry"
		printf "  ${CYAN}[%d]${NC}  System Volume : ${GRN}%s${NC}\n" "$i" "$sv" >&2
		printf "       Data Volume   : ${GRN}%s${NC}\n" "$dv" >&2
		printf "       Disk ID       : ${PUR}%s${NC}\n\n" "$di" >&2
		i=$((i + 1))
	done

	local choice
	while true; do
		read -rp "Enter the number of the installation to target [1-${count}]: " choice </dev/tty
		if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
			break
		fi
		warn "Invalid choice. Please enter a number between 1 and ${count}." >&2
	done

	IFS='|' read -r system_volume data_volume disk_id <<< "${installs[$((choice - 1))]}"
}

# ─── Detect all installations and let the user pick ──────────
mapfile -t all_installs < <(detect_all_installations)

# Guard: the function runs in a subshell – error_exit/exit there
# cannot terminate the parent.  Check for empty result or sentinel.
if [ ${#all_installs[@]} -eq 0 ] || [ "${all_installs[0]}" = "__NO_INSTALL__" ]; then
	echo -e "${RED}ERROR: No macOS installation found.${NC}" >&2
	echo -e "${RED}Make sure you are in Recovery mode with at least one macOS volume mounted.${NC}" >&2
	exit 1
fi

select_installation "${all_installs[@]}"

# Display header
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Bypass MDM By Assaf Dori (assafdori.com)   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
success "System Volume : $system_volume"
success "Data Volume   : $data_volume"
echo ""

# Main menu
PS3='Please enter your choice: '
options=("Bypass MDM from Recovery" "Reboot & Exit")
select opt in "${options[@]}"; do
	case $opt in
	"Bypass MDM from Recovery")
		echo ""
		echo -e "${YEL}═══════════════════════════════════════${NC}"
		echo -e "${YEL}  Starting MDM Bypass Process${NC}"
		echo -e "${YEL}═══════════════════════════════════════${NC}"
		echo ""

		# Validate critical paths
		info "Validating system paths..."

		system_path="/Volumes/$system_volume"
		data_path="/Volumes/$data_volume"

		if [ ! -d "$system_path" ]; then
			error_exit "System volume path does not exist: $system_path"
		fi

		if [ ! -d "$data_path" ]; then
			error_exit "Data volume path does not exist: $data_path"
		fi

		dscl_path="$data_path/private/var/db/dslocal/nodes/Default"
		if [ ! -d "$dscl_path" ]; then
			error_exit "Directory Services path does not exist: $dscl_path"
		fi

		success "All system paths validated"
		echo ""

		# Create Temporary User
		echo -e "${CYAN}Creating Temporary Admin User${NC}"
		echo -e "${NC}Press Enter to use defaults (recommended)${NC}"

		# Get and validate real name
		read -p "Enter Temporary Fullname (Default is 'Apple'): " realName
		realName="${realName:=Apple}"

		# Get and validate username
		while true; do
			read -p "Enter Temporary Username (Default is 'Apple'): " username
			username="${username:=Apple}"

			if validation_msg=$(validate_username "$username"); then
				break
			else
				warn "$validation_msg"
				echo -e "${YEL}Please try again or press Ctrl+C to exit${NC}"
			fi
		done

		# Check if user already exists
		if check_user_exists "$dscl_path" "$username"; then
			warn "User '$username' already exists in the system"
			read -p "Do you want to use a different username? (y/n): " response
			if [[ "$response" =~ ^[Yy]$ ]]; then
				while true; do
					read -p "Enter a different username: " username
					if [ -z "$username" ]; then
						warn "Username cannot be empty"
						continue
					fi
					if validation_msg=$(validate_username "$username"); then
						if ! check_user_exists "$dscl_path" "$username"; then
							break
						else
							warn "User '$username' also exists. Try another name."
						fi
					else
						warn "$validation_msg"
					fi
				done
			else
				warn "Continuing with existing user '$username' (may cause conflicts)"
			fi
		fi

		# Get and validate password
		while true; do
			read -p "Enter Temporary Password (Default is '1234'): " passw
			passw="${passw:=1234}"

			if validation_msg=$(validate_password "$passw"); then
				break
			else
				warn "$validation_msg"
				echo -e "${YEL}Please try again or press Ctrl+C to exit${NC}"
			fi
		done

		echo ""

		# Find available UID
		info "Checking for available UID..."
		available_uid=$(find_available_uid "$dscl_path")
		if [ $? -eq 0 ] && [ "$available_uid" != "501" ]; then
			info "UID 501 is in use, using UID $available_uid instead"
		else
			available_uid="501"
		fi
		success "Using UID: $available_uid"
		echo ""

		# Create user account
		info "Creating user account: $username"

		if ! dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" 2>/dev/null; then
			error_exit "Failed to create user account"
		fi

		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"      || warn "Failed to set user shell"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"      || warn "Failed to set real name"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "$available_uid" || warn "Failed to set UID"
		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"       || warn "Failed to set GID"

		user_home="$data_path/Users/$username"
		if [ ! -d "$user_home" ]; then
			if mkdir -p "$user_home" 2>/dev/null; then
				success "Created user home directory: $user_home"
			else
				error_exit "Failed to create user home directory: $user_home"
			fi
		else
			warn "User home directory already exists: $user_home"
		fi

		dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username" || warn "Failed to set home directory"

		if ! dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw" 2>/dev/null; then
			error_exit "Failed to set user password"
		fi

		if ! dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username" 2>/dev/null; then
			error_exit "Failed to add user to admin group"
		fi

		success "User account created successfully"
		echo ""

		# Block MDM domains
		info "Blocking MDM enrollment domains..."

		hosts_file="$system_path/etc/hosts"
		if [ ! -f "$hosts_file" ]; then
			warn "Hosts file does not exist, creating it"
			touch "$hosts_file" || error_exit "Failed to create hosts file"
		fi

		grep -q "deviceenrollment.apple.com" "$hosts_file" 2>/dev/null || echo "0.0.0.0 deviceenrollment.apple.com" >>"$hosts_file"
		grep -q "mdmenrollment.apple.com"    "$hosts_file" 2>/dev/null || echo "0.0.0.0 mdmenrollment.apple.com"    >>"$hosts_file"
		grep -q "iprofiles.apple.com"        "$hosts_file" 2>/dev/null || echo "0.0.0.0 iprofiles.apple.com"        >>"$hosts_file"

		success "MDM domains blocked in hosts file"
		echo ""

		# Configure MDM bypass settings
		info "Configuring MDM bypass settings..."

		config_path="$system_path/var/db/ConfigurationProfiles/Settings"

		if [ ! -d "$config_path" ]; then
			if mkdir -p "$config_path" 2>/dev/null; then
				success "Created configuration directory"
			else
				warn "Could not create configuration directory"
			fi
		fi

		touch "$data_path/private/var/db/.AppleSetupDone" 2>/dev/null \
			&& success "Marked setup as complete" \
			|| warn "Could not mark setup as complete"

		rm -rf "$config_path/.cloudConfigHasActivationRecord" 2>/dev/null \
			&& success "Removed activation record" \
			|| info "No activation record to remove"

		rm -rf "$config_path/.cloudConfigRecordFound" 2>/dev/null \
			&& success "Removed cloud config record" \
			|| info "No cloud config record to remove"

		touch "$config_path/.cloudConfigProfileInstalled" 2>/dev/null \
			&& success "Created profile installed marker" \
			|| warn "Could not create profile marker"

		touch "$config_path/.cloudConfigRecordNotFound" 2>/dev/null \
			&& success "Created record not found marker" \
			|| warn "Could not create not found marker"

		echo ""
		echo -e "${GRN}╔═══════════════════════════════════════════════╗${NC}"
		echo -e "${GRN}║       MDM Bypass Completed Successfully!     ║${NC}"
		echo -e "${GRN}╚═══════════════════════════════════════════════╝${NC}"
		echo ""
		echo -e "${CYAN}Next steps:${NC}"
		echo -e "  1. Close this terminal window"
		echo -e "  2. Reboot your Mac"
		echo -e "  3. Login with username: ${YEL}$username${NC} and password: ${YEL}$passw${NC}"
		echo ""
		break
		;;
	"Reboot & Exit")
		echo ""
		info "Rebooting system..."
		reboot
		break
		;;
	*)
		echo -e "${RED}Invalid option $REPLY${NC}"
		;;
	esac
done
