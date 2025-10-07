#!/bin/bash
# UpdateScanReadmeBot.sh — Neo-level smart README generator and repo scanner (gum + flashy UI)

set -euo pipefail

# -------------------------
# Dependency checks
# -------------------------
REQUIRED=(gum figlet lolcat git)
MISSING=()
for cmd in "${REQUIRED[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING+=("$cmd")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "⚠️  Missing dependencies: ${MISSING[*]}"
  echo "Install them with: pkg install ${MISSING[*]}"
  exit 1
fi

# Termux notification check (optional)
if ! command -v termux-notification >/dev/null 2>&1; then
  echo "⚠️  termux-notification not found; notifications will be skipped."
  TERMUX_NOTIF_AVAILABLE=false
else
  TERMUX_NOTIF_AVAILABLE=true
fi

# Flashy banner
figlet -f slant "Neo Scan Bot" | lolcat
gum style --foreground 212 --border normal --padding "1" --align center "🔎 Scanning for git repos without README.md..." \
  || echo "[BOT] Scanning for git repos without README.md..."

# Option: auto mode flag (keep for compatibility)
AUTO_MODE=false
if [[ "${1:-}" == "--auto" || "${1:-}" == "-y" ]]; then
  AUTO_MODE=true
fi

# ---- SCAN PHASE ----
TMPFILE="/tmp/.scan_repos.$$"
mkdir -p /tmp || mkdir -p "$PREFIX/tmp"
[ -w /tmp ] || TMPFILE="$PREFIX/tmp/.scan_repos.$$"

