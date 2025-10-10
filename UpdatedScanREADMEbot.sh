#!/data/data/com.termux/files/usr/bin/bash
# UpdateScanReadmeBot.sh — Neo-level smart README generator and repo scanner (Termux-stable)

# ---- CONFIG ----
set -euo pipefail
SCAN_DIR="${1:-$HOME}"  # Optional arg to limit scan scope

# ---- UTILS ----
safe_echo() {
    # Color fallback: if lolcat exists, use it
    if command -v lolcat >/dev/null 2>&1; then
        echo -e "$@" | lolcat
    else
        echo -e "$@"
    fi
}

notify() {
    # Notification fallback: only if termux-api installed
    if command -v termux-notification >/dev/null 2>&1; then
        termux-notification --title "$1" --content "$2" >/dev/null 2>&1 || true
    fi
}

banner() {
    if command -v figlet >/dev/null 2>&1; then
        figlet -f slant "$1" | (command -v lolcat >/dev/null 2>&1 && lolcat || cat)
    else
        echo "=== $1 ==="
    fi
}

# ---- SCAN PHASE ----
safe_echo "[BOT] Scanning for git repos without README.md..."
banner "Scanning"
sleep 1
safe_echo "-------------Processing--------------------------------"

missing_repos=()
while IFS= read -r repo; do
    repo_dir=$(dirname "$repo")
    if [ ! -f "$repo_dir/README.md" ]; then
        echo "⚠️  Repo without README: $repo_dir"
        missing_repos+=("$repo_dir")
    fi
done < <(find "$SCAN_DIR" -maxdepth 6 -type d -name ".git" 2>/dev/null)

safe_echo "---------------------------------------------"
safe_echo "[BOT] Scan completed."

