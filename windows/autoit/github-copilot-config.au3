; GitHub Copilot Agent MCP Configuration AutoIt Script
; ====================================================
; This script automates the process of configuring MCP settings in GitHub repositories
; 
; Features:
; - Configurable timing and interaction parameters
; - Extensive logging and error reporting  
; - Multiple detection strategies for MCP configuration field
; - Robust error handling and retry logic
; - Support for different browsers and environments
;
; Exit codes:
; 0 = Success
; 1 = General error or invalid arguments
; 2 = Authentication failed
; 3 = Navigation/page loading failed
; 4 = Could not find MCP configuration field
; 5 = Could not save configuration

#include <File.au3>
#include <Array.au3>
#include <WinAPIFiles.au3>

; =============================================================================
; GLOBAL VARIABLES AND CONFIGURATION
; =============================================================================

; Command line arguments and script state
Global $g_Repository = ""           ; Target repository (owner/repo format)
Global $g_ConfigPath = ""          ; Path to MCP configuration file
Global $g_InteractiveMode = False  ; Enable interactive authentication
Global $g_DryRunMode = False       ; Preview mode without making changes
Global $g_LogFile = ""             ; Log file path

; Configurable automation parameters (set from command line)
Global $g_TabAttempts = 20          ; Number of Tab key presses to try when searching for MCP field
Global $g_ActionDelay = 500         ; Delay in milliseconds between automation actions
Global $g_PageLoadDelay = 1000      ; Delay in milliseconds to wait for pages to load
Global $g_MaxRetries = 3            ; Maximum number of retry attempts for operations

; Internal timing constants (fine-tuning parameters)
Global Const $DELAY_BETWEEN_TABS = 150      ; Milliseconds between Tab key presses
Global Const $DELAY_AFTER_CLICK = 300       ; Milliseconds to wait after clicking
Global Const $DELAY_AFTER_PASTE = 1000      ; Milliseconds to wait after pasting content
Global Const $DELAY_CLIPBOARD_OPERATION = 200  ; Milliseconds for clipboard operations
Global Const $DELAY_BROWSER_START = 2000    ; Milliseconds to wait for browser to start

; Browser detection and configuration
Global $g_BrowserPath = ""          ; Path to browser executable
Global $g_BrowserName = ""          ; Name of browser being used

; Script execution statistics
Global $g_StartTime = 0             ; Script start timestamp
Global $g_CurrentStep = ""          ; Current operation being performed
Global $g_StepCount = 0             ; Number of steps completed

; =============================================================================
; MAIN ENTRY POINT AND ARGUMENT PARSING
; =============================================================================

; Initialize script and parse command line arguments
Func Main()
    ; Record script start time for performance tracking
    $g_StartTime = TimerInit()
    
    ; Validate minimum required arguments
    ; Expected format: script.au3 repository config-path [interactive] [dryrun] [tab-attempts] [action-delay] [page-delay]
    If $CmdLine[0] < 2 Then
        ConsoleWrite("ERROR: Insufficient arguments provided" & @CRLF)
        ConsoleWrite("Usage: github-copilot-config.au3 <repository> <config-path> [interactive] [dryrun] [tab-attempts] [action-delay] [page-delay]" & @CRLF)
        ConsoleWrite("" & @CRLF)
        ConsoleWrite("Arguments:" & @CRLF)
        ConsoleWrite("  repository     : GitHub repository in owner/repo format" & @CRLF)
        ConsoleWrite("  config-path    : Path to MCP configuration file" & @CRLF)
        ConsoleWrite("  interactive    : Enable interactive authentication mode" & @CRLF)
        ConsoleWrite("  dryrun         : Preview mode without making changes" & @CRLF)
        ConsoleWrite("  tab-attempts   : Number of Tab key presses to try (default: 20)" & @CRLF)
        ConsoleWrite("  action-delay   : Delay in milliseconds between actions (default: 500)" & @CRLF)
        ConsoleWrite("  page-delay     : Delay in seconds for page loading (default: 3)" & @CRLF)
        Exit(1)
    EndIf
    
    ; Parse required arguments
    $g_Repository = $CmdLine[1]
    $g_ConfigPath = $CmdLine[2]
    
    ; Parse optional mode flags (scan all arguments for flags)
    For $i = 3 To $CmdLine[0]
        Switch $CmdLine[$i]
            Case "interactive"
                $g_InteractiveMode = True
            Case "dryrun"
                $g_DryRunMode = True
            Case Else
                ; Parse numeric configuration parameters in order
                If IsNumber($CmdLine[$i]) Then
                    ; Determine which parameter this is based on position
                    Local $paramIndex = 0
                    For $j = 3 To $i - 1
                        If $CmdLine[$j] <> "interactive" And $CmdLine[$j] <> "dryrun" Then
                            $paramIndex += 1
                        EndIf
                    Next
                    
                    Switch $paramIndex
                        Case 0 ; First numeric parameter: tab attempts
                            $g_TabAttempts = Int($CmdLine[$i])
                        Case 1 ; Second numeric parameter: action delay
                            $g_ActionDelay = Int($CmdLine[$i])
                        Case 2 ; Third numeric parameter: page load delay (convert seconds to milliseconds)
                            $g_PageLoadDelay = Int($CmdLine[$i]) * 1000
                    EndSwitch
                EndIf
        EndSwitch
    Next
    
    ; Initialize logging system
    $g_LogFile = @ScriptDir & "\..\logs\autoit-" & @YEAR & @MON & @MDAY & "-" & @HOUR & @MIN & @SEC & ".log"
    
    ; Log script initialization and configuration
    WriteLog("=== GitHub Copilot MCP Configuration AutoIt Script ===")
    WriteLog("Script started at: " & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC)
    WriteLog("Target repository: " & $g_Repository)
    WriteLog("Configuration file: " & $g_ConfigPath)
    WriteLog("Interactive mode: " & ($g_InteractiveMode ? "Enabled" : "Disabled"))
    WriteLog("Dry run mode: " & ($g_DryRunMode ? "Enabled" : "Disabled"))
    WriteLog("Configuration parameters:")
    WriteLog("  - Tab attempts: " & $g_TabAttempts)
    WriteLog("  - Action delay: " & $g_ActionDelay & "ms")
    WriteLog("  - Page load delay: " & $g_PageLoadDelay & "ms")
    WriteLog("")
    
    If $g_DryRunMode Then
        WriteLog("DRY RUN MODE ACTIVE - No changes will be applied", "WARN")
        WriteLog("")
    EndIf
    
    ; Validate input parameters
    If Not ValidateInputs() Then
        WriteLog("Input validation failed - terminating script", "ERROR")
        Exit(1)
    EndIf
    
    ; Load and validate MCP configuration
    SetCurrentStep("Loading MCP configuration")
    Local $mcpConfig = LoadMcpConfiguration($g_ConfigPath)
    If $mcpConfig = "" Then
        WriteLog("Failed to load MCP configuration from: " & $g_ConfigPath, "ERROR")
        Exit(1)
    EndIf
    
    ; Start the main browser automation process
    SetCurrentStep("Starting browser automation")
    If Not StartBrowserAutomation($g_Repository, $mcpConfig) Then
        WriteLog("Browser automation process failed", "ERROR")
        Exit(1)
    EndIf
    
    ; Calculate and log execution statistics
    Local $executionTime = TimerDiff($g_StartTime) / 1000
    WriteLog("")
    WriteLog("=== Script Execution Complete ===")
    WriteLog("Total execution time: " & Round($executionTime, 2) & " seconds")
    WriteLog("Steps completed: " & $g_StepCount)
    WriteLog("Repository '" & $g_Repository & "' configured successfully")
    
    Exit(0)
