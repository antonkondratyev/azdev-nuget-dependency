param (
    [string] $nuSpecFilesPath,
    [string] $customVersion,
    [string] $dependencyID,
    [string] $dependencyVersion
)

Write-Verbose "NuSpecFilesPath = $nuSpecFilesPath"
Write-Verbose "CustomVersion = $customVersion"
Write-Verbose "DependencyID = $dependencyID"
Write-Verbose "DependencyVersion = $dependencyVersion"

$nuspecFiles = Get-ChildItem $nuSpecFilesPath -Recurse -Force
if ($nuspecFiles.Count -le 0) {
    Write-Warning ".nuspec file(s) not found"
    exit
}

if ($customVersion -eq "true") {
    Write-Output "Found $($nuspecFiles.Count) .nuspec file(s):"
    Write-Output $nuspecFiles.FullName
    Write-Output "`n.nuspec with '$($dependencyID)' package:"

    foreach ($nuspecFile in $nuspecFiles) {
        [xml] $xmlNuSpec = Get-Content -Encoding UTF8 $nuspecFile
        $dependencyWithCustomID = $xmlNuSpec.GetElementsByTagName("dependency") | Where-Object { $_.id -match $dependencyID }

        if ($dependencyWithCustomID) {
            $dependencyWithCustomID.SetAttribute("version", $dependencyVersion)
            Write-Output $nuspecFile.FullName
            $xmlNuSpec.Save($nuspecFile)
        }
    }
}
else {
    $nuspecWithCfg = $nuspecFiles | Where-Object { Test-Path ([System.IO.Path]::Combine($_.DirectoryName, "packages.config")) }

    if ($nuspecWithCfg.Count -le 0) {
        Write-Warning ".nuspec file(s) with 'packages.config' not found"
        exit
    }

    Write-Output "Found $($nuspecWithCfg.Count) .nuspec with 'packages.config':"
    Write-Output $nuspecWithCfg.FullName

    foreach ($nuspecFile in $nuspecWithCfg) {
        $configFile = [System.IO.Path]::Combine($nuspecFile.DirectoryName, "packages.config")
        [xml] $xmlNuSpec = Get-Content -encoding UTF8 $nuspecFile
        [xml] $xmlConfig = Get-Content -encoding UTF8 $configFile
        $pkgs = $xmlConfig.packages.package

        # create new node with two attributes
        function CreateDependencyNode($id, $ver) {
            $dependencyNode = $xmlNuSpec.CreateElement("dependency", $xmlNuSpec.package.NamespaceURI)
            $dependencyNode.SetAttribute("id", $id)
            $dependencyNode.SetAttribute("version", $ver)
            return $dependencyNode
        }

        if (!($xmlNuSpec.package.metadata | Get-Member -Name "dependencies")) {
            # create <dependencies />
            $dependenciesNode = $xmlNuSpec.CreateElement("dependencies", $xmlNuSpec.package.NamespaceURI)

            # create <dependency />
            foreach ($pkg in $pkgs) {
                $newDependency = CreateDependencyNode -id $pkg.id -ver $pkg.version
                [void] $dependenciesNode.AppendChild($newDependency)
            }

            # add <dependencies /> in <metadata />
            [void] $xmlNuSpec.package.metadata.AppendChild($dependenciesNode)
        }
        else {
            foreach ($pkg in $pkgs) {
                $dependency = $xmlNuSpec.GetElementsByTagName("dependency").Where({ $_.id -eq $pkg.id })

                if ($dependency) {
                    if ($dependency.version -ne $pkg.version) {
                        $dependency.SetAttribute("version", $pkg.version)
                    }
                }
                else {
                    $newDependency = CreateDependencyNode -id $pkg.id -ver $pkg.version
                    [void] $xmlNuSpec.package.metadata.dependencies.AppendChild($newDependency)
                }
            }
        }

        $xmlNuSpec.Save($nuspecFile)
    }
}