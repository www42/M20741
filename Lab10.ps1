# MOC 20741B Lab Creating and Using Hyper-V Virtual Switches (Module 10)
#
# Exercise 1
# ----------

$DC1  = "20741B-LON-DC1-B"
$SVR1 = "20741B-LON-SVR1-B"
$CL1  = "20741B-LON-CL1-B"

$PW = ConvertTo-SecureString -String 'Pa55w.rd' -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential 'Adatum\Administrator',$PW


# 1-3. Start LON-DC1
# --------------------
Get-VM
Update-VMVersion -Name $DC1 -Force      # Prerequisite for PowerShell Direct
Update-VMVersion -Name $SVR1 -Force
Start-VM -Name $DC1 


# 4-5. Connect to LON-DC1
# -------------------------
$DC1 = New-PSSession -VMName '20741B-LON-DC1-B' -Credential $Cred


# 6. Repeat steps 3 through 5 for 20741B-LON-SVR1-B and 20741B-LON-CL1-B
# ----------------------------------------------------------------------
Start-VM -Name '20741B-LON-SVR1-B','20741B-LON-CL1-B'


# 7-8. Confirm Private Network exists
# -------------------------------------
Get-VMSwitch
Get-VMNetworkAdapter -All | ? SwitchName -eq "Private Network" | ft VMName,IPaddresses


# 9-12. Create External Virtual Switch
# --------------------------------------
$NetAdapter = Get-NetAdapter | % Name
New-VMSwitch -Name "External Switch" -NetAdapterName $NetAdapter -AllowManagementOS $true


# 13-14. Create Internal Switch
# -------------------------------
New-VMSwitch -Name "Internal Switch" -SwitchType Internal


# 15-16. Shutdown LON-SVR1
# --------------------------
Stop-VM -Name $SVR1


# 17-18. Create Network Adapter on LON-SVR1
# -----------------------------------------
Add-VMNetworkAdapter -VMName $SVR1 -Name "New Network Adapter"
Connect-VMNetworkAdapter -VMName $SVR1 -Name "New Network Adapter" -SwitchName "External Switch"


# 19-20. View new network adapter's configuration
# -----------------------------------------------
Get-VMNetworkAdapter -VMName $SVR1 -Name "New Network Adapter"


# 21. Start LON-SVR1
# ------------------
Start-VM -Name $SVR1


# 22-23. Sign in to LON-SVR1
# --------------------------
$SVR1Session = New-PSSession -VMName $SVR1 -Credential $Cred


# 24-27. Open Ethernet 2 details (on LON-SVR1)
# --------------------------------------------
Invoke-Command -Session $SVR1Session {Get-NetAdapter -Name "Ethernet 2"}
$IfIndex = Invoke-Command -Session $SVR1Session {Get-NetAdapter -Name "Ethernet 2" | % InterfaceIndex}


# 28. View IP address (on LON-SVR1)
# ---------------------------------
Invoke-Command -Session $SVR1Session {Get-NetIPConfiguration -InterfaceIndex $using:IfIndex}


# 29-31. Configure new team (on LON-SVR1)
# ---------------------------------------
Invoke-Command -Session $SVR1Session {New-NetLbfoTeam -Name "LON-SVR1 NIC Team" -TeamMembers "Ethernet 2" -Confirm:$false}


# 32. View NIC teaming settings (on LON-SVR1)
# ------------------------------------------
Invoke-Command -Session $SVR1Session 