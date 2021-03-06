#================================================================================================================
#
# Script purpose : Collect Intune Device event logs, files and folders and upload them on Azure File Share
# Author 		 : Damien VAN ROBAEYS
# Twitter 		 : @syst_and_deploy
# Blog 		     : http://www.systanddeploy.com/
#
#================================================================================================================

$Current_Folder = split-path $MyInvocation.MyCommand.Path
$xml = "$Current_Folder\GitHub_Infos.xml"
$my_xml = [xml] (Get-Content $xml)
$GitHub_Token = $my_xml.Configuration.GitHub_Token
$GitHub_Repo = $my_xml.Configuration.GitHub_Repository
$GitHub_Owner = $my_xml.Configuration.GitHub_OwnerName

$SystemRoot = $env:SystemRoot
$CompName = $env:computername

$Get_Day_Date = Get-Date -Format "yyyyMMdd"
$Log_File = "$SystemRoot\Debug\Collect_Device_Content_$CompName" + "_$Get_Day_Date.log"
$Logs_Collect_Folder = "C:\Device_Logs_From" + "_$CompName" + "_$Get_Day_Date"
$Logs_Collect_Folder_ZIP = "$Logs_Collect_Folder" + ".zip"

$EVTX_files = "$Logs_Collect_Folder\EVTX_Files"
$Reg_Export = "$Logs_Collect_Folder\Export_Reg_Values.csv"
$Logs_Folder = "$Logs_Collect_Folder\All_logs"

$ProgData = $env:ProgramData
$Content_to_collect_File = "$Current_Folder\Content_to_collect.xml"
$Content_to_collect_XML = [xml] (Get-Content $Content_to_collect_File)

If(!(test-path $Logs_Collect_Folder)){new-item $Logs_Collect_Folder -type Directory -force | out-null}
If(!(test-path $EVTX_files)){new-item $EVTX_files -type Directory -force | out-null}
If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}
If(!(test-path $Logs_Folder)){new-item $Logs_Folder -type Directory -force | out-null}

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"			
	}
	
Function Export_Event_Logs
	{
		param(
		$Log_To_Export,	
		$Log_Output,
		$File_Name
		)	
		
		Add-content $Log_File ""	
		Write_Log -Message_Type "INFO" -Message "Collecting logs from: $Log_To_Export"
		Try
			{
				WEVTUtil export-log $Log_To_Export "$Log_Output\$File_Name.evtx" | out-null	
				Write_Log -Message_Type "SUCCESS" -Message "Event log $File_Name.evtx has been successfully exported"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting event log $File_Name.evtx"
			}
	}	
	
	
Function Export_Logs_Files_Folders
	{
		param(
		$Log_To_Export,	
		$Log_Output
		)	
		
		Add-content $Log_File ""			
		If(test-path $Log_To_Export)
			{
				$Content_Name = Get-Item $Log_To_Export
				Try
					{
						Copy-Item $Log_To_Export $Log_Output -Recurse -Force
						Write_Log -Message_Type "SUCCESS" -Message "The folder $Content_Name has been successfully copied"													
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "An issue occured while copying the folder $Content_Name"																				
					}
			}
		Else
			{
				Write_Log -Message_Type "ERROR" -Message "The following path does not exist: $Log_To_Export"			
			}
	}	
	
	
Function Export_Registry_Values
	{
		param(
		$Reg_Path,	
		$Reg_Specific_Value,
		$Output_Path
		)	
		
		Add-content $Log_File ""			
		If(test-path "registry::$Reg_Path")
			{					
				$Reg_Array = @()
				$Get_Reg_Values = Get-ItemProperty -path registry::$Reg_Path
				If($Reg_Specific_Value)
					{
						$List_Values = $Get_Reg_Values.$Reg_Specific_Value
						$Get_Reg_Values_Array = New-Object PSObject
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Name $Reg_Specific_Value -passthru
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Value $List_Values -passthru
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Reg_Path $Reg_Path -passthru
					}
				Else	
					{
						$List_Values = $Get_Reg_Values.psobject.properties | select name, value | Where-Object {($_.name -ne "PSPath" -and $_.name -ne "PSParentPath" -and $_.name -ne "PSChildName" -and $_.name -ne "PSProvider")}
						$Get_Reg_Values_Array = New-Object PSObject
						$Get_Reg_Values_Array = $List_Values
						$Get_Reg_Values_Array = $Get_Reg_Values_Array | Add-Member NoteProperty Reg_Path $Reg_Path -passthru
					}
				
				$Reg_Array += $Get_Reg_Values_Array
				
				If(!(test-path $Output_Path))
					{			
						Try
							{
								$Reg_Array | export-csv $Output_Path  -notype
								Write_Log -Message_Type "SUCCESS" -Message "Registry values from $Reg_Path have been successfully exported"													
							}
						Catch
							{
								Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting registry values from $Reg_Path"																				
							}					
					}
				Else
					{
						Try
							{
								$Reg_Array | export-csv -Append $Output_Path  -notype
								Write_Log -Message_Type "SUCCESS" -Message "Registry values from $Reg_Path have been successfully exported"													
							}
						Catch
							{
								Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting registry values from $Reg_Path"																				
							}															
					}					
			}
		Else
			{
				Write_Log -Message_Type "ERROR" -Message "The following REG path does not exist: $Reg_Path"			
			}
	}	


