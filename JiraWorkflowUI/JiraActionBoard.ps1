# JiraActionBoard.ps1
# Main GUI Script - Layout Fixes

#Requires -Version 5.1
<#
.SYNOPSIS
A PowerShell GUI to display actionable Jira tickets with action buttons and theme toggle.

.DESCRIPTION
Imports JiraApiHelper module to connect to Jira (or uses fake data).
Displays tickets in categorized columns. Styling improved. Labels fixed.
Includes general/contextual buttons and a Dark Mode toggle at the top.

.PARAMETER TestMode
Switch parameter. If present, generates fake data instead of connecting to Jira.

.NOTES
- Requires JiraApiHelper.psm1 in the same directory.
- Requires config.json unless -TestMode is used.
- Requires PowerShell 5.1 or later.
#>

param(
    [switch]$TestMode
)

# --- Configuration & Setup ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# --- Global Variables ---
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configFile = Join-Path $scriptPath "config.json"
$modulePath = Join-Path $scriptPath "JiraApiHelper.psm1"

# Module import
try {
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    Write-Verbose "JiraApiHelper module imported."
} catch {
    [System.Windows.Forms.MessageBox]::Show("Failed to import JiraApiHelper.psm1 from '$scriptPath'.`nError: $($_.Exception.Message)", "Module Import Error", 0, 16); Exit 1
}

# Global vars
$script:JiraConfig = $null; $script:JiraAuthInfo = $null; $global:FullDataSets = @{}
$script:ContextualButtons = @{}; $script:ListViews = @{}; $script:ColumnLabels = @{}
$script:BaseFont = New-Object System.Drawing.Font("Segoe UI", 9)
$script:IsDarkMode = $false # Theme state

# --- Theme Colors ---
$script:ColorPalette = @{
    Light = @{
        FormBack = [System.Drawing.Color]::FromArgb(248, 249, 250)
        FormText = [System.Drawing.SystemColors]::ControlText
        PanelBack = [System.Drawing.Color]::FromArgb(233, 236, 239)
        TableBack = [System.Drawing.Color]::FromArgb(248, 249, 250) # Match form
        ListBack = [System.Drawing.SystemColors]::Window
        ListText = [System.Drawing.SystemColors]::WindowText
        LabelText = [System.Drawing.SystemColors]::ControlDarkDark
        StatusBack = [System.Drawing.SystemColors]::Control
        StatusText = [System.Drawing.SystemColors]::ControlText
        ButtonFlatStyle = [System.Windows.Forms.FlatStyle]::System
    }
    Dark = @{
        FormBack = [System.Drawing.Color]::FromArgb(45, 45, 48)     # Dark Grey
        FormText = [System.Drawing.Color]::FromArgb(241, 241, 241) # Off-White
        PanelBack = [System.Drawing.Color]::FromArgb(55, 55, 60)     # Lighter Dark Grey
        TableBack = [System.Drawing.Color]::FromArgb(45, 45, 48)     # Match form
        ListBack = [System.Drawing.Color]::FromArgb(30, 30, 30)     # Very Dark Grey
        ListText = [System.Drawing.Color]::FromArgb(241, 241, 241)
        LabelText = [System.Drawing.Color]::FromArgb(200, 200, 200) # Light Grey
        StatusBack = [System.Drawing.Color]::FromArgb(30, 30, 30)
        StatusText = [System.Drawing.Color]::FromArgb(241, 241, 241)
        ButtonFlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    }
}

# --- Functions ---

# Functions moved to JiraApiHelper.psm1: Load-Config, Get-JiraIssues

