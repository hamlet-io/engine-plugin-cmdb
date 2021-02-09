[#ftl]

[#--------------------------------------
-- CMDB layered file system functions --
----------------------------------------]

[#-- This macro needs to be called before any other CMDB access is attempted --]
[#-- The CMDB structure analysis is always cached.                           --]
[#macro initialiseCMDB cacheAll=false]
    [#local result = initialiseCMDBFileSystem({}) ]
    [#assign cmdbCache = initialiseCache() ]
    [#assign cmdbCacheAll = cacheAll ]
[/#macro]

[#-- Common filtering on the results of a CMDB query --]
[#function filterCMDBMatches matches filters={} ]
    [#if ! filters?has_content]
        [#return matches]
    [/#if]
    [#local result = matches]
    [#if filters.IgnoreFiles!false]
        [#local result = internalFilterCMDBIgnoreFiles(result)]
    [/#if]
    [#if filters.IgnoreDirectories!false]
        [#local result = internalFilterCMDBIgnoreDirectories(result)]
    [/#if]
    [#if filters.ContentOnly!false]
        [#local result = internalFilterCMDBContentOnly(result)]
    [/#if]
    [#if filters.JSONContentOnly!false]
        [#local result = internalFilterCMDBJSONContentOnly(result)]
    [/#if]
    [#if filters.IncludeContentOnly!false]
        [#local result = internalFilterCMDBIncludesOnly(result)]
    [/#if]
    [#if filters.SuppressContent!false]
        [#local result = internalFilterCMDBSuppressContent(result)]
    [/#if]
    [#if filters.FilenamesOnly!false]
        [#local result = internalFilterCMDBFilenamesOnly(result, false) ]
    [/#if]
    [#if filters.FlattenedFilenamesOnly!false]
        [#local result = internalFilterCMDBFilenamesOnly(result, true) ]
    [/#if]
    [#return result]
[/#function]

[#-- Base function for looking up matches in the cmdb file system --]
[#--]
Options are
- MinDepth - how deep to go before searching relative to path
- MaxDepth - how deep to go before stopping searching relative to path
- StopAfterFirstMatch(false) - at most one result returned
- IgnoreSubtreeAfterMatch(false) - only one match per directory tree
- FilenameGlob - glob pattern that file/directory names must match
- AddStartingWildcard(true) - add ".*" between path and regex (if not "^" anchored)
- AddEndingWildcard(true) - add ".*" after regex (if not "$" anchored)
- Regex - array of regex patterns to match
- IgnoreDotDirectories(true) - don't search directories starting with "."
- IgnoreDotFiles(true) : don't include files starting with "."
- IncludeCMDBInformation(false) - include CMDB information in each match result
--]
[#function findCMDBMatches path alternatives=[] options={} filters={} ]

    [#-- Ignore empty paths --]
    [#if !path?has_content]
        [#return [] ]
    [/#if]

    [#-- Construct alternate paths --]
    [#-- Alternatives can be arrays of values to be converted into a relative path --]
    [#local regex = [] ]
    [#list asArray(alternatives) as alternative]
        [#local alternativePath = formatRelativePath(alternative)]
        [#if alternativePath?has_content]
            [#local regex += [ alternativePath ] ]
        [/#if]
    [/#list]

    [#-- Find matches --]
    [#return
        filterCMDBMatches(
            getCMDBTree(
                formatAbsolutePath(path),
                options +
                attributeIfContent("Regex", regex)
            ),
            filters
        )
    ]
[/#function]

[#-- CMDB cache management --]
[#macro addToCMDBCache contents...]
    [#assign cmdbCache = addToCache(cmdbCache, contents) ]
[/#macro]

[#macro clearCMDBCache paths={} ]
    [#assign cmdbCache = clearCache(cmdbCache, paths) ]
[/#macro]

[#macro clearCMDBCacheSection path=[] ]
    [#assign cmdbCache = clearCacheSection(cmdbCache, path) ]
[/#macro]

[#function getCMDBCacheSection path=[] ]
    [#return getCacheSection(cmdbCache, path) ]
[/#function]

[#function getCMDBCacheTenantSection tenant path=[] ]
    [#return getCMDBCacheSection(["Tenants", tenant] + path) ]
[/#function]

[#function getCMDBCacheAccountSection tenant account path=[] ]
    [#return getCMDBCacheTenantSection(tenant, ["Accounts", account] + path) ]
[/#function]

[#function getCMDBCacheProductSection tenant product path=[] ]
    [#return getCMDBCacheTenantSection(tenant, ["Products", product] + path) ]
[/#function]

[#function getCMDBCacheEnvironmentSection tenant product environment path=[] ]
    [#return getCMDBCacheProductSection(tenant, product, ["Environments", environment] + path) ]
[/#function]

[#function getCMDBCacheSegmentSection tenant product environment segment path=[] ]
    [#return getCMDBCacheProductSection(tenant, product, ["Environments", environment, "Segments", segment] + path) ]
[/#function]

[#-- CMDB structure analysis --]
[#function analyseCMDBTenantStructure tenant="" path="/" ]
    [#if
        cmdbCache.Tenants?? &&
        (
            (!tenant?has_content) ||
            (cmdbCache.Tenants[tenant]?has_content)
        ) ]
        [#local tenants = cmdbCache.Tenants]
    [#else]
        [#local cmdbPath = internalFindFirstCMDBPath(["tenant", "accounts"])]
        [#if cmdbPath?has_content]
            [#local tenants = internalAnalyseTenantStructure(cmdbPath, tenant, {"MaxDepth" : 2} ) ]
        [#else]
            [#local tenants = internalAnalyseTenantStructure(path, tenant) ]
        [/#if]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : tenants
                }
            )
        ]
    [/#if]

    [#return tenants ]
[/#function]

[#function analyseCMDBAccountStructure tenant account="" ]
    [#-- Assume tenants up to date in cmdbCache --]
    [#local tenantStructure = getCMDBCacheTenantSection(tenant) ]
    [#local accounts = {} ]

    [#if tenantStructure?has_content ]
        [#if
            tenantStructure.Accounts?? &&
            (
                (!account?has_content) ||
                (tenantStructure.Accounts[account]?has_content)
            ) ]
            [#local accounts = tenantStructure.Accounts ]
        [#else]
            [#local startingPath = tenantStructure.Paths.CMDB]
            [#local cmdbPath = internalFindFirstCMDBPath(["accounts"])]
            [#if cmdbPath?has_content]
                [#local startingPath = cmdbPath]
            [/#if]

            [#local accounts = internalAnalyseAccountStructure(startingPath, account) ]
            [#assign cmdbCache =
                addToCache(
                    cmdbCache,
                    {
                        "Tenants" : {
                            tenant :
                                {
                                    "Accounts" : accounts
                                }
                        }
                    }
                )
            ]
        [/#if]
    [/#if]

    [#return accounts ]
[/#function]

[#function analyseCMDBProductStructure tenant product="" ]
    [#-- Assume tenants up to date in cmdbCache --]
    [#local tenantStructure = getCMDBCacheTenantSection(tenant) ]
    [#local products = {} ]

    [#if tenantStructure?has_content ]
        [#if
            tenantStructure.Products?? &&
            (
                (!product?has_content) ||
                (tenantStructure.Products[product]?has_content)
            ) ]
            [#local products =
                valueIfContent(
                    getObjectAttributes(
                        tenantStructure.Products,
                        product
                    ),
                    product,
                    tenantStructure.Products
                )
            ]
        [#else]
            [#--
            [#local startingPath = (tenantStructure.Paths.CMDB)!""]
            [#local cmdbPath = internalFindFirstCMDBPath(product)]
            [#if cmdbPath?has_content]
                [#local startingPath = cmdbPath]
            [/#if]
             --]
            [#local startingPath = "/" ]

            [#local products = internalAnalyseProductStructure(startingPath, product) ]
            [#assign cmdbCache =
                addToCache(
                    cmdbCache,
                    {
                        "Tenants" : {
                            tenant :
                                {
                                    "Products" : products
                                }
                        }
                    }
                )
            ]
        [/#if]
    [/#if]

    [#return products ]
[/#function]

[#function analyseCMDBEnvironmentStructure tenant product environment="" ]

    [#-- Assume product up to date in cmdbCache --]
    [#local productStructure = getCMDBCacheProductSection(tenant, product) ]
    [#local environments = {} ]

    [#if productStructure?has_content ]
        [#if
            productStructure.Environments?? &&
            (
                (!environment?has_content) ||
                (productStructure.Environments[environment]?has_content)
            ) ]
            [#local environments =
                valueIfContent(
                    getObjectAttributes(
                        productStructure.Environments,
                        environment
                    ),
                    environment,
                    productStructure.Environments
                )
            ]
        [#else]
            [#local environments = internalAnalyseEnvironmentStructure((productStructure.Paths.Infrastructure.Solutions)!"", environment) ]
            [#assign cmdbCache =
                addToCache(
                    cmdbCache,
                    {
                        "Tenants" : {
                            tenant : {
                                "Products" : {
                                    product : {
                                        "Environments" : environments
                                    }
                                }
                            }
                        }
                    }
                )
            ]
        [/#if]
    [/#if]

    [#return environments ]
[/#function]

[#function analyseCMDBSegmentStructure tenant product environment segment="" ]

    [#-- Assume environment up to date in cmdbCache --]
    [#local environmentStructure = getCMDBCacheEnvironmentSection(tenant, product, environment) ]
    [#local segments = {} ]

    [#if environmentStructure?has_content ]
        [#if
            environmentStructure.Segments?? &&
            (
                (!segment?has_content) ||
                (environmentStructure.Segments[segment]?has_content)
            ) ]
            [#local segments =
                valueIfContent(
                    getObjectAttributes(
                        environmentStructure.Segments,
                        segment
                    ),
                    segment,
                    environmentStructure.Segments
                )
            ]
        [#else]
            [#local segments =  internalAnalyseSegmentStructure((environmentStructure.Paths.Marker)!"", segment) ]
            [#assign cmdbCache =
                addToCache(
                    cmdbCache,
                    {
                        "Tenants" : {
                            tenant : {
                                "Products" : {
                                    product : {
                                        "Environments" : {
                                            environment : {
                                                "Segments" : segments
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                )
            ]
        [/#if]
    [/#if]

    [#return segments ]
[/#function]

[#function getCMDBTenants ]
    [#return analyseCMDBTenantStructure()?keys?sort]
[/#function]

[#function getCMDBAccounts tenant]
    [#return analyseCMDBAccountStructure(tenant)?keys?sort]
[/#function]

[#function getCMDBProducts tenant]
    [#return analyseCMDBProductStructure(tenant)?keys?sort]
[/#function]

[#function getCMDBEnvironments tenant product]
    [#return analyseCMDBEnvironmentStructure(tenant, product)?keys?sort]
[/#function]

[#function getCMDBSegments tenant product environment]
    [#return analyseCMDBSegmentStructure(tenant, product, environment)?keys?sort]
[/#function]

[#-- Analyse overall CMDB structure - results are automatically cached --]
[#macro analyseCMDBStructure cacheAll=false]
    [@initialiseCMDB cacheAll /]
    [#list getCMDBTenants() as tenant]
        [#local accounts = getCMDBAccounts(tenant) ]
        [#list getCMDBProducts(tenant) as product]
            [#list getCMDBEnvironments(tenant, product) as environment]
                [#local segments = getCMDBSegments(tenant, product, environment) ]
            [/#list]
        [/#list]
    [/#list]
[/#macro]

[#-- CMDB File analysis --]
[#function analyseCMDBTenantFiles tenant filters={} cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheTenantSection(tenant, ["Files"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Analyse files --]
    [#local result = internalAssembleCMDBTenantFiles(tenant, filters) ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Files" : result
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#function analyseCMDBAccountFiles tenant account filters={} cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheAccountSection(tenant, account, ["Files"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Analyse files --]
    [#local result = internalAssembleCMDBAccountFiles(tenant, account, filters) ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Accounts" : {
                                account : {
                                    "Files" : result
                                }
                            }
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#function analyseCMDBProductFiles tenant product filters={} cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheProductSection(tenant, product, ["Files"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Analyse files --]
    [#local result = internalAssembleCMDBProductFiles(tenant, product, filters) ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Products" : {
                                product : {
                                    "Files" : result
                                }
                            }
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#function analyseCMDBSegmentFiles tenant product environment segment filters={} cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheSegmentSection(tenant, product, environment, segment, ["Files"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Analyse files --]
    [#local result = internalAssembleCMDBSegmentFiles(tenant, product, environment, segment, filters) ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Products" : {
                                product : {
                                    "Environments" : {
                                        environment : {
                                            "Segments" : {
                                                segment : {
                                                    "Files" : result
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#-- CMDB content --]
[#function getCMDBTenantContent tenant cacheResult=false]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheTenantSection(tenant, ["Content"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Assemble files --]
    [#local files = analyseCMDBTenantFiles(tenant, {}, cacheResult) ]

    [#-- Assemble content --]
    [#local result =
        {
            "Blueprint" : internalAssembleCMDBBlueprint(files.Blueprint)
        }
    ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Content" : result
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#function getCMDBAccountContent tenant account cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheAccountSection(tenant, account, ["Content"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Assemble files --]
    [#local files = analyseCMDBAccountFiles(tenant, account, {}, cacheResult) ]

    [#-- Assemble content --]
    [#local result =
        {
            "Blueprint" : internalAssembleCMDBBlueprint(files.Blueprint),
            "Settings" : internalAssembleCMDBSettings(files.Settings),
            "StackOutputs" : internalAssembleCMDBStackOutputs(files.StackOutputs)
        }
    ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Accounts" : {
                                account : {
                                    "Content" : result
                                }
                            }
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#function getCMDBProductContent tenant product cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheProductSection(tenant, product, ["Content"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Assemble files --]
    [#local files = analyseCMDBProductFiles(tenant, product, {}, cacheResult) ]

    [#-- Assemble content --]
    [#local result =
        {
            "Blueprint" : internalAssembleCMDBBlueprint(files.Blueprint)
        }
    ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Products" : {
                                product : {
                                    "Content" : result
                                }
                            }
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#function getCMDBSegmentContent tenant product environment segment cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheSegmentSection(tenant, product, environment, segment, ["Content"]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Assemble files --]
    [#local files = analyseCMDBSegmentFiles(tenant, product, environment, segment, {}, cacheResult) ]

    [#-- Assemble content --]
    [#local result =
        {
            "Blueprint" : internalAssembleCMDBBlueprint(files.Blueprint),
            "Settings" : internalAssembleCMDBSettings(files.Settings),
            "StackOutputs" : internalAssembleCMDBStackOutputs(files.StackOutputs),
            "Fragments" : internalAssembleCMDBFragments(files.Fragments)
        }
    ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Products" : {
                                product : {
                                    "Environments" : {
                                        environment : {
                                            "Segments" : {
                                                segment : {
                                                    "Content" : result
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#function getCMDBSegmentPlacementContent tenant product environment segment account region cacheResult=false ]
    [#-- Check cache --]
    [#if cmdbCacheAll || cacheResult]
        [#local result = getCMDBCacheSegmentSection(tenant, product, environment, segment, ["Placements", account, region]) ]
        [#if result?has_content]
            [#return result]
        [/#if]
    [/#if]

    [#-- Assemble files --]
    [#local files = analyseCMDBSegmentFiles(tenant, product, environment, segment, {}, cacheResult) ]

    [#-- Assemble content --]
    [#local result = internalAssembleCMDBDefinitions(files.Definitions, account, region) ]
    [#if cmdbCacheAll || cacheResult]
        [#assign cmdbCache =
            addToCache(
                cmdbCache,
                {
                    "Tenants" : {
                        tenant : {
                            "Products" : {
                                product : {
                                    "Environments" : {
                                        environment : {
                                            "Segments" : {
                                                segment : {
                                                    "Placements" : {
                                                        account : {
                                                            region : result
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            )
        ]
    [/#if]
    [#return result]
[/#function]

[#--------------------------------------------------
-- Internal support functions for cmdb processing --
----------------------------------------------------]

[#function internalFilterCMDBIgnoreFiles matches]
    [#return matches?filter(match -> match.IsDirectory) ]
[/#function]

[#function internalFilterCMDBIgnoreDirectories matches]
    [#return matches?filter(match -> !match.IsDirectory) ]
[/#function]

[#function internalFilterCMDBIncludesOnly matches]
    [#return matches?filter(match -> match.IsTemplate!false) ]
[/#function]

[#function internalFilterCMDBFilenamesOnly matches flatten=false]
    [#local result = [] ]
    [#list matches as match ]
        [#if flatten]
            [#local result += [ match.File ] ]
        [#else]
            [#local result += [ {"File" : match.File} ] ]
        [/#if]
    [/#list]
    [#return result]
[/#function]

[#function internalFilterCMDBContentOnly matches ]
    [#return matches?filter(match -> match.Contents?has_content) ]
[/#function]

[#function internalFilterCMDBJSONContentOnly matches ]
    [#return matches?filter(match -> match.ContentsAsJSON?has_content) ]
[/#function]

[#function internalFilterCMDBSuppressContent matches ]
    [#local result = [] ]
    [#list matches as match ]
        [#local result +=
            [
                match +
                {
                    "Contents" : match.Contents?has_content,
                    "ContentsAsJSON" : match.ContentsAsJSON?has_content
                }
            ]
        ]
    [/#list]
    [#return result]
[/#function]

[#-- Return the first file/directory match --]
[#function internalGetFirstCMDBMatch path alternatives options={} filters={} ]
    [#local result =
        findCMDBMatches(
            path,
            alternatives,
            {
                "AddEndingWildcard" : false,
                "StopAfterFirstMatch" : true
            } +
            options,
            filters
        )
    ]
    [#if result?has_content]
        [#return result[0] ]
    [/#if]
    [#return {} ]
[/#function]

[#-- Convenience method to attach a marker file to a range of alternatives --]
[#function internalGetCMDBMarkerFiles path alternatives marker options={} ]
    [#local markers = [] ]
    [#list alternatives as alternative]
        [#local markers += [ [alternative, marker] ] ]
    [/#list]

    [#-- Don't bother with searching subdirectories under any found marker file --]
    [#return
        findCMDBMatches(
            path,
            markers,
            {
                "AddEndingWildcard" : false,
                "IgnoreSubtreeAfterMatch" : true
            } +
            options
        )
    ]
[/#function]

[#-- Find files with JSON content --]
[#function internalAssembleCMDBJSONFiles path alternatives options={} filters={} ]
    [#-- Support json or yaml --]
    [#local regex = [] ]
    [#list alternatives as alternative]
        [#local regex += [ [alternative, r"[^/]+\.(json|yaml|yml)"] ] ]
    [/#list]
    [#return
        findCMDBMatches(
            path,
            regex,
            options +
            {
                "AddEndingWildcard" : false
            },
            filters +
            {
                "AddStartingWildcard" : false,
                "IgnoreDirectories" : true,
                "JSONContentOnly" : true
            }
        )
    ]
[/#function]

[#-- Find freemarker files --]
[#function internalAssembleCMDBIncludeFiles path alternatives options={} filters={} ]
    [#return
        findCMDBMatches(
            path,
            alternatives,
            options +
            {
                "FilenameGlob" : "*.ftl",
                "IncludeCMDBInformation" : true
            },
            filters +
            {
                "AddStartingWildcard" : false,
                "IgnoreDirectories" : true,
                "IncludeContentOnly" : true,
                [#-- Only interested in Include attribute --]
                "SuppressContent" : true
            }
        )
    ]
[/#function]

[#-- Combine JSON content to give a single object --]
[#function internalCombineCMDBJSONFiles files]
    [#local result = {} ]
    [#list files as file]
        [#local result = mergeObjects(result, file.ContentsAsJSON!{}) ]
    [/#list]
    [#return result ]
[/#function]

[#-- Assemble a blueprint --]
[#function internalAssembleCMDBBlueprint files ]
    [#return internalCombineCMDBJSONFiles(files) ]
[/#function]

[#-- Convert paths to setting namespaces --]
[#-- Also handle asFile processing and   --]
[#-- General/Sensitive/Builds            --]
[#function  internalAssembleCMDBSettings groups]
    [#local result =
        {
            "General" : {},
            "Builds" : {},
            "Sensitive" : {}
        }
    ]

    [#list groups as group]
        [#list group.Files as file]
            [#local base = file.Filename?remove_ending("." + file.Extension)]
            [#local attribute = base?replace("_", "_")?upper_case]
            [#local namespace =
                concatenate(
                    file.Path?remove_beginning(group.Base)?lower_case?replace("/", " ")?trim?split(" "),
                    "-"
                )
            ]
            [#-- For now remove the "/default" from the front to yield a path --]
            [#-- relative to the CMDB root.                                   --]
            [#-- TODO(mfl): Refactor when asFile contents moved to state of   --]
            [#-- CMDB as part of the createTemplate process                   --]
            [#if file.Path?lower_case?contains("asfile") ]
                [#local content =
                    {
                        attribute : {
                            "Value" : file.Filename,
                            "AsFile" : file.File?remove_beginning("/default")
                        }
                    }
                ]
            [#else]

                [#-- Settings format depends on file extension --]
                [#switch file.Extension?lower_case]
                    [#case "json"]
                    [#case "yaml"]
                    [#case "yml"]
                        [#if file.ContentsAsJSON??]
                            [#local content = file.ContentsAsJSON]
                            [#break]
                        [/#if]
                        [#-- Fall through to handle file generically if no JSON content --]
                    [#default]
                        [#local content =
                            {
                                attribute : {
                                    "Value" : file.Contents,
                                    "FromFile" : file.File
                                }
                            }
                        ]
                        [#break]
                [/#switch]
            [/#if]

            [#-- General by default --]
            [#local category = "General" ]

            [#if file.Filename?lower_case?trim?matches(r"^.*build\.json$")]
                [#-- Builds --]
                [#local category = "Builds"]
            [/#if]
            [#if file.Filename?lower_case?trim?matches(r"^.*credentials\.json|.*sensitive\.json$")]
                [#-- Sensitive --]
                [#local category = "Sensitive" ]
            [/#if]

            [#-- Update the settings structure --]
            [#local result =
                mergeObjects(
                    result,
                    {
                        category : {
                            namespace : content
                        }
                    }
                )
            ]
        [/#list]
    [/#list]

    [#return result ]
[/#function]

[#-- More detailed processing done by stack output handler --]
[#function  internalAssembleCMDBStackOutputs files ]
    [#local result = [] ]

    [#list files as file]
        [#-- Return a simple list of the outputs - the format is opaque at this point --]
        [#local result +=
            [
                {
                    "FilePath" : file.Path,
                    "FileName" : file.Filename,
                    "Content" : [file.ContentsAsJSON!{}]
                }
            ]
        ]
    [/#list]

    [#return result ]
[/#function]

[#function internalAssembleCMDBDefinitions files account region ]
    [#local result = {} ]

    [#list files as file]
        [#local content = file.ContentsAsJSON!{} ]
        [#-- Ignore if not using a definition structure which includes account and region --]
        [#if (content[account][region])?has_content]
            [#local result = mergeObjects(result, content) ]
        [/#if]
    [/#list]

    [#return result ]
[/#function]

[#-- Construct the fragmewnt case statement  --]
[#function  internalAssembleCMDBFragments files]
    [#local result = "" ]

    [#list files as file]

        [#-- Return a simple list of the outputs - the format is opaque at this point --]
        [#local result += file.Contents ]
    [/#list]

    [#-- FTL directive left off the front so we can directly interpret the code via the ?interpret directive --]
    [#return
        valueIfContent(
            [
                [#-- r"[#ftl]", --]
                r'[@debug message="Fragment Id" context=fragmentId enabled=true /]',
                r"[#switch fragmentId]",
                result,
                r"[/#switch]"
            ]?join("\n"),
            result,
            ""
        )
    ]
[/#function]


[#function internalAssembleCMDBTenantFiles tenant filters={} ]
    [#local tenantSection = getCMDBCacheTenantSection(tenant)!{}]
    [#return
        {
            "Blueprint" :
                internalAssembleCMDBJSONFiles(
                    (tenantSection.Paths.Marker)!"",
                    [ [] ],
                    {
                        "MinDepth" : 1,
                        "MaxDepth" : 1
                    },
                    filters
                ),
            "Extensions" :
                internalAssembleCMDBIncludeFiles(
                    (tenantSection.Paths.Extensions)!"",
                    [ [] ],
                    {},
                    filters
                ),
            "Modules" :
                internalAssembleCMDBIncludeFiles(
                    (tenantSection.Paths.Modules)!"",
                    [ [] ],
                    {},
                    filters
                )
        }
    ]
[/#function]

[#function internalAssembleCMDBAccountFiles tenant account filters={} ]
    [#local accountSection = getCMDBCacheAccountSection(tenant, account)!{}]

    [#return
        {
            "Blueprint" :
                internalAssembleCMDBJSONFiles(
                    (accountSection.Paths.Marker)!"",
                    [ [] ],
                    {
                        "MinDepth" : 1,
                        "MaxDepth" : 1
                    },
                    filters
                ),
            "Settings" : [
                {
                    "Files" :
                        findCMDBMatches(
                            (accountSection.Paths.Settings.Config)!"",
                            [ ["shared", r"[^/]+"] ],
                            {
                                "AddStartingWildcard" : false,
                                "MinDepth" : 2,
                                "MaxDepth" : 2
                            },
                            filters +
                            {
                                "IgnoreDirectories" : true
                            }
                        ),
                    "Base" : (accountSection.Paths.Settings.Config)!""
                },
                {
                    "Files" :
                        findCMDBMatches(
                            (accountSection.Paths.Settings.Operations)!"",
                            [ ["shared", r"[^/]+"] ],
                            {
                                "AddStartingWildcard" : false,
                                "MinDepth" : 2,
                                "MaxDepth" : 2
                            },
                            filters +
                            {
                                "IgnoreDirectories" : true
                            }
                        ),
                    "Base" : (accountSection.Paths.Settings.Operations)!""
                }
            ],
            "StackOutputs" :
                findCMDBMatches(
                    (accountSection.Paths.State)!"",
                    [ [r"[^/]+", "shared", r".+"] ],
                    {
                        "AddStartingWildcard" : false,
                        "AddEndingWildcard" : false
                    },
                    filters +
                    {
                        "IgnoreDirectories" : true,
                        "FilenameGlob" : "*-stack.json"
                    }
                ),
            "Extensions" :
                internalAssembleCMDBIncludeFiles(
                    (accountSection.Paths.Extensions)!"",
                    [ [] ],
                    {},
                    filters
                ),
            "Modules" :
                internalAssembleCMDBIncludeFiles(
                    (accountSection.Paths.Modules)!"",
                    [ [] ],
                    {},
                    filters
                )
        }
    ]
[/#function]

[#function internalAssembleCMDBProductFiles tenant product filters={} ]
    [#return
        {
            "Blueprint" :
                internalAssembleCMDBJSONFiles(
                    (getCMDBCacheProductSection(tenant, product).Paths.Marker)!"",
                    [ [] ],
                    {
                        "MinDepth" : 1,
                        "MaxDepth" : 1
                    },
                    filters
                ),
            "Extensions" :
                internalAssembleCMDBIncludeFiles(
                    (accountSection.Paths.Extensions)!"",
                    [ [] ],
                    {},
                    filters
                ),
            "Modules" :
                internalAssembleCMDBIncludeFiles(
                    (accountSection.Paths.Modules)!"",
                    [ [] ],
                    {},
                    filters
                )
        }
    ]
[/#function]

[#function internalAssembleCMDBSegmentFiles tenant product environment segment filters={} ]
    [#local productSection = getCMDBCacheProductSection(tenant, product)!{} ]

    [#-- Check for a directory that isn't one of the other segments --]
    [#local ignoreOtherSegmentsRegex =
        "(?!(" +
        removeValueFromArray(getCMDBSegments(tenant, product, environment), segment)?join("|") +
        ")/).+" ]

    [#return
        {
            "Blueprint" :
                internalAssembleCMDBJSONFiles(
                    (productSection.Paths.Infrastructure.Solutions)!"",
                    [
                        ["shared"],
                        ["shared", segment],
                        [environment],
                        [environment, segment]
                    ],
                    {},
                    filters
                ),
            "Settings" : [
                {
                    "Files" :
                        findCMDBMatches(
                            (productSection.Paths.Settings.Config)!"",
                            [
                                ["shared", ignoreOtherSegmentsRegex],
                                [environment, ignoreOtherSegmentsRegex]
                            ],
                            {
                                "AddStartingWildcard" : false,
                                "AddEndingWildcard" : false
                            },
                            filters +
                            {
                                "IgnoreDirectories" : true
                            }

                        ),
                    "Base" : (productSection.Paths.Settings.Config)!""
                },
                {
                    "Files" :
                        findCMDBMatches(
                            (productSection.Paths.Infrastructure.Builds)!"",
                            [
                                ["shared", ignoreOtherSegmentsRegex],
                                [environment, ignoreOtherSegmentsRegex]
                            ],
                            {
                                "AddStartingWildcard" : false,
                                "AddEndingWildcard" : false
                            },
                            filters +
                            {
                                "IgnoreDirectories" : true
                            }
                        ),
                    "Base" : (productSection.Paths.Infrastructure.Builds)!""
                },
                {
                    "Files" :
                        findCMDBMatches(
                            (productSection.Paths.Settings.Operations)!"",
                            [
                                ["shared", ignoreOtherSegmentsRegex],
                                [environment, ignoreOtherSegmentsRegex]
                            ],
                            {
                                "AddStartingWildcard" : false,
                                "AddEndingWildcard" : false
                            },
                            filters +
                            {
                                "IgnoreDirectories" : true
                            }
                        ),
                    "Base" : (productSection.Paths.Settings.Operations)!""
                }
            ],
            "StackOutputs" :
                findCMDBMatches(
                    (productSection.Paths.State)!"",
                    [
                        [r"[^/]+", "shared", r"[^/]+"],
                        [r"[^/]+", "shared", segment, r".+"],
                        [r"[^/]+", environment, r"[^/]+"],
                        [r"[^/]+", environment, segment, r".+"]
                    ],
                    {
                        "AddStartingWildcard" : false,
                        "AddEndingWildcard" : false
                    },
                    filters +
                    {
                        "IgnoreDirectories" : true,
                        "FilenameGlob" : "*-stack.json"
                    }
                ),
            "Definitions" :
                findCMDBMatches(
                    (productSection.Paths.State)!"",
                    [
                        [r"[^/]+", "shared", r"[^/]+"],
                        [r"[^/]+", "shared", segment, r".+"],
                        [r"[^/]+", environment, r"[^/]+"],
                        [r"[^/]+", environment, segment, r".+"]
                    ],
                    {
                        "AddStartingWildcard" : false,
                        "AddEndingWildcard" : false
                    },
                    filters +
                    {
                        "IgnoreDirectories" : true,
                        "FilenameGlob" : "*-definition.json"
                    }
                ),
            "Fragments" :
                findCMDBMatches(
                    (productSection.Paths.Infrastructure.Solutions)!"",
                    [
                        ["shared", r"[^/]+"],
                        ["shared", segment, r"[^/]+"],
                        [environment, r"[^/]+"],
                        [environment, segment, r"[^/]+"]
                    ],
                    {
                        "AddStartingWildcard" : false,
                        "AddEndingWildcard" : false,
                        "IgnoreDirectories" : true,
                        "FilenameGlob" : "fragment_*.ftl",
                        "IncludeCMDBInformation" : true
                    }
                )

        }
    ]
[/#function]

[#-- Determine the key directories associated with a marker file  --]
[#-- Full analysis can optionally be bypassed where not necessary --]
[#-- Support for aggregate repo structures must be explicitly enabled --]
[#function internalAnalyseCMDBPaths path markerFiles full aggregate=false]
    [#local result = {} ]

    [#-- Analyse paths --]
    [#list markerFiles as markerFile]
        [#local name = markerFile.Path?keep_after_last("/") ]
        [#local rootDir = markerFile.Path ]
        [#if name == "config"]
            [#local rootDir = rootDir?keep_before_last("/") ]
            [#local name = rootDir?keep_after_last("/") ]
        [/#if]
        [#if name?has_content ]
            [#local entry =
                {
                    "Paths" : {
                        "Marker" : markerFile.Path
                    } +
                    attributeIfContent("CMDB", (markerFile.CMDB.BasePath)!"")
                }
            ]

            [#if full]
                [#-- First try the common case of a single cmdb --]
                [#local config =
                    internalGetFirstCMDBMatch(
                        rootDir,
                        [
                            ["config", "settings"]
                        ],
                        {
                            "AddStartingWildcard" : false,
                            "MinDepth" : 2,
                            "MaxDepth" : 2
                        },
                        {
                            "IgnoreFiles" : true
                        }
                    )
                ]
                [#local operations =
                    internalGetFirstCMDBMatch(
                        rootDir,
                        [
                            ["operations", "settings"],
                            ["infrastructure", "operations"]
                        ],
                        {
                            "AddStartingWildcard" : false,
                            "MinDepth" : 2,
                            "MaxDepth" : 2
                        },
                        {
                            "IgnoreFiles" : true
                        }
                    )
                ]
                [#local solutions =
                    internalGetFirstCMDBMatch(
                        rootDir,
                        [
                            ["infrastructure", "solutions"],
                            ["config", "solutionsv2"]
                        ],
                        {
                            "AddStartingWildcard" : false,
                            "MinDepth" : 2,
                            "MaxDepth" : 2
                        },
                        {
                            "IgnoreFiles" : true
                        }
                    )
                ]
                [#local builds =
                    internalGetFirstCMDBMatch(
                        rootDir,
                        [
                            ["infrastructure", "builds"],
                            ["config", "settings"]
                        ],
                        {
                            "AddStartingWildcard" : false,
                            "MinDepth" : 2,
                            "MaxDepth" : 2
                        },
                        {
                            "IgnoreFiles" : true
                        }
                    )
                ]
                [#local state =
                    internalGetFirstCMDBMatch(
                        rootDir,
                        [
                            ["state"],
                            ["infrastructure"]
                        ],
                        {
                            "AddStartingWildcard" : false,
                            "MinDepth" : 1,
                            "MaxDepth" : 1
                        },
                        {
                            "IgnoreFiles" : true
                        }
                    )
                ]
                [#local extensions =
                    internalGetFirstCMDBMatch(
                        rootDir,
                        [
                            ["extensions"]
                        ],
                        {
                            "AddStartingWildcard" : false,
                            "MinDepth" : 1,
                            "MaxDepth" : 1
                        },
                        {
                            "IgnoreFiles" : true
                       }
                    )
                ]
                [#local modules =
                    internalGetFirstCMDBMatch(
                        rootDir,
                        [
                            ["modules"]
                        ],
                        {
                            "AddStartingWildcard" : false,
                            "MinDepth" : 1,
                            "MaxDepth" : 1
                        },
                        {
                            "IgnoreFiles" : true
                       }
                    )
                ]


                [#-- Try more expensive aggregate searches if required --]
                [#if aggregate]
                    [#if !config?has_content]
                        [#local config =
                            internalGetFirstCMDBMatch(
                                path,
                                [
                                    [name, "config", "settings"],
                                    ["config", ".*", name, "settings"]
                                ],
                                {
                                    "AddStartingWildcard" : true
                                },
                                {
                                    "IgnoreFiles" : true
                                }
                            )
                        ]
                    [/#if]
                    [#if !operations?has_content]
                        [#local operations =
                            internalGetFirstCMDBMatch(
                                path,
                                [
                                    [name, "operations", "settings"],
                                    ["operations", ".*", name, "settings"],
                                    [name, "infrastructure", "operations"],
                                    ["infrastructure", ".*", name, "operations"]
                                ],
                                {
                                    "AddStartingWildcard" : true
                                },
                                {
                                    "IgnoreFiles" : true
                                }
                            )
                        ]
                    [/#if]
                    [#if !solutions?has_content]
                        [#local solutions =
                            internalGetFirstCMDBMatch(
                                path,
                                [
                                    [name, "infrastructure", "solutions"],
                                    ["infrastructure", ".*", name, "solutions"],
                                    [name, "config", "solutionsv2"],
                                    ["config", ".*", name, "solutionsv2"]
                                ],
                                {
                                    "AddStartingWildcard" : true
                                },
                                {
                                    "IgnoreFiles" : true
                                }
                            )
                        ]
                    [/#if]
                    [#if !builds?has_content]
                        [#local builds =
                            internalGetFirstCMDBMatch(
                                path,
                                [
                                    [name, "infrastructure", "builds"],
                                    ["infrastructure", ".*", name, "builds"],
                                    [name, "config", "settings"],
                                    ["config", ".*", name, "settings"]
                                ],
                                {
                                    "AddStartingWildcard" : true
                                },
                                {
                                    "IgnoreFiles" : true
                                }
                            )
                        ]
                    [/#if]
                    [#if !state?has_content]
                        [#local state =
                            internalGetFirstCMDBMatch(
                                path,
                                [
                                    [name, "state"],
                                    ["state", ".*", name],
                                    [name, "infrastructure"],
                                    ["infrastructure", ".*", name]
                                ],
                                {
                                    "AddStartingWildcard" : true
                                },
                                {
                                    "IgnoreFiles" : true
                                }
                            )
                        ]
                    [/#if]
                    [#if !extensions?has_content]
                        [#local extensions =
                            internalGetFirstCMDBMatch(
                                path,
                                [
                                    [name, "extensions"],
                                    ["extensions", ".*", name]
                                ],
                                {
                                    "AddStartingWildcard" : true
                                },
                                {
                                    "IgnoreFiles" : true
                                }
                            )
                        ]
                    [/#if]
                    [#if !modules?has_content]
                        [#local extensions =
                            internalGetFirstCMDBMatch(
                                path,
                                [
                                    [name, "modules"],
                                    ["modules", ".*", name]
                                ],
                                {
                                    "AddStartingWildcard" : true
                                },
                                {
                                    "IgnoreFiles" : true
                                }
                            )
                        ]
                    [/#if]
                [/#if]

                [#local entry =
                    mergeObjects(
                        entry,
                        {
                            "Paths" : {
                                "Settings" : {
                                    "Config" : config.File!"",
                                    "Operations" : operations.File!""
                                },
                                "Infrastructure" : {
                                    "Builds" : builds.File!"",
                                    "Solutions" : solutions.File!""
                                },
                                "State" : state.File!"",
                                "Extensions" : extensions.File!"",
                                "Modules" : modules.File!""
                            }
                        }
                    )
                ]
            [/#if]
            [#local result += { name : entry } ]
        [/#if]
    [/#list]
    [#return result ]
[/#function]

[#function internalAnalyseTenantStructure path tenant="" options={} ]
    [#-- Find marker files --]
    [#local markerFiles =
        internalGetCMDBMarkerFiles(
            path,
            arrayIfTrue(
                [
                    [tenant],
                    [tenant, "config"]
                ],
                tenant?has_content,
                [ [] ]
            ),
            r"tenant\.(json|yaml|yml)",
            {
                "IncludeCMDBInformation" : true,
                "FilenameGlob" : r"tenant.*"
            } +
            options
        )
    ]

    [#-- Analyse paths --]
    [#return internalAnalyseCMDBPaths(path, markerFiles, true) ]
[/#function]

[#function internalAnalyseAccountStructure path account=""]
    [#-- Find marker files --]
    [#local markerFiles =
        internalGetCMDBMarkerFiles(
            path,
            arrayIfTrue(
                [
                    [account],
                    [account, "config"]
                ],
                account?has_content,
                [ [] ]
            ),
            r"account\.(json|yaml|yml)",
            {
                "FilenameGlob" : r"account.*"
            }
        )
    ]

    [#-- Analyse paths --]
    [#return internalAnalyseCMDBPaths(path, markerFiles, true) ]

[/#function]

[#function internalAnalyseProductStructure path product=""]
    [#-- Find marker files --]
    [#if product?has_content && path?ends_with(product)]
        [#local markerFiles =
            internalGetCMDBMarkerFiles(
                path,
                [
                    [],
                    ["config"]
                ],
                r"product\.(json|yaml|yml)",
                {
                    "MaxDepth" : 2,
                    "FilenameGlob" : r"product.*"
                }
            )
        ]
    [#else]
        [#-- Setting the max depth is an optimisation that may need --]
        [#-- revisiting depending on refactoring of repo layouts    --]
        [#local markerFiles =
            internalGetCMDBMarkerFiles(
                path,
                arrayIfTrue(
                    [
                        [product],
                        [product, "config"]
                    ],
                    product?has_content,
                    [ [] ]
                ),
                r"product\.(json|yaml|yml)",
                {
                    "MaxDepth" : 3,
                    "FilenameGlob" : r"product.*"
                }
            )
        ]
    [/#if]

    [#-- Analyse paths --]
    [#return internalAnalyseCMDBPaths(path, markerFiles, true) ]

[/#function]

[#function internalAnalyseEnvironmentStructure path environment="" ]
    [#-- Find marker files --]
    [#local markerFiles =
        internalGetCMDBMarkerFiles(
            path,
            arrayIfTrue(
                [
                    [environment]
                ],
                environment?has_content,
                [ [] ]
            ),
            r"environment\.(json|yaml|yml)",
            {
                "MinDepth" : 2,
                "MaxDepth" : 2,
                "FilenameGlob" : r"environment.*"
            } +
            attributeIfContent("AddStartingWildcard", environment, false)
        )
    ]

    [#-- Analyse paths --]
    [#return internalAnalyseCMDBPaths(path, markerFiles, false) ]

[/#function]

[#function internalAnalyseSegmentStructure path segment="" ]
    [#-- Find marker files --]
    [#local markerFiles =
        internalGetCMDBMarkerFiles(
            path,
            arrayIfTrue(
                [
                    [segment]
                ],
                segment?has_content,
                [ [] ]
            ),
            r"segment\.(json|yaml|yml)",
            {
                "AddStartingWildcard" : true,
                "MinDepth" : 2,
                "MaxDepth" : 2,
                "FilenameGlob" : r"segment.*"
            } +
            attributeIfContent("AddStartingWildcard", segment, false)
        )
    ]

    [#-- Analyse paths --]
    [#return internalAnalyseCMDBPaths(path, markerFiles, false) ]

[/#function]

[#function internalFindFirstCMDBPath names=[] ]
    [#-- Iterate through the CMDBS to see if one matches the name(s) requested --]
    [#local cmdbs = getCMDBs({"ActiveOnly" : true}) ]
    [#list asArray(names) as name]
       [#list cmdbs as cmdb]
            [#if cmdb.Name == name]
                [#return cmdb.CMDBPath]
            [/#if]
        [/#list]
    [/#list]

    [#return ""]
[/#function]
