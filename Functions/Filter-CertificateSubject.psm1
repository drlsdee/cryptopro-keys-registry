function Filter-CertificateSubject {
    <#
    TODO: Write help and comments
    Host version:
        Version          : 3.0
        CurrentCulture   : ru-RU
        CurrentUICulture : ru-RU
    #>
    param (
        # Certificate subject (string from certificate field)
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        #ValueFromPipelineByPropertyName=$true,
        ParameterSetName = "Subject")]
        [string]
        $Subject,

        # Certificate issuer (string from certificate field)
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        #ValueFromPipelineByPropertyName=$true,
        ParameterSetName = "Issuer")]
        [string]
        $Issuer,

        [Parameter()]
        [switch]
        $AsObject,

        [Parameter()]
        [string]
        $Separator = ", "
    )
    begin {
        if ($Subject) {
            $InputString = $Subject
        } elseif ($Issuer) {
            $InputString = $Issuer
        } else {
            Write-Error -Message "Neither subject nor issuer specified!"
            break
        }
        Write-Verbose -Message "Start working with subject:"
        Write-Verbose -Message $InputString
        Write-Verbose -Message "Split subject by given separator:"
        Write-Verbose -Message $Separator
        $subjSplit = $InputString -split $Separator
        foreach ($substr in $subjSplit) {
            Write-Verbose -Message $substr
        }
        $arrayOfStrings = @()
    }
    process {
        $Count = $subjSplit.Count
        Write-Verbose  -Message "Subject has $Count unfiltered strings"
        $Index = 0
        while ($Index -lt $Count) {
            Write-Verbose -Message "Index of current unfiltered string is: $Index"
            $currentString = $subjSplit[$Index]
            Write-Verbose -Message "String content is:"
            Write-Verbose -Message $currentString
            if ($currentString -match "=") {
                Write-Verbose -Message "Current string starts with attribute name:"
                Write-Verbose -Message ($currentString -replace '=[\w*\W*\s*]*')
                $nextInd = $Index + 1
                $nextString = $subjSplit[$nextInd]
                if (-not $nextString) {
                    Write-Verbose -Message "Current string is last string"
                    $arrayOfStrings += $currentString
                }
                elseif ($nextString -match "=") {
                    Write-Verbose -Message "The NEXT string starts with attribute name:"
                    Write-Verbose -Message ($nextString -replace '=[\w*\W*\s*]*')
                    $arrayOfStrings += $currentString
                } else {
                    Write-Verbose -Message "The NEXT string contains part of the attribute value"
                    $ind = $nextInd
                    do {
                    $ind++
                    Write-Verbose $ind
                    $nxtStr = $subjSplit[$ind]
                    Write-Verbose -Message $nxtStr
                    } until ($nxtStr -match "=")
                    $joinPart = $subjSplit[$nextInd..($ind - 1)] -join $Separator
                    Write-Verbose -Message $joinPart
                    $joinedString = $currentString,$joinPart -join $Separator
                    Write-Verbose -Message $joinedString
                    $arrayOfStrings += $joinedString
                }
            } else {
                Write-Verbose -Message "The current string does not contain the attribute name"
            }
            $Index++
        }
    }
    end {
        if ($AsObject) {
            $arrayOfObjects = @()
            foreach ($string in $arrayOfStrings) {
                $strSplitted = $string -split "="
                $attrName = $strSplitted[0]
                Write-Verbose "Attribute name is $attrName"
                $attrValue = $strSplitted[1]
                Write-Verbose "Attribute value is $attrValue"
                $strObj = @{
                    "$attrName" = $attrValue
                }
                $arrayOfObjects += $strObj
            }
            $Out = $arrayOfObjects
        } else {
            $Out = $arrayOfStrings
        }
        return $Out
    }
}
Export-ModuleMember -Function "Filter-CertificateSubject"

function ConvertFrom-QuotedStringToArray {
    param (
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true)]
        # Input string with quotes
        [string]
        $InputString,

        [Parameter()]
        # Quote char
        [char]
        $QuoteChar = '"'
    )
    [array]$unQuotedArray = $InputString -split $QuoteChar | Where-Object -FilterScript {$_.Length -gt 0} | ForEach-Object {$_.Trim(' ')}
    return $unQuotedArray
}

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

function ConvertTo-PSObjectFromCertificateSubject {
    param (
        [Parameter(Mandatory=$true)]
        # Subject or issuer as array of strings, each contains both field name and value, i.e. "CN=Common Subject Name"
        [string[]]
        $Subject,

        [Parameter()]
        # Field separator, default is '='
        [char]
        $FieldSeparator = '='
    )
    $OutputObject = New-Object -TypeName psobject
    foreach ($string in $Subject) {
        $stringSeparated = $string -split $FieldSeparator
        $OutputObject | Add-Member -MemberType NoteProperty -Name $stringSeparated[0] -Value $stringSeparated[1]
    }
    return $OutputObject
}

<#
Date in format 'yyyy-MM-dd'
OrgSubject - 'O' as abbreviation
OrgSubject - 'CN' as 'Surname_Name_Patronym'
Roles from OIDs and .Extensions.EnhancedKeyUsages.Value
    OR
CA - CN from Issuer
#>
function New-CryptoProKeyContainerName {
    param (
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true)]
        # Certificate for input
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate
    )
    $certDateValidRaw = $Certificate.NotAfter
    [string]$certDateValidString = Get-Date -Date $certDateValidRaw -Format 'yyyy-MM-dd'

    $certSubjectRaw = Filter-CertificateSubject -Subject $Certificate.Subject
    $certIssuerRaw = Filter-CertificateSubject -Issuer $Certificate.Issuer
    $certSubject = ConvertTo-PSObjectFromCertificateSubject -Subject $certSubjectRaw
    $certIssuer = ConvertTo-PSObjectFromCertificateSubject -Subject $certIssuerRaw
    $certSubjectOrgRaw = $certSubject.O
    $certIssuerOrgRaw = $certIssuer.CN

    if ($certSubjectOrgRaw -match '"') {
        $subjArrTmp = $certSubjectOrgRaw | ConvertFrom-QuotedStringToArray
        $oPFPrefix = New-Abbreviation -StringArray ($subjArrTmp[0].Split(' -')) -MaxWordLength 1
        $orgName = New-Abbreviation -StringArray ($subjArrTmp[1].Split(' -'))
        $orgNameFull = $oPFPrefix, $orgName -join '_'
    } else {
        $orgNameFull = New-Abbreviation -StringArray ($certSubjectOrgRaw.Split(' -')) -JoinChar '_'
    }
    $orgNameFull = $orgNameFull -replace '[^\w\s-]', '-'

    $certSubjectPerson = $certSubject.SN, ($certSubject.G -replace ' ', '_') -join '_'
    $certIssuerAbbrArr = ($certIssuerOrgRaw -replace '[^\w\s]', '') -split ' '
    
    $certIssuerAbbr = New-Abbreviation -StringArray $certIssuerAbbrArr -JoinChar '_'

    $outString = $certDateValidString, $orgNameFull, $certSubjectPerson, $certIssuerAbbr -join '+'
    return $outString
}
Export-ModuleMember -Function 'New-CryptoProKeyContainerName'