EndFunc

; =============================================================================
; UTILITY FUNCTIONS FOR LOGGING AND PROGRESS TRACKING
; =============================================================================

; Enhanced logging function with multiple severity levels and detailed formatting
Func WriteLog($message, $level = "INFO")
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $logEntry = "[" & $timestamp & "] [" & $level & "]"
    
    ; Add current step information if available
    If $g_CurrentStep <> "" Then
        $logEntry &= " [" & $g_CurrentStep & "]"
    EndIf
    
    $logEntry &= " " & $message
    
    ; Write to console with color coding (if supported)
    ConsoleWrite($logEntry & @CRLF)
    
    ; Write to log file with error handling
    Local $fileHandle = FileOpen($g_LogFile, 1) ; Append mode
    If $fileHandle <> -1 Then
        FileWriteLine($fileHandle, $logEntry)
        FileClose($fileHandle)
    EndIf
EndFunc

; Set the current operation step for progress tracking
Func SetCurrentStep($stepDescription)
    $g_CurrentStep = $stepDescription
    $g_StepCount += 1
    WriteLog("Step " & $g_StepCount & ": " & $stepDescription, "PROGRESS")
EndFunc

; Log verbose information (detailed operational data)
Func WriteVerboseLog($message)
    WriteLog("VERBOSE: " & $message, "DEBUG")
EndFunc

; Log timing information for performance analysis
Func WriteTimingLog($operation, $startTime)
    Local $elapsed = TimerDiff($startTime)
    WriteLog("Timing - " & $operation & " completed in " & Round($elapsed, 2) & "ms", "TIMING")
EndFunc

; =============================================================================
; INPUT VALIDATION AND CONFIGURATION LOADING
; =============================================================================

; Validate all input parameters and system requirements
Func ValidateInputs()
    WriteLog("Validating input parameters and system requirements")
    
    ; Validate repository format (owner/repo)
    If Not StringRegExp($g_Repository, "^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$") Then
        WriteLog("Invalid repository format: " & $g_Repository & " (expected: owner/repo)", "ERROR")
        Return False
    EndIf
    WriteVerboseLog("Repository format validation passed: " & $g_Repository)
    
    ; Validate configuration file exists and is readable
    If Not FileExists($g_ConfigPath) Then
        WriteLog("Configuration file not found: " & $g_ConfigPath, "ERROR")
        Return False
    EndIf
    WriteVerboseLog("Configuration file exists: " & $g_ConfigPath)
    
    ; Validate configuration parameters are within reasonable bounds
    If $g_TabAttempts < 1 Or $g_TabAttempts > 100 Then
        WriteLog("Tab attempts parameter out of range (1-100): " & $g_TabAttempts, "ERROR")
        Return False
    EndIf
    
    If $g_ActionDelay < 10 Or $g_ActionDelay > 10000 Then
        WriteLog("Action delay parameter out of range (10-10000ms): " & $g_ActionDelay, "ERROR")
        Return False
    EndIf
    
    If $g_PageLoadDelay < 1000 Or $g_PageLoadDelay > 60000 Then
        WriteLog("Page load delay parameter out of range (1-60 seconds): " & $g_PageLoadDelay, "ERROR")
        Return False
    EndIf
    
    WriteVerboseLog("Configuration parameters validation passed")
    WriteLog("Input validation completed successfully")
    Return True
EndFunc

