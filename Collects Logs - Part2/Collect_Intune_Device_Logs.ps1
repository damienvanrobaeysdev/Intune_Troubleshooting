#================================================================================================================
#
# Script purpose : Collect Intune Device Logs and upload them on GitHub
# Author 		 : Damien VAN ROBAEYS
# Twitter 		 : @syst_and_deploy
# Blog 		     : http://www.systanddeploy.com/
#
#================================================================================================================

$Current_Folder = split-path $MyInvocation.MyCommand.Path
$SystemRoot = $env:SystemRoot
$CompName = $env:computername

$Current_Folder = split-path $MyInvocation.MyCommand.Path
$xml = "$Current_Folder\GitHub_Infos.xml"
$my_xml = [xml] (Get-Content $xml)
$GitHub_Token = $my_xml.Configuration.GitHub_Token
$GitHub_Repo = $my_xml.Configuration.GitHub_Repository
$GitHub_Owner = $my_xml.Configuration.GitHub_OwnerName

$Log_File = "$SystemRoot\Debug\Collect_Intune_Logs_GitHub_$CompName.log"
$Logs_Collect_Folder = "C:\Intune_Logs_From" + "_$CompName"
$Logs_Collect_Folder_ZIP = "$Logs_Collect_Folder.zip"

$EVTX_files = "$Logs_Collect_Folder\EVTX_Files"
$MDMDiagnostic_Logs = "$Logs_Collect_Folder\MDMDiagnostic_Logs"
$ProgData = $env:ProgramData
$Device_IntuneManagementExtension = "$ProgData\Microsoft\IntuneManagementExtension\*"
$Save_IntuneManagementExtension = "$Logs_Collect_Folder\IntuneManagementExtension"

If(!(test-path $Logs_Collect_Folder)){new-item $Logs_Collect_Folder -type Directory -force | out-null}
If(!(test-path $EVTX_files)){new-item $EVTX_files -type Directory -force | out-null}
If(!(test-path $MDMDiagnostic_Logs)){new-item $MDMDiagnostic_Logs -type Directory -force | out-null}
If(!(test-path $Save_IntuneManagementExtension)){new-item $Save_IntuneManagementExtension -type Directory -force | out-null}

If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}
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
	
Function Export_MDMDiag_Report
	{
		param(
		$Type_Log,
		$Area_Cat
		)
		
		Add-content $Log_File ""
		Try
			{
				If($Type_Log -eq "Out")
					{
						$File_Category = "Main_Log.html"
						Write_Log -Message_Type "INFO" -Message "Collecting main diagnostic report"
						MdmDiagnosticsTool.exe -out "$MDMDiagnostic_Logs\Logs" | out-null
						Remove-item $MDMDiagnostic_Logs\Logs -Recurse -Force
					}
				Else
					{
						$File_Category = "Area_Cat.cab"
						Write_Log -Message_Type "INFO" -Message "Collecting $Area_Cat diagnostic report"
						MdmDiagnosticsTool.exe -area $Area_Cat -cab "$MDMDiagnostic_Logs\$Area_Cat.cab" | out-null
					}
				Write_Log -Message_Type "SUCCESS" -Message "MDM Diagnostic logs $File_Category has been successfully exported"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting MDM Diagnostic logs $File_Category"
			}
	}

Write_Log -Message_Type "INFO" -Message "Starting collecting Intune logs on $CompName"

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 1 - Collecting event logs"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"

Add-content $Log_File ""
Write_Log -Message_Type "INFO" -Message "Collecting logs from: Microsoft System"
	
Export_Event_Logs -Log_To_Export "System" -Log_Output $EVTX_files -File_Name "System"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin" -Log_Output $EVTX_files -File_Name "MDM_Admin"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational" -Log_Output $EVTX_files -File_Name "MDM_Operational"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-AAD/Analytic" -Log_Output $EVTX_files -File_Name "AAD_Analytic"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-AAD/Operational" -Log_Output $EVTX_files -File_Name "AAD_Operational"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot" -Log_Output $EVTX_files -File_Name "ModernDeployment_Autopilot"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Admin" -Log_Output $EVTX_files -File_Name "ModernDeployment_Admin"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-ModernDeployment-Diagnostics-Provider/ManagementService" -Log_Output $EVTX_files -File_Name "ModernDeployment_ManagementService"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-AppxDeploymentServer/Operational" -Log_Output $EVTX_files -File_Name "AppxDeploymentServer_Operational"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-assignedaccess/Operational" -Log_Output $EVTX_files -File_Name "assignedaccess_Operational"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-assignedaccess/Admin" -Log_Output $EVTX_files -File_Name "assignedaccess_Admin"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-assignedaccessbroker/Operational" -Log_Output $EVTX_files -File_Name "assignedaccessbroker_Operational"
Export_Event_Logs -Log_To_Export "Microsoft-Windows-assignedaccessbroker/Admin" -Log_Output $EVTX_files -File_Name "assignedaccessbroker_Admin"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-provisioning-diagnostics-provider/Admin" -Log_Output $EVTX_files -File_Name "ProvisioningDiag_Admin"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-shell-core/Operational" -Log_Output $EVTX_files -File_Name "shellCore_Operational"

Export_Event_Logs -Log_To_Export "Microsoft-Windows-user device registration/Admin" -Log_Output $EVTX_files -File_Name "UserDeviceRegistration_Admin"

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 2 - Exporting report with MdmDiagnosticsTool"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Export_MDMDiag_Report -Type_Log "Out" 
Export_MDMDiag_Report -Type_Log "Area" -Area_Cat "Autopilot"	
Export_MDMDiag_Report -Type_Log "Area" -Area_Cat "DeviceEnrollment"	
Export_MDMDiag_Report -Type_Log "Area" -Area_Cat "DeviceProvisioning"	
# Export_MDMDiag_Report -Type_Log "Area" -Area_Cat "TPM"	

Add-content $Log_File ""
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Write_Log -Message_Type "INFO" -Message "Step 3 - Exporting logs from IntuneManagementExtension folder"
Add-content $Log_File "---------------------------------------------------------------------------------------------------------"
Try
	{
		Copy-item $Device_IntuneManagementExtension $Save_IntuneManagementExtension -Recurse -Force 
		Write_Log -Message_Type "SUCCESS" -Message "Logs from IntuneManagementExtension have been successfully copied"		
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while copying IntuneManagementExtension logs"		
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

