class NetBoxAPI {
    [string]$uriBase
    [string]$lastkey
    hidden [string]$contentT = 'application/json'
    hidden [hashtable]$h = @{Accept='application/json;indent=4'}
    hidden [hashtable]$h2

    NetBoxAPI([string]$uribase) {
        $this.uriBase = $uribase
    }

<#  # INSECURE
    NetBoxAPI([string]$uribase, [string]$usr, [string]$pwd) {
        $this.uriBase = $uribase
        $this.lastkey = $this.GetToken([string]$usr, [string]$pwd) 
    }
#>

    NetBoxAPI([string]$uribase, [ref]$cred) {
        $this.uriBase = $uribase
        $this.lastkey = $this.GetToken($cred)
    }
    
    [string] GetToken([ref]$cred) {
        $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode(($cred.Value).password)
        try {
            $pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)

            [string[]]$body = (@{username=$(($cred.Value).UserName); password=$pwd}) | ConvertTo-Json -Depth 1 -Compress
            [string]$url = "$($this.uriBase)/api/users/tokens/provision/"
            $response = Invoke-RestMethod -Headers $this.h -Method Post -ContentType $this.contentT -uri $url -body $body

            $this.lastkey = $response.key
            $this.h2 = $this.auth()
            $result = $response.key
        }
        catch {
            $result = ''
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
            #$pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
        }
        return $result
    }

<#  #INSECURE
    [string] GetToken([string]$usr, [string]$pwd) {
        [string[]]$body = (@{username=$usr; password=$pwd}) | ConvertTo-Json -Depth 1 -Compress
        [string]$url = "$($this.uriBase)/api/users/tokens/provision/"
        $response = Invoke-RestMethod -Headers $this.h -Method Post -ContentType $this.contentT -uri $url -body $body

        $this.lastkey = $response.key
        $this.h2 = $this.auth()
        return $response.key
    }
#>
    hidden [hashtable] auth() {
        return $this.h + @{Authorization="Token $($this.lastkey)"}
    }

    [PSObject] GetSites() {
        return $this.GetSites($false)
    }

    [PSObject] GetSites([bool]$brief = $false) {
        [string]$url = "$($this.uriBase)/api/dcim/sites/"
        if ($brief) {
            $url += "?brief=1"
        }
        $results = Invoke-RestMethod -Method Get -ContentType $this.contentT -Headers $this.h2 -Uri $url
        return $results.results
    }

    [PSObject] GetIPAddresses([bool]$brief = $false) {
        [string]$url = "$($this.uriBase)/api/ipam/ip-addresses/"
        if ($brief) {
            $url += "?brief=1"
        }
        $results = Invoke-RestMethod -Method Get -ContentType $this.contentT -Headers $this.h2 -Uri $url
        #return $results #.results
        While ($null -ne $results.next -and '' -ne $results.next) {
            $url = $results.next
            $results2 = Invoke-RestMethod -Method Get -ContentType $this.contentT -Headers $this.h2 -Uri $url
            $results2.results = $results.results + $results2.results
            $results = $results2
        }        
        return $results.results
    }

    [PSObject] GetIPAddress([int]$ndx, [bool]$brief = $false) {
        [string]$url = "$($this.uriBase)/api/ipam/ip-addresses/$($ndx)/"
        if ($brief) {
            $url += "?brief=1"
        }
        $results = Invoke-RestMethod -Method Get -ContentType $this.contentT -Headers $this.h2 -Uri $url
        return $results
    }

    [PSObject] GetIPAddress([string]$ipv4) {
        return $this.GetIPAddress($ipv4, $false)
    }

    [PSObject] GetIPAddress([string]$ipv4, [bool]$brief = $false) {
        [string]$url = "$($this.uriBase)/api/ipam/ip-addresses/?q=$($ipv4)"
        if ($brief) {
            $url += "&brief=1"
        }
        $results = Invoke-RestMethod -Method Get -ContentType $this.contentT -Headers $this.h2 -Uri $url
        return $results.results
    }

    [PSObject] GetPrefixes() {
        return $this.GetPrefixes($false)
    }

    [PSObject] GetPrefixes([bool]$brief = $false) {
        [string]$url = "$($this.uriBase)/api/ipam/prefixes/"
        if ($brief) {
            $url += "?brief=1"
        }
        $results = Invoke-RestMethod -Method Get -ContentType $this.contentT -Headers $this.h2 -Uri $url
        While ($null -ne $results.next -and '' -ne $results.next) {
            $url = $results.next
            $results2 = Invoke-RestMethod -Method Get -ContentType $this.contentT -Headers $this.h2 -Uri $url
            $results2.results = $results.results + $results2.results
            $results = $results2
        }
        return $results.results
    }

    [PSObject] AddIP4Address([string]$ip4cidr, [string]$description=$null) {
        [string]$url = "$($this.uriBase)/api/ipam/ip-addresses/"
        [hashtable]$bod = @{address=$ip4cidr; status='active'}
        if ($null -ne $description -and '' -ne $description) {
            $bod += @{description=$description}
        }
        [string[]]$body = $bod | ConvertTo-Json -Depth 1 -Compress
        $response = Invoke-RestMethod -Method Post -ContentType $this.contentT -Headers $this.h2 -uri $url -body $body
        return $response
    }

    [PSObject] AddSite([string]$siteName, [string]$slug, [bool]$active=$true) {
        [string]$url = "$($this.uriBase)/api/dcim/sites/"
        if ($null -eq $slug -or '' -eq $slug) {
            $slug = $siteName.Replace(' ','-').Replace('.','').ToLower()
        }
        if($active) {
            [string]$status = 'active'
        }
        else {
            [string]$status = 'planned'
        }
        [string[]]$body = @{name=$siteName; slug=$slug; status=$status} | ConvertTo-Json -Depth 1 -Compress
        $response = Invoke-RestMethod -Method Post -ContentType $this.contentT -Headers $this.h2 -uri $url -body $body
        return $response
    }

    [PSObject] AddPrefix([string]$prefix, [string]$description, [int]$site) {
        [string]$url = "$($this.uriBase)/api/ipam/prefixes/"
        [hashtable]$bod = @{prefix=$prefix; status='active'}
        if ($null -ne $site) {
            $bod += @{site=$site}
        }
        if ($null -ne $description -and '' -ne $description) {
            $bod += @{description=$description}
        }
        [string[]]$body = $bod | ConvertTo-Json -Depth 1 -Compress
        $response = Invoke-RestMethod -Method Post -ContentType $this.contentT -Headers $this.h2 -uri $url -body $body
        return $response
    }

}


try {
    $credential = Import-Clixml -Path '.\credNetBox.cred'
    $f = [NetBoxAPI]::new('http://10.0.2.135:8000', [ref]$credential)
}
finally {
    $credential.Password.Clear()
    $credential.Password.Dispose()
}

$f.GetSites()