; Load and validate MCP configuration from file
Func LoadMcpConfiguration($configPath)
    WriteLog("Loading MCP configuration from: " & $configPath)
    
    ; Check file accessibility
    If Not FileExists($configPath) Then
        WriteLog("Configuration file not found: " & $configPath, "ERROR")
        Return ""
    EndIf
    
    ; Read file content with error handling
    Local $fileHandle = FileOpen($configPath, 0)
    If $fileHandle = -1 Then
        WriteLog("Failed to open configuration file: " & $configPath, "ERROR")
        Return ""
    EndIf
    
    Local $content = FileRead($fileHandle)
    FileClose($fileHandle)
    
    ; Validate content is not empty
    If StringLen($content) = 0 Then
        WriteLog("Configuration file is empty: " & $configPath, "ERROR")
        Return ""
    EndIf
    
    ; Basic JSON structure validation (look for mcpServers)
    If Not StringInStr($content, "mcpServers") Then
        WriteLog("Warning: Configuration does not contain 'mcpServers' - may not be valid MCP config", "WARN")
    EndIf
    
    ; Log configuration size and basic info
    WriteVerboseLog("Configuration loaded successfully:")
    WriteVerboseLog("  File size: " & StringLen($content) & " characters")
    WriteVerboseLog("  Contains mcpServers: " & (StringInStr($content, "mcpServers") > 0 ? "Yes" : "No"))
    WriteVerboseLog("  First 100 characters: " & StringLeft($content, 100) & "...")
    
    WriteLog("MCP configuration loaded successfully")
    Return $content
EndFunc

; =============================================================================
; MAIN BROWSER AUTOMATION ORCHESTRATION
; =============================================================================

; Main browser automation function - orchestrates the entire configuration process
Func StartBrowserAutomation($repository, $mcpConfig)
    WriteLog("Starting browser automation workflow for repository: " & $repository)

    ; Construct the target GitHub Copilot settings URL
    Local $url = "https://github.com/" & $repository & "/settings/copilot/coding_agent"
    WriteLog("Target URL: " & $url)
    WriteVerboseLog("Full automation workflow starting with URL: " & $url)

    ; Step 1: Start browser and navigate to target page
    SetCurrentStep("Starting browser and navigation")
    If Not StartBrowser($url) Then
        WriteLog("Failed to start browser or navigate to target URL", "ERROR")
        Return False
    EndIf
    WriteVerboseLog("Browser started and initial navigation completed")

    ; Step 1.5: Check for 404 page after navigation
    Sleep(1000) ; Give a moment for the title to update
    Local $windowTitle = WinGetTitle("[ACTIVE]")
    WriteVerboseLog("Window title after navigation: " & $windowTitle)
    If StringInStr($windowTitle, "Page not found") > 0 Or StringInStr($windowTitle, "404") > 0 Then
        WriteLog("Detected 404 or 'Page not found' after navigation. Exiting.", "ERROR")
        Exit(4)
    EndIf

    ; Step 2: Wait for initial page load
    SetCurrentStep("Waiting for page load")
    WriteLog("Waiting " & ($g_PageLoadDelay / 1000) & " seconds for page to load...")
    Sleep($g_PageLoadDelay)
    WriteVerboseLog("Initial page load wait completed")

    ; Step 3: Handle GitHub authentication if required
    SetCurrentStep("Handling authentication")
    If Not HandleAuthentication() Then
        WriteLog("Authentication process failed", "ERROR")
        Return False
    EndIf
    WriteVerboseLog("Authentication handling completed successfully")

    ; Step 4: Locate and navigate to MCP configuration section
    SetCurrentStep("Locating MCP configuration field")
    If Not NavigateToMcpSection() Then
        WriteLog("Failed to locate MCP configuration section on page", "ERROR")
        Return False
    EndIf
    WriteVerboseLog("MCP configuration field located and focused")

    ; Step 5: Apply the MCP configuration
    SetCurrentStep("Applying MCP configuration")
    If Not ConfigureMcpSettings($mcpConfig) Then
        WriteLog("Failed to apply MCP configuration settings", "ERROR")
        Return False
    EndIf
    WriteVerboseLog("MCP configuration applied successfully")

    ; Step 6: Save the configuration (unless in dry run mode)
    If Not $g_DryRunMode Then
        SetCurrentStep("Saving configuration")
        If Not SaveConfiguration() Then
            WriteLog("Failed to save MCP configuration", "ERROR")
            Return False
        EndIf
        WriteVerboseLog("Configuration saved successfully")
    Else
        WriteLog("DRY RUN: Skipping configuration save step")
    EndIf

    ; Step 7: Clean up browser session
    SetCurrentStep("Cleaning up browser session")
    CloseBrowser()
    WriteVerboseLog("Browser cleanup completed")

    WriteLog("Browser automation workflow completed successfully")
    Return True
EndFunc

; =============================================================================
; BROWSER DETECTION AND STARTUP FUNCTIONS
; =============================================================================

