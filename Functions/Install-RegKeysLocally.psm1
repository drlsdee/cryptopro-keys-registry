function Install-RegKeysLocally {
    [CmdletBinding()]
    param (
        [Parameter()]
        # Path to containers hive on 32-bit systems
        [string]
        $cryptoProRegPathX86 = 'HKLM:\SOFTWARE\Crypto Pro\Settings\Users',

        [Parameter()]
        # Path to containers hive on 64-bit systems
        [string]
        $cryptoProRegPathX64 = 'HKLM:\SOFTWARE\Wow6432Node\Crypto Pro\Settings\Users',

        [Parameter()]
        # Path to folder where regfiles stored
        [string]
        $regFilesFolder = 'C:\Users\Public',

        [Parameter()]
        # Path to subfolder for 64-bit systems
        [string]
        $regSubFolderX64Name = 'x64out',

        [Parameter()]
        # Path to subfolder for 32-bit systems
        [string]
        $regSubFolderX86Name = 'x86out',

        [Parameter()]
        # Path to 'csptest.exe'
        [string]
        $pathToCspTest = 'C:\Program Files\Crypto Pro\CSP',

        [Parameter()]
        # Codepage for commadn-line utilities (assuming 1251)
        [int]
        $codePage = 1251
    )

    begin {
        [string]$dateTimeFormat = 'yyyy-MM-dd HH:mm:ss:fff'
        [string]$theFunctionName = $MyInvocation.MyCommand.Name
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Function started."
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Set codepage for command-line utilities to $codePage. Command string will be: `"chcp $codePage`""
        & chcp $codePage
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Enum source folders."
        if (Test-Path -Path $regFilesFolder -PathType Container) {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Folder `"$regFilesFolder`" exists."
        } else {
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Folder `"$regFilesFolder`" DOES NOT exist! Exiting..."
            return
        }
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Test path to CryptoPro CSP."
        if (Test-Path -Path $pathToCspTest -PathType Container) {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Folder `"$pathToCspTest`" found. Continue..."
            if (Get-ChildItem -Path $pathToCspTest -Filter 'csptest.exe') {
                Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Program 'csptest.exe' found in the folder `"$pathToCspTest`". Continue..."
            } else {
                Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Program 'csptest.exe' NOT FOUND in the folder `"$pathToCspTest`"! Exiting..."
            }
        } else {
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Folder `"$pathToCspTest`" NOT FOUND! Exiting..."
            return
        }
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Test registry paths."
        if (Test-Path -Path $cryptoProRegPathX86 -PathType Container) {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Reg hive `"$cryptoProRegPathX86`" exists. Assuming the system is 32-bit."
            [string]$regFilesFolderArch = Join-Path -Path $regFilesFolder -ChildPath $regSubFolderX86Name
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Source folder is `"$regFilesFolderArch`"."
            [string]$folderPathForCleanup = Join-Path -Path $regFilesFolder -ChildPath $regSubFolderX64Name
        } else {
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Reg hive `"$cryptoProRegPathX86`" DOES NOT exist! Assuming the system is 64-bit..."
            if (Test-Path -Path $cryptoProRegPathX64 -PathType Container) {
                Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Reg hive `"$cryptoProRegPathX64`" exists. Confirm that the system is 64-bit. Continue..."
                [string]$regFilesFolderArch = Join-Path -Path $regFilesFolder -ChildPath $regSubFolderX64Name
                Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Source folder is `"$regFilesFolderArch`"."
                [string]$folderPathForCleanup = Join-Path -Path $regFilesFolder -ChildPath $regSubFolderX86Name
            } else {
                Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Nor 64-bit neither 32-bit reg hives not found! Exiting..."
                return
            }
        }
        if (Test-Path -Path $regFilesFolderArch -PathType Container) {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Folder `"$regFilesFolderArch`" exists."
        } else {
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Folder `"$regFilesFolderArch`" DOES NOT exists! Exiting..."
            return
        }
        Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: The folder `"$folderPathForCleanup`" will be removed if exists!"
        Remove-Item -Path $folderPathForCleanup -Recurse -Force -ErrorAction SilentlyContinue
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Searching for subfolders in the folder `"$regFilesFolderArch`"..."
        [array]$subFolders = Get-ChildItem -Path $regFilesFolderArch -Directory
        if ($subFolders.Count -eq 0) {
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Subfolders NOT FOUND in the folder `"$regFilesFolderArch`"! Exiting..."
            return
        } else {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: In the folder `"$regFilesFolderArch`" found $($subFolders.Count) subfolders..."
        }
        $regFilesSrcPath = Join-Path -Path $regFilesFolderArch -ChildPath $env:USERNAME
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Path to source folder set as `"$regFilesSrcPath`"..."
        if (Test-Path -Path $regFilesSrcPath -PathType Container) {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Source folder `"$regFilesSrcPath`" exists. Continue..."
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: ALL OTHER FOLDERS IN `"$regFilesFolderArch`" WILL BE REMOVED!"
            [array]$foldersToCleanUp = ($subFolders | Where-Object {$_.BaseName -ne $env:USERNAME}).FullName
            foreach ($cleanFldr in $foldersToCleanUp) {
                Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: REMOVING FOLDER `"$cleanFldr`"!"
                Remove-Item -Path $cleanFldr -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
        } else {
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Source folder `"$regFilesSrcPath`" DOES NOT exists! Exiting..."
            return
        }
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Searching for registry key files in the source folder `"$regFilesSrcPath`"..."
        [array]$regFilesPathsToImport = (Get-ChildItem -Path $regFilesSrcPath -Filter '*.reg').FullName
        if ($regFilesPathsToImport.Count -eq 0) {
            Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Regfiles NOT FOUND in the folder `"$regFilesSrcPath`"! Exiting..."
            return
        } else {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: In the folder `"$regFilesSrcPath`" found $($regFilesPathsToImport.Count) regfiles. Continue..."
        }
    }

    process {
        foreach ($regFile in $regFilesPathsToImport) {
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Importing hive from file `"$regFile`"..."
            if ($regFile -match '\s+') {
                Write-Warning -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Path `"$regFile`" contains spaces! Try to escape..."
                $regFile = "`"$regFile`""
            }
            Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Command string with arguments will be: `"regedit /s $regFile`""
            & regedit /s $regFile
        }
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: Installing certs from ALL CONTAINERS. Command string will be: `"$pathToCspTest\csptest.exe -absorb -certs`""
        & $pathToCspTest\csptest.exe -absorb -certs
    }

    end {
        Write-Verbose -Message "[$(Get-Date -Format $dateTimeFormat)]: [$theFunctionName]: End of function."
        return
    }
}

Export-ModuleMember -Function 'Install-RegKeysLocally'