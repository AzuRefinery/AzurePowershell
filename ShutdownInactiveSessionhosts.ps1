Connect-Azaccount -identity

$all_hostpools=Get-AzResource | Select-Object Name,ResourceGroupName,ResourceType | Where-Object {$_.ResourceType -EQ "Microsoft.DesktopVirtualization/hostpools"}
Foreach ($hostpool in $all_hostpools)
{
    # Retrieve all hostpools 
    $hostpooltype = Get-AzWvdHostPool -ResourceGroupName $hostpool.ResourceGroupName -HostPoolName $hostpool.Name
    # Edit the if statement to include the hostpool types you want to target
    if (($hostpooltype.HostPoolType -like "personal") -or ($hostpooltype.HostPoolType -like "pooled"))
    {
        $all_user_sessions = Get-AzWvdUserSession -ResourceGroupName $hostpool.ResourceGroupName -HostPoolName $hostpool.Name | select *
        $all_sessionhosts = Get-AzWvdSessionHost -ResourceGroupName $hostpool.ResourceGroupName -HostPoolName $hostpool.Name | select *
        $pattern = "\/(.*)\/"
        $sessions_arr=@()  # This array holds all Active and Disconnected sessions
        
        foreach ($user_session in $all_user_sessions)
            {
                $regex = [regex]::Matches($user_session.name ,$pattern)
                $sessions_arr += $regex.groups[1].value 
            }
        
        $sessionhosts_arr=@()   # This array holds all Session Hosts    
        foreach ($sessionhost in $all_sessionhosts)
            {
                $splitted=$sessionhost.Name -split("/")  
                $sessionhosts_arr+= $splitted[1]     
            }
        # Compare the two arrays and get the difference - This returns all session hosts that have no active or disconnected sessions
        $shutdowntargets = Compare-Object -ReferenceObject ($sessionhosts_arr) -DifferenceObject ($sessions_arr) -PassThru

        # If there are any session hosts that have no active or disconnected sessions - check if the VM is running and deallocate it

        if ($shutdowntargets -gt 0){
            foreach ($shutdowntarget in $shutdowntargets)
                {
                $vmpowerstate = Get-AzVM -status -VMName $shutdowntarget
                    if (($vmpowerstate.PowerState -like "VM running") ){
                        $vmrg = Get-AzResource | Select-Object Name,ResourceGroupName | Where-Object {$_.name -like $shutdowntarget}
                        Write-output "Deallocating VM: $shutdowntarget"
                        Stop-AzVM -Name $shutdowntarget -ResourceGroupName $vmrg.ResourceGroupName -Force -nowait -whatif
                    }
                }             
            }
    }
}

