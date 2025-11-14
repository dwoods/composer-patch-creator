#!/usr/bin/env bash

################################################################################
# Configuration - EDIT
################################################################################
declare -r CONFIG_PATCHES_DIR="./patches"

################################################################################
# Strict Mode
################################################################################
set -euo pipefail
IFS=$'\n\t'

################################################################################
# Terminal colors
################################################################################
declare -r COLOR_GREEN="\033[0;32m"
declare -r COLOR_RED="\033[0;31m"
declare -r COLOR_YELLOW="\033[1;33m"
declare -r COLOR_RESET="\033[0m"

################################################################################
# Utility Functions
################################################################################
declare -r CONFIG_COMPOSER_FILE="composer.json"
# Comprehensive error handling with more detailed tracing
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
error_handler() {
    local exit_code="$1"
    local line_number="$2"
    local command="$3"

    log_message "${COLOR_RED}" "❌ Error in script execution"
    log_message "${COLOR_RED}" "Exit Code: ${exit_code}"
    log_message "${COLOR_RED}" "Line Number: ${line_number}"
    log_message "${COLOR_RED}" "Command: ${command}"

    exit "${exit_code}"
}

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    echo -e "${level}${message}${COLOR_RESET}"

    # Optional: Log to file
    # echo "[${timestamp}] ${message}" >> "/path/to/log/file"
}

# Dependency check function
check_dependencies() {
    local dependencies=("git" "jq" "cp" "mkdir" "sed" "date")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        log_message "${COLOR_RED}" "Missing required dependencies:"
        printf '%s\n' "${missing_deps[@]}" | sed 's/^/  - /'
        error_exit "Please install the missing dependencies before running this script."
    fi

    # Check for git repository
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        error_exit "Script must be run inside a git repository."
    fi

    # Check for composer.json
    if [[ ! -f "$CONFIG_COMPOSER_FILE" ]]; then
        error_exit "composer.json not found in the current directory."
    fi
}

# Help function
show_help() {
    echo
    echo "Vendor Patch Creation Utility Script (v2.0.0)"
    echo
    echo "📋 Usage: $0 <vendor/package> [options]"
    echo
    echo "🛠️ Options:"
    echo "  -h, --help                  Show this help message"
    echo "  -n, --name <patch_name>     Specify a custom patch name"
    echo "  -m, --message <message>     Specify a patch description message"
    echo "  -r, --project-relative      Create patch with paths relative to project root (default: vendor-relative)"
    echo
    echo "📝 Description:"
    echo "  → Create a patch file for packages by identifying modified files."
    echo "  → Supports custom installer paths (e.g., Drupal projects)."
    echo "  → Automatically detects package location from composer.json installer-paths."
    echo "  → Add an entry for the patches in composer.json."
    echo "  → Patches should be applied via composer plugin: cweagans/composer-patches."
    echo
    echo "📂 Examples:"
    echo "  $0 magento/module-url-rewrite"
    echo "  $0 drupal/webform -n fix-validation.patch -m \"Fixed webform validation\""
    echo "  $0 bower-asset/photoswipe -n photoswipe-fix.patch"
    echo
    echo "🎯 Supported Paths:"
    echo "  → Standard vendor directory (vendor/vendor-name/package-name)"
    echo "  → Drupal modules (web/modules/contrib, web/modules/custom)"
    echo "  → Drupal themes (web/themes/contrib, web/themes/custom)"
    echo "  → Drupal libraries (web/libraries)"
    echo "  → Drush commands (drush/Commands/contrib)"
    echo "  → Any custom paths defined in composer.json extra.installer-paths"
    echo
    echo "💡 Pro Tip: Always review patches before applying to vendor code!"
    echo
    echo -e "\e[1;32m❤️ Built with ❤️ by:\e[0m \e[1;36mRaj KB\e[0m \e[90m<magepsycho@gmail.com>\e[0m"
    exit 1
}

# Error handling
error_exit() {
    log_message "${COLOR_RED}" "Error: $1"
    exit 1
}