Function Generate-FakeJiraIssues {
    # (Function unchanged)
     param([string]$ProjectKey, [int]$Count = 10)
    $fakeIssues = @(); $statuses = @("Open", "In Progress", "Ready for QA", "In Review", "Blocked", "Done", "To Do", "Testing", "Needs Info"); $issueTypes = @("Story", "Bug", "Task", "Sub-task", "Epic", "Test Case", "Test Execution", "Test Plan"); $priorities = @("Highest", "High", "Medium", "Low", "Lowest"); $summaries = @("Implement login", "Fix button", "Create tests", "Deploy v1.2", "Investigate error", "Update docs", "Refactor data", "Add cache", "Write tests", "Explore library", "Handle edge case", "Improve perf")
    for ($i = 1; $i -le $Count; $i++) { $issueNumber = Get-Random -Min 100 -Max 9999; $hasStatus = (Get-Random -Min 0 -Max 10) -gt 1; $hasType = (Get-Random -Min 0 -Max 10) -gt 1; $hasPrio = (Get-Random -Min 0 -Max 10) -gt 1; $hasUpdated = (Get-Random -Min 0 -Max 10) -gt 2; $fakeIssue = [PSCustomObject]@{ key = "$($ProjectKey)-$issueNumber"; fields = [PSCustomObject]@{ summary = Get-Random $summaries; status = if($hasStatus) { [PSCustomObject]@{ name = (Get-Random $statuses) } } else { $null }; issuetype = if($hasType) { [PSCustomObject]@{ name = (Get-Random $issueTypes) } } else { $null }; priority = if($hasPrio) { [PSCustomObject]@{ name = (Get-Random $priorities) } } else { $null }; updated = if($hasUpdated) { (Get-Date).AddDays(-(Get-Random -Min 0 -Max 30)).ToString("o") } else { $null }; project = [PSCustomObject]@{ key = $ProjectKey }; assignee = $null } }; $fakeIssues += $fakeIssue }; Write-Verbose "Generated $($fakeIssues.Count) fake for $ProjectKey."; return $fakeIssues
}

Function Populate-ListView {
    # (Function unchanged)
    param([System.Windows.Forms.ListView]$ListView, [array]$IssuesToDisplay)
    $ListView.BeginUpdate(); $ListView.Items.Clear()
    if ($null -ne $IssuesToDisplay) { foreach ($issue in $IssuesToDisplay) { if ($null -eq $issue -or $null -eq $issue.key -or $null -eq $issue.fields) { Write-Warning "Skip invalid issue: $($ListView.Name)."; continue }; $summary = $issue.fields.summary -replace '[\r\n]+', ' '; if ([string]::IsNullOrWhiteSpace($summary)){ $summary = "(No Summary)"}; $statusName = "N/A"; if ($null -ne $issue.fields.status -and -not [string]::IsNullOrWhiteSpace($issue.fields.status.name)) { $statusName = $issue.fields.status.name }; $issueTypeName = "N/A"; if ($null -ne $issue.fields.issuetype -and -not [string]::IsNullOrWhiteSpace($issue.fields.issuetype.name)) { $issueTypeName = $issue.fields.issuetype.name }; $priorityName = "N/A"; if ($null -ne $issue.fields.priority -and -not [string]::IsNullOrWhiteSpace($issue.fields.priority.name)) { $priorityName = $issue.fields.priority.name }; $updatedDate = ""; if (-not [string]::IsNullOrWhiteSpace($issue.fields.updated)) { $updatedDate = $issue.fields.updated }; $listItem = New-Object System.Windows.Forms.ListViewItem($issue.key); $listItem.SubItems.Add($summary) | Out-Null; $listItem.SubItems.Add($statusName) | Out-Null; $listItem.ToolTipText = "Type: $issueTypeName`nPriority: $priorityName`nUpdated: $updatedDate"; $listItem.Tag = $issue; $ListView.Items.Add($listItem) | Out-Null } }
    $ListView.EndUpdate()
}

