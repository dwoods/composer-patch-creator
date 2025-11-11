# PHP Composer Patch Creator

## 🛠 Overview

A robust and lightning-fast Bash utility script designed to simplify and accelerate the process of creating and managing vendor package patches for Composer-based PHP projects (such as Magento, Laravel, Symfony, Drupal, etc.).

**Now with full Drupal support!** Automatically detects and works with custom installer paths for Drupal modules, themes, libraries, and drush commands.

This is likely the quickest and most efficient way to generate Composer-compatible patches for vendor packages, saving developers significant time and effort.

## 🚀 Why Use This Script?

### Traditional Patch Creation Workflow
```bash
# Manually stage specific files
git add -f ./vendor/{vendor}/{package}/file1.php ./vendor/{vendor}/{package}/file2.php ...

# Perform required changes on files
# ... (manual editing)

# Create patch manually
git diff ./vendor/{vendor}/{package}/file1.php ./vendor/{vendor}/{package}/file2.php ... > patches/{patch-name}.patch

# Cleanup steps
git restore ./vendor/{vendor}/{package}/file1.php ./vendor/{vendor}/{package}/file2.php ...
git reset HEAD ./vendor/{vendor}/{package}/file1.php ./vendor/{vendor}/{package}/file2.php ...

# OR If you are using diff command
# cp ./vendor/{vendor}/{package}/file.php ./vendor/{vendor}/{package}/file.php.old
# {perform required changes on file.php}
# diff -u ./vendor/{vendor}/{package}/file.php.old ./vendor/{vendor}/{package}/file.php > patches/{patch-name}.patch
# rm ./vendor/{vendor}/{package}/file.php
# mv ./vendor/{vendor}/{package}/file.php.old ./vendor/{vendor}/{package}/file.php

# Manually update composer.json
"extra": {
    "patches": {
        "{vendor}/{package}": {
            "{patch-message}": "patches/{patch-name}.patch",
        },
    }
}
```

### With Composer Patch Creation Utility
```bash
# Single command to start patch creation
cpc {vendor}/{package} -n {patch-name}.patch -m {patch-message}

# Perform required changes in vendor repo files
# Press 'y' when done

# Automatic patch generation and composer.json update ✨
```

### 🌟 Key Benefits
- **Simplified Workflow**: Reduce multiple manual steps to a single command
- **Smart Path Detection**: Automatically detects package location from composer.json
    - Standard vendor directory
    - Drupal custom paths (modules, themes, libraries, drush commands)
    - Any custom installer paths defined in composer.json
- **Automatic File Management**:
    - Automatically stages files
    - Generates patch
    - Restores original files
    - Cleans up git staging
- **Composer.json Integration**:
    - Automatically updates patch configuration
    - Creates backup before modification
- **Interactive Process**:
    - Guides you through patch creation
    - Provides clear prompts and feedback
- **Error Handling**:
    - Checks dependencies
    - Validates input
    - Provides detailed error messages

## 📦 Prerequisites

### Required Tools
- `git`
- `composer`
- `jq`
- Standard Unix tools (`cp`, `mkdir`, `sed`, `date`)
- Composer Patches Plugin: `cweagans/composer-patches` / `vaimo/composer-patches`

### Supported Environments
- Linux
- macOS

## 🚀 Installation

1. Clone the script to your project:
```bash
curl -0 https://raw.githubusercontent.com/MagePsycho/composer-patch-creator/main/src/composer-patch-creator.sh -o cpc.sh
chmod +x cpc.sh
```

To make it system-wide command
```bash
sudo mv cpc.sh /usr/local/bin/cpc
```

2. Ensure all dependencies are installed

## 💡 Usage

### Basic Usage
```bash
./cpc.sh <vendor/package>
```

### Advanced Options
```bash
# Magento module example
./cpc.sh magento/module-url-rewrite -n TICKET-custom-patch.patch

# Drupal module example
./cpc.sh drupal/webform -n fix-validation.patch -m "Fixed webform validation issue"

# Drupal library example
./cpc.sh bower-asset/photoswipe -n photoswipe-caption-fix.patch

# Drush command example
./cpc.sh drush/drush -n drush-command-fix.patch

# Full example with all options
./cpc.sh magento/module-url-rewrite -n TICKET-123.patch -m "Resolved routing issue"
```

