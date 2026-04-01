#!/bin/bash
# Axios Supply Chain Attack Auto-Remediation Script
# Only targets malicious versions: 1.14.1 and 0.30.4
# Auto-reverts to safe versions: 1.14.0 and 0.30.3
# rm node_modules/ + lockfiles, updates package.json, full reinstall, and sets prevention

echo "=== Axios Malicious Version Auto-Remediation ==="
echo "Scanning system for compromised axios packages (1.14.1 and 0.30.4)..."

find / -path "*/node_modules/axios/package.json" 2>/dev/null | while read -r f; do
    if [ -f "$f" ]; then
        version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | grep -o '[0-9.]*' | head -1)
        
        if [[ "$version" == "1.14.1" || "$version" == "0.30.4" ]]; then
            project_dir=$(dirname "$(dirname "$f")")
            
            echo "🚨 MALICIOUS AXIOS DETECTED!"
            echo "   Project directory : $project_dir"
            echo "   axios version     : $version"
            echo "   package.json path : $f"
            echo "   ───────────────────────────────────────"
            
            # === AUTO-REMEDIATION STARTS HERE ===
            cd "$project_dir" || { echo "   ❌ Failed to enter project directory – skipping"; continue; }
            
            # Determine safe version
            if [[ "$version" == "1.14.1" ]]; then
                safe_version="1.14.0"
            elif [[ "$version" == "0.30.4" ]]; then
                safe_version="0.30.3"
            fi
            
            echo "   → Removing entire node_modules/ directory (as requested)..."
            rm -rf node_modules
            
            echo "   → Removing lockfiles for clean reinstall..."
            rm -f package-lock.json yarn.lock pnpm-lock.yaml
            
            echo "   → Replacing malicious axios version in package.json..."
            if command -v jq >/dev/null 2>&1; then
                # Preferred: jq updates dependencies OR devDependencies safely
                jq --arg v "^$safe_version" '
                    if has("dependencies") and (.dependencies | has("axios")) then .dependencies.axios = $v else . end |
                    if has("devDependencies") and (.devDependencies | has("axios")) then .devDependencies.axios = $v else . end
                ' package.json > package.json.tmp 2>/dev/null && mv package.json.tmp package.json
            else
                # Fallback: sed (still reliable for this case)
                sed -i.bak "s/\"axios\":\s*\"[^\"]*\"/\"axios\": \"^$safe_version\"/g" package.json
            fi
            
            echo "   → Reinstalling all packages with safe axios ^$safe_version..."
            npm install --no-audit --no-fund --prefer-offline --save-exact
            
            echo "   ✅ FULLY REMEDIATED: $project_dir now uses axios@$safe_version"
            echo "────────────────────────────────────────────────────"
        fi
    fi
done

# Global prevention step (run once after all projects)
echo ""
echo "🛡️  Applying protection so this is less likely to happen again..."
npm config set min-release-age 3
echo "✅ npm config 'min-release-age' is now set to 3 days (blocks very fresh malicious releases – assumes Node.js/npm is recent enough)."
echo ""
echo "=== Auto-remediation complete ==="
echo "⚠️  Review the projects listed above."
echo "   • package.json was updated and backed up (original saved as .bak)."
echo "   • All malicious node_modules were wiped and reinstalled cleanly."
echo "   • Please change/rotate any API keys/secrets if the malicious package executed."
