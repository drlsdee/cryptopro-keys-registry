function Join-AttributeParts {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        # String array - splitted certificate field
        [string[]]
        $StringArray,

        [Parameter()]
        # Current string
        [string]
        $CurrentString    
    )
    # Attribute separator, default is '='
    [char]$attributeSeparator = '='
    [string]$myName = "[$($MyInvocation.MyCommand.Name)]:"
    Write-Verbose -Message "$myName Starting function..."
    if (-not $CurrentString) {
        $CurrentString = $StringArray[0]
    }
    $indexCurrent = $StringArray.IndexOf($CurrentString)
    Write-Verbose -Message "$myName Current string is [$indexCurrent]: `"$CurrentString`""
    if ($CurrentString -notmatch $attributeSeparator) {
        Write-Verbose -Message "$myName Current string [$indexCurrent]: `"$CurrentString`" - probably contains only part of attribute value. Nothing to return!"
        return
    } elseif ($indexCurrent -eq ($StringArray.Count - 1)) {
        Write-Verbose -Message "$myName Current string [$indexCurrent]: `"$CurrentString`" - is the LAST string and contains attribute name. Returning current string."
    } else {
        $indexNext = $indexCurrent + 1
        do {
            $CurrentString = (@($CurrentString, $stringNext) | Where-Object {$_}) -join ', '
            $stringNext = $StringArray[$indexNext]
            $indexNext++
            Write-Verbose -Message "$myName Next string [$indexNext]: `"$stringNext`"."
            Write-Verbose -Message "$myName Current value of current string is: `"$CurrentString`"."
        } while (($stringNext -notmatch $attributeSeparator) -and ($indexNext -lt $StringArray.Count))
        Write-Verbose -Message "$myName Final string: `"$CurrentString`". Returning..."
    }
    Write-Verbose -Message "$myName End of function."
    return $CurrentString
}

function Split-CertificateSubject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        # String array from certificate 'Subject' or 'issuer' fields - already filtered and joined
        [string[]]
        $InputArray,

        [Parameter()]
        [ValidateSet('Upper','Lower','Preserve')]
        # Switch case (default is UPPER)
        [string]
        $SwitchCase = 'Upper',

        [Parameter()]
        # Remove quotes
        [switch]
        $UnQuote,

        [Parameter()]
        # Select only unique attribute values
        [switch]
        $Unique,

        [Parameter()]
        # Skip empty attributes
        [switch]
        $SkipEmpty
    )
    # Field separator, default is '='
    [char]$attributeSeparator = '='
    [string]$myName = "[$($MyInvocation.MyCommand.Name)]:"
    Write-Verbose -Message "$myName Starting function..."
    $outputObject = New-Object -TypeName psobject
    foreach ($certAttribute in $InputArray) {
        switch ($SwitchCase) {
            'Upper' {$certAttribute = $certAttribute.ToUpper()}
            'Lower' {$certAttribute = $certAttribute.ToLower()}
            Default {$certAttribute = $certAttribute}
        }
        [string[]]$certAttributeSplitted = $certAttribute.Split($attributeSeparator)
        # Assuming that each attribute contains at least Attribute name
        [string]$attributeName = $certAttributeSplitted[0]
        [string[]]$attributeValue = $certAttributeSplitted[1]
        if ($UnQuote) {
            #$fieldValue = $fieldValue -replace '^"(.*)"$','$1'
            Write-Verbose -Message "$myName Unquoting attribute value: `"$attributeValue`""
            $attributeValue = $attributeValue -replace '"', ''
        }
        if ($SkipEmpty -and (-not $attributeValue)) {
            Write-Warning -Message "$myName Value of attribute `"$attributeName`" is empty! SKIPPING..."
        } else {
            if (-not $attributeValue) {Write-Warning -Message "$myName Value of attribute `"$attributeName`" is empty! SKIPPING..."}
            if (-not ($outputObject | Get-Member -Name $attributeName)) {
                Write-Verbose -Message "$myName Adding field `"$attributeName`" to output..."
                $outputObject | Add-Member -MemberType NoteProperty -Name $attributeName -Value $attributeValue
            } elseif ($Unique -and ($outputObject.$attributeName -contains $attributeValue)) {
                Write-Warning -Message "$myName Field `"$attributeName`" already present and contains value `"$attributeValue`"! Skipping..."
            } else {
                Write-Verbose -Message "$myName Field `"$attributeName`" already present! Adding value `"$attributeValue`""
                $outputObject.$attributeName += $attributeValue
            }
        }
    }
    Write-Verbose -Message "$myName End of function."
    return $outputObject
}