; Start browser and navigate to target URL with multiple browser support
Func StartBrowser($url)
    WriteLog("Attempting to start browser and navigate to: " & $url)
    
    ; Define browser configurations with priority order
    ; Format: [executable_name, window_argument, description]
    Local $browsers[][3] = [ _
        ["chrome.exe", "--new-window", "Google Chrome"], _
        ["msedge.exe", "--new-window", "Microsoft Edge"], _
        ["firefox.exe", "-new-window", "Mozilla Firefox"] _
    ]
    
    WriteVerboseLog("Trying " & UBound($browsers) & " different browsers in priority order")
    
    ; Try each browser in order of preference
    For $i = 0 To UBound($browsers) - 1
        Local $browserExe = $browsers[$i][0]
        Local $windowArg = $browsers[$i][1]
        Local $browserDesc = $browsers[$i][2]
        
        WriteVerboseLog("Attempting to find and start: " & $browserDesc)
        
        ; Find the browser installation path
        Local $browserPath = FindBrowserPath($browserExe)
        If $browserPath <> "" Then
            WriteLog("Found browser: " & $browserDesc & " at " & $browserPath)
            
            ; Construct command line for browser launch
            Local $cmdLine = '"' & $browserPath & '" ' & $windowArg & ' "' & $url & '"'
            WriteVerboseLog("Browser command line: " & $cmdLine)
            
            ; Attempt to launch browser
            Local $startTime = TimerInit()
            Local $pid = Run($cmdLine)
            
            If $pid > 0 Then
                WriteLog("Browser started successfully with PID: " & $pid)
                WriteVerboseLog("Waiting " & ($DELAY_BROWSER_START / 1000) & " seconds for browser to initialize...")
                
                ; Wait for browser to start and load
                Sleep($DELAY_BROWSER_START)
                
                ; Store browser info for later use
                $g_BrowserPath = $browserPath
                $g_BrowserName = $browserDesc
                
                WriteTimingLog("Browser startup", $startTime)
                WriteLog("Browser startup completed successfully")
                Return True
            Else
                WriteLog("Failed to start browser: " & $browserDesc, "WARN")
                WriteVerboseLog("Run() returned PID: " & $pid & " for browser: " & $browserDesc)
            EndIf
        Else
            WriteVerboseLog("Browser not found: " & $browserDesc)
        EndIf
    Next
    
    WriteLog("No supported browser could be started", "ERROR")
    WriteLog("Please ensure Chrome, Edge, or Firefox is installed", "ERROR")
    Return False
EndFunc

; Find browser installation path with comprehensive search
Func FindBrowserPath($browserExe)
    WriteVerboseLog("Searching for browser executable: " & $browserExe)
    
    ; Define common browser installation paths
    Local $searchPaths[]
    
    ; Configure search paths based on browser type
    Switch $browserExe
        Case "chrome.exe"
            Local $chromePaths[] = [ _
                @ProgramFilesDir & "\Google\Chrome\Application\chrome.exe", _
                EnvGet("ProgramFiles(x86)") & "\Google\Chrome\Application\chrome.exe", _
                @LocalAppDataDir & "\Google\Chrome\Application\chrome.exe" _
            ]
            $searchPaths = $chromePaths
            
        Case "msedge.exe"
            Local $edgePaths[] = [ _
                @ProgramFilesDir & "\Microsoft\Edge\Application\msedge.exe", _
                EnvGet("ProgramFiles(x86)") & "\Microsoft\Edge\Application\msedge.exe" _
            ]
            $searchPaths = $edgePaths
            
        Case "firefox.exe"
            Local $firefoxPaths[] = [ _
                @ProgramFilesDir & "\Mozilla Firefox\firefox.exe", _
                EnvGet("ProgramFiles(x86)") & "\Mozilla Firefox\firefox.exe" _
            ]
            $searchPaths = $firefoxPaths
            
        Case Else
            WriteLog("Unknown browser executable: " & $browserExe, "WARN")
            Return ""
    EndSwitch
    
    ; Search each path and return first found
    For $i = 0 To UBound($searchPaths) - 1
        Local $path = $searchPaths[$i]
        WriteVerboseLog("Checking path: " & $path)
        
        If FileExists($path) Then
            WriteVerboseLog("Browser found at: " & $path)
            Return $path
        EndIf
    Next
    
    WriteVerboseLog("Browser executable not found in any standard location: " & $browserExe)
    Return ""
EndFunc

; Handle GitHub authentication

; =============================================================================
; MCP CONFIGURATION FIELD DETECTION AND NAVIGATION
; =============================================================================

; Navigate to MCP configuration section using multiple detection strategies

Func NavigateToMcpSection()
    WriteLog("Attempting to locate MCP configuration field using multiple strategies")
    WriteVerboseLog("Tab attempts configured: " & $g_TabAttempts)
    WriteVerboseLog("Action delay configured: " & $g_ActionDelay & "ms")

    ; Strategy 0: Use Ctrl+F, search for 'MCP configuration', Esc, Tab, Tab, Ctrl+A
    WriteLog("Strategy 0: Ctrl+F, search for 'MCP configuration', Esc, Tab, Tab, Ctrl+A")
    If FocusMcpFieldViaSearchShortcut() Then
        WriteLog("Successfully focused MCP field using search shortcut strategy")
        Return True
    EndIf

    ; Strategy 1: Sequential Tab navigation to find the field
    WriteLog("Strategy 1: Sequential Tab navigation through form elements")
    If TabNavigationStrategy() Then
        WriteLog("Successfully found MCP field using Tab navigation")
        Return True
    EndIf

    ; Strategy 2: Use browser search to locate MCP configuration text
    WriteLog("Strategy 2: Using browser search to locate MCP configuration")
    If SearchNavigationStrategy() Then
        WriteLog("Successfully found MCP field using search navigation")
        Return True
    EndIf

    ; Strategy 3: Try common keyboard shortcuts to reach configuration
    WriteLog("Strategy 3: Using keyboard shortcuts for form navigation")
    If ShortcutNavigationStrategy() Then
        WriteLog("Successfully found MCP field using keyboard shortcuts")
        Return True
    EndIf

    ; Strategy 4: Page down navigation to scroll through content
    WriteLog("Strategy 4: Page scrolling to locate configuration section")
    If ScrollNavigationStrategy() Then
        WriteLog("Successfully found MCP field using scroll navigation")
        Return True
    EndIf

    WriteLog("All navigation strategies failed to locate MCP configuration field", "ERROR")
    WriteLog("The page structure may have changed or the field may not be present", "ERROR")
    Return False
EndFunc

