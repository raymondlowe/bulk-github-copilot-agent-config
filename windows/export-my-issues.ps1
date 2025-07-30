# This PowerShell script will collect every issue you have created in every repository you have access to in the last 6 months, using the GitHub CLI (gh).
# It will output a single text file with all issue titles and bodies, separated by clear delimiters.

# Set output file
$outputFile = "all-my-issues-last-6-months.txt"

# Get your GitHub username
Write-Host "Getting authenticated GitHub username..."
$user = gh api user --jq ".login"
if (-not $user) {
    Write-Host "Could not determine GitHub username. Make sure you are authenticated with 'gh auth login'." -ForegroundColor Red
    exit 1
}

# Get date 6 months ago in ISO format
$sixMonthsAgo = (Get-Date).AddMonths(-6).ToString("yyyy-MM-ddTHH:mm:ssZ")



# Get repositories from windows\config\repos.txt (one per line, format owner/repo)
$reposFile = "windows\config\repos.txt"
if (!(Test-Path $reposFile)) {
    Write-Host "Repository list file not found: $reposFile" -ForegroundColor Red
    exit 1
}
$repos = Get-Content $reposFile | Where-Object { $_ -match '^\s*[^#]' -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
if (-not $repos -or $repos.Count -eq 0) {
    Write-Host "No valid repositories found in $reposFile." -ForegroundColor Yellow
    exit 0
}

# Prepare output file
"# All issues created by $user in the last 6 months`n" | Set-Content $outputFile

foreach ($repo in $repos) {
    Write-Host "Processing $repo..."
    # List all issues in this repo (state: all)
    $issuesJson = gh issue list -R $repo --state all --limit 1000 --json number
    if ($issuesJson) {
        $issueNumbers = $issuesJson | ConvertFrom-Json | ForEach-Object { $_.number }
        foreach ($issueNumber in $issueNumbers) {
            # Get full issue details
            $issue = gh issue view $issueNumber -R $repo --json title,body,url,createdAt --jq "{title: .title, body: .body, url: .url, createdAt: .createdAt}"
            if ($issue) {
                $issueObj = $issue | ConvertFrom-Json
                "" | Add-Content $outputFile
                "---" | Add-Content $outputFile
                "Repository: $repo" | Add-Content $outputFile
                "URL: $($issueObj.url)" | Add-Content $outputFile
                "Created: $($issueObj.createdAt)" | Add-Content $outputFile
                "Title: $($issueObj.title)" | Add-Content $outputFile
                "" | Add-Content $outputFile
                $issueObj.body | Add-Content $outputFile
            }
        }
    }
}

Write-Host "Done! All issues saved to $outputFile" -ForegroundColor Green