Function Update-ContextualButtons {
    # (Function unchanged)
    $anySelected = $false; $selectedIssue = $null
    foreach ($lvName in $script:ListViews.Keys) { $lv = $script:ListViews[$lvName]; if ($lv.SelectedItems.Count -gt 0) { $anySelected = $true; if ($null -eq $selectedIssue) { $selectedIssue = $lv.SelectedItems[0].Tag }; break } }
    foreach ($buttonName in $script:ContextualButtons.Keys) { $script:ContextualButtons[$buttonName].Enabled = $anySelected }
}

Function Apply-Theme {
    # Applies theme colors to controls
    $themeName = if ($script:IsDarkMode) { "Dark" } else { "Light" }
    $colors = $script:ColorPalette[$themeName]
    Write-Verbose "Applying Theme: $themeName"

    $script:mainForm.SuspendLayout(); $script:topButtonPanel.SuspendLayout(); $script:tableLayoutPanel.SuspendLayout()

    $script:mainForm.BackColor = $colors.FormBack; $script:mainForm.ForeColor = $colors.FormText
    $script:topButtonPanel.BackColor = $colors.PanelBack
    $script:tableLayoutPanel.BackColor = $colors.TableBack
    $script:statusBar.BackColor = $colors.StatusBack

    foreach ($lvKey in $script:ListViews.Keys) { $lv = $script:ListViews[$lvKey]; $lv.BackColor = $colors.ListBack; $lv.ForeColor = $colors.ListText }
    foreach ($lblKey in $script:ColumnLabels.Keys) { $lbl = $script:ColumnLabels[$lblKey]; $lbl.ForeColor = $colors.LabelText; $lbl.BackColor = $colors.TableBack } # Match table background

    $buttonFlatStyle = $colors.ButtonFlatStyle
    foreach ($ctrl in $script:topButtonPanel.Controls) {
        if ($ctrl -is [System.Windows.Forms.Button]) {
            $ctrl.FlatStyle = $buttonFlatStyle
            if ($script:IsDarkMode -and $buttonFlatStyle -eq [System.Windows.Forms.FlatStyle]::Flat) {
                 $ctrl.BackColor = $script:ColorPalette.Dark.PanelBack; $ctrl.ForeColor = $script:ColorPalette.Dark.FormText; $ctrl.FlatAppearance.BorderColor = $script:ColorPalette.Dark.FormText; $ctrl.FlatAppearance.BorderSize = 1
            } else { $ctrl.UseVisualStyleBackColor = $true }
        }
        if ($ctrl -is [System.Windows.Forms.CheckBox]) { $ctrl.ForeColor = $colors.FormText; $ctrl.BackColor = $colors.PanelBack }
    }

    $script:tableLayoutPanel.ResumeLayout(); $script:topButtonPanel.ResumeLayout(); $script:mainForm.ResumeLayout()
}