# Get package type from composer.json
get_package_type() {
    local vendor_package="$1"
    local vendor
    vendor=$(echo "$vendor_package" | cut -d'/' -f1)
    local package
    package=$(echo "$vendor_package" | cut -d'/' -f2)

    # Check if package exists in any possible location and determine its type
    # First, try to find the package's composer.json to get the actual type
    local possible_paths=(
        "vendor/${vendor}/${package}"
        "web/modules/contrib/${package}"
        "web/modules/custom/${package}"
        "web/themes/contrib/${package}"
        "web/themes/custom/${package}"
        "web/profiles/contrib/${package}"
        "web/profiles/custom/${package}"
        "web/libraries/${package}"
        "web/core"
        "drush/Commands/contrib/${package}"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -f "${path}/composer.json" ]]; then
            local package_type
            package_type=$(jq -r '.type // "library"' "${path}/composer.json" 2>/dev/null || echo "library")
            echo "$package_type"
            return
        fi
    done

    # Fallback: infer type from package name patterns for Drupal
    local package_type
    package_type=$(jq -r --arg pkg "$vendor_package" '
        if .require[$pkg] != null or .["require-dev"][$pkg] != null then
            # Determine type based on package name patterns
            if ($pkg | startswith("drupal/core")) then "drupal-core"
            elif ($pkg | startswith("drupal-library/")) then "drupal-library"
            elif ($pkg | startswith("bower-asset/")) then "drupal-library"
            elif ($pkg | startswith("drupal/")) then
                if ($pkg | contains("theme")) then "drupal-theme"
                else "drupal-module" end
            elif ($pkg | startswith("drush/") or $pkg | contains("drush")) then "drupal-drush"
            else "library" end
        else
            "library"
        end
    ' "$CONFIG_COMPOSER_FILE" 2>/dev/null || echo "library")

    echo "$package_type"
}