### Drupal-Specific Examples
The script automatically detects Drupal package locations based on your `composer.json`:

```bash
# Drupal contrib module (installed in web/modules/contrib/)
./cpc.sh drupal/admin_toolbar

# Drupal contrib theme (installed in web/themes/contrib/)
./cpc.sh drupal/olivero

# Drupal library (installed in web/libraries/)
./cpc.sh drupal-library/ckeditor5-anchor-drupal

# Drush commands (installed in drush/Commands/contrib/)
./cpc.sh drush-ops/behat-drush-endpoint
```

### Options
- `-h, --help`: Show help message
- `-n, --name`: Specify custom patch filename
- `-m, --message`: Add patch description

Once the script execution is complete, run the `composer install` [ or `composer patch apply` if using `vaimo/composer-patches` ] command to apply the patches.  
For more details, refer to the `Composer Configuration` section.

> [!CAUTION]
> Only edit the files **after you run the command**.  
> Changes made prior to running the command won't be detected.

### In Action (Screenshots)
![Composer Patch Creator - Help](https://github.com/MagePsycho/composer-patch-creator/raw/main/docs/composer-patch-creator-help.png "Composer Patch Creator - Help")
*Fig: help command*

![Composer Patch Creator - Creator](https://github.com/MagePsycho/composer-patch-creator/raw/main/docs/composer-patch-creator-in-action.png "Composer Patch Creator - Creator")
*Fig: patch command in action*

## 🔍 How It Works

1. Checks system dependencies
2. Detects package type from composer.json or package name patterns
3. Resolves package installation path using composer.json `extra.installer-paths`
4. Validates package existence at the resolved path
5. Stages package files using git
6. Prompts for file modifications
7. Creates patch file from git diff
8. Restores and unstages modified files
9. Updates `composer.json` with patch information

### Path Detection Logic
The script intelligently detects package locations by:
1. Reading the package type from the installed package's composer.json
2. Matching the type against `extra.installer-paths` in the root composer.json
3. Resolving the path pattern with the actual package name
4. Falling back to standard `vendor/` directory if no custom path is defined

## 📝 Composer Configuration

### Standard Projects
Ensure your `composer.json` has patch plugin configuration:

```json
{
    "require": {
        "cweagans/composer-patches": "^1.7"
    },
    "extra": {
        "patches": {}
    }
}
```

### Drupal Projects
For Drupal projects with custom installer paths, your `composer.json` should include:

```json
{
    "require": {
        "composer/installers": "^2.0",
        "cweagans/composer-patches": "^1.7"
    },
    "extra": {
        "installer-paths": {
            "web/core": ["type:drupal-core"],
            "web/libraries/{$name}": ["type:drupal-library"],
            "web/modules/contrib/{$name}": ["type:drupal-module"],
            "web/themes/contrib/{$name}": ["type:drupal-theme"],
            "drush/Commands/contrib/{$name}": ["type:drupal-drush"],
            "web/modules/custom/{$name}": ["type:drupal-custom-module"],
            "web/themes/custom/{$name}": ["type:drupal-custom-theme"]
        },
        "patches": {}
    }
}
```

The script will automatically detect and use these installer paths when creating patches.

## ⚠️ Best Practices

- Always review patches before applying
- Use descriptive patch names
- Keep patch files version-controlled
- Minimize patch scope and complexity

## 🐛 Troubleshooting

### Common Issues

**Package not found error:**
- Ensure the package is installed via composer
- Verify the package name is correct (use `composer show` to list packages)
- Check that composer.json has the correct `installer-paths` configuration for Drupal projects

**Path detection issues:**
- The script looks for the package's composer.json to determine its type
- For Drupal, ensure packages have the correct type in their composer.json (drupal-module, drupal-theme, etc.)
- Check that your root composer.json has `extra.installer-paths` properly configured

**General troubleshooting:**
- Ensure you're in a git repository
- Verify all dependencies are installed (git, jq, composer)
- Check file permissions
- Confirm `composer.json` is present in the current directory

## 📄 License
MIT License

## 👥 Contributing
Contributions welcome! Please open issues or submit pull requests.

## 🙌 Credit
Developed with ❤️ by Raj KB <magepsycho@gmail.com>