Function Refresh-Data {
    # (Function unchanged)
    if ($null -eq $script:statusBarLabel -or $null -eq $script:mainForm) { Write-Warning "Refresh called before GUI init."; return }
    $script:statusBarLabel.Text = "Refreshing data..."; $script:mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor; $script:mainForm.SuspendLayout()
    $global:FullDataSets.Clear(); $fetchedData = @{}
    if ($TestMode.IsPresent) { $script:statusBarLabel.Text = "Generating fake data..."; $fetchedData['listViewCol1'] = Generate-FakeJiraIssues -ProjectKey "DEV" -Count (Get-Random -Min 3 -Max 12); $fetchedData['listViewCol2'] = Generate-FakeJiraIssues -ProjectKey "TST" -Count (Get-Random -Min 5 -Max 15); $fetchedData['listViewCol3'] = Generate-FakeJiraIssues -ProjectKey "DEV" -Count (Get-Random -Min 1 -Max 8); $fetchedData['listViewCol4'] = Generate-FakeJiraIssues -ProjectKey "TST" -Count (Get-Random -Min 4 -Max 10) }
    else { if (-not $script:JiraConfig -or -not $script:JiraAuthInfo) { $script:statusBarLabel.Text = "Error: Jira Config/Auth not loaded."; $script:mainForm.Cursor = [System.Windows.Forms.Cursors]::Default; $script:mainForm.ResumeLayout(); Return }; $script:statusBarLabel.Text = "Loading data from Jira..."; $devProj = $script:JiraConfig.DevProjectKey; $tstProj = $script:JiraConfig.TstProjectKey; Write-Verbose "Using Proj: $devProj, $tstProj"; $jqlDev = "project = $devProj AND assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC"; $jqlTst = "project = $tstProj AND assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC"; $jqlReview = "project = $devProj AND assignee = currentUser() AND status = 'In Review' ORDER BY updated DESC"; $jqlTestExec = "project = $tstProj AND issuetype = 'Test Execution' AND assignee = currentUser() AND status = 'TODO' ORDER BY updated DESC"; $tempCol1 = Get-JiraIssues -Jql $jqlDev -Config $script:JiraConfig -Base64AuthInfo $script:JiraAuthInfo; $tempCol2 = Get-JiraIssues -Jql $jqlTst -Config $script:JiraConfig -Base64AuthInfo $script:JiraAuthInfo; $tempCol3 = Get-JiraIssues -Jql $jqlReview -Config $script:JiraConfig -Base64AuthInfo $script:JiraAuthInfo; $tempCol4 = Get-JiraIssues -Jql $jqlTestExec -Config $script:JiraConfig -Base64AuthInfo $script:JiraAuthInfo; $fetchedData['listViewCol1'] = $tempCol1; $fetchedData['listViewCol2'] = $tempCol2; $fetchedData['listViewCol3'] = $tempCol3; $fetchedData['listViewCol4'] = $tempCol4 }
    foreach ($key in $script:ListViews.Keys) { $listView = $script:ListViews[$key]; if ($null -eq $listView) { Write-Warning "ListView '$key' not found."; continue }; $global:FullDataSets[$key] = $fetchedData[$key]; Populate-ListView -ListView $listView -IssuesToDisplay $fetchedData[$key] } # Populate directly
    Update-ContextualButtons; $statusMsg = if ($TestMode.IsPresent) { "Fake data refreshed." } elseif ($script:statusBarLabel.Text -like 'Error*') { $script:statusBarLabel.Text } else { "Jira data refreshed." }; $script:statusBarLabel.Text = $statusMsg; $script:mainForm.Cursor = [System.Windows.Forms.Cursors]::Default; $script:mainForm.ResumeLayout()
}


# --- GUI Definition ---

# Initial Config Load
if (-not $TestMode.IsPresent) { $apiDetails = Load-Config -ConfigFilePath $configFile; if ($null -ne $apiDetails) { $script:JiraConfig = $apiDetails.Config; $script:JiraAuthInfo = $apiDetails.AuthInfo } else { Write-Warning "Initial config load failed." } } else { Write-Host "--- TEST MODE ACTIVE ---" }

# Main Form
$mainForm = New-Object System.Windows.Forms.Form; $formTitle = "Jira Action Board"; if ($TestMode.IsPresent) { $formTitle += " (TEST MODE)" } elseif ($script:JiraConfig -ne $null -and $script:JiraConfig.Email) { $formTitle += " - $($script:JiraConfig.Email)" } else { $formTitle += " (Config Issue?)" }; $mainForm.Text = $formTitle; $mainForm.Size = New-Object System.Drawing.Size(1400, 750); $mainForm.MinimumSize = New-Object System.Drawing.Size(900, 450); $mainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$script:mainForm = $mainForm; $mainForm.Font = $script:BaseFont

# Status Bar
$statusBar = New-Object System.Windows.Forms.StatusBar; $statusBarLabel = New-Object System.Windows.Forms.StatusBarPanel; $statusBarLabel.AutoSize = [System.Windows.Forms.StatusBarPanelAutoSize]::Spring; $statusBarLabel.Text = "Initializing..."; $statusBar.Panels.Add($statusBarLabel) | Out-Null; $statusBar.ShowPanels = $true
$script:statusBarLabel = $statusBarLabel