if [ ${#missing_repos[@]} -eq 0 ]; then
    notify "Git Bot Alert" "All repos have README.md ✅"
    safe_echo "✅ All repositories have README.md files."
    exit 0
fi

# ---- TECH STACK DETECTION ----
detect_tech_stack() {
    local path="$1"
    local tech=()

    [[ -f "$path/package.json" || $(find "$path" -name "*.js" -print -quit 2>/dev/null) ]] && tech+=("[Node.js][JavaScript]")
    [[ -f "$path/requirements.txt" || $(find "$path" -name "*.py" -print -quit 2>/dev/null) ]] && tech+=("[Python]")
    [[ -f "$path/index.html" || $(find "$path" -name "*.css" -o -name "*.js" -print -quit 2>/dev/null) ]] && tech+=("[HTML][CSS][JavaScript]")
    [[ -f "$path/composer.json" || $(find "$path" -name "*.php" -print -quit 2>/dev/null) ]] && tech+=("[PHP]")
    [[ $(find "$path" -name "*.java" -print -quit 2>/dev/null) || -f "$path/pom.xml" || -f "$path/build.gradle" ]] && tech+=("[Java]")
    [[ $(find "$path" -name "*.c" -o -name "*.h" -print -quit 2>/dev/null) ]] && tech+=("[C]")
    [[ $(find "$path" -name "*.cpp" -o -name "*.hpp" -print -quit 2>/dev/null) ]] && tech+=("[C++]")
    [[ -f "$path/main.go" ]] && tech+=("[Go]")
    [[ -f "$path/Cargo.toml" ]] && tech+=("[Rust]")
    [[ -f "$path/Dockerfile" ]] && tech+=("[Docker]")
    [[ -f "$path/Gemfile" ]] && tech+=("[Ruby]")
    [[ -f "$path/AndroidManifest.xml" ]] && tech+=("[Android]")
    [[ $(find "$path" -name "*.ipynb" -print -quit 2>/dev/null) ]] && tech+=("[Jupyter Notebook]")
    [[ $(find "$path" -name "*.sh" -print -quit 2>/dev/null) ]] && tech+=("[Bash]")
    [[ -f "$path/Makefile" ]] && tech+=("[C/Build Tools]")

    if [ ${#tech[@]} -eq 0 ]; then
        echo "[Unknown]"
    else
        echo "${tech[@]}"
    fi
}

# ---- TABLE OUTPUT ----
safe_echo "Detected repositories missing README.md:"
printf "%-5s %-50s %-30s\n" "No." "Repository" "Detected Tech" | (command -v lolcat >/dev/null 2>&1 && lolcat || cat)
echo "------------------Processing...----------------------------------------------------" | (command -v lolcat >/dev/null 2>&1 && lolcat || cat)
index=1
declare -A tech_map
for repo in "${missing_repos[@]}"; do
    detected=$(detect_tech_stack "$repo")
    tech_map["$repo"]="$detected"
    printf "%-5s %-50s %-30s\n" "[$index]" "$repo" "$detected"
    ((index++))
done
safe_echo "--------------------------------------------------------------------------------------"

# ---- SELECTION ----
echo
read -rp "Enter the numbers of repos to generate README for (e.g., 1 3 5 or 'all'): " choice
selected_repos=()
if [[ "$choice" == "all" ]]; then
    selected_repos=("${missing_repos[@]}")
else
    for num in $choice; do
        ((num--))
        selected_repos+=("${missing_repos[$num]}")
    done
fi

# ---- OPTIONAL PREVIEW ----
echo
read -rp "Would you like to preview the selected repos before generating READMEs? [y/N]: " preview_choice
if [[ "$preview_choice" =~ ^[Yy]$ ]]; then
    for repo in "${selected_repos[@]}"; do
        echo
        safe_echo "📁 Switching to: $repo"
        cd "$repo" || { echo "⚠️ Failed to enter $repo"; continue; }
        echo "---------------------------------------------"
        echo "Contents of $(pwd):"
        ls --color=auto
        echo "---------------------------------------------"
        read -rp "Press Enter to continue to the next repo..." _
        cd - >/dev/null || exit
    done
fi

# ---- README GENERATOR ----
generate_readme() {
    read -rp "Project Name: " TITLE
    read -rp "One-line Description: " DESC



    if [ -f ".git/config" ]; then
        AUTO_REPOURL=$(git config --get remote.origin.url | sed 's/^git@/https:\/\//' | sed 's/com:/com\//' | sed 's/\.git$/.git/')
    else
        AUTO_REPOURL=""
    fi
    read -rp "GitHub Repo URL (default: $AUTO_REPOURL): " REPOURL
    REPOURL=${REPOURL:-$AUTO_REPOURL}

    read -rp "Features (comma separated): " FEATURES
    read -rp "Tech Stack (comma separated): " TECH
    read -rp "Preview image filename (leave blank if none): " PREVIEW
    read -rp "Local server command (default: python -m http.server 5500): " SERVERCMD
    SERVERCMD=${SERVERCMD:-python -m http.server 5500}

    if command -v figlet >/dev/null 2>&1; then
        BANNER=$(figlet -f slant "$TITLE")
    else
        BANNER="$TITLE"
    fi

    GITHUB_PATH=$(echo "$REPOURL" | sed -E 's#https?://github.com/([^/]+)/([^/]+)(.git)?#\1/\2#')

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
cd $(basename "$REPOURL" .git)
ls
\`\`\`

---

## Running locally

\`\`\`bash
$SERVERCMD
\`\`\`

Open your browser at http://localhost:5500

---

## Tech Stack
$(echo "$TECH" | sed 's/,/][/g' | sed 's/^/[/' | sed 's/$/]/')

---

## License
MIT License
EOF

    safe_echo "✅ README.md generated successfully!"
}

# ---- PROCESS SELECTED ----
generated_count=0
for repo in "${selected_repos[@]}"; do
    echo
    safe_echo "---------------------------------------------"
    safe_echo "[BOT] Processing: $repo"
    cd "$repo" || continue

    detected_stack="${tech_map[$repo]}"
    echo "Detected Tech Stack: $detected_stack"

    if [[ "$detected_stack" == "[Unknown]" ]]; then
        read -rp "Detected stack unknown. Enter manually? [y/N]: " manual
        if [[ "$manual" =~ ^[Yy]$ ]]; then
            read -rp "Enter tech stack (comma separated): " manual_stack
            detected_stack="$manual_stack"
        fi
    fi

    echo "Final Tech Stack: $detected_stack"
    echo
    read -rp "Generate README.md for this repo? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        generate_readme
        ((generated_count++))
        notify "Git Bot" "Generated README for $(basename "$repo") ✅"
    else
        safe_echo "⏭️  Skipped $repo"
        notify "Git Bot" "Skipped $(basename "$repo")"
    fi
    cd - >/dev/null || exit
done

# ---- SUMMARY ----
if [ "$generated_count" -gt 0 ]; then
    notify "Git Bot Complete" "$generated_count README.md files generated ✅"
else
    notify "Git Bot Complete" "No READMEs generated."
fi

safe_echo "---------------------------------------------"
safe_echo "[BOT] Operation finished. $generated_count README.md file(s) generated."
