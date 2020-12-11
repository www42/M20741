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


# 12-18 Install DHCP Server (on LON-SVR1)
# ---------------------------------------
Invoke-Command -Session $SVR1Session {Install-WindowsFeature -Name DHCP,RSAT-DHCP}
Invoke-Command -Session $SVR1Session {Add-DhcpServerSecurityGroup}
Invoke-Command -Session $SVR1Session {Restart-Service -Name DHCPServer}
Invoke-Command -Session $SVR1Session {Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2}


# 19-20. Authorize LON-SVR1
# -------------------------
Invoke-Command -Session $SVR1Session {Add-DhcpServerInDC}


# 21-30. New DHCP scope (on LON-SVR1)
# -----------------------------------

Invoke-Command -Session $SVR1Session {Add-DhcpServerv4Scope -Name "Lab 10 Scope" `
                                                            -StartRange   "172.16.0.200" `
                                                            -EndRange     "172.16.0.210" `
                                                            -SubnetMask   "255.255.0.0" }
Invoke-Command -Session $SVR1Session {Get-DhcpServerv4Scope -ScopeId "172.16.0.0" | Set-DhcpServerv4OptionValue -Router "172.16.0.1"}


# 31-32.Confirm activate scope selection
# --------------------------------------
Invoke-Command -Session $SVR1Session {Get-DhcpServerv4Scope -ScopeId "172.16.0.0" | % State}



# 33-34. Prevent LON-DC1 from issuing DHCP lease
# ----------------------------------------------
Set-VMNetworkAdapter -VMName $DC1 -DhcpGuard On
Set-VMNetworkAdapter -VMName $SVR1 -DhcpGuard Off


# 35-36. Renew IP configuration (on LON-CL1)
# ------------------------------------------
Invoke-Command -Session $CL1Session {ipconfig /release}
Invoke-Command -Session $CL1Session {ipconfig /renew}


# 37-39. Confirm DHCP server (on LON-CL1)
# ---------------------------------------
Invoke-Command -Session $CL1Session {Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4}






# ------------------
# Exercise 3 VLANs
# ------------------

# 1-3. Delete LON-SVR1 NIC Team
Invoke-Command -Session $SVR1Session {Remove-NetLbfoTeam  -Name "LON-SVR1 NIC Team" -Confirm:$false}


# 4-5. Enable VLAN ID for "External Switch" (for LON-HOST1)
# ---------------------------------------------------------
#
#   IP Address LON-HOST1:
    Get-NetIPAddress -AddressFamily IPv4 | ? InterfaceAlias -like *External* | % IPAddress
#     --> 172.16.10.100
#
#   IP Address LON-SVR1:
    Get-VMNetworkAdapter -VMName $SVR1 | ? SwitchName -eq "External Switch" | % IPaddresses
#     --> 172.16.10.102
#
#   ping?
    Test-NetConnection -ComputerName 172.16.10.102
#     --> yes we can!
#
#   ----------------------------
Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "External Switch" -Access -VlanId 2
Get-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName "External Switch"



# 6-7. Enable VLAN ID for "New Network Adapter" (for LON-SVR1)
# ------------------------------------------------------------

Set-VMNetworkAdapterVlan -VMName $SVR1 -VMNetworkAdapterName "New Network Adapter" -Access -VlanId 2
Get-VMNetworkAdapterVlan -VMName $SVR1 -VMNetworkAdapterName "New Network Adapter" 


# 8-9. Enable bandwidth management (for LON-SVR1)
# -----------------------------------------------
Set-VMNetworkAdapter -VMName $SVR1 -VMNetworkAdapterName "New Network Adapter" -MinimumBandwidthAbsolute 100MB


# 10-16. Observe Ethernet usage (on LON-SVR1)
# -------------------------------------------
# --> GUI


# 17-18. Change "New Network Adapter"'s Virtual Switch
# ----------------------------------------------------
Disconnect-VMNetworkAdapter -VMName $SVR1 -VMNetworkAdapterName "New Network Adapter"


# 19-21. Remove "External Switch"
# -------------------------------
Remove-VMSwitch -Name "External Switch" -Force
Get-VMSwitch