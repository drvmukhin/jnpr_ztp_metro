'------------------------------------------------------------------
' This script is a part of the zero touch provisioning solution for 
' Script creates multiple copies of the configlet file <configlet_name>.txt
' and saves it as <serial_number>.cfg. List of Serial Numbers is taken 
' from the <inventory>.csv file. Following format of records are expected 
' in csv file:
'       <node name>,<serial number>,<paltform>
' File location:
'       strLCLDir\inventory\<inventory_file_name>.csv
'       strLCLDir\config\<configlet_file_name>.txt
' Set strLCLDir accordingly prior running script
' To trigger population of config files make you should have
'        <inventory_file_name> = <configlet_file_name>
'------------------------------------------------------------------
' - Variables
Dim strInventoryDir
Dim strConfigDirectory
Dim strInventoryFile 
Dim strConfigFile
Dim objFSO, objDebug, objInfo, objFolder, colFiles, vNewConfFile, vConfFile
Dim nDebug
' - Constants
Const ForAppending = 8
Const ForWriting = 2
Const CFG_DIR = "config"
Const INV_DIR = "inventory"
Const MODELED_DEVICES = "ztp_devices"
Const DEBUG_FILE = "debug"
Const INFO_FILE = "info"
Const MAX_LEN = 140
Const SLEEP = 30000
Const D0 = "01/01/2015"
Const SECONDS = "s"
nDebug = 0
strDirLCL = ""
Set objFSO = CreateObject("Scripting.FileSystemObject")
Main()
' - Close log files
If IsObject(objDebug) Then objDebug.Close : End If
If IsObject(objInfo) Then objInfo.Close : End If
Set objFSO = Nothing

' Main Sub
Sub Main()
	If WScript.Arguments.Count >= 1 Then 
	    For i = 0 to WScript.Arguments.Count - 1
		Select Case WScript.Arguments(i)
			Case "-d" 
				If i + 1 < WScript.Arguments.Count Then 
					i = i + 1
					strDirLCL = WScript.Arguments(i)
				End If 
			Case "-t"  ' - enable debug log
				nDebug = 1
			Case Else 
				MsgBox   "Wrong arguments" & chr(13) &_
						 "Use the following format:" & chr(13) &_
						 "<script name>.vbs -d <root directory> [-t enables optional debug]"
				Exit sub
		End Select
		Next
    End If
	If strDirLCL = "" Then 
		strDirLCL = "C:\volume"
		strDirInventory = strDirLCL & "\" & INV_DIR
		strDirConfig = strDirLCL & "\" & CFG_DIR
	    If Not Continue( "Script will use default directories:" & chr(13) &_
		                 "Inventory: " & strDirInventory & chr(13) &_
			             "Configs:   " & strDirConfig & chr(13) &_
						 "To change default location use the following format:" & chr(13) &_
						 "<script name>.vbs -d <root directory> [-t enables optional debug]", "Continue?") Then Exit Sub End If
	End If
	strDirInventory = strDirLCL & "\" & INV_DIR
	strDirConfig = strDirLCL & "\" & CFG_DIR
	
	If Not objFSO.FolderExists(strDirLCL) Then 
		MsgBox "Can't find root directory: " & strDirLCL & chr(13) & "Terminating script."
		Exit Sub
		nResult = -1
	End If
