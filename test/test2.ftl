[#ftl]
[#assign start = .now]
[#assign timer = start]

[#include "/base.ftl" ]
[#include "../cmdb/cmdb.ftl"]
[#include "../cmdb/views/cmdbmigration/setup.ftl"]

[
[#assign result = {} ]
[#list findFiles("/default/cic/state/cf/integration/default/") as stateFile]
    [#assign fileAnalysis = analysePostAccountIdFilename(stateFile) ]
    [#if stateFile.Path?contains(fileAnalysis.DeploymentUnit) ]
        [#continue]
    [/#if]
    [#switch fileAnalysis.Region]
        [#case "us-east-1"]
            [#assign placement = "global"]
            [#break]

        [#default]
            [#assign placement = "default"]
    [/#switch]
    [#assign fromFile = stateFile.File]
    [#assign toFile = formatAbsolutePath(stateFile.Path, fileAnalysis.DeploymentUnit, placement,stateFile.Filename)]
[#--]
    [@toJSON
        {
            "FromFile" : fromFile,
            "ToFile" : toFile,
            "Analysis" : fileAnalysis,
            "Result":
                cpCMDB(
                    fromFile,
                    toFile,
                    {
                        "Recurse" : false,
                        "Preserve" : true
                    }
                )
        }
    /],
--]
    [@toJSON
        {
            "FromFile" : stateFile.File,
            "Analysis" : fileAnalysis,
            "Result":
                moveFiles(
                    createProgressIndicator(),
                    stateFile,
                    stateFile.Path,
                    formatAbsolutePath(stateFile.Path, fileAnalysis.DeploymentUnit, placement),
                    "Upgrade",
                    ""
                )
        }
    /],
    [#break]
[/#list]
""]