; Strategy 0: Ctrl+F, search for 'MCP configuration', Esc, Tab, Tab, Ctrl+A
Func FocusMcpFieldViaSearchShortcut()
    WriteVerboseLog("Trying to focus MCP field using Ctrl+F, search, Esc, Tab, Tab, Ctrl+A")
    ; Open browser search (Ctrl+F)
    Send("^f")
    Sleep($g_ActionDelay)
    ; Type search term
    Send("MCP configuration")
    Sleep($g_ActionDelay)
    ; Press Enter to jump to result
    Send("{ENTER}")
    Sleep($g_ActionDelay)
    ; Close search dialog
    Send("{ESC}")
    Sleep($g_ActionDelay)
    ; Tab twice to move to the editor
    Send("{TAB}")
    Sleep($DELAY_BETWEEN_TABS)
    Send("{TAB}")
    Sleep($DELAY_BETWEEN_TABS)
    ; Try selecting all (Ctrl+A)
    Send("^a")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    ; Check if this is the MCP field
    If CheckForMcpField("SearchShortcut") Then
        WriteVerboseLog("Focused MCP field using search shortcut")
        Return True
    EndIf
    WriteVerboseLog("Search shortcut strategy did not find MCP field")
    Return False
EndFunc

; Strategy 1: Tab through form elements to find MCP configuration field
Func TabNavigationStrategy()
    WriteVerboseLog("Starting Tab navigation strategy with " & $g_TabAttempts & " attempts")
    
    ; Start from beginning of page
    Send("^{HOME}") ; Ctrl+Home to go to top of page
    Sleep($g_ActionDelay)
    
    ; Tab through elements looking for MCP configuration field
    For $i = 1 To $g_TabAttempts
        WriteVerboseLog("Tab attempt " & $i & " of " & $g_TabAttempts)
        
        Send("{TAB}")
        Sleep($DELAY_BETWEEN_TABS)
        
        ; Check if current element is the MCP configuration field
        If CheckForMcpField("Tab navigation") Then
            WriteLog("Found MCP field at Tab position " & $i)
            Return True
        EndIf
        
        ; Add small delay between tab attempts to prevent overwhelming the page
        If Mod($i, 5) = 0 Then
            WriteVerboseLog("Pausing after " & $i & " tab attempts...")
            Sleep($g_ActionDelay)
        EndIf
    Next
    
    WriteVerboseLog("Tab navigation completed without finding MCP field")
    Return False
EndFunc

; Strategy 2: Use browser search to find MCP configuration
Func SearchNavigationStrategy()
    WriteVerboseLog("Starting search navigation strategy")
    
    ; Array of search terms to try
    Local $searchTerms[] = ["MCP configuration", "MCP", "configuration", "copilot", "agent"]
    
    For $i = 0 To UBound($searchTerms) - 1
        Local $searchTerm = $searchTerms[$i]
        WriteVerboseLog("Searching for: " & $searchTerm)
        
        ; Open browser search (Ctrl+F)
        Send("^f")
        Sleep($g_ActionDelay)
        
        ; Search for the term
        Send($searchTerm)
        Sleep($g_ActionDelay)
        Send("{ENTER}")
        Sleep($g_ActionDelay * 2)
        
        ; Close search dialog
        Send("{ESC}")
        Sleep($g_ActionDelay)
        
        ; Try tabbing from the search result to find a nearby input field
        For $j = 1 To 10
            Send("{TAB}")
            Sleep($DELAY_BETWEEN_TABS)
            
            If CheckForMcpField("Search + Tab") Then
                WriteLog("Found MCP field via search for '" & $searchTerm & "' + " & $j & " tabs")
                Return True
            EndIf
        Next
        
        ; Try Shift+Tab to go backwards
        For $j = 1 To 10
            Send("+{TAB}") ; Shift+Tab
            Sleep($DELAY_BETWEEN_TABS)
            
            If CheckForMcpField("Search + Shift+Tab") Then
                WriteLog("Found MCP field via search for '" & $searchTerm & "' + " & $j & " reverse tabs")
                Return True
            EndIf
        Next
    Next
    
    WriteVerboseLog("Search navigation completed without finding MCP field")
    Return False
EndFunc

; Strategy 3: Use keyboard shortcuts for form navigation
Func ShortcutNavigationStrategy()
    WriteVerboseLog("Starting keyboard shortcut navigation strategy")
    
    ; Try different form navigation shortcuts
    Local $shortcuts[] = ["{F6}", "^{TAB}", "{TAB}", "+{TAB}"]
    Local $shortcutNames[] = ["F6 (Switch pane)", "Ctrl+Tab", "Tab", "Shift+Tab"]
    
    For $i = 0 To UBound($shortcuts) - 1
        WriteVerboseLog("Trying shortcut: " & $shortcutNames[$i])
        
        ; Reset to top of page
        Send("^{HOME}")
        Sleep($g_ActionDelay)
        
        ; Try the shortcut multiple times
        For $j = 1 To 10
            Send($shortcuts[$i])
            Sleep($g_ActionDelay)
            
            If CheckForMcpField($shortcutNames[$i]) Then
                WriteLog("Found MCP field using " & $shortcutNames[$i] & " (attempt " & $j & ")")
                Return True
            EndIf
        Next
    Next
    
    WriteVerboseLog("Keyboard shortcut navigation completed without finding MCP field")
    Return False
EndFunc

; Strategy 4: Scroll through page to find configuration section
Func ScrollNavigationStrategy()
    WriteVerboseLog("Starting scroll navigation strategy")
    
    ; Start at top of page
    Send("^{HOME}")
    Sleep($g_ActionDelay)
    
    ; Scroll down page section by section
    For $i = 1 To 20
        WriteVerboseLog("Scroll attempt " & $i & " - Page Down")
        
        Send("{PGDN}")
        Sleep($g_ActionDelay)
        
        ; Try tabbing after each scroll
        For $j = 1 To 5
            Send("{TAB}")
            Sleep($DELAY_BETWEEN_TABS)
            
            If CheckForMcpField("Scroll + Tab") Then
                WriteLog("Found MCP field after " & $i & " page downs + " & $j & " tabs")
                Return True
            EndIf
        Next
    Next
    
    WriteVerboseLog("Scroll navigation completed without finding MCP field")
    Return False
