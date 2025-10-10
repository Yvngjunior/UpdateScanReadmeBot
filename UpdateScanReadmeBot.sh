#!/bin/bash
# find_scan_noreadme.sh — Neo-level smart README generator and repo scanner

set -euo pipefail

echo "[BOT] Scanning for git repos without README.md..." | lolcat
figlet -f slant "Scanning" | lolcat && sleep 2 && echo "-------------Processing...--------------------------------" | lolcat

missing_repos=()

# ---- SCAN PHASE ----
while IFS= read -r repo; do
    repo_dir=$(dirname "$repo")
    if [ ! -f "$repo_dir/README.md" ]; then
        echo "⚠️  Repo without README: $repo_dir"
        missing_repos+=("$repo_dir")
    fi
done < <(find "$HOME" -type d -name ".git")

echo "---------------------------------------------"
echo "[BOT] Scan completed." | lolcat
echo

if [ ${#missing_repos[@]} -eq 0 ]; then
    termux-notification \
        --title "Git Bot Alert" \
        --content "All repos have README.md ✅"
    echo "✅ All repositories have README.md files."
    exit 0
fi

# ---- TECH STACK DETECTION FUNCTION (smarter rules) ----
detect_tech_stack() {
    local path="$1"
    local tech=()

    [[ -f "$path/package.json" || $(find "$path" -name "*.js" -print -quit) ]] && tech+=("[Node.js][JavaScript]")
    [[ -f "$path/requirements.txt" || $(find "$path" -name "*.py" -print -quit) ]] && tech+=("[Python]")
    [[ -f "$path/index.html" || $(find "$path" -name "*.css" -o -name "*.js" -print -quit) ]] && tech+=("[HTML][CSS][JavaScript]")
    [[ -f "$path/composer.json" || $(find "$path" -name "*.php" -print -quit) ]] && tech+=("[PHP]")
    [[ $(find "$path" -name "*.java" -print -quit) || -f "$path/pom.xml" || -f "$path/build.gradle" ]] && tech+=("[Java]")
    [[ $(find "$path" -name "*.c" -o -name "*.h" -print -quit) ]] && tech+=("[C]")
    [[ $(find "$path" -name "*.cpp" -o -name "*.hpp" -print -quit) ]] && tech+=("[C++]")
    [[ -f "$path/main.go" ]] && tech+=("[Go]")
    [[ -f "$path/Cargo.toml" ]] && tech+=("[Rust]")
    [[ -f "$path/Dockerfile" ]] && tech+=("[Docker]")
    [[ -f "$path/Gemfile" ]] && tech+=("[Ruby]")
    [[ -f "$path/AndroidManifest.xml" ]] && tech+=("[Android]")
    [[ $(find "$path" -name "*.ipynb" -print -quit) ]] && tech+=("[Jupyter Notebook]")
    [[ $(find "$path" -name "*.sh" -print -quit) ]] && tech+=("[Bash]")
    [[ -f "$path/Makefile" ]] && tech+=("[C/Build Tools]")

    if [ ${#tech[@]} -eq 0 ]; then
        echo "[Unknown]"
    else
        echo "${tech[@]}"
    fi
}

# ---- CLEANER TABLE OUTPUT ----
echo "Detected repositories missing README.md:"
printf "%-5s %-50s %-30s\n" "No." "Repository" "Detected Tech" | lolcat
echo "------------------Processing...--------------------------------------------------------------------" | lolcat
index=1
declare -A tech_map
for repo in "${missing_repos[@]}"; do
    detected=$(detect_tech_stack "$repo")
    tech_map["$repo"]="$detected"
    printf "%-5s %-50s %-30s\n" "[$index]" "$repo" "$detected"
    ((index++))
done
echo "--------------------------------------------------------------------------------------"

# ---- SELECTION ----
echo
read -p "Enter the numbers of repos to generate README for (e.g., 1 3 5 or 'all'): " choice

selected_repos=()
if [[ "$choice" == "all" ]]; then
    selected_repos=("${missing_repos[@]}")
else
    for num in $choice; do
        ((num--))
        selected_repos+=("${missing_repos[$num]}")
    done
fi

# ---- OPTIONAL: Preview Selected Repos ----
echo
read -p "Would you like to preview the selected repos before generating READMEs? [y/N]: " preview_choice
if [[ "$preview_choice" =~ ^[Yy]$ ]]; then
    for repo in "${selected_repos[@]}"; do
        echo
        echo "📁 Switching to: $repo"
        cd "$repo" || { echo "⚠️ Failed to enter $repo"; continue; }
        echo "---------------------------------------------"
        echo "Contents of $(pwd):"
        ls --color=auto
        echo "---------------------------------------------"
        read -p "Press Enter to continue to the next repo..." _
        cd - >/dev/null || exit
    done
fi

# ---- README GENERATOR FUNCTION (your original + GitHub auto-detect) ----
generate_readme() {

# ---- User Input ----
read -p "Project Name: " TITLE
read -p "One-line Description: " DESC

# ---- Detect GitHub URL automatically ----
if [ -f ".git/config" ]; then
  AUTO_REPOURL=$(git config --get remote.origin.url | sed 's/^git@/https:\/\//' | sed 's/com:/com\//' | sed 's/\.git$/.git/')
else
  AUTO_REPOURL=""
fi
read -p "GitHub Repo URL (default: $AUTO_REPOURL): " REPOURL
REPOURL=${REPOURL:-$AUTO_REPOURL}

read -p "Features (comma separated): " FEATURES
read -p "Tech Stack (comma separated): " TECH
read -p "Preview image filename (leave blank if none): " PREVIEW
read -p "Local server command (default: python -m http.server 5500): " SERVERCMD
SERVERCMD=${SERVERCMD:-python -m http.server 5500}

# ---- Generate ASCII Banner ----
if command -v figlet >/dev/null 2>&1; then
  BANNER=$(figlet -f slant "$TITLE")
else
  BANNER="$TITLE"
fi

# ---- Convert repo URL to GitHub path ----
GITHUB_PATH=$(echo "$REPOURL" | sed -E 's#https?://github.com/([^/]+)/([^/]+)(.git)?#\1/\2#')

# ---- Generate README.md ----

exec < /dev/tty

cat > README.md <<EOF
\`\`\`
$BANNER
\`\`\`

$DESC

---

## Badges
[![License](https://img.shields.io/badge/license-MIT-blue.svg)]($REPOURL)
[![GitHub stars](https://img.shields.io/github/stars/${GITHUB_PATH}?style=flat)]($REPOURL)
[![Language](https://img.shields.io/github/languages/top/${GITHUB_PATH}?style=flat)]($REPOURL)
[![Last Commit](https://img.shields.io/github/last-commit/${GITHUB_PATH}?style=flat)]($REPOURL)

---

## Features
$(echo "${FEATURES}" | sed 's/,/\n- /g' | sed 's/^/- /')

---

## Preview
$(if [ -n "$PREVIEW" ]; then echo "![Preview]($PREVIEW)"; else echo "_Add a screenshot or GIF here (e.g., screenshot.png)_"; fi)

---

## Installation & Setup

\`\`\`bash
# Clone the repository
git clone $REPOURL

# Enter the folder
cd $(basename "$REPOURL" .git)

# List files
ls
\`\`\`

---

## Running locally

\`\`\`bash
$SERVERCMD
\`\`\`

Open your browser at http://localhost:5500 (or your chosen port)

---

## Usage

1. Open the app in your browser
2. Watch dynamic system logs
3. Observe progress bar animations
4. Enjoy the Neo-style terminal interface 😎

---

## Tech Stack
$(echo "$TECH" | sed 's/,/][/g' | sed 's/^/[/' | sed 's/$/]/')

---

## Contributing

1. Fork the repo
2. Create a branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m "Add feature"`)
4. Push and open a Pull Request

---

## License

This project is released under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## Terminal Neo-style Banner

Optional terminal preview if you have figlet and lolcat installed:

\`\`\`bash
figlet "$TITLE" | lolcat
\`\`\`

EOF

echo "✅ README.md generated! Open README.md to see your  masterpiece." | lolcat
}

# ---- PROCESS EACH SELECTED REPO ----
generated_count=0
for repo in "${selected_repos[@]}"; do
    echo
    echo "---------------------------------------------"
    echo "[BOT] Processing: $repo" | lolcat
    cd "$repo"

    detected_stack="${tech_map[$repo]}"
    echo "Detected Tech Stack: $detected_stack"

    # Ask user if detected stack should be confirmed or overridden
    if [[ "$detected_stack" == "[Unknown]" ]]; then
        read -p "Detected stack is unknown. Would you like to specify manually? [y/N]: " manual
        if [[ "$manual" =~ ^[Yy]$ ]]; then
            read -p "Enter tech stack (comma separated): " manual_stack
            detected_stack="$manual_stack"
        fi
    fi

    echo "Final Tech Stack: $detected_stack"
    echo

    read -p "Proceed to generate README.md for this repo? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        generate_readme
        ((generated_count++))
        termux-notification --title "Git Bot" --content "Generated README for $(basename "$repo") ✅"
    else
        echo "⏭️  Skipping $repo"
        termux-notification --title "Git Bot" --content "Skipped $(basename "$repo")"
    fi
    cd - >/dev/null
done

# ---- SUMMARY ----
if [ "$generated_count" -gt 0 ]; then
    termux-notification \
        --title "Git Bot Complete" \
        --content "$generated_count README.md files generated successfully ✅" \
        --priority high
else
    termux-notification \
        --title "Git Bot Complete" \
        --content "No READMEs generated."
fi

echo "---------------------------------------------"
echo "[BOT] Operation finished. $generated_count README.md file(s) generated." | lolcat
