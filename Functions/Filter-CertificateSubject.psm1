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