gum spin --spinner line --title "Scanning $HOME for .git folders..." -- \
bash -c "
  while IFS= read -r -d '' gitdir; do
      repo_dir=\$(dirname \"\$gitdir\")
      if [ ! -f \"\$repo_dir/README.md\" ]; then
          printf '%s\0' \"\$repo_dir\"
      fi
  done < <(find \"$HOME\" -type d -name '.git' -print0)
" > \"$TMPFILE\" 2>/dev/null || true

# Load results
missing_repos=()
if [ -f \"$TMPFILE\" ]; then
  while IFS= read -r -d '' repo_path; do
    missing_repos+=(\"$repo_path\")
  done < \"$TMPFILE\"
  rm -f \"$TMPFILE\"
fi

if [ ${#missing_repos[@]} -eq 0 ]; then
  if $TERMUX_NOTIF_AVAILABLE; then
    termux-notification --title "Git Bot Alert" --content "All repos have README.md ✅"
  fi
  gum style --foreground 10 "✅ All repositories have README.md files."
  exit 0
fi

# ---- TECH STACK DETECTION FUNCTION (smarter rules) ----
detect_tech_stack() {
    local path="$1"
    local tech=()

    # Use -print -quit style to avoid heavy output; tests kept similar to original
    if [[ -f "$path/package.json" || $(find "$path" -name "*.js" -print -quit 2>/dev/null) ]]; then tech+=("[Node.js][JavaScript]"); fi
    if [[ -f "$path/requirements.txt" || $(find "$path" -name "*.py" -print -quit 2>/dev/null) ]]; then tech+=("[Python]"); fi
    if [[ -f "$path/index.html" || $(find "$path" -name "*.css" -o -name "*.js" -print -quit 2>/dev/null) ]]; then tech+=("[HTML][CSS][JavaScript]"); fi
    if [[ -f "$path/composer.json" || $(find "$path" -name "*.php" -print -quit 2>/dev/null) ]]; then tech+=("[PHP]"); fi
    if [[ $(find "$path" -name "*.java" -print -quit 2>/dev/null) || -f "$path/pom.xml" || -f "$path/build.gradle" ]]; then tech+=("[Java]"); fi
    if [[ $(find "$path" -name "*.c" -o -name "*.h" -print -quit 2>/dev/null) ]]; then tech+=("[C]"); fi
    if [[ $(find "$path" -name "*.cpp" -o -name "*.hpp" -print -quit 2>/dev/null) ]]; then tech+=("[C++]"); fi
    if [[ -f "$path/main.go" ]]; then tech+=("[Go]"); fi
    if [[ -f "$path/Cargo.toml" ]]; then tech+=("[Rust]"); fi
    if [[ -f "$path/Dockerfile" ]]; then tech+=("[Docker]"); fi
    if [[ -f "$path/Gemfile" ]]; then tech+=("[Ruby]"); fi
    if [[ -f "$path/AndroidManifest.xml" ]]; then tech+=("[Android]"); fi
    if [[ $(find "$path" -name "*.ipynb" -print -quit 2>/dev/null) ]]; then tech+=("[Jupyter Notebook]"); fi
    if [[ $(find "$path" -name "*.sh" -print -quit 2>/dev/null) ]]; then tech+=("[Bash]"); fi
    if [[ -f "$path/Makefile" ]]; then tech+=("[C/Build Tools]"); fi

    if [ ${#tech[@]} -eq 0 ]; then
        echo "[Unknown]"
    else
        # join with space
        printf "%s " "${tech[@]}"
    fi
}

# ---- CLEANER TABLE OUTPUT ----
gum style --foreground 159 --border double --padding "1" "Detected repositories missing README.md:"
printf "%-5s %-70s %-30s\n" "No." "Repository" "Detected Tech" | lolcat
echo "------------------Processing...--------------------------------------------------------------------" | lolcat
index=1
declare -A tech_map
for repo in "${missing_repos[@]}"; do
    detected=$(detect_tech_stack "$repo")
    tech_map["$repo"]="$detected"
    # Truncate repo display if too long
    display_repo="$repo"
    if [ ${#display_repo} -gt 65 ]; then
        display_repo="...${display_repo: -62}"
    fi
    printf "%-5s %-70s %-30s\n" "[$index]" "$display_repo" "$detected"
    ((index++))
done
echo "--------------------------------------------------------------------------------------"

# ---- SELECTION (gum choose) ----
gum style --foreground 220 --border normal --padding "1" "📁 Select repos to generate README for (space to select, enter to confirm)"
# Build human-readable items "N) /path (Tech)"
CHOICE_ITEMS=()
i=1
for repo in "${missing_repos[@]}"; do
  CHOICE_ITEMS+=("[$i] $repo — ${tech_map[$repo]}")
  ((i++))
done

# let user choose multiple; if none selected, exit
mapfile -t chosen_lines < <(gum choose --no-limit "${CHOICE_ITEMS[@]}")
if [ ${#chosen_lines[@]} -eq 0 ]; then
  gum style --foreground 166 "No repositories selected. Exiting."
  exit 0
fi

# translate chosen_lines back to repo paths
selected_repos=()
for line in "${chosen_lines[@]}"; do
  # line looks like "[N] /full/path — tech..."
  # extract the bracketed number
  if [[ "$line" =~ \[([0-9]+)\] ]]; then
    idx="${BASH_REMATCH[1]}"
    ((idx--))
    selected_repos+=("${missing_repos[$idx]}")
  fi
done

# ---- OPTIONAL: Preview Selected Repos (gum confirm + preview) ----
if gum confirm "Would you like to preview the selected repos before generating READMEs?"; then
    for repo in "${selected_repos[@]}"; do
        gum style --foreground 39 --border rounded --padding "1" "📁 Preview: $repo"
        if cd "$repo"; then
            echo "Contents of $(pwd):" | lolcat
            # Use ls -la for a better preview; handle if ls doesn't support --color
            if ls --color=auto >/dev/null 2>&1; then
              ls -la --color=auto
            else
              ls -la
            fi
            gum confirm "Continue to next repo?" || break
            cd - >/dev/null || true
        else
            gum style --foreground 160 "⚠️  Failed to enter $repo"
        fi
    done
fi

# ---- README GENERATOR FUNCTION (gum-powered prompts, preserves content) ----
generate_readme() {
    # interactive inputs replaced with gum inputs
    TITLE=$(gum input --prompt "🧩 Project Name:" --placeholder "Project title")
    DESC=$(gum input --prompt "📝 One-line Description:" --placeholder "Short summary")

    # Detect GitHub URL automatically (if in a git repo)
    AUTO_REPOURL=""
    if [ -f ".git/config" ]; then
      AUTO_REPOURL=$(git config --get remote.origin.url | sed 's/^git@/https:\/\//' | sed 's/com:/com\//' | sed 's/\.git$/.git/')
    fi
    REPOURL=$(gum input --prompt "🌐 GitHub Repo URL (leave blank to auto):" --value "$AUTO_REPOURL" --placeholder "$AUTO_REPOURL")
    REPOURL=${REPOURL:-$AUTO_REPOURL}

    FEATURES=$(gum input --prompt "✨ Features (comma separated):" --placeholder "feature1, feature2")
    TECH=$(gum input --prompt "🧠 Tech Stack (comma separated):" --placeholder "Python, Flask")

    PREVIEW=$(gum input --prompt "🖼️ Preview image filename (optional):" --placeholder "screenshot.png")
    SERVERCMD=$(gum input --prompt "🖥️ Local server command (default: python -m http.server 5500):" --value "python -m http.server 5500" --placeholder "python -m http.server 5500")
    SERVERCMD=${SERVERCMD:-python -m http.server 5500}

    # Generate ASCII Banner
    if command -v figlet >/dev/null 2>&1; then
      BANNER=$(figlet -f slant "$TITLE")
    else
      BANNER="$TITLE"
    fi

    # Convert repo URL to GitHub path
    GITHUB_PATH=$(echo "$REPOURL" | sed -E 's#https?://github.com/([^/]+)/([^/]+)(.git)?#\1/\2#')

    # Create README.md
    cat > README.md <<EOF
\`\`\`
$BANNER
\`\`\`

$DESC

---

## Badges
$(if [ -n "$REPOURL" ]; then
  cat <<BADGES
[![License](https://img.shields.io/badge/license-MIT-blue.svg)]($REPOURL)
[![GitHub stars](https://img.shields.io/github/stars/${GITHUB_PATH}?style=flat)]($REPOURL)
[![Language](https://img.shields.io/github/languages/top/${GITHUB_PATH}?style=flat)]($REPOURL)
[![Last Commit](https://img.shields.io/github/last-commit/${GITHUB_PATH}?style=flat)]($REPOURL)
BADGES
else
  echo "_Add your repo URL to enable dynamic badges._"
fi)

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
2. Create a branch (\`git checkout -b feature/my-feature\`)
3. Commit your changes (\`git commit -m "Add feature"\`)
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

    gum style --foreground 120 "✅ README.md generated! Open README.md to see your masterpiece."
}

# ---- PROCESS EACH SELECTED REPO ----
generated_count=0
for repo in "${selected_repos[@]}"; do
    gum spin --spinner line --title "Processing $repo ..." -- bash -c "sleep 0.2" >/dev/null 2>&1 || true
    gum style --foreground 51 --border normal --padding "1" "📂 Processing: $repo"
    # change directory into repo
    if ! cd "$repo"; then
        gum style --foreground 160 "⚠️  Failed to enter $repo. Skipping."
        continue
    fi

    detected_stack="${tech_map[$repo]}"
    gum style --foreground 159 "Detected Tech Stack: $detected_stack"

    # If unknown ask if user wants to manually specify (gum confirm + input)
    if [[ "$detected_stack" == "[Unknown]" ]]; then
        if gum confirm "Detected stack is unknown. Specify manually?"; then
            manual_stack=$(gum input --prompt "Enter tech stack (comma separated):" --placeholder "Python, Flask")
            detected_stack="$manual_stack"
        fi
    fi

    gum style --foreground 150 "Final Tech Stack: $detected_stack"

    if $AUTO_MODE; then
        do_generate=true
    else
        if gum confirm "🚀 Proceed to generate README.md for $(basename "$repo")?"; then
            do_generate=true
        else
            do_generate=false
        fi
    fi

    if [ "$do_generate" = true ]; then
        # run generator
        generate_readme
        ((generated_count++))
        if $TERMUX_NOTIF_AVAILABLE; then
            termux-notification --title "Git Bot" --content "Generated README for $(basename "$repo") ✅"
        fi

        # Ask about auto push
        if gum confirm "📤 Auto-commit and push README.md to remote?"; then
            if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                git add README.md
                # attempt commit; ignore if no changes
                if git commit -m "Add autogenerated README.md via Neo Bot" >/dev/null 2>&1; then
                    if git push >/dev/null 2>&1; then
                        gum style --foreground 120 "Pushed $(basename "$repo") to origin."
                        if $TERMUX_NOTIF_AVAILABLE; then
                          termux-notification --title "Git Bot" --content "Pushed $(basename "$repo") to remote 🚀"
                        fi
                    else
                        gum style --foreground 166 "⚠️  Commit created but push failed (check remote)."
                    fi
                else
                    gum style --foreground 214 "ℹ️  No changes to commit (README may be unchanged)."
                fi
            else
                gum style --foreground 166 "⚠️  Not a git repo or no remote configured."
            fi
        fi
    else
        gum style --foreground 244 "⏭️  Skipping $(basename "$repo")"
        if $TERMUX_NOTIF_AVAILABLE; then
            termux-notification --title "Git Bot" --content "Skipped $(basename "$repo")"
        fi
    fi

    # return to previous directory if possible
    cd - >/dev/null || true
done

# ---- SUMMARY ----
if [ "$generated_count" -gt 0 ]; then
    if $TERMUX_NOTIF_AVAILABLE; then
        termux-notification --title "Git Bot Complete" --content "$generated_count README.md files generated successfully ✅" --priority high
    fi
    gum style --foreground 120 --border double --padding "1" "🎉 Operation finished. $generated_count README.md file(s) generated."
else
    if $TERMUX_NOTIF_AVAILABLE; then
        termux-notification --title "Git Bot Complete" --content "No READMEs generated."
    fi
    gum style --foreground 244 --border normal --padding "1" "Operation finished. No README.md files were generated."
fi

# optional: save run log
LOGFILE="$HOME/.local/share/UpdateScanReadmeBot/history.log"
mkdir -p "$(dirname "$LOGFILE")"
echo "$(date '+%F %T') - Generated: $generated_count repo(s) - Selected: ${#selected_repos[@]}" >> "$LOGFILE"
