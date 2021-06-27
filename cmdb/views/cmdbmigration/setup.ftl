[#ftl]

[#macro cmdb_view_default_cmdbmigration_generationcontract  ]
    [@addDefaultGenerationContract subsets=[ "prologue" ] /]
[/#macro]

[#macro cmdb_view_default_cmdbmigration_prologue ]
    [#local options = getCommandLineOptions() ]

    [#-- Permit selection of the cmdbs to upgrade --]
    [#local cmdbs = getCMDBs({"ActiveOnly" : false}) ]
    [#if options.CMDB.Names?has_content]
        [#local requiredCMDBs = options.CMDB.Names?split("|") ]
        [#local cmdbs = cmdbs?filter(entry -> requiredCMDBs?seq_contains(entry.Name)) ]
    [/#if]

    [#local actions = options.CMDB.Actions?split("|") ]

    [#list cmdbs?sort_by("Name") as cmdb]
        [#-- Perform migrations --]
        [#if actions?seq_contains("upgrade") ]
            [#local result = internalMigrateCmdb(cmdb, INTERNAL_CMDB_UPGRADE, options) ]
            [@addToDefaultScriptOutput getProgressLog(result) /]
            [#if progressIsNotOK(result) ]
                [#return]
            [/#if]
        [/#if]

        [#-- Perform cleanup --]
        [#if actions?seq_contains("cleanup") ]
            [#local result = internalMigrateCmdb(cmdb, INTERNAL_CMDB_CLEANUP, options) ]
            [@addToDefaultScriptOutput getProgressLog(result) /]
            [#if progressIsNotOK(result) ]
                [#return]
            [/#if]
        [/#if]
    [/#list]
[/#macro]

[#--------------------------------------------------
-- Internal support functions for cmdb migrations --
----------------------------------------------------]

[#assign INTERNAL_CMDB_UPGRADE = "Upgrade"]
[#assign INTERNAL_CMDB_CLEANUP = "Cleanup"]

[#-- Primary function to perform migration activities --]
[#function internalMigrateCmdb cmdb action options]

    [#local result = createProgressIndicator() ]
    [#local dryrun = options.CMDB.Dryrun ]
    [#--
    Migrations from the following earlier versions have been ported from
    the bash implementation, but not extensively tested as there is no
    known use of them with current users.

    Should this prove to not be the case, the minimum current accepted
    version can be extended to the values below but testing using dryrun
    is recommended to confirm correct migration logic.

    "Upgrade" : ["v1.0.0", "v1.1.0", "v1.2.0", "v1.3.0", "v1.3.1", "v1.3.2"]
    "Cleanup" : ["v1.0.0", "v1.1.0", "v1.1.1"]
    --]

    [#local migrationOrder =
        {
            "Upgrade" : ["v1.3.2", "v2.0.0", "v2.0.1"],
            "Cleanup" : ["v1.1.1", "v2.0.0"]
        } ]

    [#-- Access current version state --]
    [#local contents = cmdb.ContentsAsJSON!{} ]

    [#-- Determine the version of last upgrade --]
    [#local currentVersion = (contents.Version[action])!"v0.0.0"]

    [#-- Determine is repo is pinned to a particular version --]
    [#local pinnedVersion = (contents.Pin[action])!""]

    [#-- Determine the requested version --]
    [#local requestedVersion = options.CMDB.Version[action] ]

    [#-- Support forced migrations by setting pinned versions --]
    [#if pinnedVersion?has_content]
        [#if semverCompare(pinnedVersion, requestedVersion) == SEMVER_GREATER_THAN ]
            [#local requestedVersion = pinnedVersion]
        [/#if]
    [/#if]

    [#-- Details on the cmdb being migrated --]
    [#local header =
        [
            "#",
            "#",
            "# " + .now?iso_utc,
            "# " + action + " cmdb " + cmdb.Name +
                ", path = " + cmdb.FileSystemPath +
                ", requested = " + requestedVersion +
                ", current = " +
                    valueIfTrue(
                        currentVersion,
                        currentVersion != "v0.0.0",
                        "<not initialised>"
                    ) +
                valueIfContent(
                    ", pinned = " + pinnedVersion
                    pinnedVersion,
                    ""
                )
        ]
    ]

    [#-- Check a migration is possible --]
    [#if semverCompare(currentVersion, migrationOrder[action][0]) == SEMVER_LESS_THAN]
        [#return addToProgressLog(result, header, logAlert(migrationOrder[action][0] + " - migration from current version not supported")) ]
    [/#if]

    [#local addHeader = true]

    [#list (migrationOrder[action])![] as migrationVersion]

        [#-- Header if required --]
        [#if addHeader]
            [#local result = addToProgressLog(result, header) ]
            [#local addHeader = false]
        [/#if]

        [#-- ignore already applied migrations --]
        [#if semverCompare(currentVersion, migrationVersion) != SEMVER_LESS_THAN]
            [#local result = addToProgressLog(result,logAlert(migrationVersion + " - already applied")) ]
            [#continue]
        [/#if]

        [#-- check for pinned versions --]
        [#if pinnedVersion?has_content]
            [#if semverCompare(migrationVersion, pinnedVersion) == SEMVER_GREATER_THAN ]
                [#local result = addToProgressLog(result,logAlert(migrationVersion + " - blocked by pin")) ]
                [#continue]
            [/#if]
        [/#if]

        [#-- check requested version --]
        [#if semverCompare(migrationVersion, requestedVersion) == SEMVER_GREATER_THAN ]
            [#local result = addToProgressLog(result,logAlert(migrationVersion + " - skipped, later than required")) ]
            [#continue]
        [/#if]

        [#-- Determine the migration function to be called --]
        [#local migrationVersionComponents = semverClean(migrationVersion)]
        [#local migrationFunction =
            (
                ["internal_cmdb_cmdbmigration"] +
                [action?lower_case] +
                migrationVersionComponents[1..3]
            )?join("_")
        ]

        [#-- Invoke the migration function --]
        [#if (.vars[migrationFunction]!"")?is_directive]
            [#local result = addToProgressLog(result,logAlert(migrationVersion + " - applying" + dryrun)) ]
            [#local result = (.vars[migrationFunction])(result, cmdb, dryrun) ]

            [#if progressIsOK(result)]
                [#-- Repeat the header on the next migration so it is easier to understand the log --]
                [#local addHeader = true]

                [#-- Capture the results of the migration --]
                [#local result += {"Log" : result.Log + logSeparator("Record results") } ]

                [#-- Clean up any legacy .cmdb files - should only be one --]
                [#local markerFiles = listFilesInDirectory(cmdb.CMDBPath, r"\.cmdb", {"IgnoreDotFiles" : false}) ]
                [#if markerFiles?has_content]
                    [#local result = deleteFiles(result, markerFiles, action, dryrun) ]
                    [#if progressIsNotOK(result)]
                        [#break]
                    [/#if]
                [/#if]

                [#-- Create the .cmdb directory --]
                [#local cmdbConfigPath = formatAbsolutePath(cmdb.CMDBPath, ".cmdb") ]
                [#local cmdbConfigFile = formatAbsolutePath(cmdbConfigPath, "config.json") ]
                [#local result = makeDirectory(result, cmdbConfigPath, action, dryrun) ]
                [#if progressIsNotOK(result)]
                    [#break]
                [/#if]

                [#-- Update the cmdb contents --]
                [#local result =
                    writeFile(
                        result,
                        cmdbConfigFile,
                        mergeObjects(
                            contents,
                            {
                                "Version" : {
                                    action : migrationVersion
                                }
                            }
                        ),
                        "Update",
                        action?lower_case + "=" + migrationVersion,
                        dryrun
                    )
                ]
                [#if progressIsNotOK(result)]
                    [#break]
                [/#if]

                [#-- Capture the migration log in the .cmdb directory                   --]
                [#-- Append to the file in case there is already one present, e.g. when --]
                [#-- rerunning the migration                                            --]
                [#local cmdbMigrationsLogPath = formatAbsolutePath(cmdbConfigPath, "migrations") ]
                [#local result = makeDirectory(result, cmdbMigrationsLogPath, action, dryrun) ]
                [#if progressIsNotOK(result)]
                    [#break]
                [/#if]

                [#local migrationLogFilename = action?lower_case + "-" + migrationVersion + ".log" ]
                [#local result =
                    writeFile(
                        result,
                        formatAbsolutePath(cmdbMigrationsLogPath, migrationLogFilename),
                        (getProgressLog(result) + ["#", "#"])?join('\n'),
                        "Create",
                        "migration log",
                        dryrun,
                        {
                            "Format" : "plaintext",
                            "Append" : true
                        }
                    )
                ]
                [#if progressIsNotOK(result)]
                    [#break]
                [/#if]

            [#else]
                [#-- Stop as migration failed --]
                [#local result = addToProgressLog(result,["#", logAlert("Aborting due to migration failure"), "#"]) ]
                [#break]
            [/#if]
        [#else]
            [#local result = addToProgressLog(result,logAlert(migrationVersion + " - skipped, no function defined")) ]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#-- v1.0.0
.ref -> .json
credentials.json -> remove Credentials top level element
container.json -> segment.json
--]
[#function internal_cmdb_cmdbmigration_upgrade_1_0_0 progress cmdb dryrun]
    [#local result = migrateLegacyReferences(progress, findFiles(cmdb.CMDBPath, r"*.ref"), INTERNAL_CMDB_UPGRADE, dryrun) ]
    [#if progressIsNotOK(result)]
        [#return result]
    [/#if]

    [#local result = migrateLegacyCredentials(result, findFiles(cmdb.CMDBPath, r"credentials.json"), INTERNAL_CMDB_UPGRADE, dryrun) ]
    [#if progressIsNotOK(result)]
        [#return result]
    [/#if]

    [#return migrateContainerFiles(result, findFiles(cmdb.CMDBPath, r"container.json"), INTERNAL_CMDB_UPGRADE, dryrun) ]
[/#function]

[#function internal_cmdb_cmdbmigration_cleanup_1_0_0 progress cmdb dryrun]
    [#local result = deleteFiles(progress, findFiles(cmdb.CMDBPath, r"*.ref"), INTERNAL_CMDB_CLEANUP, dryrun) ]
    [#if progressIsNotOK(result)]
        [#return result]
    [/#if]

    [#return deleteFiles(result, findFiles(cmdb.CMDBPath, r"container.json"), INTERNAL_CMDB_CLEANUP, dryrun) ]
[/#function]

[#-- v1.1.0
Rename top level directories
Introduce environment/segment directory layout
Add environment.json marker files
Introduce directory for shared configuration
--]
[#assign INTERNAL_CMDB_V_1_1_0_UPGRADE_DIRECTORIES =
    {
        "appsettings" : {
            "Dir" : "settings"
        },
        "solutions" : {
            "Dir" : "solutionsv2"
        },
        "credentials" : {
            "Dir" : "operations"
        },
        "aws" : {
            "Dir" : "cf",
            "SubDir" : "cf"
        }
    }
]

[#-- Migrate current environment configuration to the "default" segment --]
[#function internal_cmdb_cmdbmigration_upgrade_1_1_0 progress cmdb dryrun]

    [#local result = progress ]
    [#local action = INTERNAL_CMDB_UPGRADE]

    [#list INTERNAL_CMDB_V_1_1_0_UPGRADE_DIRECTORIES as from, to]

        [#-- find instances of the from directory --]
        [#local files = findDirectories(cmdb.CMDBPath, from) ]

        [#list files as file]
            [#local fromDir = file.File ]
            [#local toDir = formatAbsolutePath(file.Path, to.Dir) ]

            [#-- Add the segment dirs --]
            [#local result = migrateToSegmentDirs(result, fromDir, toDir, to.SubDir!"", action, dryrun) ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]

            [#-- Cleanup unwanted files --]
            [#-- This assumes the 1.0.0 upgrade has been done but not cleaned up. --]
            [#local result = deleteFiles(result, findFiles(toDir, r"*.ref"), action, dryrun) ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]

            [#local result = deleteFiles(result, findFiles(toDir, r"container.json"), action, dryrun) ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]

            [#-- Special processing --]
            [#switch from]
                [#case "solutions"]
                    [#local sharedDir = formatAbsolutePath(toDir,"shared") ]
                    [#local sharedDefaultDir = formatAbsolutePath(sharedDir,"default") ]
                    [#-- Shared solution files now specific to the default segment --]
                    [#local result =
                        moveFilesInDirectory(
                            result,
                            sharedDir,
                            sharedDefaultDir,
                            action,
                            dryrun
                        ) ]
                    [#if progressIsNotOK(result)]
                        [#return result]
                    [/#if]

                    [#-- Create the shared segment file --]
                    [#local sharedSegmentFile = formatAbsolutePath(sharedDefaultDir, "segment.json")]
                    [#local result =
                        writeFile(
                            result,
                            sharedSegmentFile,
                            {
                                "Segment" : {
                                    "Id" : "default"
                                }
                            },
                            "Create",
                            "shared segment file",
                            dryrun
                        )
                    ]
                    [#if progressIsNotOK(result)]
                        [#return result]
                    [/#if]

                    [#local segments = findFiles(toDir, r"segment.json") ]
                    [#list segments as segment]
                        [#-- Add environment.json files --]
                        [#local environmentFile = formatAbsolutePath(getParentDirectory(segment.Path), "environment.json") ]
                        [#local result =
                            writeFile(
                                result,
                                environmentFile,
                                {
                                    "Environment" : {
                                        "Id" : (segment.ContentAsJSON.Segment.Environment)!""
                                    }
                                },
                                "Create",
                                "environment file",
                                dryrun
                            )
                        ]
                        [#if progressIsNotOK(result)]
                            [#return result]
                        [/#if]

                        [#-- Cleanup the segment file --]
                        [#local result =
                            writeFile(
                                result,
                                segment.File,
                                removeObjectAttributes((segment.ContentAsJSON)!{}, "Segment") +
                                    {
                                        "Segment" :
                                            removeObjectAttributes(
                                                (segment.ContentAsJSON.Segment)!{},
                                                ["Id", "Name", "Title", "Environment"]
                                            )
                                    },
                                "Cleanup",
                                "",
                                dryrun
                            )
                        ]
                        [#if progressIsNotOK(result)]
                            [#return result]
                        [/#if]
                    [/#list]
                    [#break]

                [#case "credentials"]
                    [#local pemFiles = findFiles(toDir, r"aws-ssh*.pem")]
                    [#list pemFiles as pemFile]
                        [#-- Move pem file --]
                        [#local result =
                            moveFile(
                                result,
                                pemFile,
                                pemFile +
                                {
                                    "File" : formatAbsolutePath(pemFile.Path, "." + pemFile.Filename),
                                    "Filename" : "." + pemFile.Filename
                                },
                                action,
                                dryrun
                            )
                        ]
                        [#if progressIsNotOK(result)]
                            [#return result]
                        [/#if]

                        [#-- Create the .gitignore file --]
                        [#local gitIgnoreFile = formatAbsolutePath(pemFile.Path, r".gitignore") ]
                        [#local result =
                            writeFile(
                                result,
                                gitIgnoreFile,
                                "*.plaintext\n*.decrypted\n*.ppk",
                                "Create",
                                ".ignore file",
                                dryrun
                            )
                        ]
                        [#if progressIsNotOK(result)]
                            [#return result]
                        [/#if]
                    [/#list]
                    [#break]

            [/#switch]
        [/#list]
    [/#list]

    [#return result]
[/#function]

[#function internal_cmdb_cmdbmigration_cleanup_1_1_0 progress cmdb dryrun]
    [#local result = progress ]

    [#list INTERNAL_CMDB_V_1_1_0_UPGRADE_DIRECTORIES as from, to]

        [#-- Find instances of the from directory --]
        [#local files = findDirectories(cmdb.CMDBPath, from) ]

        [#list files as file]
            [#local result =
                deleteDirectory(
                    result,
                    file.File,
                    INTERNAL_CMDB_CLEANUP,
                    dryrun
                )
            ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]
        [/#list]
    [/#list]

    [#return result]
[/#function]

[#-- v1.1.1
Needed to correct a bug in the original (bash) implementation of v1.1.0
--]
[#function internal_cmdb_cmdbmigration_cleanup_1_1_1 progress cmdb dryrun]
    [#return internal_cmdb_cmdbmigration_cleanup_1_1_0(progress, cmdb, dryrun) ]
[/#function]

[#-- v1.2.0
Switch to using the term "fragment" instead of "container"
--]
[#function internal_cmdb_cmdbmigration_upgrade_1_2_0 progress cmdb dryrun]
    [#local result = migrateContainerFragmentFiles(progress, findFiles(cmdb.CMDBPath, r"container_*.ftl"), INTERNAL_CMDB_UPGRADE, dryrun) ]
    [#if progressIsNotOK(result)]
        [#return result]
    [/#if]

    [#return deleteFiles(result, findFiles(cmdb.CMDBPath, r"container_*.ftl"), INTERNAL_CMDB_CLEANUP, dryrun) ]
[/#function]

[#-- v1.3.0
Include account and region in stacks/ssh keys
--]
[#function internal_cmdb_cmdbmigration_upgrade_1_3_0 progress cmdb dryrun]

    [#local result = progress]

    [#-- Update stacks with account and region information --]
    [#local cmkStacks = findFiles(cmdb.CMDBPath, r"seg-cmk-*[0-9]-stack.json") ]
    [#list cmkStacks as cmdbStack]
        [#local cmkStackAnalysis =  analysePreAccountIdFile(cmkStack) ]
        [#local cmkProviderId = cmkStackAnalysis.Outputs.ProviderId ]
        [#local cmkAccountId = getAccountMappings()[cmkProviderId]!"" ]
        [#local cmkRegion = cmkStackAnalysis.Outputs.Region ]

        [#if cmkProviderId?has_content]

            [#-- Ensure the providerId cn be mapped to an accountId --]
            [#if !cmkAccountId?has_content ]
                [#return addToProgressLog(setProgressAbort(result), logAlert("Unable to map provider Id" + cmkProviderId + " to an accountId")) ]
            [/#if]

            [#-- Ensure stack files contain the providerId and region --]
            [#local stackFiles = findFiles(cmkStack.Path, r"*stack.json") ]
            [#local result =
                addPlacementDetailsToStackFiles(
                    result,
                    stackFiles,
                    cmkProviderId,
                    cmkRegion,
                    action,
                    dryrun
                )
            ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]

            [#-- Include the accountId in the stack filenames --]
            [#local result =
                addAccountIdToFilenames(
                    result,
                    stackFiles,
                    cmkAccountId,
                    action,
                    dryrun
                )
            ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]

            [#-- Include the accountId and region in pem filenames --]
            [#local result =
                addAccountIdToPEMFiles(
                    result,
                    findFiles(
                        cmdbStack.Path?replace("infrastructure/cf", "infrastructure/operations"),
                        r".aws-ssh*.pem*"
                    ),
                    cmkAccountId,
                    cmkRegion,
                    action,
                    dryrun
                )
            ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]
        [/#if]
    [/#list]

    [#return result]

[/#function]

[#-- v1.3.1
Include accountId in all state files that contain a region
--]
[#function internal_cmdb_cmdbmigration_upgrade_1_3_1 progress cmdb dryrun]

    [#local result = progress]
    [#local action = INTERNAL_CMDB_UPGRADE]

    [#-- Update filenames with accountId information --]
    [#local cmkStacks = findFiles(cmdb.CMDBPath, r"seg-cmk-*[0-9]-stack.json") ]
    [#list cmkStacks as cmdbStack]
        [#local cmkStackAnalysis =  analysePreAccountIdFile(cmkStack) ]
        [#local cmkProviderId = cmkStackAnalysis.Outputs.ProviderId ]
        [#local cmkAccountId = getAccountMappings()[cmkProviderId]!"" ]
        [#local cmkRegion = cmkStackAnalysis.Outputs.Region ]

        [#if cmkProviderId?has_content]

            [#-- Ensure the providerId cn be mapped to an accountId --]
            [#if !cmkAccountId?has_content ]
                [#return addToProgressLog(setProgressAbort(result), logAlert("Unable to map provider Id" + cmkProviderId + " to an accountId")) ]
            [/#if]

            [#-- Include the accountId in all filenames that include a region --]
            [#local result =
                addAccountIdToFilenames(
                    result,
                    findFiles(cmkStack.Path),
                    cmkAccountId,
                    action,
                    dryrun
                )
            ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]
        [/#if]
    [/#list]

    [#return result]

[/#function]

[#-- v1.3.2
Needed to correct a bug in the original (bash) implementation of v1.3.1
--]
[#function internal_cmdb_cmdbmigration_upgrade_1_3_2 progress cmdb dryrun]
    [#return internal_cmdb_cmdbmigration_upgrade_1_3_1(progress, cmdb, dryrun) ]
[/#function]

[#-- v2.0.0
Reorganise cmdb to make it easier to manage via branches and dynamic cmdbs

State is now in its own directory at the same level as config and infrastructure
Solutions is now under infrastructure
Builds are separated from settings and are now under infrastructure
Operations are now in their own directory at same level as config and
infrastructure. For consistency with config, a settings subdirectory has been
added.

With this layout,
- infrastructure should be the same across environments assuming no builds
  are being promoted
- product and operations settings are managed consistently
- all the state info is cleanly separated (so potentially in its own repo)

/config/settings
/operations/settings
/infrastructure/solutions
/infrastructure/builds
/state/cf
/state/cot

If config and infrastructure are not in the one repo, then the upgrade must
be performed manually and the cmdb version manually updated
--]
[#function internal_cmdb_cmdbmigration_upgrade_2_0_0 progress cmdb dryrun]

    [#local result = progress ]
    [#local action = INTERNAL_CMDB_UPGRADE]

    [#list findDirectories(cmdb.CMDBPath, r"config") as config]
        [#local baseDir = config.Path]
        [#local configDir = config.File]
        [#local infrastructureDir = (listDirectoriesInDirectory(baseDir, "infrastructure")[0])!{} ]
        [#-- Manual update required --]
        [#if ! infrastructureDir?has_content]
            [#return addToProgressLog(setProgressAbort(result), logAlert("Upgrade must be manually performed for split cmdb repos")) ]
        [/#if]

        [#-- Move the state into its own top level tree --]
        [#list ["cf", "cot"] as framework]
            [#local frameworkDir = (listDirectoriesInDirectory(infrastructureDir.File, framework)[0])!{} ]
            [#if frameworkDir?has_content]
                [#local targetDir = formatAbsolutePath(baseDir, "state", frameworkDir.Filename) ]
                [#local result += {"Log" : result.Log + logSeparator("Move state tree " + frameworkDir.File + " to " + targetDir) } ]
                [#local result = moveDirectoryTree(result, frameworkDir.File, targetDir, action, dryrun) ]
                [#if progressIsNotOK(result)]
                    [#return result]
                [/#if]
            [/#if]
        [/#list]

        [#-- Move operations settings into their own top level tree --]
        [#local operationsDir = (listDirectoriesInDirectory(infrastructureDir.File, "operations")[0])!{} ]
        [#if operationsDir?has_content]
            [#local targetDir = formatAbsolutePath(baseDir, "operations", "settings") ]
            [#local result += {"Log" : result.Log + logSeparator("Move operations tree " + operationsDir.File + " to " + targetDir) } ]
            [#local result = moveDirectoryTree(result, operationsDir.File, targetDir, action, dryrun) ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]
        [/#if]

        [#-- Copy the solutionsv2 tree from config to infrastructure and rename --]
        [#local solutionsv2Dir = (listDirectoriesInDirectory(configDir, "solutionsv2")[0])!{} ]
        [#if solutionsv2Dir?has_content]
            [#local targetDir = formatAbsolutePath(infrastructureDir.File, "solutions") ]
            [#local result += {"Log" : result.Log + logSeparator("Copy solutionsv2 tree " + solutionsv2Dir.File + " to " + targetDir) } ]
            [#local result = copyDirectoryTree(result, solutionsv2Dir.File, targetDir, action, dryrun) ]
            [#if progressIsNotOK(result)]
                [#return result]
            [/#if]
        [/#if]

        [#-- Copy the builds into their own tree.                               --]
        [#-- Start under settings so relative paths correct for the builds tree --]
        [#local settingsDir = formatAbsolutePath(configDir, "settings") ]
        [#local buildFiles = findFiles(settingsDir, "*build.json") ]
        [#local buildsDir = (listDirectoriesInDirectory(infrastructureDir.File, "builds")[0])!{} ]
        [#if ! buildsDir?has_content]
            [#local targetDir = formatAbsolutePath(infrastructureDir.File, "builds") ]
            [#local result += {"Log" : result.Log + logSeparator("Create build tree " + targetDir) } ]
            [#local result =
                copyFiles(
                    result,
                    buildFiles,
                    settingsDir,
                    targetDir,
                    action,
                    dryrun
                )
            ]
        [/#if]

        [#-- Clean the settings tree --]
        [#local result += {"Log" : result.Log + logSeparator("Clean settings tree " + configDir) } ]
        [#local result = deleteFiles(result, buildFiles, action, dryrun) ]
        [#if progressIsNotOK(result)]
            [#return result]
        [/#if]
        [#local result = deleteEmptyDirectories(result, configDir, action, dryrun) ]
        [#if progressIsNotOK(result)]
            [#return result]
        [/#if]

    [/#list]

    [#return result]

[/#function]

[#function internal_cmdb_cmdbmigration_cleanup_2_0_0 progress cmdb dryrun]

    [#local result = progress ]

    [#-- delete solutionsv2 directories --]
    [#list findDirectories(cmdb.CMDBPath, r"solutionsv2") as solution]
        [#local result += {"Log" : result.Log + logSeparator("Delete solutionsv2 tree " + solution.File) } ]
        [#local result =
            deleteDirectory(
                result,
                solution.File,
                INTERNAL_CMDB_CLEANUP,
                dryrun
            )
        ]
        [#if progressIsNotOK(result)]
            [#break]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#-- v2.0.1
Reorganise state files into a directory tree based on deployment unit and placement

The format of the state tree will follow the pattern
state/{df}/{env}/{seg}/{du}/{placement}

Delete definition files because their file name contains the occurrence name not the
deployment unit. They will be regenerated into the correct dir on the next build.
--]
[#function internal_cmdb_cmdbmigration_upgrade_2_0_1 progress cmdb dryrun]

    [#local result = progress ]
    [#local action = INTERNAL_CMDB_UPGRADE]

    [#list findDirectories(cmdb.CMDBPath, r"state") as state]
        [#list listDirectoriesInDirectory(state.File) as framework]
            [#local result += {"Log" : result.Log + logSeparator("Reorganise state tree " + framework.File) } ]
            [#list findFiles(framework.File) as stateFile]
                [#local fileAnalysis = analysePostAccountIdFilename(stateFile) ]
                [#switch fileAnalysis.Level]
                    [#case "unknown"]
                        [#local result =
                            {
                                "Status" : CMDB_MIGRATION_PROGRESS_OK,
                                "Log" :
                                    result.Log +
                                    ["# Ignore   " + stateFile.File + " - unknown filename format"]
                            }
                        ]
                        [#break]

                    [#case "defn"]
                        [#-- Definition files are copied on every template creation --]
                        [#local result = deleteFiles(result, stateFile, action, dryrun) ]
                        [#if progressIsNotOK(result)]
                            [#return result]
                        [/#if]
                        [#break]

                    [#default]
                        [#-- Add deployment unit based subdirectories --]
                        [#if stateFile.Path?contains(fileAnalysis.DeploymentUnit) ]
                            [#-- Already added --]
                            [#continue]
                        [/#if]
                        [#switch fileAnalysis.Region]
                            [#case "us-east-1"]
                                [#local placement = "global"]
                                [#break]

                            [#default]
                                [#local placement = "default"]
                        [/#switch]
                        [#local result =
                            moveFiles(
                                result,
                                stateFile,
                                stateFile.Path,
                                formatAbsolutePath(stateFile.Path, fileAnalysis.DeploymentUnit, placement),
                                action,
                                dryrun
                            )
                        ]
                        [#if progressIsNotOK(result)]
                            [#return result]
                        [/#if]
                [/#switch]
            [/#list]
        [/#list]
    [/#list]

    [#return result]

[/#function]

[#--
Legacy reference files used a positional text format
and ended in ".ref". This function converts them to
their json based replacements
--]
[#function migrateLegacyReferences progress files action dryrun]

    [#local result = progress ]

    [#list files as file]

        [#if ! file.Contents?has_content]
            [#local result = addToProgressLog(result, logEntry("Legacy", file.File, "skipped, has no content")) ]
            [#continue]
        [/#if]

        [#-- Determine the positional fields --]
        [#local contents = file.Contents?split(r"\s+", "r") ]

        [#if file.Filename == "build.ref"]
            [#local newFile = formatAbsolutePath(file.Path,"build.json") ]

            [#local commit = contents[0]!"" ]
            [#local tag = contents[1]!"" ]

            [#-- Reformat --]
            [#local newContents =
                {
                    "Format" : ["docker"]
                } +
                attributeIfContent(
                    "Commit",
                    commit
                ) +
                attributeIfContent(
                    "Tag",
                    tag
                )
            ]

            [#local description =
                valueIfContent(
                    "commit=" + commit,
                    commit,
                    ""
                ) +
                valueIfContent(
                    ", tag=" + tag,
                    tag,
                    ""
                )
            ]
        [#else]
            [#local newFile = formatAbsolutePath(file.Path,"shared_build.json") ]

            [#local reference = contents[0]!"" ]

            [#-- Reformat --]
            [#local newContents =
                attributeIfContent(
                    "Reference",
                    reference
                )
            ]

            [#local description =
                valueIfContent(
                    "reference=" + reference,
                    reference,
                    ""
                )
            ]
        [/#if]

        [#-- Write out the new file --]
        [#local result = writeFile(result, newFile, newContents, "Create", description, dryrun) ]

        [#if progressIsNotOK(result)]
            [#-- Abort processing --]
            [#break]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Strip top level "Credentials" attribute from credentials files
--]
[#function migrateLegacyCredentials progress files action dryrun]

    [#local result = progress ]

    [#list files as file]

        [#if ! (file.ContentsAsJSON.Credentials)?? ]
            [#local result = addToProgressLog(result, logEntry("Legacy", file.File, "skipped, no top level Credentials attribute")) ]
            [#continue]
        [/#if]

        [#-- Write out the new file --]
        [#local result =
            writeFile(
                result,
                file.File,
                removeObjectAttributes(file.ContentsAsJSON, ["Credentials"]) +
                    file.ContentsAsJSON.Credentials,
                "Update",
                "removeParent=Credentials",
                dryrun
            )
        ]

        [#if progressIsNotOK(result)]
            [#-- Abort processing --]
            [#break]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Rename container.json files to segment.json files
--]
[#function migrateContainerFiles progress files action dryrun]

    [#local result = progress ]

    [#-- find container files --]
    [#list files as file]

        [#local description = file.File]

        [#local existingFiles = findFiles(file.Path, r"segment.json") ]

        [#if existingFiles?has_content ]
            [#local result = addToProgressLog(result, logEntry("Container", file.File, "skipped, already copied")) ]
            [#continue]
        [/#if]

        [#local result =
            writeFile(
                result,
                formatAbsolutePath(file.Path, "segment.json"),
                file.ContentsAsJSON,
                "Create",
                "from container.json",
                dryrun
            )
        ]

        [#if progressIsNotOK(result)]
            [#-- Abort processing --]
            [#break]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Rename container_*.ftl files to segment_*.ftl files
--]
[#function migrateContainerFragmentFiles progress files action dryrun]

    [#local result = progress ]

    [#list files as file]
        [#local segmentFragmentFilename = file.Filename?replace("container_", "segment_") ]

        [#local existingFiles = findFiles(file.Path, segmentFragmentFilename) ]

        [#if existingFiles?has_content ]
            [#local result = addToProgressLog(result, logEntry("Container", file.File, "skipped, already copied")) ]
            [#continue]
        [/#if]

        [#local result =
            writeFile(
                result,
                formatAbsolutePath(file.Path, segmentFragmentFilename),
                file.Contents,
                "Create",
                "from container_",
                dryrun
            )
        ]

        [#if progressIsNotOK(result)]
            [#-- Abort processing --]
            [#break]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Analyse file as part of inclusion of AccountId in name and content
--]
[#function analysePreAccountIdFile file]
    [#-- Check the file content --]
    [#local outputs = (file.ContentsAsJSON.Stacks[0].Outputs)![] ]
    [#local result =
        {
            "Outputs" : {
                "ProviderId" : (outputs?filter(o -> o.OutputKey == "Account")[0].OutputValue)!"",
                "Region" : (outputs?filter(o -> o.OutputKey == "Region")[0].OutputValue)!""
            }
        }
    ]

    [#-- Check the file name --]
    [#local match = file.Filename?matches("([a-z0-9]+)-(.+)-([1-9][0-9]{10})-([a-z]{2}-[a-z]+-[1-9])(-pseudo)?-(.+)") ]
    [#if match]
        [#return
            result +
            {
                "Filename" :{
                    "Level" : match?groups[1],
                    "DeploymentUnit" : match?groups[2],
                    "ProviderId" : match?groups[3],
                    "Region" : match?groups[4]
                },
                "Pseudo" : match?groups?size == 6
            }
        ]
    [/#if]
    [#local match = file.Filename?matches("([a-z0-9]+)-(.+-.+)-(.+)-([a-z]{2}-[a-z]+-[1-9])(-pseudo)?-(.+)") ]
    [#if match]
        [#return
            result +
            {
                "Filename" : {
                    "Level" : match?groups[1],
                    "DeploymentUnit" : match?groups[2],
                    "ProviderId" : "",
                    "Region" : match?groups[4]
                },
                "Pseudo" : match?groups?size == 6
            }
        ]
    [/#if]
    [#local match = file.Filename?matches("([a-z0-9]+)-(.+)-([a-z]{2}-[a-z]+-[1-9])(-pseudo)?-(.+)") ]
    [#if match]
        [#return
            result +
            {
                "Filename" : {
                    "Level" : match?groups[1],
                    "DeploymentUnit" : match?groups[2],
                    "ProviderId" : "",
                    "Region" : match?groups[3]
                },
                "Pseudo" : match?groups?size == 5
            }
        ]
    [/#if]
    [#return result]
[/#function]

[#--
Analyse file assuming AccountId in name
--]
[#function analysePostAccountIdFilename file]
    [#local match = file.Filename?matches("([a-z0-9]+)-(.+)-([a-z][a-z0-9]+)-([a-z]{2}-[a-z]+-[1-9])(-pseudo)?-(.+)") ]
    [#if match]
        [#-- Standard AWS state file --]
        [#return
            {
                "Level" : match?groups[1],
                "DeploymentUnit" : match?groups[2],
                "AccountId" : match?groups[3],
                "Region" : match?groups[4]
            }
        ]
    [/#if]
    [#local match = file.Filename?matches("([a-z0-9]+)-(.+)-([a-z][a-z0-9]+)-(eastus|australiaeast|australiasoutheast|australiacentral|australiacentral2)(-pseudo)?-(.+)") ]
    [#if match]
        [#-- Standard Azure state file --]
        [#return
            {
                "Level" : match?groups[1],
                "DeploymentUnit" : match?groups[2],
                "AccountId" : match?groups[3],
                "Region" : match?groups[4]
            }
        ]
    [/#if]
    [#-- Legacy account formats --]
    [#local match = file.Filename?matches("account-([a-z][a-z0-9]+)-([a-z]{2}-[a-z]+-[1-9])-(.+)") ]
    [#if match]
        [#return
            {
                "Level" : "account",
                "DeploymentUnit" : match?groups[1],
                "Region" : match?groups[2]
            }
        ]
    [/#if]
    [#local match = file.Filename?matches("account-([a-z]{2}-[a-z]+-[1-9])-(.+)") ]
    [#if match]
        [#return
            {
                "Level" : "account",
                "DeploymentUnit" : "s3",
                "Region" : match?groups[1]
            }
        ]
    [/#if]
    [#-- Legacy product formats --]
    [#local match = file.Filename?matches("product-([a-z]{2}-[a-z]+-[1-9])-(.+)") ]
    [#if match]
        [#return
            {
                "Level" : "product",
                "DeploymentUnit" : "cmk",
                "Region" : match?groups[1]
            }
        ]
    [/#if]
    [#-- Legacy segment formats --]
    [#local match = file.Filename?matches("(seg|cont)-key-([a-z]{2}-[a-z]+-[1-9])-(.+)") ]
    [#if match]
        [#return
            {
                "Level" : "seg",
                "DeploymentUnit" : "cmk",
                "Region" : match?groups[2]
            }
        ]
    [/#if]
    [#local match = file.Filename?matches("cont-([a-z][a-z0-9]+)-([a-z]{2}-[a-z]+-[1-9])-(.+)") ]
    [#if match]
        [#return
            {
                "Level" : "seg",
                "DeploymentUnit" : match?groups[1],
                "Region" : match?groups[2]
            }
        ]
    [/#if]
    [#return
        {
            "Level" : "unknown"
        }
    ]
[/#function]

[#--
Lookup provider id to account id mapping
--]
[#function getAccountMappings]
    [#local result = {} ]
    [#list getCMDBTenants() as tenant]
        [#local accounts = getCMDBAccounts(tenant) ]
        [#list accounts as account]
            [#local accountContent = (getCMDBAccountContent(tenant, account).Blueprint.Account)!{} ]
            [#local providerId = accountContent.ProviderId!accountContent.AWSId!accountContent.AzureId!""]
            [#local accountId = accountContent.Id!accountContent.Name!""]
            [#if providerId?has_content && accountId?has_content]
                [#local result += { providerId : accountId } ]
            [/#if]
        [/#list]
    [/#list]
    [#return result]
[/#function]

[#--
Add placement information to stack file content
--]
[#function addPlacementDetailsToStackFiles progress files providerId region action dryrun]

    [#local result = progress ]

    [#list files as file]
        [#-- Ensure something to work with --]
        [#local content = (file.ContentsAsJSON)!{} ]
        [#if !content?has_content]
            [#continue]
        [/#if]

        [#local fileAnalysis = analysePreAccountIdFile(file) ]

        [#-- Stack filename should provide the region but just in case ... --]
        [#local stackRegion = (fileAnalysis.Filename.Region)!region ]

        [#local contentUpdateNeeded = ! (fileAnalysis.Outputs.ProviderId?has_content && fileAnalysis.Outputs.Region?has_content) ]

        [#if contentUpdateNeeded]
            [#local stackContent = [] ]
            [#list content.Stacks as stack]
                [#if stack?first]
                    [#local outputs = (stack.Outputs)![] ]

                    [#-- Add placement content if not present --]
                    [#if ! fileAnalysis.Outputs.ProviderId?has_content]
                        [#local outputs += [ {"OutputKey" : "Account", "OutputValue" : providerId} ] ]
                    [/#if]
                    [#if ! fileAnalysis.Outputs.Region?has_content]
                        [#local outputs += [ {"OutputKey" : "Region", "OutputValue" : stackRegion} ] ]
                    [/#if]

                    [#local stackContent += [stack + {"Outputs" : outputs }] ]
                [#else]
                    [#local stackContent += [stack] ]
                [/#if]
            [/#list]

            [#local content += {"Stacks" : stackContent} ]
            [#local result =
                writeFile(
                    result,
                    file.File,
                    content,
                    "Update"
                    "placement info",
                    dryrun
                )
            ]
            [#if result.Status != CMDB_MIGRATION_PROGRESS_OK]
                [#-- Abort processing --]
                [#break]
            [/#if]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Add accountId information to filenames that contain a region
--]
[#function addAccountIdToFilenames progress files accountId action dryrun]

    [#local result = progress ]

    [#list files as file]
        [#local fileAnalysis = analysePreAccountIdFile(file) ]

        [#local region = (fileAnalysis.Filename.Region)!"" ]

        [#if region?has_content &&
            (! ((fileAnalysis.Filename.ProviderId)?has_content || file.File?contains("-" + accountId + "-"))) ]

            [#local result =
                moveFile(
                    result,
                    file,
                    file +
                    {
                        "File" : file.File?replace("-" + region + "-","-" + accountId + "-" + region  + "-"),
                        "Filename" : file.Filename?replace("-" + region + "-","-" + accountId + "-" + region  + "-")
                    },
                    action,
                    dryrun
                )
            ]
            [#if result.Status != CMDB_MIGRATION_PROGRESS_OK]
                [#-- Abort processing --]
                [#break]
            [/#if]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Add accountId information to pem files
--]
[#function addAccountIdToPEMFiles progress files accountId region action dryrun]

    [#local result = progress ]

    [#list files as file]

        [#local result =
            moveFile(
                result,
                file,
                file +
                {
                    "File" : file.File?replace("aws-","aws-" + accountId + "-" + region  + "-"),
                    "Filename" : file.Filename?replace("aws-","aws-" + accountId + "-" + region  + "-")
                },
                action,
                dryrun
            )
        ]
        [#if result.Status != CMDB_MIGRATION_PROGRESS_OK]
            [#-- Abort processing --]
            [#break]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Progress indicator
--]
[#assign CMDB_MIGRATION_PROGRESS_OK = 0]
[#assign CMDB_MIGRATION_PROGRESS_ABORT = 0]

[#function createProgressIndicator status=CMDB_MIGRATION_PROGRESS_OK log=[] ]
    [#return {"Status" : status, "Log" : asFlattenedArray(log)} ]
[/#function]
[#function getProgressStatus progressIndicator]
    [#return progressIndicator.Status ]
[/#function]
[#function getProgressLog progressIndicator]
    [#return progressIndicator.Log ]
[/#function]
[#function updateProgressStatus progressIndicator status ]
    [#return progressIndicator + {"Status" : status} ]
[/#function]
[#function addToProgressLog progressIndicator log...]
    [#return progressIndicator + {"Log" : progressIndicator.Log + asFlattenedArray(log)} ]
[/#function]
[#function progressIsNotOK progressIndicator]
    [#return getProgressStatus(progressIndicator) != CMDB_MIGRATION_PROGRESS_OK ]
[/#function]
[#function progressIsOK progressIndicator]
    [#return getProgressStatus(progressIndicator) == CMDB_MIGRATION_PROGRESS_OK ]
[/#function]
[#function setProgressOK progressIndicator]
    [#return updateProgressStatus(progressIndicator, CMDB_MIGRATION_PROGRESS_OK) ]
[/#function]
[#function setProgressAbort progressIndicator]
    [#return updateProgressStatus(progressIndicator, CMDB_MIGRATION_PROGRESS_ABORT) ]
[/#function]

[#--
Log entry
--]
[#function formatLogEntry action description outcome=""]
    [#return  "# " + action?right_pad(9) + " " + description + valueIfContent(" - " + outcome, outcome, "") ]
[/#function]
[#function logEntry action description outcome=""]
    [#return [formatLogEntry(action, description, outcome)] ]
[/#function]
[#function logStatusEntry action description status=CMDB_MIGRATION_PROGRESS_OK]
    [#return logEntry(action, description, valueIfTrue("successful", status == CMDB_MIGRATION_PROGRESS_OK, "failed, code=" + status)) ]
[/#function]

[#--
Log separator
--]
[#function formatLogSeparator description]
    [#return  formatLogEntry("=========", description) ]
[/#function]
[#function logSeparator description]
    [#return  ["#", formatLogSeparator(description)] ]
[/#function]

[#--
Log alert
--]
[#function formatLogAlert description]
    [#return  "# ... " + description]
[/#function]
[#function logAlert description]
    [#return  [formatLogAlert(description)] ]
[/#function]

[#--
Find file matches in directory tree
--]
[#function findFileMatches rootDir options={} ]
    [#return findCMDBMatches(rootDir, [], options, {"IgnoreDirectories" : true}) ]
[/#function]

[#--
Find directory matches in directory tree
--]
[#function findDirectoryMatches rootDir options={} ]
    [#return findCMDBMatches(rootDir, [], options, {"IgnoreFiles" : true}) ]
[/#function]

[#--
Find files in directory tree
--]
[#function findFiles rootDir glob="" options={} ]
    [#return findFileMatches(rootDir, options + attributeIfContent("FilenameGlob", glob)) ]
[/#function]

[#--
Find directories in directory tree
--]
[#function findDirectories rootDir glob="" options={} ]
    [#return findDirectoryMatches(rootDir, options + attributeIfContent("FilenameGlob", glob)) ]
[/#function]

[#--
Find matches in directory
--]
[#function listMatchesInDirectory rootDir options={} ]
    [#return findCMDBMatches(rootDir, [], options+ { "MinDepth" : 1, "MaxDepth" : 1 }) ]
[/#function]

[#--
List files in directory
--]
[#function listFilesInDirectory rootDir glob="" options={} ]
    [#return findFiles(rootDir, glob, options + { "MinDepth" : 1, "MaxDepth" : 1 }) ]
[/#function]

[#--
List subdirectories in directory
--]
[#function listDirectoriesInDirectory rootDir glob="" ]
    [#return findDirectories(rootDir, glob, { "MinDepth" : 1, "MaxDepth" : 1 }) ]
[/#function]

[#--
Get parent directory
--]
[#function getParentDirectory dir ]
    [#local parts = dir.split("?")]
    [#return formatAbsolutePath(parts[0..parts.length-2])]
[/#function]

[#--
Get parent directory name
--]
[#function getDirectoryName dir ]
    [#local parts = dir.split("?")]
    [#return parts[parts.length-1] ]
[/#function]

[#--
Make Directory
--]
[#function makeDirectory progress dir action dryrun]

    [#local result = setProgressOK(progress) ]

    [#-- Nothing to do if it already exists --]
    [#if findDirectories(
            dir?keep_before_last('/'),
            dir?keep_after_last('/'),
            {
                "IgnoreDotDirectories" : false,
                "StopAfterFirstMatch" : true
            }
        )?has_content ]
        [#return result]
    [/#if]

    [#if ! dryrun?has_content]
        [#local result =
            updateProgressStatus(
                result,
                mkdirCMDB(
                    dir,
                    {
                        "Parents" : true
                    }
                )
            )
        ]
    [/#if]

    [#return addToProgressLog(result, logStatusEntry("MkDir", dir, getProgressStatus(result))) ]

[/#function]

[#--
Copy file
--]
[#function copyFile progress from to action dryrun failOnContentMismatch]

    [#local result = setProgressOK(progress) ]

    [#local description = from.File + " to " + to.File]

    [#local existingFile = (listFilesInDirectory(to.Path, to.Filename, {"IgnoreDotFiles" : false, "IgnoreDotDirectories" : false} )[0])!{} ]
    [#if existingFile?has_content ]
        [#-- confirm the content is the same - otherwise it is likely an error --]
        [#if existingFile.Content == from.Content]
            [#return addToProgressLog(result, logEntry("Copy", description, "skipped, file exists with same content")) ]
        [#else]
            [#if failOnContentMismatch]
                [#return addToProgressLog(setProgressAbort(result), logEntry("Copy", description, "failed, file exists with different content")) ]
            [#else]
                [#return addToProgressLog(result, logEntry("Copy", description, "skipped, file exists (content ignored) ")) ]
            [/#if]
        [/#if]
    [#else]
        [#local result = makeDirectory(result, to.Path, action, dryrun) ]
    [/#if]

    [#if progressIsOK(result) ]
        [#if ! dryrun?has_content]
            [#local result =
                updateProgressStatus(
                    result,
                    cpCMDB(
                        from.File,
                        to.File,
                        {
                            "Recurse" : false,
                            "Preserve" : true
                        }
                    )
                )
            ]
        [/#if]

        [#local result = addToProgressLog(result, logStatusEntry("Copy", description, getProgressStatus(result))) ]
    [/#if]
    [#return result]
[/#function]

[#--
Copy files
--]
[#function copyFiles progress files fromBaseDir toBaseDir action dryrun failOnContentMismatch=true]

    [#local result = setProgressOK(progress) ]

    [#list asArray(files) as fromFile]
        [#if fromFile.Path == fromBaseDir]
            [#local toDir = toBaseDir ]
        [#else]
            [#local relativeDir = fromFile.Path?remove_beginning(fromBaseDir) ]
            [#local toDir = formatAbsolutePath(toBaseDir, relativeDir) ]
        [/#if]
        [#-- Simulate the file entry for the target file --]
        [#local toFile =
            {
                "File" : formatAbsolutePath(toDir, fromFile.Filename),
                "Path" : toDir,
                "Filename" : fromFile.Filename
            }
        ]

        [#local result = copyFile(result, fromFile, toFile, action, dryrun, failOnContentMismatch) ]
        [#if progressIsNotOK(result) ]
            [#-- Abort processing --]
            [#break]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Copy files in directory
--]
[#function copyFilesInDirectory progress fromDir toDir action dryrun failOnContentMismatch=true]
    [#return copyFiles(progress,listFilesInDirectory(fromDir), fromDir, toDir, action, dryrun, failOnContentMismatch) ]
[/#function]

[#--
Copy directory tree
--]
[#function copyDirectoryTree progress fromDir toDir action dryrun failOnContentMismatch=true]
    [#return
        copyFiles(
            progress,
            findFiles(fromDir, "", {"IgnoreDotFiles" : false, "IgnoreDotDirectories" : false}),
            fromDir,
            toDir,
            action,
            dryrun,
            failOnContentMismatch
        )
    ]
[/#function]

[#--
Delete files
--]
[#function deleteFiles progress files action dryrun]

    [#local result = setProgressOK(progress) ]

    [#list asArray(files) as file]

        [#if ! dryrun?has_content]
            [#local result =
                updateProgressStatus(
                    result,
                    rmCMDB(
                        file.File,
                        {
                            "Recurse" : false,
                            "Force" : false
                        }
                    )
                )
            ]
        [/#if]

        [#local result = addToProgressLog(result, logStatusEntry("Delete", file.File, getProgressStatus(result))) ]

        [#if progressIsNotOK(result) ]
            [#-- Abort processing --]
            [#break]
        [/#if]
    [/#list]

    [#return result ]

[/#function]

[#--
Delete directory
--]
[#function deleteDirectory progress fromDir action dryrun]

    [#local result = setProgressOK(progress) ]

    [#if ! dryrun?has_content]
        [#local result =
            updateProgressStatus(
                result,
                rmCMDB(
                    fromDir,
                    {
                        "Recurse" : true,
                        "Force" : true
                    }
                )
            )
        ]
    [/#if]

    [#return addToProgressLog(result, logStatusEntry("Deltree", fromDir, getProgressStatus(result))) ]
[/#function]

[#-- Remove empty directories --]
[#function deleteEmptyDirectories progress fromDir action dryrun]

    [#local result = setProgressOK(progress) ]

    [#local directories = findDirectories(fromDir, "", {"IgnoreDotDirectories" : false})?sort_by("File")?reverse ]

    [#list directories as directory]
        [#local matches = listMatchesInDirectory(directory.File, {"IgnoreDotFiles" : false, "IgnoreDotDirectories" : false}) ]
        [#if matches?size == 0 ]
            [#local result = deleteDirectory(result, directory.File, action, dryrun) ]
            [#if progressIsNotOK(result) ]
                [#break]
            [/#if]
        [/#if]
    [/#list]

    [#return result]
[/#function]

[#--
Move file
--]
[#function moveFile progress from to action dryrun failOnContentMismatch=true]

    [#local result = copyFile(progress, from, to, action, dryrun, failOnContentMismatch) ]
    [#if progressIsNotOK(result) ]
        [#return result]
    [/#if]

    [#return deleteFiles(result, from, action, dryrun) ]
[/#function]

[#--
Move files
--]
[#function moveFiles progress files fromBaseDir toBaseDir action dryrun failOnContentMismatch=true]

    [#local result = copyFiles(progress, files, fromBaseDir, toBaseDir, action, dryrun, failOnContentMismatch) ]
    [#if progressIsNotOK(result) ]
        [#return result]
    [/#if]

    [#return deleteFiles(result, files, action, dryrun) ]
[/#function]

[#--
Move files in directory
--]
[#function moveFilesInDirectory progress fromDir toDir action dryrun failOnContentMismatch=true]
    [#return moveFiles(progress, listFilesInDirectory(fromDir), fromDir, toDir, action, dryrun, failOnContentMismatch) ]
[/#function]

[#--
Move directory tree
--]
[#function moveDirectoryTree progress fromDir toDir action dryrun failOnContentMismatch=true]
    [#-- Move all the files --]
    [#local result =
        moveFiles(
            progress,
            findFiles(fromDir, "", {"IgnoreDotFiles" : false, "IgnoreDotDirectories" : false}),
            fromDir,
            toDir,
            action,
            dryrun,
            failOnContentMismatch) ]
    [#if progressIsNotOK(result) ]
        [#return result]
    [/#if]

    [#-- Remove any empty directories that result --]
    [#return deleteEmptyDirectories(result, fromDir, action, dryrun) ]

[/#function]

[#-- Write file --]
[#function writeFile progress file content action description dryrun options={} ]

    [#local result = setProgressOK(progress) ]

    [#local writeOptions =
        {
            "Format" : "json",
            "Formatting" : "pretty",
            "Append" : false
        } +
        options
    ]

    [#if ! dryrun?has_content]
        [#local result =
            updateProgressStatus(
                result,
                toCMDB(
                    file,
                    content,
                    writeOptions
                )
            )
        ]
    [/#if]

    [#return
        addToProgressLog(
            result,
            logStatusEntry(
                action,
                file + valueIfContent(" (" + description + ")", description, ""),
                getProgressStatus(result)
            )
        )
    ]
[/#function]

[#--
Migrate to segment subdirs

subDir should be an empty string for settings, and "cf" for state
--]
[#function migrateToSegmentDirs progress fromDir toDir subDir action dryrun]

    [#-- First copy the files --]
    [#local result = copyFilesInDirectory(progress, formatAbsolutePath(fromDir, subDir), formatAbsolutePath(toDir, "shared"), action, dryrun) ]
    [#if progressIsNotOK(result) ]
        [#return result] ]
    [/#if]

    [#-- Now handle the directories --]
    [#list listDirectoriesInDirectory(fromDir) as file]

        [#if file.Filename == subDir]
            [#continue]
        [/#if]

        [#local sourceDir = formatAbsolutePath(file.File, subDir) ]

        [#if ! listMatchesInDirectory(sourceDir)?has_content]
            [#-- Nothing to copy --]
            [#continue]
        [/#if]

        [#local result = copyDirectoryTree(result, sourceDir, formatAbsolutePath(toDir, File.Filename, "default"), action, dryrun) ]

        [#if progressIsNotOK(result) ]
            [#-- Abort processing --]
            [#break]
        [/#if]

    [/#list]

    [#return result ]
[/#function]
