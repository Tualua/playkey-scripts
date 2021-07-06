[CmdletBinding(DefaultParametersetName='None')]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Offsets,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$HostIP,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$HostName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ExtIP,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ExtIface,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][int]$VMBase,
    [Parameter(ParameterSetName='UseVMNumber', Mandatory=$false)][switch]$UseVMNumber,
    [Parameter(ParameterSetName='UseVMNumber', Mandatory=$true)][int]$FirstVMNumber
)
function Get-FirewallRuleString {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Comment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtIf,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtIP,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int16]$ExtPort,

        [Parameter(Mandatory)]
        [ValidateSet('tcp','udp')]
        [string]$Protocol,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IntIP,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int16]$IntPort
    )

    return "/ip firewall nat add action=dst-nat chain=dstnat comment={0} dst-address={1} dst-port={2} in-interface={3} protocol={4} to-addresses={5} to-ports={6}" -f $Comment, $ExtIP, $ExtPort, $ExtIf, $Protocol, $IntIP, $IntPort
}

$SSHPort = 14009
$TCPPorts = 14000,14001
$UDPPorts = 14010,14011,14012,14013

[string[]]$MikrotikScript = @()

$_Offsets = $Offsets.Split(',')
$_HostIP = [ipaddress]$HostIP.Trim()

for ($i=1; $i -le $_Offsets.Count; $i++) {
    $Octets = $_HostIP.ToString().Split('.')[0..2]
    if ($UseVMNumber) {
        $Octets += [string]([int]$VMBase + $FirstVMNumber + $i - 1)
        $VMIP = $Octets -join '.'
        $VMNum = $FirstVMNumber + $i - 1
    } else {
        $Octets += [string]([int]$VMBase + [int]$_Offsets[$i-1])
        $VMIP = $Octets -join '.'
        $VMNum = [int]$_Offsets[$i-1]
    }
    $MikrotikScript += Get-FirewallRuleString -Comment $("`"SSH {0}`"" -f $HostName) -ExtIf $ExtIface -ExtIP $ExtIP -ExtPort ($SSHPort + [int]$_Offsets[$i-1]*100) `
    -Protocol 'tcp' -IntPort $SSHPort -IntIP $_HostIP
    foreach ($TCPPort in $TCPPorts) {
        $MikrotikScript += Get-FirewallRuleString -Comment $("`"vm{0}`"" -f $VMNum) -ExtIf $ExtIface -ExtIP $ExtIP -ExtPort ($TCPPort + [int]$_Offsets[$i-1]*100) `
        -Protocol 'tcp' -IntPort ($TCPPort + [int]$_Offsets[$i-1]*10) -IntIP $_HostIP
    }
    foreach ($UDPPort in $UDPPorts) {
        $MikrotikScript += Get-FirewallRuleString -Comment $("`"vm{0}`"" -f $VMNum) -ExtIf $ExtIface -ExtIP $ExtIP -ExtPort ($UDPPort + [int]$_Offsets[$i-1]*100) `
        -Protocol 'udp' -IntPort $UDPPort $VMIP
    }
}


$MikrotikScript | Out-File "$Hostname-$ExtIP-$_HostIP.rsc"