Write_Log -Message_Type "INFO" -Message "Starting collecting Intune logs on $CompName"

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 1 - Collecting event logs"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"	
$Events_To_Check = $Content_to_collect_XML.Content_to_collect.Event_Logs.Event_Log
ForEach($Event in $Events_To_Check)
	{
		$Event_Name = $Event.Event_Name
		$Event_Path = $Event.Event_Path	
		Export_Event_Logs -Log_To_Export $Event_Path -Log_Output $EVTX_files -File_Name $Event_Name		
	}
	
	
Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 2 - Copying files and folders"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"	
$Folder_To_Check = $Content_to_collect_XML.Content_to_collect.Folders.Folder_Path
ForEach($Explorer_Content in $Folder_To_Check)
	{		
		Export_Logs_Files_Folders -Log_To_Export $Explorer_Content -Log_Output $Logs_Folder		
	}	
	
	
Write_Log -Message_Type "INFO" -Message "Starting collecting Intune logs on $CompName"

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 3 - Collecting registry keys"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"	
$Reg_Keys_To_Check = $Content_to_collect_XML.Content_to_collect.Reg_Keys.Reg_Key
ForEach($Reg in $Reg_Keys_To_Check)
	{
		$Get_Reg_Path = $Reg.Reg_Path
		$Get_Reg_Specific_Value = $Reg.Reg_Specific_Value	
		Export_Registry_Values -Reg_Path $Get_Reg_Path -Reg_Specific_Value $Get_Reg_Specific_Value -Output_Path $Reg_Export
	}	


Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 4 - Creating the ZIP with logs"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Try
	{
		Add-Type -assembly "system.io.compression.filesystem"
		[io.compression.zipfile]::CreateFromDirectory($Logs_Collect_Folder, $Logs_Collect_Folder_ZIP) 
		Write_Log -Message_Type "SUCCESS" -Message "The ZIP file has been successfully created"			
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while creating the ZIP file"		
	}
 

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 5 - Checking GitHub module"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
 
If (!(Get-Module -listavailable | where {$_.name -like "*PowerShellForGitHub*"})) 
	{ 
		Try
			{
				Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Force 						
				Install-Module -Name PowerShellForGitHub -force -confirm:$false -ErrorAction SilentlyContinue 				
				Write_Log -Message_Type "SUCCESS" -Message "GitHub module has been successfully installed"	
				$GitHub_Module_Status = "OK"		
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while installing module"	
				$GitHub_Module_Status = "KO"		
			}			
	}
Else
	{
		Import-Module PowerShellForGitHub  -ErrorAction SilentlyContinue 	
		Write_Log -Message_Type "INFO" -Message "The module already exists"		
		$GitHub_Module_Status = "OK"				
	}


If($GitHub_Module_Status -eq "OK")
	{	
		Add-content $Log_File ""
		Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
		Write_Log -Message_Type "INFO" -Message "Step 6 - Uploading the ZIP logs on GitHub"
		Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
		Try
			{
				$GitHub_SecureToken = ConvertTo-SecureString $GitHub_Token -AsPlainText -Force
				$cred = New-Object System.Management.Automation.PSCredential "username is ignored", $GitHub_SecureToken
				Set-GitHubAuthentication -Credential $cred -SessionOnly | out-null	
				Write_Log -Message_Type "SUCCESS" -Message "Authentification OK to GitHub"	
				$GitHub_Status = "OK"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "Authentification KO to GitHub"	
				$GitHub_Status = "KO"		
			}	
			
				
		If($GitHub_Status -eq "OK")
			{
				Add-content $Log_File ""
				Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
				Write_Log -Message_Type "INFO" -Message "Step 7 - Encoding the ZIP file to base 64"
				Add-content $Log_File "---------------------------------------------------------------------------------------------------------"		
				Try
					{
						$Get_File_Name = (Get-ChildItem $Logs_Collect_Folder_ZIP).name					
						$Encoded_File = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$Logs_Collect_Folder_ZIP"));	
						Write_Log -Message_Type "SUCCESS" -Message "ZIP file has been successfully encoded to base 64"	
						$Encoding_Status = "OK"
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "An issue occured while encoding the ZIP file to base 64"	
						$Encoding_Status = "KO"		
					}	
			}	

		If($Encoding_Status -eq "OK")
			{
				Add-content $Log_File ""
				Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
				Write_Log -Message_Type "INFO" -Message "Step 8 - Uploading the ZIP to GitHub"
				Add-content $Log_File "---------------------------------------------------------------------------------------------------------"			
				Try
					{
$MyFile_JSON = @"
{
  "message": "",
  "content": "$Encoded_File"
}
"@

						Invoke-GHRestMethod -UriFragment "https://api.github.com/repos/$GitHub_Owner/$GitHub_Repo/contents/$Get_File_Name" -Method PUT -Body $MyFile_JSON
						Write_Log -Message_Type "SUCCESS" -Message "ZIP file has been successfully uploaded to GitHub"	
					}
				Catch
					{
						Write_Log -Message_Type "SUCCESS" -Message "An issue occured while uploading the ZIP file to GitHub"	
					}	
			}
			
		
		Add-content $Log_File ""
		Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
		Write_Log -Message_Type "INFO" -Message "Step 9 - Uninstalling GitHub module"
		Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
		
		Try
			{
				Uninstall-Module -Name PowerShellForGitHub -ErrorAction SilentlyContinue 
				Write_Log -Message_Type "SUCCESS" -Message "PowerShellForGitHub module has been successfully uninstalled"	
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while uninstalling module"	
			}			
	}
	
Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 10 - Removing temp collect folder and ZIP"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"

Try
	{
		Remove-Item $Logs_Collect_Folder -Recurse -Force
		Remove-Item $Logs_Collect_Folder_ZIP -Recurse -Force		
		Write_Log -Message_Type "SUCCESS" -Message "The collect folders have been removed"	
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while removing log collect folder"	
	}	