function Filter-CertificateSubject {
    [CmdletBinding()]
    <#
    TODO: Write help and comments
    Host version:
        Version          : 3.0
        CurrentCulture   : ru-RU
        CurrentUICulture : ru-RU
    #>
    param (
        # Certificate subject or issuer (as string from certificate fields)
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        ParameterSetName='Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
        $Certificate,

        # Certificate subject or issuer (as string from certificate field)
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        ParameterSetName='String')]
        [string[]]
        $Subject,

        [Parameter(ParameterSetName='Certificate')]
        # Field of certificate
        [ValidateSet('Subject','Issuer')]
        [string]
        $Field = 'Subject',

        [Parameter()]
        [ValidateSet('Upper','Lower','Preserve')]
        # Switch case (default is UPPER)
        [string]
        $SwitchCase = 'Upper',

        [Parameter()]
        # Remove quotes
        [switch]
        $UnQuote,

        [Parameter()]
        # Select only unique attribute values
        [switch]
        $UniqueAttribute,

        [Parameter()]
        # Select only unique subjects
        [switch]
        $UniqueSubject,

        [Parameter()]
        # Skip empty attributes
        [switch]
        $SkipEmpty,

        [Parameter()]
        # For multiple subjects; if set, merges all attributes with same names from all certificates into one field. "Unique" switch sets to "$true".
        [switch]
        $Merge
    )
    [string]$myName = "[$($MyInvocation.MyCommand.Name)]:"
    Write-Verbose -Message "$myName Starting function..."
    [string]$Separator = ", "
    if ((-not $Subject) -and (-not $Certificate)) {
        Write-Error -Message "$myName Subject or issuer not specified!"
        return
    } elseif ($Subject) {
        $InputStringArray = $Subject
    } elseif ($Certificate) {
        Write-Verbose -Message "$myName Working on certificate with thumbprint `"$($Certificate.Thumbprint)`", field is `"$Field`""
        $InputStringArray = $Certificate.$Field
    }
    if ($Merge) {
        $UniqueAttribute = $true
        $InputStringArray = $InputStringArray -join $Separator
    }

    [psobject[]]$outputObject = @()
    foreach ($InputString in $InputStringArray) {
        Write-Verbose -Message "$myName Start splitting string `"$InputString`"..."
        $inputStringSplitted = $InputString -split $Separator
        [string[]]$inputArray = $inputStringSplitted | ForEach-Object {Join-AttributeParts -StringArray $inputStringSplitted -CurrentString $_}
        if (-not $inputArray) {
            Write-Warning -Message "$myName Subject not parsed! Exiting..."
        } else {
            $outputObject += Split-CertificateSubject -InputArray $inputArray -UnQuote:$UnQuote -Unique:$UniqueAttribute -SkipEmpty:$SkipEmpty -SwitchCase $SwitchCase
        }
    }
    if ($UniqueSubject) {
        Write-Verbose -Message "$myName Filtering unique subjects..."
        $outputObject = $outputObject | Select-Object -Property * -Unique
    }
    Write-Verbose -Message "$myName End of function."
    return $outputObject
}
Export-ModuleMember -Function "Filter-CertificateSubject"

function New-Abbreviation {
    param (
        [Parameter(Mandatory=$true)]
        # Input array of strings
        [string[]]
        $StringArray,

        [Parameter()]
        # Max letters count per word (if some words will be shorter, these words will not be shortened).
        [int]
        $MaxWordLength = 3,

        [Parameter()]
        # Character for joining words
        [char]
        $JoinChar #= ''
    )
    $outArray = @()
    foreach ($word in $StringArray) {
        $subStringLength = $MaxWordLength
        if ($word.Length -lt $MaxWordLength) {
            $subStringLength = $word.Length
        }
        $wordShortened = $word.Substring(0,$subStringLength)
        $outArray += $wordShortened
    }
    [string]$outString = $outArray -join $JoinChar
    return $outString
}

<#
Date in format 'yyyy-MM-dd'
OrgSubject - 'O' as abbreviation
OrgSubject - 'CN' as 'Surname_Name_Patronym'
Roles from OIDs and .Extensions.EnhancedKeyUsages.Value
    OR
CA - CN from Issuer
#>