# ToolTip Component
$script:toolTip = New-Object System.Windows.Forms.ToolTip

# --- Top Button Panel ---
$topButtonPanel = New-Object System.Windows.Forms.Panel; $topButtonPanel.Name = "topButtonPanel"; $topButtonPanel.Height = 50; $topButtonPanel.Dock = [System.Windows.Forms.DockStyle]::Top; $topButtonPanel.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8); # Adjusted Padding LTRB
$mainForm.Controls.Add($topButtonPanel); $script:topButtonPanel = $topButtonPanel
$topButtonPanel.SuspendLayout()

$script:buttonX = $topButtonPanel.Padding.Left

# Helper to add Action Buttons Horizontally
Function Add-TopActionButton {
    param([string]$ButtonName, [string]$Text, [scriptblock]$OnClickAction, [string]$ToolTip = "", [int]$Width = 150, [bool]$IsContextual = $false)
    $button = New-Object System.Windows.Forms.Button; $button.Name = $ButtonName; $button.Text = $Text; $button.Size = New-Object System.Drawing.Size($Width, 32); $button.Location = New-Object System.Drawing.Point($script:buttonX, $topButtonPanel.Padding.Top); $button.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left)
    if (-not [string]::IsNullOrWhiteSpace($ToolTip)) { $script:toolTip.SetToolTip($button, $ToolTip) }
    $button.Add_Click($OnClickAction); $topButtonPanel.Controls.Add($button) | Out-Null
    $script:buttonX += $button.Width + 6 # Spacing
    if ($IsContextual) { $script:ContextualButtons[$ButtonName] = $button; $button.Enabled = $false }
    return $button
}

# Define Button Actions
$exportAction = { [System.Windows.Forms.MessageBox]::Show("Placeholder: Export CSV", "Export CSV", 0, 64) }
$getBuildAction = { [System.Windows.Forms.MessageBox]::Show("Placeholder: Get Latest Build", "Get Latest Build", 0, 64) }
$vmStatusAction = { [System.Windows.Forms.MessageBox]::Show("Placeholder: Check VM Status", "Check VM Status", 0, 64) }
$createCaseAction = { $sel = Get-SelectedIssue; if($sel) { [System.Windows.Forms.MessageBox]::Show("Placeholder: Create Test Case for $($sel.key)", "Create Test Case", 0, 64) } }
$configEnvAction = { $sel = Get-SelectedIssue; if($sel) { [System.Windows.Forms.MessageBox]::Show("Placeholder: Configure Test Env for $($sel.key)", "Configure Test Env", 0, 64) } }
$coverageAction = { $sel = Get-SelectedIssue; if($sel) { [System.Windows.Forms.MessageBox]::Show("Placeholder: Check Coverage for $($sel.key)", "Check Coverage", 0, 64) } }

# Helper to get selected issue
Function Get-SelectedIssue { foreach ($lvName in $script:ListViews.Keys) { if ($script:ListViews[$lvName].SelectedItems.Count -gt 0) { return $script:ListViews[$lvName].SelectedItems[0].Tag } }; return $null }

# Create Refresh Button
$refreshButton = New-Object System.Windows.Forms.Button; $refreshButton.Name = "refreshButton"; $refreshButton.Text = "Refresh"; $refreshButton.Size = New-Object System.Drawing.Size(100, 32); $refreshButton.Location = New-Object System.Drawing.Point($script:buttonX, $topButtonPanel.Padding.Top); $refreshButton.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left); $refreshButton.Add_Click({ Refresh-Data }); $topButtonPanel.Controls.Add($refreshButton) | Out-Null; $script:buttonX += $refreshButton.Width + 12

