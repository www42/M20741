# MOC 20741B Lab Creating and Using Hyper-V Virtual Switches (Module 10)
#
# Exercise 1
# ----------

$DC1 = "20741B-LON-DC1-B"
$SVR1 = "20741B-LON-SVR1-B"
$CL1 = "20741B-LON-CL1-B"

# 1 - 3. Start LON-DC1
Get-VM
Update-VMVersion -Name $DC1 -Force # Prerequ for PowerShell Direct
Start-VM -Name $DC1 

# 4 - 5. Connect to LON-DC1
$PW = ConvertTo-SecureString -String 'Pa55w.rd' -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential 'Adatum\Administrator',$PW
$DC1 = New-PSSession -VMName '20741B-LON-DC1-B' -Credential $Cred

# 6. Repeat steps 3 through 5 for 20741B-LON-SVR1-B and 20741B-LON-CL1-B
Start-VM -Name '20741B-LON-SVR1-B','20741B-LON-CL1-B'

# 7 - 8. Confirm Private Network exists
Get-VMSwitch
Get-VMNetworkAdapter -All | ? SwitchName -eq "Private Network" | ft VMName,IPaddresses

# 9 - 12. Create External Virtual Switch
