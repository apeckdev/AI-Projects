
param (
    [string]$Path = "DAB-97.xml"
)

# Load the XML file
[xml]$jiraTicket = Get-Content -Path $Path

# Extract relevant information
$title = $jiraTicket.rss.channel.item.title
$description = $jiraTicket.rss.channel.item.description
$summary = $jiraTicket.rss.channel.item.summary
$issueKey = $jiraTicket.rss.channel.item.key.'#text'

# Clean up the description (remove HTML tags)
$cleanedDescription = $description -replace '<[^>]+>', ""

# Create the prompt for Ollama
$acceptanceCriteria = $($jiraTicket.rss.channel.item.description.ul.li | ForEach-Object { "- " + $_ }) -join "`n"
$prompt = @"
You are an expert QA Engineer specializing in Behavior-Driven Development (BDD). Your task is to write a comprehensive Gherkin feature file based on the provided Jira ticket.

The feature file must:
- Accurately reflect the user story and acceptance criteria.
- Include multiple, distinct scenarios to cover the main functionality.
- When a scenario uses variable data, it MUST be structured as a `Scenario Outline` with an `Examples` table.
- Use placeholders like `<time_in_minutes>` in the `Scenario Outline` and define the concrete values in the `Examples` table.
- Include at least one scenario for an edge case or a negative path (e.g., what happens if a condition is not met).
- Be written in perfect Gherkin syntax.
- Contain NO markdown formatting, code fences (like ```), or any other text outside of the Gherkin syntax itself.

Jira Ticket Information:
**Title:** $title
**Summary:** $summary
**Description:**
$cleanedDescription
**Acceptance Criteria:**
$acceptanceCriteria
"@

# Call Ollama API
$ollamaRequest = @{
    model = "gemma:latest"
    prompt = $prompt
    stream = $false
}

$ollamaResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:11434/api/generate" -Body ($ollamaRequest | ConvertTo-Json) -ContentType "application/json"

# Save the response to a .feature file
$featureContent = $ollamaResponse.response
# Remove markdown code blocks
if ($featureContent -match '(?s)```gherkin(.*)```') {
    $featureContent = $matches[1]
}
$featureContent = $featureContent.Trim()
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$featureFilePath = "${issueKey}_${timestamp}.feature"
$featureContent | Out-File -FilePath $featureFilePath -Encoding utf8

Write-Host "Gherkin feature file generated at: $featureFilePath"