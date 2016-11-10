<#
.SYNOPSIS
	Finds and replaces strings in multiple specs-path.

.DESCRIPTION
	Replaces occurances of strings in path specifications. Supports multiple path specifications at once, wildcards, and regular expressions.

.PARAMETER Find
	The string (regular expression) to search for.

.PARAMETER Replace
	The string (regular expression) to replace with. Supports backreferences.

.PARAMETER Paths
	An array of path specifications. Single element arrays cause no problems. Supports wildcards, ~, and anything else that Path-Resolve can work with.

.PARAMETER DryRun
	Shows potential find/replaces, but doesn’t touch any files. implies -Echo.

.PARAMETER Backup
	Copies files to a .bak file before making replacements--helps to prevent ruining data.

.PARAMETER Restore
	Complimentary with -Backup. Copies .bak files over the originals, and then deletes the backup files. No replacements will be made.

.PARAMETER Clear
	Deletes .bak files. No replacements will be made.

.PARAMETER IncludeBackups
	Replaces in .bak files as well.
#>
function Find-Replace {
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline = $True,
			Position = 3
			)]
		[Array]$Paths = ".\*",

		[Parameter(
			Position = 1
			)]
		[String]$Find,

		[Parameter(
			Position = 2
			)]
		[String]$Replace,

		[Switch]$Echo,

		[Switch]$Backup,# = $True,

		[Switch]$Restore,

		[Switch]$Clear,

		[Switch]$DryRun,

		[Switch]$IncludeBackups
		)
	Begin {
		If($Clear)
		{
			#don't try to back up and then clear
			$Backup = $False
		}

		#Verbose notices
		If($DryRun)
		{
			Write-Verbose "This is a dry run, no changes will be made."
		}
		
		If($Clear)
		{
			Write-Verbose "Clearing backup files, no replacements will be made."
		}

		If($Restore)
		{
			Write-Verbose "Restoring backup files, no replacements will be made."
		}
	}

	Process {
		#operate on each path in the array
		#if there's only one path, this only loops once
		ForEach ($Path in $Paths)
		{
			#get files to operate on
			$Files = Get-ChildItem (Resolve-Path $Path) -File
			Write-Verbose ("    Replacing content in $($Files.Count) files in $(Resolve-Path $Path)")
			#iterate through the files
			foreach ($File in $Files)
			{
				Write-Verbose ("Processing $($File)")
				#If the file ends with .bak and the user hasn't specifically included backups, skip it
				If($File.PSPath.EndsWith(".bak") -and !$IncludeBackups)
				{
					Continue
				}

				#Either back up
				If($Backup)
				{
					Write-Verbose "    Creating backup of $($File.FullName)"
					#copy to filename.bak
					Copy-Item $File "$($File.PSPath).bak"
				}
				#Or restore
				ElseIf($Restore)
				{
					Write-Verbose "    Restoring backup of $($File.FullName)"
					#Copy and overwrite
					Copy-Item "$($File.PSPath).bak" $File
				}
				#gotta be seperate so the user can restore/clear at once
				If( ($Clear -or #If the user has requested a clear
					$Restore) -and #or a restore
					(Test-Path "$($File.PSPath).bak") #and the file exists
					)
				{
					Write-Verbose "    Clearing $($File)"
					Remove-Item "$($File.PSPath).bak"
				}

				If( !$Clear -or #if the user doesn't want a clear
					$Find -ne "" #or the user specified find/replace
					#not testing for $Replace in case the user wants to delete matches
				)
				{
					If($Echo -or $DryRun)
					{
						$File |
						Select-String $Find |
						ForEach-Object {
							Write-Output "$($_.Filename):$($_.LineNumber): $($_.Matches) $([char]0x2192) $($_.Matches -Replace $Find, $Replace)"
							Write-Verbose "`n`r$($_.Line)`n`r        $([char]0x2193)`n`r$($_.Line -Replace $Find, $Replace)"
						}
					}

					If(!$DryRun)
					{
						$InText = (Get-Content $File.PSPath)
						$OutText = ( $InText |
						ForEach-Object {
								$_ -Replace $Find, $Replace
							} )

						If($OutText -ne $InText)
						{
							Set-Content $File $OutText
						}
					}
				}
			}
		}
	}
}