# Get package installation path from composer.json installer-paths
get_package_path() {
    local vendor_package="$1"
    local package_type="$2"
    local vendor
    vendor=$(echo "$vendor_package" | cut -d'/' -f1)
    local package
    package=$(echo "$vendor_package" | cut -d'/' -f2)

    # First, check if installer-paths exist in composer.json
    local has_installer_paths
    has_installer_paths=$(jq -r '.extra["installer-paths"] // empty | if . then "true" else "false" end' "$CONFIG_COMPOSER_FILE" 2>/dev/null || echo "false")

    if [[ "$has_installer_paths" == "true" ]]; then
        # Get the path pattern from installer-paths based on package type
        local path_pattern
        path_pattern=$(jq -r --arg type "$package_type" '
            .extra["installer-paths"] // {} |
            to_entries[] |
            select(.value[] | contains("type:" + $type)) |
            .key
        ' "$CONFIG_COMPOSER_FILE" 2>/dev/null | head -n1)

        # If we found a path pattern, replace the {$name} placeholder
        if [[ -n "$path_pattern" ]]; then
            local resolved_path="${path_pattern//\{\$name\}/$package}"
            echo "$resolved_path"
            return
        fi
    fi

    # Default fallback to standard vendor directory
    echo "vendor/${vendor}/${package}"
}

# Validate input
validate_input() {
    if [[ $# -eq 0 ]]; then
        show_help
    fi

    local vendor_package="$1"
    local vendor
    vendor=$(echo "$vendor_package" | cut -d'/' -f1)
    local package
    package=$(echo "$vendor_package" | cut -d'/' -f2)

    # Detect package type and get the actual installation path
    local package_type
    package_type=$(get_package_type "$vendor_package")

    local package_path
    package_path=$(get_package_path "$vendor_package" "$package_type")

    if [[ ! -d "$package_path" ]]; then
        error_exit "Package not found at: $package_path (type: $package_type)"
    fi

    # Export the package path for use in other functions
    export RESOLVED_PACKAGE_PATH="$package_path"
}

# Detect modified files in the specified package path
get_modified_files() {
    local package_path="$1"
    git ls-files -m "$package_path"
}

# Update composer.json with new patch
update_composer_json() {
    local vendor="$1"
    local package="$2"
    local patch_file="$3"
    local patch_description="$4"

    # Create backup of composer.json
    cp "$CONFIG_COMPOSER_FILE" "${CONFIG_COMPOSER_FILE}.bak"

    # Update composer.json
    if [[ -z "$patch_description" ]]; then
        # If no patch message, just add the patch file directly
        jq --arg vendor "$vendor/$package" \
           --arg patch_file "$patch_file" \
           --indent 4 \
           '.extra.patches[$vendor] += [$patch_file]' \
           "$CONFIG_COMPOSER_FILE" > "${CONFIG_COMPOSER_FILE}.tmp" && \
        mv "${CONFIG_COMPOSER_FILE}.tmp" "$CONFIG_COMPOSER_FILE"
    else
        # If patch message exists, use key-value format
        jq --arg vendor "$vendor/$package" \
           --arg patch_file "$patch_file" \
           --arg patch_description "$patch_description" \
           --indent 4 \
           '.extra.patches[$vendor] += {($patch_description): $patch_file}' \
           "$CONFIG_COMPOSER_FILE" > "${CONFIG_COMPOSER_FILE}.tmp" && \
        mv "${CONFIG_COMPOSER_FILE}.tmp" "$CONFIG_COMPOSER_FILE"
    fi

    if [[ $? -eq 0 ]]; then
        log_message "${COLOR_GREEN}" "Updated composer.json with new patch"
    else
        log_message "${COLOR_RED}" "Failed to update composer.json"
        # Restore backup
        mv "${CONFIG_COMPOSER_FILE}.bak" "$CONFIG_COMPOSER_FILE"
        return 1
    fi
}

# Main patch creation function
create_vendor_patch() {
    local vendor_package="$1"
    local patch_name="${2:-}"
    local patch_description="${3:-}"
    local project_relative="${4:-false}"
    local vendor
    vendor=$(echo "$vendor_package" | cut -d'/' -f1)
    local package
    package=$(echo "$vendor_package" | cut -d'/' -f2)

    # Use the resolved package path from validate_input
    local package_path="$RESOLVED_PACKAGE_PATH"

    # Create patches directory
    mkdir -p "${CONFIG_PATCHES_DIR}"

    # Stage files
    log_message "${COLOR_GREEN}" "Staging package files for patch at: ${package_path}"
    git add -f "$package_path/"
    echo -e "✔ Done!"

    # Notify user
    log_message "${COLOR_GREEN}" "📝 Modify the required files for package: ${vendor_package} at ${package_path}"

    # User interaction
    #read -r -p "Once you have finished making the changes, press y to continue or a to abort" changes_complete
    echo -e "Once you have finished making the changes:\n- Press \033[1my\033[0m to continue.\n- Press \033[1ma\033[0m or any other key to abort."
    read -r -p "Your choice: " changes_complete

    # Find files in the package
    local files
    files=$(get_modified_files "$package_path")

    if [[ "$changes_complete" != "y" ]]; then
        log_message "${COLOR_RED}" "Patch creation aborted."
        exit 1
    fi

    if [[ -z "$files" ]]; then
        git restore "$package_path/"
        git reset HEAD "$package_path/" > /dev/null 2>&1
        error_exit "No modified files found in package: $vendor_package at $package_path"
    else
        log_message "${COLOR_GREEN}" "Modified files:"
        echo "$files"
    fi

    # Patch name handling
    if [[ -z "$patch_name" ]]; then
        read -r -p "Enter patch file name (default: patch_${vendor}_${package}_{date}.patch, press Enter to skip): " patch_name
        if [[ -z "$patch_name" ]]; then
            patch_name="patch_${vendor}_${package}_$(date +"%Y%m%d_%H%M%S").patch"
        fi
    fi

    # Patch message handling
    if [[ -z "$patch_description" ]]; then
        read -r -p "Enter patch description (optional, press Enter to skip): " patch_description
    fi

    local patch_path="${CONFIG_PATCHES_DIR}/${patch_name}"

    # Create patch
    log_message "${COLOR_GREEN}" "Creating patch file: ${patch_name}..."
    git diff "$package_path/" > "${patch_path}"

    # Convert to vendor-relative paths unless project-relative flag is set
    if [[ "$project_relative" != "true" ]]; then
        log_message "${COLOR_GREEN}" "Converting patch to vendor-relative paths..."
        # Strip the package path prefix from all file paths in the patch
        sed -i "s|a/${package_path}/|a/|g; s|b/${package_path}/|b/|g" "${patch_path}"
    fi

    echo -e "✔ Done!"

    log_message "${COLOR_GREEN}" "Restoring/Un-staging the modified files..."
    # restore the changes
    git restore "$package_path/"

    # Unstage files
    git reset HEAD "$package_path/" > /dev/null 2>&1
    echo -e "✔ Done!"

    # Update composer.json
    update_composer_json "$vendor" "$package" "patches/${patch_name}" "$patch_description"

    log_message "${COLOR_GREEN}" "✅ Patch created successfully: ${patch_path}"
}

# Script entry point
main() {
    local help_flag=0
    local patch_name=""
    local patch_description=""
    local vendor_package=""
    local project_relative="false"

    # Perform dependency checks
    check_dependencies

    # No arguments
    [[ $# -eq 0 ]] && show_help

    # Parse Arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -n|--name)
                patch_name="$2"
                shift 2
                ;;
            -m|--message)
                patch_description="$2"
                shift 2
                ;;
            -r|--project-relative)
                project_relative="true"
                shift
                ;;
            -n=*|--name=*)
                patch_name="${1#*=}"
                shift
                ;;
            -m=*|--message=*)
                patch_description="${1#*=}"
                shift
                ;;
            -*)
                log_message "${COLOR_RED}" "Unknown option: $1"
                show_help
                ;;
            *)
                if [[ -z "$vendor_package" ]]; then
                    vendor_package="$1"
                    shift
                else
                    log_message "${COLOR_RED}" "Too many arguments"
                    show_help
                fi
                ;;
        esac
    done

    # Validate vendor package is provided
    if [[ -z "$vendor_package" ]]; then
        echo "Error: Vendor package is required"
        show_help
    fi

    # Validate and create patch
    validate_input "$vendor_package"
    create_vendor_patch "$vendor_package" "$patch_name" "$patch_description" "$project_relative"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