# Create General Action Buttons
Add-TopActionButton -ButtonName "exportButton" -Text "Export CSV" -OnClickAction $exportAction -ToolTip "Export data to CSV." -Width 110
Add-TopActionButton -ButtonName "buildButton" -Text "Get Latest Build" -OnClickAction $getBuildAction -ToolTip "Check build status." -Width 120
Add-TopActionButton -ButtonName "vmButton" -Text "Check VM Status" -OnClickAction $vmStatusAction -ToolTip "Query VM status." -Width 130

# Create Contextual Action Buttons
$script:buttonX += 10
Add-TopActionButton -ButtonName "createCaseButton" -Text "Create Test Case" -OnClickAction $createCaseAction -ToolTip "Create Xray Test Case for selected item." -Width 130 -IsContextual $true
Add-TopActionButton -ButtonName "configEnvButton" -Text "Configure Env" -OnClickAction $configEnvAction -ToolTip "Configure test environment for selected item." -Width 120 -IsContextual $true
Add-TopActionButton -ButtonName "coverageButton" -Text "Check Coverage" -OnClickAction $coverageAction -ToolTip "Check test coverage status for selected item." -Width 130 -IsContextual $true

# --- Dark Mode Toggle CheckBox --- (Added AFTER buttons, position calculated)
$darkModeCheckBox = New-Object System.Windows.Forms.CheckBox
$darkModeCheckBox.Name = "darkModeCheckBox"; $darkModeCheckBox.Text = "Dark Mode"; $darkModeCheckBox.AutoSize = $true
$darkModeCheckBox.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right) # Anchor Right
# Calculate X position based on panel width
$checkBoxX = $topButtonPanel.ClientSize.Width - $darkModeCheckBox.PreferredSize.Width - $topButtonPanel.Padding.Right
$checkBoxY = $topButtonPanel.Padding.Top + ($topButtonPanel.ClientSize.Height - $topButtonPanel.Padding.Top - $topButtonPanel.Padding.Bottom - $darkModeCheckBox.PreferredSize.Height) / 2 # Center vertically
$darkModeCheckBox.Location = New-Object System.Drawing.Point($checkBoxX, [int]$checkBoxY) # Ensure Y is integer
$darkModeCheckBox.Add_CheckedChanged({ param($s, $e); $script:IsDarkMode = $s.Checked; Apply-Theme })
$topButtonPanel.Controls.Add($darkModeCheckBox) | Out-Null

$topButtonPanel.ResumeLayout()

# --- TableLayoutPanel for Columns ---
$tableLayoutPanel = New-Object System.Windows.Forms.TableLayoutPanel; $tableLayoutPanel.Name = "mainTableLayout"; $tableLayoutPanel.Dock = [System.Windows.Forms.DockStyle]::Fill; $tableLayoutPanel.ColumnCount = 4;
$tableLayoutPanel.RowCount = 2 # Label, ListView
$tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))); $tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))); $tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))); $tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
# === Adjusted Row Height ===
$tableLayoutPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 0: Labels (Taller)
$tableLayoutPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Row 1: ListViews
$tableLayoutPanel.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 8) # Adjusted Padding LTRB
$mainForm.Controls.Add($tableLayoutPanel)
$script:tableLayoutPanel = $tableLayoutPanel
$tableLayoutPanel.SuspendLayout()