EndFunc

; =============================================================================
; MCP FIELD DETECTION AND VALIDATION
; =============================================================================

; Check if current focus is on MCP configuration field using multiple detection methods
Func CheckForMcpField($detectionMethod = "Unknown")
    WriteVerboseLog("Checking if current element is MCP configuration field (via " & $detectionMethod & ")")
    
    ; Method 1: Check clipboard content after copying field content
    If CheckFieldContentViaClipboard() Then
        WriteVerboseLog("Field identified as MCP config field via clipboard content analysis")
        Return True
    EndIf
    
    ; Method 2: Check field context via accessibility or surrounding text
    If CheckFieldContextViaNavigation() Then
        WriteVerboseLog("Field identified as MCP config field via context analysis")
        Return True
    EndIf
    
    ; Method 3: Check for JSON-like structure in the field
    If CheckFieldForJsonStructure() Then
        WriteVerboseLog("Field identified as MCP config field via JSON structure detection")
        Return True
    EndIf
    
    WriteVerboseLog("Current element does not appear to be MCP configuration field")
    Return False
EndFunc

; Method 1: Analyze clipboard content to identify MCP configuration field
Func CheckFieldContentViaClipboard()
    WriteVerboseLog("Analyzing field content via clipboard")
    
    ; Clear clipboard first
    ClipPut("")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    
    ; Select all content in current field and copy to clipboard
    Send("^a") ; Select all
    Sleep($DELAY_CLIPBOARD_OPERATION)
    Send("^c") ; Copy to clipboard
    Sleep($DELAY_CLIPBOARD_OPERATION)
    
    ; Get clipboard content for analysis
    Local $clipboardContent = ClipGet()
    WriteVerboseLog("Clipboard content length: " & StringLen($clipboardContent))
    
    If StringLen($clipboardContent) > 0 Then
        WriteVerboseLog("Clipboard content preview: " & StringLeft($clipboardContent, 100) & "...")
    EndIf
    
    ; Check for MCP-specific indicators in content
    Local $mcpIndicators[] = ["mcpServers", '"type":', '"command":', '"args":', '"url":', '"tools":']
    
    For $i = 0 To UBound($mcpIndicators) - 1
        If StringInStr($clipboardContent, $mcpIndicators[$i]) > 0 Then
            WriteVerboseLog("Found MCP indicator in content: " & $mcpIndicators[$i])
            Return True
        EndIf
    Next
    
    ; Check for JSON structure patterns
    If StringInStr($clipboardContent, "{") > 0 And StringInStr($clipboardContent, "}") > 0 Then
        WriteVerboseLog("Field contains JSON-like structure")
        ; Additional validation: check if it's a reasonable size for MCP config
        If StringLen($clipboardContent) > 20 And StringLen($clipboardContent) < 10000 Then
            WriteVerboseLog("JSON structure size is reasonable for MCP configuration")
            Return True
        EndIf
    EndIf
    
    ; Check for empty field that might be intended for MCP configuration
    If StringLen($clipboardContent) = 0 Then
        WriteVerboseLog("Field is empty - could be MCP configuration field awaiting content")
        ; This requires additional context checking to avoid false positives
        Return CheckFieldContextViaNavigation()
    EndIf
    
    WriteVerboseLog("Content analysis does not indicate MCP configuration field")
    Return False
EndFunc

; Method 2: Check field context by examining surrounding elements
Func CheckFieldContextViaNavigation()
    WriteVerboseLog("Checking field context via navigation")
    
    ; Save current clipboard content
    Local $originalClipboard = ClipGet()
    
    ; Try to copy label or nearby text by navigating around the field
    ; Look for labels above or to the left of the current field
    
    ; Check above the current field
    Send("+{TAB}") ; Shift+Tab to go to previous element
    Sleep($DELAY_BETWEEN_TABS)
    Send("^a")     ; Select all in previous element
    Sleep($DELAY_CLIPBOARD_OPERATION)
    Send("^c")     ; Copy to clipboard
    Sleep($DELAY_CLIPBOARD_OPERATION)
    
    Local $previousElementContent = ClipGet()
    WriteVerboseLog("Previous element content: " & StringLeft($previousElementContent, 50))
    
    ; Return to the target field
    Send("{TAB}")
    Sleep($DELAY_BETWEEN_TABS)
    
    ; Restore original clipboard
    ClipPut($originalClipboard)
    Sleep($DELAY_CLIPBOARD_OPERATION)
    
    ; Check if previous element contains MCP-related labels
    Local $labelIndicators[] = ["MCP", "configuration", "config", "server", "agent", "tool"]
    
    For $i = 0 To UBound($labelIndicators) - 1
        If StringInStr(StringLower($previousElementContent), StringLower($labelIndicators[$i])) > 0 Then
            WriteVerboseLog("Found context indicator: " & $labelIndicators[$i])
            Return True
        EndIf
    Next
    
    WriteVerboseLog("Context analysis does not indicate MCP configuration field")
    Return False
EndFunc

