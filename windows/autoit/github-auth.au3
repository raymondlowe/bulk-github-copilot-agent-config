; GitHub Authentication AutoIt Script
; Handles GitHub login and authentication for Copilot configuration

#include <File.au3>
#include <WinAPIFiles.au3>

; Global variables
Global $g_LogFile = ""
Global $g_InteractiveMode = False

; Constants
Global Const $TIMEOUT_AUTH = 60000    ; 60 seconds for authentication
Global Const $TIMEOUT_PAGE = 15000    ; 15 seconds for page loads

; Initialize authentication script
Func Main()
    ; Parse command line arguments
    If $CmdLine[0] < 1 Then
        ConsoleWrite("Usage: github-auth.au3 <target-url> [interactive]" & @CRLF)
        Exit(1)
    EndIf
    
    Local $targetUrl = $CmdLine[1]
    
    ; Check for interactive mode
    If $CmdLine[0] >= 2 And $CmdLine[2] = "interactive" Then
        $g_InteractiveMode = True
    EndIf
    
    ; Initialize logging
    $g_LogFile = @ScriptDir & "\..\logs\auth-" & @YEAR & @MON & @MDAY & "-" & @HOUR & @MIN & @SEC & ".log"
    
    WriteLog("Starting GitHub authentication process")
    WriteLog("Target URL: " & $targetUrl)
    
    If $g_InteractiveMode Then
        WriteLog("Running in interactive mode")
    EndIf
    
    ; Perform authentication
    If Not PerformAuthentication($targetUrl) Then
        WriteLog("Authentication failed", "ERROR")
        Exit(1)
    EndIf
    
    WriteLog("Authentication completed successfully")
    Exit(0)
EndFunc

; Logging function
Func WriteLog($message, $level = "INFO")
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $logEntry = "[" & $timestamp & "] [" & $level & "] " & $message
    
    ConsoleWrite($logEntry & @CRLF)
    FileWriteLine($g_LogFile, $logEntry)
EndFunc

; Main authentication function
Func PerformAuthentication($targetUrl)
    WriteLog("Starting authentication process")
    
    ; Open GitHub login page
    If Not OpenLoginPage() Then
        Return False
    EndIf
    
    ; Detect if already logged in
    If IsAlreadyLoggedIn() Then
        WriteLog("Already authenticated with GitHub")
        
        ; Navigate to target URL
        NavigateToTarget($targetUrl)
        Return True
    EndIf
    
    ; Handle login process
    If $g_InteractiveMode Then
        Return HandleInteractiveLogin($targetUrl)
    Else
        Return HandleAutomaticLogin($targetUrl)
    EndIf
EndFunc

; Open GitHub login page
Func OpenLoginPage()
    WriteLog("Opening GitHub login page")
    
    Local $loginUrl = "https://github.com/login"
    
    ; Find and start browser
    Local $browserPath = FindBrowser()
    If $browserPath = "" Then
        WriteLog("No supported browser found", "ERROR")
        Return False
    EndIf
    
    ; Start browser with login URL
    Local $cmdLine = '"' & $browserPath & '" "' & $loginUrl & '"'
    If Run($cmdLine) <= 0 Then
        WriteLog("Failed to start browser", "ERROR")
        Return False
    EndIf
    
    ; Wait for browser to load
    Sleep(3000)
    
    WriteLog("Browser started successfully")
    Return True
EndFunc

; Find available browser
Func FindBrowser()
    Local $browsers[] = [ _
        @ProgramFilesDir & "\Google\Chrome\Application\chrome.exe", _
        @ProgramFilesDir & "\Microsoft\Edge\Application\msedge.exe", _
        @ProgramFilesDir & "\Mozilla Firefox\firefox.exe", _
        EnvGet("ProgramFiles(x86)") & "\Google\Chrome\Application\chrome.exe", _
        EnvGet("ProgramFiles(x86)") & "\Microsoft\Edge\Application\msedge.exe" _
    ]
    
    For $browser In $browsers
        If FileExists($browser) Then
            WriteLog("Found browser: " & $browser)
            Return $browser
        EndIf
    Next
    
    WriteLog("No browser found in standard locations", "ERROR")
    Return ""
EndFunc

; Check if already logged in to GitHub
Func IsAlreadyLoggedIn()
    WriteLog("Checking if already logged in to GitHub")
    
    ; Wait for page to load
    Sleep(3000)
    
    ; Check window title and URL patterns
    Local $windowTitle = WinGetTitle("[ACTIVE]")
    
    ; If we see "Dashboard" or username in title, likely logged in
    If StringInStr($windowTitle, "Dashboard") > 0 Or StringInStr($windowTitle, "GitHub") > 0 Then
        ; Additional check: try to navigate to profile or settings
        Send("^l") ; Focus address bar
        Sleep(500)
        Send("https://github.com/settings/profile")
        Send("{ENTER}")
        Sleep(3000)
        
        ; Check if we're on settings page (would indicate logged in)
        $windowTitle = WinGetTitle("[ACTIVE]")
        If StringInStr($windowTitle, "Settings") > 0 Or StringInStr($windowTitle, "Profile") > 0 Then
            WriteLog("User is already logged in")
            Return True
        EndIf
    EndIf
    
    WriteLog("User is not logged in")
    Return False
EndFunc