# Helper Function to create Label and ListView (No FilterBox)
Function Create-ColumnControls {
    param([string]$LabelText, [string]$ListViewName)
    # Label Styling
    $label = New-Object System.Windows.Forms.Label; $label.Name = "label_$($ListViewName)"; $label.Text = $LabelText; $label.Dock = [System.Windows.Forms.DockStyle]::Fill; $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $label.Font = New-Object System.Drawing.Font($script:BaseFont.FontFamily, 10, [System.Drawing.FontStyle]::Bold); $label.AutoEllipsis = $true;
    $label.Visible = $true # Ensure visible
    $label.Margin = New-Object System.Windows.Forms.Padding(0) # Remove Margin
    $script:ColumnLabels[$label.Name] = $label

    # ListView Styling
    $listView = New-Object System.Windows.Forms.ListView; $listView.Name = $ListViewName; $listView.View = [System.Windows.Forms.View]::Details; $listView.FullRowSelect = $true; $listView.GridLines = $true; $listView.MultiSelect = $false; $listView.Dock = [System.Windows.Forms.DockStyle]::Fill; $listView.HideSelection = $false; $listView.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $listView.Font = $script:BaseFont
    $listView.Columns.Add("Key", 80) | Out-Null; $listView.Columns.Add("Summary", -2) | Out-Null; $listView.Columns.Add("Status", 100) | Out-Null
    $listView.Add_DoubleClick({ param($s, $e); $lv = $s -as [System.Windows.Forms.ListView]; if ($lv -eq $null -or $lv.SelectedItems.Count -eq 0) { return }; $item = $lv.SelectedItems[0]; if ($null -eq $item -or $null -eq $item.Tag) { return }; $issue = $item.Tag; $issueKey = $issue.key; $baseUrl = "https://jira.example.com"; if (-not $script:TestMode.IsPresent -and $script:JiraConfig -ne $null -and -not [string]::IsNullOrWhiteSpace($script:JiraConfig.JiraUrl)) { $baseUrl = $script:JiraConfig.JiraUrl }; if ($script:TestMode.IsPresent) { [System.Windows.Forms.MessageBox]::Show("Test: Would open:`n$baseUrl/browse/$issueKey", "Test Action", 0, 64); return }; $url = "$baseUrl/browse/$issueKey"; Write-Host "Opening $url"; try { Start-Process $url -EA Stop } catch { $msg = "Could not open URL '$url': $($_.Exception.Message)"; Write-Warning $msg; [System.Windows.Forms.MessageBox]::Show("Could not open URL.`nError: $($_.Exception.Message)", "Browse Error", 0, 16) } })
    $listView.add_SelectedIndexChanged({ Update-ContextualButtons })

    $script:ListViews[$ListViewName] = $listView
    return @{ Label = $label; ListView = $listView }
}

# Define columns
$columnDefs = @( @{ LabelText = "DEV: Needs Action?"; ListViewName = "listViewCol1" }; @{ LabelText = "TST: Needs Action?"; ListViewName = "listViewCol2" }; @{ LabelText = "Needs Review / Blocked?"; ListViewName = "listViewCol3" }; @{ LabelText = "Test Executions ToDo?"; ListViewName = "listViewCol4" } )

# Create and Add Controls
for ($i = 0; $i -lt $columnDefs.Length; $i++) {
    $colDef = $columnDefs[$i]
    $controls = Create-ColumnControls -LabelText $colDef.LabelText -ListViewName $colDef.ListViewName
    $tableLayoutPanel.Controls.Add($controls.Label, $i, 0)    | Out-Null
    $tableLayoutPanel.Controls.Add($controls.ListView, $i, 1)  | Out-Null
}

$tableLayoutPanel.ResumeLayout()

# --- Final Form Setup ---
$mainForm.Controls.Add($statusBar) # Add Status Bar LAST
$statusBar.BringToFront()

# --- Apply Initial Theme ---
Write-Verbose "Applying initial theme..."
Apply-Theme

# --- Initial Data Load ---
Write-Verbose "Performing initial data refresh..."
Refresh-Data

# --- Show the Form ---
Write-Verbose "Showing main form..."
$mainForm.ShowDialog() | Out-Null

# --- Cleanup ---
Write-Verbose "Cleaning up form..."
$mainForm.Dispose()
if ($script:toolTip) { $script:toolTip.Dispose() }
if ($script:BaseFont) { $script:BaseFont.Dispose() }
Write-Verbose "Script finished."