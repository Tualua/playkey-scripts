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

$_Offsets = Read-Host -Prompt "Enter offsets (comma separated)"
$_HostIP = Read-Host -Prompt "Enter host IP address"
$HostName = Read-Host -Prompt "Enter hostname"
$VMStartNumber = Read-Host -Prompt "Enter VM Start Number"
$ExternalAddress = Read-Host -Prompt 'Enter external IP address'
$ExternalIface = Read-Host -Prompt 'Enter external interface name'
$Offsets = $_Offsets.Split(',')
$HostIP = [ipaddress]$_HostIP.Trim()

for ($i=1; $i -le $Offsets.Count; $i++) {
    $Octets = $HostIP.ToString().Split('.')[0..2]
    $Octets += ([int]($HostIP.ToString().Split('.')[-1])+$i).ToString()
    $VMIP = $Octets -join '.'
    $MikrotikScript += Get-FirewallRuleString -Comment $("`"SSH {0}`"" -f $HostName) -ExtIf $ExternalIface -ExtIP $ExternalAddress -ExtPort ($SSHPort + [int]$Offsets[$i-1]*100) `
    -Protocol 'tcp' -IntPort $SSHPort -IntIP $HostIP
    foreach ($TCPPort in $TCPPorts) {
        $MikrotikScript += Get-FirewallRuleString -Comment $("`"vm{0}`"" -f $([int]$VMStartNumber+$i-1)) -ExtIf $ExternalIface -ExtIP $ExternalAddress -ExtPort ($TCPPort + [int]$Offsets[$i-1]*100) `
        -Protocol 'tcp' -IntPort ($TCPPort + [int]$Offsets[$i-1]*10) -IntIP $HostIP
    }
    foreach ($UDPPort in $UDPPorts) {
        $MikrotikScript += Get-FirewallRuleString -Comment $("`"vm{0}`"" -f $([int]$VMStartNumber+$i-1)) -ExtIf $ExternalIface -ExtIP $ExternalAddress -ExtPort ($UDPPort + [int]$Offsets[$i-1]*100) `
        -Protocol 'udp' -IntPort $UDPPort $VMIP
    }
}


$MikrotikScript | Out-File "$Hostname-$ExternalAddress-$HostIP.rsc"