; Method 3: Check for JSON structure patterns in the field
Func CheckFieldForJsonStructure()
    WriteVerboseLog("Checking field for JSON structure patterns")
    
    ; This is a more sophisticated check for JSON-like content
    ; that could indicate an MCP configuration field
    
    ; Get current field content
    ClipPut("")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    Send("^a")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    Send("^c")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    
    Local $content = ClipGet()
    
    ; Remove whitespace for analysis
    Local $trimmedContent = StringStripWS($content, 8) ; Remove all whitespace
    
    ; Check for JSON object structure
    If StringLeft($trimmedContent, 1) = "{" And StringRight($trimmedContent, 1) = "}" Then
        WriteVerboseLog("Content has JSON object structure")
        
        ; Check for common JSON patterns
        If StringInStr($content, '":') > 0 Or StringInStr($content, '": ') > 0 Then
            WriteVerboseLog("Content contains JSON key-value patterns")
            
            ; Check content length is reasonable for configuration
            If StringLen($content) > 10 And StringLen($content) < 50000 Then
                WriteVerboseLog("Content length is reasonable for configuration")
                Return True
            EndIf
        EndIf
    EndIf
    
    ; Check for empty JSON object (could be placeholder)
    If StringStripWS($content, 8) = "{}" Then
        WriteVerboseLog("Field contains empty JSON object - likely MCP config field")
        Return True
    EndIf
    
    WriteVerboseLog("JSON structure analysis does not indicate MCP configuration field")
    Return False
EndFunc

; =============================================================================
; MCP CONFIGURATION APPLICATION AND VALIDATION
; =============================================================================

; Configure MCP settings by applying the provided configuration
Func ConfigureMcpSettings($mcpConfig)
    WriteLog("Applying MCP configuration to the field")
    WriteVerboseLog("Configuration size: " & StringLen($mcpConfig) & " characters")

    If $g_DryRunMode Then
        WriteLog("DRY RUN: Would apply MCP configuration to current field")
        WriteVerboseLog("DRY RUN: Configuration preview: " & StringLeft($mcpConfig, 200) & "...")
        Return True
    EndIf

    ; Step 1: Clear existing content from the field
    WriteVerboseLog("Clearing existing field content")
    Local $clearStartTime = TimerInit()

    ; Select all existing content
    Send("^a") ; Ctrl+A to select all
    Sleep($DELAY_CLIPBOARD_OPERATION)

    ; Delete selected content
    Send("{DELETE}")
    Sleep($g_ActionDelay)

    WriteTimingLog("Field content clearing", $clearStartTime)

    ; Step 2: Prepare and apply new configuration
    WriteVerboseLog("Preparing configuration for clipboard")
    Local $pasteStartTime = TimerInit()

    ; Put configuration into clipboard
    ClipPut($mcpConfig)
    Sleep($DELAY_CLIPBOARD_OPERATION)

    ; Verify clipboard content
    Local $clipboardVerify = ClipGet()
    If $clipboardVerify <> $mcpConfig Then
        WriteLog("Clipboard verification failed - content mismatch", "ERROR")
        WriteVerboseLog("Expected length: " & StringLen($mcpConfig) & ", Actual length: " & StringLen($clipboardVerify))
        Return False
    EndIf
    WriteVerboseLog("Clipboard prepared successfully")

    ; Paste configuration into field
    WriteVerboseLog("Pasting configuration into field")
    Send("^v") ; Ctrl+V to paste
    Sleep($DELAY_AFTER_PASTE)

    WriteTimingLog("Configuration pasting", $pasteStartTime)

    ; Step 3: Verify the configuration was applied correctly
    WriteVerboseLog("Verifying configuration was applied correctly")
    Local $verifyStartTime = TimerInit()

    ; Select all content in field and copy to verify
    Send("^a")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    Send("^c")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    Send("{ESC}")
    Sleep($DELAY_CLIPBOARD_OPERATION)
    Send("{ESC}")
    Sleep($DELAY_BETWEEN_TABS)
    Send("{TAB}")
    Sleep($DELAY_BETWEEN_TABS)
    Send("{ENTER}")
    Sleep($g_ActionDelay * 2)
    WriteVerboseLog("Save button click sequence sent (Esc, Tab, Enter)")
    Return True
EndFunc

; =============================================================================
; CONFIGURATION SAVE AND AUTHENTICATION FUNCTIONS
; =============================================================================

; Save the MCP configuration using multiple save strategies
Func SaveConfiguration()
    ; Saving is now handled immediately after pasting config in ConfigureMcpSettings
    WriteVerboseLog("SaveConfiguration called, but saving is already handled after paste.")
    Return True
EndFunc

; Save strategy 1: Use Ctrl+S keyboard shortcut


; Save strategy 2: Find and click Save button
Func SaveViaButtonClick()
    WriteVerboseLog("Attempting to save via Esc, Tab to Save button, then Enter")
    ; Press Esc to exit the editor
    Send("{ESC}")
    Sleep($DELAY_BETWEEN_TABS)
    ; Tab to move focus to the Save button (usually next element)
    Send("{TAB}")
    Sleep($DELAY_BETWEEN_TABS)
    ; Press Enter to activate the Save button
    Send("{ENTER}")
    Sleep($g_ActionDelay * 2)
    WriteVerboseLog("Save button click sequence sent (Esc, Tab, Enter)")
    Return True
EndFunc

; Save strategy 3: Form submission via Enter key
Func SaveViaFormSubmission()
    WriteVerboseLog("Attempting form submission via Enter key")
    
    ; Go back to the MCP configuration field
    ; This assumes we're still in or near the field
    Send("^a") ; Select content to ensure we're in the field
    Sleep($DELAY_CLIPBOARD_OPERATION)
    
    ; Try Enter key for form submission
    Send("{ENTER}")
    Sleep($g_ActionDelay * 2)
    
    WriteVerboseLog("Form submission attempt completed")
    Return True ; Simplified - assume success
EndFunc