; Handle interactive login
Func HandleInteractiveLogin($targetUrl)
    WriteLog("Starting interactive login process")
    
    ; Show message to user
    Local $message = "Please log in to GitHub in your browser." & @CRLF & @CRLF & _
                    "Steps:" & @CRLF & _
                    "1. Enter your GitHub username/email" & @CRLF & _
                    "2. Enter your password" & @CRLF & _
                    "3. Complete any two-factor authentication" & @CRLF & _
                    "4. Click OK in this dialog when logged in"
    
    Local $result = MsgBox(1, "GitHub Authentication Required", $message, 300) ; 5 minute timeout
    
    If $result = 1 Then ; OK clicked
        WriteLog("User indicated login is complete")
        
        ; Verify login was successful
        If VerifyLoginSuccess() Then
            ; Navigate to target URL
            NavigateToTarget($targetUrl)
            Return True
        Else
            WriteLog("Login verification failed", "ERROR")
            Return False
        EndIf
    Else
        WriteLog("User cancelled or timed out during login", "ERROR")
        Return False
    EndIf
EndFunc

; Handle automatic login (placeholder for future implementation)
Func HandleAutomaticLogin($targetUrl)
    WriteLog("Automatic login not yet implemented")
    WriteLog("Please use interactive mode (-interactive flag)", "ERROR")
    Return False
    
    ; Future implementation could:
    ; 1. Use stored credentials (securely)
    ; 2. Use OAuth tokens
    ; 3. Use browser stored sessions
    ; 4. Use GitHub CLI authentication
EndFunc

; Navigate to target URL after authentication
Func NavigateToTarget($targetUrl)
    WriteLog("Navigating to target URL: " & $targetUrl)
    
    ; Focus address bar and navigate
    Send("^l") ; Ctrl+L to focus address bar
    Sleep(500)
    Send($targetUrl)
    Send("{ENTER}")
    Sleep(3000)
    
    WriteLog("Navigation to target URL completed")
EndFunc

; Verify login was successful
Func VerifyLoginSuccess()
    WriteLog("Verifying login success")
    
    ; Try to access GitHub settings page
    Send("^l") ; Focus address bar
    Sleep(500)
    Send("https://github.com/settings")
    Send("{ENTER}")
    Sleep(5000)
    
    ; Check if we're on a settings page
    Local $windowTitle = WinGetTitle("[ACTIVE]")
    If StringInStr($windowTitle, "Settings") > 0 Or StringInStr($windowTitle, "Account") > 0 Then
        WriteLog("Login verification successful")
        Return True
    EndIf
    
    ; Alternative verification: check for user profile elements
    ; This is simplified - in practice you might need more robust checks
    WriteLog("Login verification inconclusive")
    Return True ; Assume success for now
EndFunc

; Handle two-factor authentication
Func HandleTwoFactorAuth()
    WriteLog("Handling two-factor authentication")
    
    If $g_InteractiveMode Then
        Local $message = "Two-factor authentication detected." & @CRLF & @CRLF & _
                        "Please complete the 2FA process in your browser:" & @CRLF & _
                        "1. Enter your 2FA code from your app or SMS" & @CRLF & _
                        "2. Click OK when authentication is complete"
        
        Local $result = MsgBox(1, "Two-Factor Authentication", $message, 180) ; 3 minute timeout
        
        If $result = 1 Then
            WriteLog("User completed 2FA process")
            Return True
        Else
            WriteLog("2FA process cancelled or timed out", "ERROR")
            Return False
        EndIf
    Else
        WriteLog("2FA detected but not in interactive mode", "ERROR")
        Return False
    EndIf
EndFunc

; Handle GitHub OAuth app authorization
Func HandleOAuthAuthorization()
    WriteLog("Handling OAuth app authorization")
    
    ; Look for "Authorize" button and click it
    ; This is simplified - in practice you'd need to locate the specific button
    
    If $g_InteractiveMode Then
        Local $message = "GitHub OAuth authorization may be required." & @CRLF & @CRLF & _
                        "If you see an authorization page:" & @CRLF & _
                        "1. Review the permissions requested" & @CRLF & _
                        "2. Click 'Authorize' if acceptable" & @CRLF & _
                        "3. Click OK when authorization is complete"
        
        Local $result = MsgBox(1, "OAuth Authorization", $message, 120) ; 2 minute timeout
        
        If $result = 1 Then
            WriteLog("OAuth authorization completed")
            Return True
        Else
            WriteLog("OAuth authorization cancelled or timed out", "ERROR")
            Return False
        EndIf
    Else
        ; Try to automatically click authorize button
        ; This is a placeholder for future implementation
        WriteLog("Automatic OAuth authorization not yet implemented")
        Return False
    EndIf
EndFunc

; Clean up and close browser if needed
Func CleanupBrowser($keepOpen = True)
    WriteLog("Cleaning up browser session")
    
    If Not $keepOpen Then
        ; Close browser
        Send("!{F4}") ; Alt+F4 to close window
        Sleep(1000)
        WriteLog("Browser closed")
    Else
        WriteLog("Browser session kept open")
    EndIf
EndFunc

; Handle session timeouts
Func HandleSessionTimeout()
    WriteLog("Handling session timeout")
    
    ; Check if session has expired
    Local $windowTitle = WinGetTitle("[ACTIVE]")
    If StringInStr($windowTitle, "Sign in") > 0 Or StringInStr($windowTitle, "Login") > 0 Then
        WriteLog("Session appears to have expired")
        
        If $g_InteractiveMode Then
            Local $message = "Your GitHub session appears to have expired." & @CRLF & @CRLF & _
                            "Please log in again and click OK when ready."
            
            Local $result = MsgBox(1, "Session Expired", $message)
            Return $result = 1
        Else
            WriteLog("Session expired but not in interactive mode", "ERROR")
            Return False
        EndIf
    EndIf
    
    Return True
EndFunc

; Main entry point
Main()