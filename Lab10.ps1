# MOC 20741B Lab Creating and Using Hyper-V Virtual Switches (Module 10)
#

# ---------------------------
# Exercise 1 Virtual Switches
# ---------------------------

$DC1  = "20741B-LON-DC1-B"
$SVR1 = "20741B-LON-SVR1-B"
$CL1  = "20741B-LON-CL1-B"

Update-VMVersion -Name $DC1,$SVR1,$CL1 -Force      # Prerequisite for PowerShell Direct

$PW = ConvertTo-SecureString -String 'Pa55w.rd' -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential 'Adatum\Administrator',$PW


# 1-3. Start LON-DC1
# --------------------
Get-VM
Start-VM -Name $DC1 


# 4-5. Connect to LON-DC1
# -----------------------
$DC1 = New-PSSession -VMName '20741B-LON-DC1-B' -Credential $Cred


# 6. Start LON-SVR1 and LON-CL1
# -----------------------------
Start-VM -Name $SVR1,$CL1



# 7-8. Confirm "Private Network" exists
# -------------------------------------
Get-VMSwitch
Get-VMNetworkAdapter -All | ? SwitchName -eq "Private Network" | ft VMName,IPaddresses


# 9-12. Create External Virtual Switch
# ------------------------------------
$NetAdapter = Get-NetAdapter | % Name
New-VMSwitch -Name "External Switch" -NetAdapterName $NetAdapter -AllowManagementOS $true


# 13-14. Create internal switch
# -----------------------------
New-VMSwitch -Name "Internal Switch" -SwitchType Internal


# 15-16. Shutdown LON-SVR1
# -------------------------
Stop-VM -Name $SVR1


# 17-18. Create network adapter on LON-SVR1
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





# -------------------------
# Exercise 2 DHCP Guarding
# -------------------------

# 1. Open LON-SVR1 settings
# -------------------------
Get-VMNetworkAdapter -VMName $SVR1 -Name "Network Adapter" | fl SwitchName,MacAddress,MacAddressSpoofing,DhcpGuard,RouterGuard

# 2. Enable DHCP guard on LON-SVR1
# --------------------------------
Set-VMNetworkAdapter -VMName $SVR1 -Name "Network Adapter" -DhcpGuard On

# 3. Enable DHCP guard on LON-CL1
# -------------------------------
Set-VMNetworkAdapter -VMName $CL1 -Name "Network Adapter" -DhcpGuard On
Get-VMNetworkAdapter -VMName $CL1 -Name "Network Adapter" | fl SwitchName,MacAddress,MacAddressSpoofing,DhcpGuard,RouterGuard

# 4-8. Note TCP/IP settings (on LON-CL1)
# --------------------------------------
$CL1Session = New-PSSession -VMName $CL1 -Credential $Cred
Invoke-Command -Session $CL1Session {Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4}


# 9. Set IPv4 to obtain addresses automatically
# ---------------------------------------------
Invoke-Command -Session $CL1Session {Set-NetIPInterface -InterfaceAlias "Ethernet" -AddressFamily IPv4 -Dhcp Enabled}


# 10-11. Note IPv4 DHCP server
# ----------------------------
Invoke-Command -Session $CL1Session {Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4}