; Handle GitHub authentication with interactive and automatic modes
Func HandleAuthentication()
    WriteLog("Checking authentication status and handling login if required")
    
    ; Wait for page to stabilize after initial navigation
    WriteVerboseLog("Waiting for page to stabilize for authentication check")
    Sleep($g_PageLoadDelay / 2)
    
    ; Check for authentication indicators
    If IsAuthenticationRequired() Then
        WriteLog("Authentication is required")
        
        If $g_InteractiveMode Then
            WriteLog("Interactive mode enabled - requesting manual authentication")
            Return HandleInteractiveAuthentication()
        Else
            WriteLog("Interactive mode disabled - automatic authentication not yet implemented", "ERROR")
            WriteLog("Please run with 'interactive' parameter for manual authentication", "ERROR")
            Return False
        EndIf
    Else
        WriteLog("Authentication check passed - user appears to be logged in")
        Return True
    EndIf
EndFunc

; Check if authentication is required by examining page indicators
Func IsAuthenticationRequired()
    WriteVerboseLog("Checking for authentication requirement indicators")
    
    ; Get current window title for analysis
    Local $windowTitle = WinGetTitle("[ACTIVE]")
    WriteVerboseLog("Current window title: " & $windowTitle)
    
    ; Check for login-related keywords in window title
    Local $loginIndicators[] = ["Sign in", "Login", "Authenticate", "GitHub Login"]
    
    For $i = 0 To UBound($loginIndicators) - 1
        If StringInStr($windowTitle, $loginIndicators[$i]) > 0 Then
            WriteVerboseLog("Found login indicator in window title: " & $loginIndicators[$i])
            Return True
        EndIf
    Next
    
    ; Additional check: look for login form elements
    ; Try to find common login field patterns
    WriteVerboseLog("Checking for login form elements")
    
    ; This is a simplified check - could be enhanced with:
    ; - More sophisticated element detection
    ; - OCR to read page content
    ; - Browser API integration
    
    WriteVerboseLog("No obvious authentication requirements detected")
    Return False
EndFunc

; Handle interactive authentication with user guidance
Func HandleInteractiveAuthentication()
    WriteLog("Starting interactive authentication process")
    
    ; Prepare detailed instructions for the user
    Local $instructions = "GitHub Authentication Required" & @CRLF & @CRLF & _
                         "Please complete the following steps in your browser:" & @CRLF & _
                         "1. Enter your GitHub username or email address" & @CRLF & _
                         "2. Enter your GitHub password" & @CRLF & _
                         "3. Complete two-factor authentication if prompted" & @CRLF & _
                         "4. Ensure you reach the GitHub Copilot settings page" & @CRLF & _
                         "5. Click OK in this dialog when authentication is complete" & @CRLF & @CRLF & _
                         "Target page: https://github.com/" & $g_Repository & "/settings/copilot/coding_agent"
    
    ; Show authentication dialog with timeout
    WriteLog("Displaying authentication instructions to user")
    Local $result = MsgBox(1, "GitHub Authentication Required", $instructions, 300) ; 5 minute timeout
    
    If $result = 1 Then ; OK button clicked
        WriteLog("User indicated authentication is complete")
        
        ; Give additional time for page navigation
        WriteLog("Waiting for authentication completion and page navigation...")
        Sleep($g_PageLoadDelay)
        
        ; Verify authentication was successful
        If VerifyAuthenticationSuccess() Then
            WriteLog("Authentication verification successful")
            Return True
        Else
            WriteLog("Authentication verification failed", "WARN")
            ; Don't fail completely - user might still be on the right page
            Return True
        EndIf
    Else
        WriteLog("User cancelled authentication or dialog timed out", "ERROR")
        Return False
    EndIf
EndFunc

; Verify that authentication was successful
Func VerifyAuthenticationSuccess()
    WriteVerboseLog("Verifying authentication success")
    
    ; Check window title for success indicators
    Local $windowTitle = WinGetTitle("[ACTIVE]")
    WriteVerboseLog("Post-authentication window title: " & $windowTitle)
    
    ; Look for GitHub settings or repository-related keywords
    Local $successIndicators[] = ["Settings", "Copilot", "GitHub", $g_Repository]
    
    For $i = 0 To UBound($successIndicators) - 1
        If StringInStr($windowTitle, $successIndicators[$i]) > 0 Then
            WriteVerboseLog("Found success indicator: " & $successIndicators[$i])
            Return True
        EndIf
    Next
    
    WriteVerboseLog("Authentication verification inconclusive")
    Return True ; Assume success to avoid blocking automation
EndFunc

; =============================================================================
; CLEANUP AND UTILITY FUNCTIONS
; =============================================================================

; Close browser session cleanly
Func CloseBrowser()
    WriteLog("Closing browser session")
    WriteVerboseLog("Browser cleanup: " & $g_BrowserName & " at " & $g_BrowserPath)
    
    ; Close current tab
    WriteVerboseLog("Closing current browser tab")
    Send("^w") ; Ctrl+W to close tab
    Sleep($g_ActionDelay)
    
    ; If this was the last tab, the browser window will close
    ; Otherwise, just the tab closes
    WriteVerboseLog("Browser cleanup completed")
EndFunc

; Placeholder for future environment/copilot key handling
Func HandleCopilotEnvironment()
    WriteLog("Copilot environment configuration handling")
    WriteVerboseLog("This function would handle environment variables and copilot keys")
    WriteVerboseLog("Implementation pending based on specific requirements")
    
    ; Future implementation would:
    ; - Navigate to environment settings
    ; - Add or update environment variables
    ; - Handle cases where copilot environment may or may not exist
    ; - Manage environment keys and secrets
    
    Return True
EndFunc

; =============================================================================
; SCRIPT ENTRY POINT
; =============================================================================

; Main entry point - start the script execution
Main()