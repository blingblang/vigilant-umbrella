#!/bin/bash

set -e

echo "Creating Migration Issues for All Repositories"
echo "=============================================="
echo ""

# List of repositories
REPOS=(
    "blingblang/vigilant-umbrella"
    "blingblang/psychic-tribble"
    "blingblang/atlas-fluvial"
    "blingblang/studious-engine"
    "blingblang/congenial-bassoon"
    "blingblang/solid-adventure"
    "blingblang/automatic-octo-tribble"
    "blingblang/joyfulagents"
    "blingblang/effective-garbanzo"
    "blingblang/super-spork"
    "blingblang/reimagined-telegram"
)

# Create the main issue body
ISSUE_BODY=$(cat migration-issue-template.md)

# Additional files content to attach as comments
MIGRATION_GUIDE=$(cat MIGRATION-GUIDE.md)
CONFIGURE_SCRIPT=$(cat configure-site-exporters.sh)
ADD_SITE_SCRIPT=$(cat add-remote-site.sh)

# Counter for tracking
SUCCESS_COUNT=0
FAILED_REPOS=()

for REPO in "${REPOS[@]}"; do
    echo "Processing: $REPO"

    # Extract repo name for the issue title
    REPO_NAME=$(echo $REPO | cut -d'/' -f2)

    # Create the issue
    if gh issue create \
        --repo "$REPO" \
        --title "Migrate to Centralized Observability Stack" \
        --body "$ISSUE_BODY" \
        --label "migration,infrastructure,observability" 2>/dev/null; then

        # Get the issue number that was just created
        ISSUE_NUMBER=$(gh issue list --repo "$REPO" --limit 1 --json number --jq '.[0].number')

        # Add migration guide as comment
        gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "## Migration Guide

\`\`\`markdown
$MIGRATION_GUIDE
\`\`\`"

        # Add configure script as comment
        gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "## Configure Site Exporters Script

Save this as \`configure-site-exporters.sh\` and run on your server:

\`\`\`bash
$CONFIGURE_SCRIPT
\`\`\`"

        # Add the add-site script as comment
        gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "## Add Remote Site Script

Save this as \`add-remote-site.sh\` and run locally to register the site:

\`\`\`bash
$ADD_SITE_SCRIPT
\`\`\`"

        echo "✅ Issue created for $REPO (#$ISSUE_NUMBER)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "❌ Failed to create issue for $REPO"
        FAILED_REPOS+=("$REPO")
    fi

    # Small delay to avoid rate limiting
    sleep 2
done

echo ""
echo "=============================================="
echo "Summary"
echo "=============================================="
echo "✅ Successfully created issues: $SUCCESS_COUNT"

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
    echo "❌ Failed repositories:"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "   - $repo"
    done
fi

echo ""
echo "Next steps:"
echo "1. Each repository now has a migration issue"
echo "2. Use Claude Code in each repo to complete the migration"
echo "3. Reference the issue for specific tasks"
echo "4. Central monitoring is ready at 159.89.243.148"