'-----------------------------------------------------------------
'  	CHECK IF START SCRIPT IS ALREADY RUNNING AND OPEN LOG FILE
'-----------------------------------------------------------------
	On Error Resume Next
	Set objDebug = objFSO.OpenTextFile(strDirLCL & "\" & DEBUG_FILE & ".log",ForWriting,True)
	Select Case Err.Number
		Case 0
		Case 70
			MsgBox "Script is already running!" & chr(13) & "Exit . . ."
			Exit Sub
		Case Else 
			MsgBox "Error #0001: Can't start script!" & chr(13) & Err.Description & chr(13) & "Exit . . ."
			Exit Sub
	End Select
	On Error goto 0
	On Error Resume Next
	Set objInfo = objFSO.OpenTextFile(strDirLCL & "\" & INFO_FILE & ".log",ForWriting,True)
	Select Case Err.Number
		Case 0
		Case Else 
			MsgBox "Error #0002. Can't start script!" & chr(13) & "Exit . . ."
			Exit Sub
	End Select
	On Error goto 0

'-----------------------------------------------------------------
'  	CHECK IF Inventory and Config directories exist
'-----------------------------------------------------------------
	If Not objFSO.FolderExists(strDirInventory) Then 
		MsgBox "Can't find inventory folder. Terminating script."
		nResult = -1
		Exit Sub
	End If
	If Not objFSO.FolderExists(strDirConfig) Then 
		MsgBox "Can't find Config folder. Terminating script."
		nResult = -1
		Exit Sub
	End If
	strTempFile = strDirConfig & "\temp_csr.conf"
'-----------------------------------------------------------------
'  	Main cycle
'-----------------------------------------------------------------
	Call TrDebug ("INFO: BEGIN SCRIPT ", "", objDebug, MAX_LEN, 3, nDebug)
	Dim nLine
	Do
		If Not objFSO.FolderExists(strDirInventory) Then 
			MsgBox "Can't find inventory folder. Terminating script."
			nResult = -1
			Exit Do
		End If
		If Not objFSO.FolderExists(strDirConfig) Then 
			MsgBox "Can't find Confif folder. Terminating script."
			nResult = -1
			Exit Do
		End If
    	Set objFolder = objFSO.GetFolder(strDirInventory)
		Set colFiles = objFolder.Files
		For Each objFile in colFiles
			strFile = objFile.Name
			If Right(LCase(strFile),4) = ".csv" Then 
				Call TrDebug ("INFO: Found inventory file: " & strFile, "", objDebug, MAX_LEN, 1, nDebug)
				strConfigletFileName = strDirConfig & "\" & Left(strFile,Len(strFile)-4) & ".txt"
				If objFSO.FileExists(strConfigletFileName) Then 
				    ' - Create new copy of the configlet file. include configuration for system hierarchy level only
				    nCount = GetFileLineCountSelect(strConfigletFileName, vConfFile,"", "", "", 0)
					Redim vNewConfFile(0)
					nLine = 0
				    For i = 0 to nCount - 1
					    If Instr(vConfFile(i),"system") then 
					        Redim Preserve vNewConfFile(nLine + 1)
							vNewConfFile(nLine) = vConfFile(i)
							nLine = nLine + 1
						End If
					Next
					If Not WriteArrayToFile(strTempFile,vNewConfFile, UBound(vNewConfFile),1,0) Then 
					    Call TrDebug ("ERROR: Can't write to temporary config file: " & strTempFile, "", objDebug, MAX_LEN, 1, nDebug)
						Call TrDebug ("ERROR: Can't write to temporary config file: " & strTempFile, "", objInfo, MAX_LEN, 1, 1)
					End If
					Call TrDebug ("INFO: Temporary config file created: " & strTempFile, "", objDebug, MAX_LEN, 1, nDebug)
     				Set objInventoryFile = objFSO.OpenTextFile(strDirInventory & "\" & strFile)
					Call TrDebug ("INFO: Start processing: " & strDirInventory & "\" & strFile, "", objDebug, MAX_LEN, 3, nDebug)
					Call TrDebug ("INFO: Start processing: " & strDirInventory & "\" & strFile, "", objInfo, MAX_LEN, 3, 1)					
					nLine = 1
					Do While objInventoryFile.AtEndOfStream <> True
						strLine = objInventoryFile.ReadLine
						If Not InStr(strLine,"#") Then 
							If Ubound(Split(strLine,",")) < 2 Then 
								Call TrDebug ("ERROR: Wrong format of the Inventory file: " & strDirInventory & "\" & strFile & " Line: " & nLine + 1, "", objInfo, MAX_LEN, 1, 1)
								Call TrDebug ("ERROR: Wrong format of the Inventory file: " & strDirInventory & "\" & strFile & " Line: " & nLine + 1, "", objDebug, MAX_LEN, 1, nDebug)								
								nResult = -1
								Exit Do
							End If
							strSerial_no = RTrim(LTrim(Split(strLine,",")(1)))
							objFSO.CopyFile strTempFile, strDirConfig & "\" & strSerial_no & ".conf", True
							Call TrDebug ("INFO: Configlet for S/N: " & strSerial_no & " populated", "", objInfo, MAX_LEN, 1, 1)
							nLine = nLine + 1
						End If
					Loop
					objInventoryFile.close
					Backup_Index = DateDiff(SECONDS, D0, Date() & " " & Time())
					objFSO.CopyFile strConfigletFileName, strDirConfig & "\" & Left(strFile,Len(strFile)-4) & "_" & Backup_Index & ".bkp", True
					objFSO.DeleteFile strConfigletFileName, True
					objFSO.CopyFile strDirInventory & "\" & strFile, strDirInventory & "\" & Left(strFile,Len(strFile)-4) & "_" & Backup_Index & ".csv.bkp", True					
					objFSO.DeleteFile strDirInventory & "\" & strFile, True
					objFSO.DeleteFile strTempFile, True
					Call TrDebug ("INFO: END processing: " & strDirInventory & "\" & strFile, "", objDebug, MAX_LEN, 3, nDebug)
					Call TrDebug ("INFO: END processing: " & strDirInventory & "\" & strFile, "", objInfo, MAX_LEN, 3, 1)					
				Else 
    				Call TrDebug ("INFO: Can't find configlet file: " & strConfigletFileName, "", objDebug, MAX_LEN, 1, nDebug)
				End If
			End If
		Next
		Call TrDebug ("INFO: NOW SLEEP FOR: " & SLEEP/1000 & " sec", "", objDebug, MAX_LEN, 1, nDebug)
		WScript.Sleep SLEEP
	Loop
End Sub
'-----------------------------------------------------------------
'     Function GetMyDate()
'-----------------------------------------------------------------
Function GetMyDate()
	GetMyDate = Month(Date()) & "/" & Day(Date()) & "/" & Year(Date()) 
End Function
' ----------------------------------------------------------------------------------------------
'   Function  TrDebug (strTitle, strString, objDebug)
'   nFormat: 
'	0 - As is
'	1 - Strach
'	2 - Center
' ----------------------------------------------------------------------------------------------
Function  TrDebug (strTitle, strString, objDebug, nChar, nFormat, nDebug)
Dim strLine
strLine = ""
If nDebug <> 1 Then Exit Function End If
If IsObject(objDebug) Then 
	Select Case nFormat
		Case 0
			strLine = GetMyDate() & " " & FormatDateTime(Time(), 3) 
			strLine = strLine & ":  " & strTitle
			strLine = strLIne & strString
			objDebug.WriteLine strLine
			
		Case 1
			strLine = GetMyDate() & " " & FormatDateTime(Time(), 3)
			strLine = strLine & ":  " & strTitle
			If nChar - Len(strLine) - Len(strString) > 0 Then 
				strLine = strLine & Space(nChar - Len(strLine) - Len(strString)) & strString
			Else 
				strLine = strLine & " " & strString
			End If
			objDebug.WriteLine strLine
		Case 2
			strLine = GetMyDate() & " " & FormatDateTime(Time(), 3) & ":  "
			
			If nChar - Len(strLine & strTitle & strString) > 0 Then 
					strLine = strLine & Space(Int((nChar - 1 - Len(strLine & strTitle & strString))/2)) & strTitle & " " & strString			
			Else 
					strLine = strLine & strTitle & " " & strString	
			End If
			objDebug.WriteLine strLine
		Case 3
			strLine = GetMyDate() & " " & FormatDateTime(Time(), 3) & ":  "
			For i = 0 to nChar - Len(strLine)
				strLIne = strLIne & "-"
			Next
			objDebug.WriteLine strLine
			strLine = GetMyDate() & " " & FormatDateTime(Time(), 3) & ":  "
			If nChar - 1 - Len(strLine & strTitle & strString) > 0 Then 
					strLine = strLine & Space(Int((nChar - 1 - Len(strLine & strTitle & strString))/2)) & strTitle & " " & strString			
			Else 
					strLine = strLine & strTitle & " " & strString	
			End If
			objDebug.WriteLine strLine
			strLine = GetMyDate() & " " & FormatDateTime(Time(), 3) & ":  "
			For i = 0 to nChar - Len(strLine)
				strLIne = strLIne & "-"
			Next
			objDebug.WriteLine strLine
	End Select
End If
End Function
'-----------------------------------------------------------------------------------
' Displays a Message Box with Cancel / Continue buttons                 
'-----------------------------------------------------------------------------------
Function Continue(strMsg, strTitle)
    ' Set the buttons as Yes and No, with the default button
    ' to the second button ("No", in this example)
    nButtons = vbYesNo + vbDefaultButton2
    
    ' Set the icon of the dialog to be a question mark
    nIcon = vbQuestion
    
    ' Display the dialog and set the return value of our
    ' function accordingly
    If MsgBox(strMsg, nButtons + nIcon, strTitle) <> vbYes Then
        Continue = False
    Else
        Continue = True
    End If
End Function 
'#######################################################################
' Function GetFileLineCountSelect - Returns number of lines int the text file
'#######################################################################
 Function GetFileLineCountSelect(strFileName, ByRef vFileLines,strChar1, strChar2, strChar3, nDebug)
    Dim nIndex
	Dim strLine
	Dim objDataFileName
    strFileWeekStream = ""	
	If objFSO.FileExists(strFileName) Then 
		On Error Resume Next
		Err.Clear
		Set objDataFileName = objFSO.OpenTextFile(strFileName)
		If Err.Number <> 0 Then 
			Call TrDebug("GetFileLineCountSelect: ERROR: CAN'T OPEN FILE:", strFileName, objDebug, MAX_LEN, 0, 1)
			On Error Goto 0
			Redim vFileLines(0)
			GetFileLineCountSelect = 0
			Exit Function
		End If
	Else
	    Call TrDebug("GetFileLineCountSelect: ERROR: CAN'T FIND FILE:", strFileName, objDebug, MAX_LEN, 0, 1)
		Redim vFileLines(0)
		GetFileLineCountSelect = 0
		Exit Function
	End If 
    Redim vFileLines(0)
	Set objDataFileName = objFSO.OpenTextFile(strFileName)	
	If nDebug = 1 Then objDebug.WriteLine "           NOW TRYING TO RIGHT INTO AN ARRAY        "
	nIndex = 0
    Do While objDataFileName.AtEndOfStream <> True
		strLine = objDataFileName.ReadLine
		Select Case Left(strLine,1)
			Case strChar1
			Case strChar2
			Case strChar3
			Case Else
					Redim Preserve vFileLines(nIndex + 1)
					vFileLines(nIndex) = strLine
					If nDebug = 1 Then objDebug.WriteLine "GetFileLineCountSelect: vFileLines(" & nIndex & ")="  & vFileLines(nIndex) End If  
					nIndex = nIndex + 1
		End Select
	Loop
	objDataFileName.Close
    GetFileLineCountSelect = nIndex
End Function
 '#######################################################################
 ' Creates File if it doesn't exists
 ' nMode = 2  Then Append
 ' nMode = 1  Then Rewire all File content
 ' Function WriteArrayToFile - Returns number of lines int the text file
 '#######################################################################
 Function WriteArrayToFile(strFile,vFileLine, nFileLine,nMode,nDebug)
    Dim i, nCount
	Dim strLine
	Dim objDataFileName, objFSO
	
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	If Not objFSO.FileExists(strFile) Then 	
		On Error Resume Next
		Err.Clear
		Set objDataFileName = objFSO.CreateTextFile(strFile)
		If Err.Number = 0 Then 
			objDataFileName.close
			On Error Goto 0
		Else
			Set objFSO = Nothing
			If IsObject(objDebug) Then 
				objDebug.WriteLine GetMyDate() & " " & FormatDateTime(Time(), 3) & ": WriteArrayToFile: ERROR: CAN'T CREATE FILE " & strFile
				objDebug.WriteLine GetMyDate() & " " & FormatDateTime(Time(), 3) & ": WriteArrayToFile:  Error: " & Err.Number & " Srce: " & Err.Source & " Desc: " &  Err.Description
			End If
			WriteArrayToFile = False
			On Error Goto 0
			Exit Function
		End If
	End If
	
	Select Case nMode
		Case 1 
			Set objDataFileName = objFSO.OpenTextFile(strFile,2,True)
		Case 2 	
			Set objDataFileName = objFSO.OpenTextFile(strFile,8,True)
	End Select 
	i = 0
	On Error Resume Next
	Err.Clear
	Do While i < nFileLine
		objDataFileName.WriteLine vFileLine(i)
		If Err.Number <> 0 Then 
			If IsObject(objDebug) Then 
				objDebug.WriteLine GetMyDate() & " " & FormatDateTime(Time(), 3) & ": WriteArrayToFile: ERROR: CAN'T WRITE TO FILE " & strFile
				objDebug.WriteLine GetMyDate() & " " & FormatDateTime(Time(), 3) & ": WriteArrayToFile:  Error: " & Err.Number & " Srce: " & Err.Source & " Desc: " &  Err.Description
			End If
			WriteArrayToFile = False
			Exit Do 			
		End If
		i = i + 1
	Loop
	On Error Goto 0
	If i = nFileLine Then WriteArrayToFile = True End If
	objDataFileName.close
	Set objFSO = Nothing
End Function